import SwiftUI
import SwiftData
import Charts

// MARK: - Main Spending View (Calendar-based)
struct SpendingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [MonthlyBudget]
    @Query private var scheduled: [ScheduledTransaction]

    @State private var currentMonth = Date()
    @State private var selectedDate  = Calendar.current.startOfDay(for: Date())
    @State private var showAdd       = false
    @State private var viewMode: SpendMode = .calendar

    enum SpendMode { case calendar, chart, budget, savings, scheduled }

    var yearMonth: Int {
        let c = Calendar.current
        return c.component(.year, from: currentMonth) * 100 + c.component(.month, from: currentMonth)
    }
    var monthTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.date, equalTo: currentMonth, toGranularity: .month) }
    }
    var selectedConfirmedTransactions: [Transaction] {
        transactions
            .filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day) && !$0.isPlanned }
            .sorted { $0.date < $1.date }
    }
    var selectedPlannedTransactions: [Transaction] {
        transactions
            .filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day) && $0.isPlanned }
            .sorted { $0.date < $1.date }
    }
    var scheduledForSelectedDate: [ScheduledTransaction] {
        let day = Calendar.current.component(.day, from: selectedDate)
        return scheduled.filter { $0.isActive && $0.dayOfMonth == day }
    }
    var plannedDates: Set<Date> {
        var set = Set<Date>()
        for t in monthTransactions where t.isPlanned {
            set.insert(Calendar.current.startOfDay(for: t.date))
        }
        let cal = Calendar.current
        let year  = cal.component(.year,  from: currentMonth)
        let month = cal.component(.month, from: currentMonth)
        let daysInMonth = cal.range(of: .day, in: .month, for: currentMonth)!.count
        for s in scheduled where s.isActive {
            let day = min(s.dayOfMonth, daysInMonth)
            if let d = cal.date(from: DateComponents(year: year, month: month, day: day)) {
                set.insert(cal.startOfDay(for: d))
            }
        }
        return set
    }
    var monthExpenses: Int { monthTransactions.filter { $0.type == "expense" && !$0.isPlanned }.reduce(0) { $0 + $1.amount } }
    var monthIncome:   Int { monthTransactions.filter { $0.type == "income"  && !$0.isPlanned }.reduce(0) { $0 + $1.amount } }
    var monthBudgets:  [MonthlyBudget] { budgets.filter { $0.yearMonth == yearMonth } }

    var dayTotals: [Date: (income: Int, expense: Int)] {
        var dict: [Date: (income: Int, expense: Int)] = [:]
        for t in monthTransactions where !t.isPlanned {
            let d = Calendar.current.startOfDay(for: t.date)
            var v = dict[d] ?? (0, 0)
            if t.type == "income" { v.income += t.amount } else { v.expense += t.amount }
            dict[d] = v
        }
        return dict
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: 헤더
            HStack {
                Button {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                }.buttonStyle(.plain)

                Text(monthString(currentMonth))
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)

                Button {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                }.buttonStyle(.plain)

                HStack(spacing: 14) {
                    toolbarBtn(icon: "chart.bar.fill",         mode: .chart)
                    toolbarBtn(icon: "list.bullet.rectangle",  mode: .budget)
                    toolbarBtn(icon: "building.columns.fill",  mode: .savings)
                    toolbarBtn(icon: "arrow.clockwise.circle", mode: .scheduled)
                    if viewMode == .calendar {
                        Button { showAdd = true } label: {
                            Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.leading, 12)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // MARK: 월 요약
            HStack(spacing: 0) {
                summaryCell(label: "수입", value: monthIncome, color: .blue)
                Divider().frame(height: 30)
                summaryCell(label: "지출", value: monthExpenses, color: .red)
                Divider().frame(height: 30)
                let bal = monthIncome - monthExpenses
                summaryCell(label: "잔액", value: bal, color: bal >= 0 ? .primary : .red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))

            Divider()

            // MARK: 콘텐츠
            switch viewMode {
            case .calendar:
                SpendingCalendarGrid(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate,
                    dayTotals: dayTotals,
                    plannedDates: plannedDates
                )
                Divider()
                SelectedDayDetail(
                    date: selectedDate,
                    confirmedTransactions: selectedConfirmedTransactions,
                    plannedTransactions: selectedPlannedTransactions,
                    scheduledForDay: scheduledForSelectedDate,
                    onAdd: { showAdd = true }
                )

            case .chart:
                ScrollView { SpendingChartSection(transactions: monthTransactions).padding(.top, 12) }

            case .budget:
                ScrollView {
                    BudgetSection(transactions: monthTransactions, budgets: monthBudgets, yearMonth: yearMonth)
                        .padding(.top, 12)
                }

            case .savings:
                ScrollView { SavingsSection().padding(.top, 8) }

            case .scheduled:
                ScrollView { ScheduledTransactionSection().padding(.top, 8) }
            }
        }
        .navigationTitle("가계부")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAdd) {
            AddTransactionSheet(
                defaultDate: selectedDate,
                defaultIsPlanned: selectedDate > Calendar.current.startOfDay(for: Date())
            )
            .presentationDetents([.medium, .large])
        }
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button { showAdd = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                        Text("거래 추가").font(.system(size: 13))
                    }.foregroundStyle(.secondary)
                }.buttonStyle(.plain).padding(.leading, 16)
                Spacer()
            }
            .padding(.vertical, 12).background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
        #endif
    }

    @ViewBuilder
    func toolbarBtn(icon: String, mode: SpendMode) -> some View {
        Button {
            withAnimation { viewMode = viewMode == mode ? .calendar : mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(viewMode == mode ? .primary : .secondary)
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    func summaryCell(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(formatPrice(value))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    func monthString(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월"
        return f.string(from: d)
    }
}

// MARK: - Calendar Grid
struct SpendingCalendarGrid: View {
    var currentMonth: Date
    @Binding var selectedDate: Date
    var dayTotals: [Date: (income: Int, expense: Int)]
    var plannedDates: Set<Date> = []

    let cal = Calendar.current
    let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var days: [Date?] {
        var comps = cal.dateComponents([.year, .month], from: currentMonth)
        let firstDay = cal.date(from: comps)!
        let offset   = cal.component(.weekday, from: firstDay) - 1
        let count    = cal.range(of: .day, in: .month, for: currentMonth)!.count
        var result: [Date?] = Array(repeating: nil, count: offset)
        for d in 1...count {
            comps.day = d
            result.append(cal.date(from: comps))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { i in
                    Text(weekdays[i])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(i == 0 ? Color.red.opacity(0.8) : i == 6 ? Color.blue.opacity(0.8) : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.03))

            Divider()

            let rows = days.chunked(into: 7)
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { c in
                            let d = rows[r][c]
                            CalDayCell(
                                date: d,
                                isSelected: d.map { cal.isDate($0, inSameDayAs: selectedDate) } ?? false,
                                isToday:    d.map { cal.isDateInToday($0) } ?? false,
                                totals:     d.flatMap { dayTotals[$0] },
                                hasPlanned: d.map { plannedDates.contains(cal.startOfDay(for: $0)) } ?? false,
                                colIndex:   c
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { if let d { selectedDate = d } }
                            if c < 6 { Divider() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if r < rows.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

struct CalDayCell: View {
    var date: Date?
    var isSelected: Bool
    var isToday: Bool
    var totals: (income: Int, expense: Int)?
    var hasPlanned: Bool = false
    var colIndex: Int

    var numColor: Color {
        if colIndex == 0 { return .red }
        if colIndex == 6 { return .blue }
        return .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let date {
                let day = Calendar.current.component(.day, from: date)
                ZStack {
                    if isSelected {
                        Circle().fill(Color.primary).frame(width: 24, height: 24)
                    } else if isToday {
                        Circle().stroke(Color.primary, lineWidth: 1.5).frame(width: 24, height: 24)
                    }
                    Text("\(day)")
                        .font(.system(size: 12, weight: isToday || isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color(white: 1) : numColor)
                }
                .overlay(alignment: .topTrailing) {
                    if hasPlanned && !isSelected {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                            .offset(x: 3, y: -2)
                    }
                }

                if let t = totals {
                    if t.expense > 0 {
                        Text(compact(t.expense))
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                    if t.income > 0 {
                        Text(compact(t.income))
                            .font(.system(size: 9))
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .padding(.horizontal, 3)
        .padding(.vertical, 5)
        .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
    }

    func compact(_ p: Int) -> String {
        return "\(p)"
    }
}

// MARK: - 선택 날짜 거래 목록
struct SelectedDayDetail: View {
    @Environment(\.modelContext) private var modelContext
    var date: Date
    var confirmedTransactions: [Transaction]
    var plannedTransactions: [Transaction]
    var scheduledForDay: [ScheduledTransaction]
    var onAdd: () -> Void

    var dayExpense: Int { confirmedTransactions.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount } }
    var dayIncome:  Int { confirmedTransactions.filter { $0.type == "income"  }.reduce(0) { $0 + $1.amount } }
    var hasPlanned: Bool { !plannedTransactions.isEmpty || !scheduledForDay.isEmpty }
    var plannedCount: Int { plannedTransactions.count + scheduledForDay.count }

    var body: some View {
        VStack(spacing: 0) {
            // 날짜 헤더
            HStack(spacing: 8) {
                Text(dayString(date))
                    .font(.system(size: 13, weight: .semibold))
                if dayExpense > 0 {
                    Text("-\(formatPrice(dayExpense))").font(.system(size: 12)).foregroundStyle(.red)
                }
                if dayIncome > 0 {
                    Text("+\(formatPrice(dayIncome))").font(.system(size: 12)).foregroundStyle(.blue)
                }
                if hasPlanned {
                    Text("예정 \(plannedCount)건")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                Button { onAdd() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20)).foregroundStyle(.primary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Color.secondary.opacity(0.04))

            Divider()

            if confirmedTransactions.isEmpty && !hasPlanned {
                VStack(spacing: 6) {
                    Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(.secondary.opacity(0.35))
                    Text("거래 내역이 없어요").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // 확정 거래
                        ForEach(confirmedTransactions) { txn in
                            TransactionRow(transaction: txn)
                            if txn.id != confirmedTransactions.last?.id || hasPlanned {
                                Divider().padding(.leading, 52)
                            }
                        }

                        // 예정 섹션
                        if hasPlanned {
                            HStack {
                                Text("예정")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(Capsule())
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, confirmedTransactions.isEmpty ? 12 : 8)
                            .padding(.bottom, 2)

                            ForEach(plannedTransactions) { txn in
                                PlannedTransactionRow(transaction: txn) {
                                    txn.isPlanned = false
                                    try? modelContext.save()
                                }
                                Divider().padding(.leading, 52)
                            }
                            ForEach(scheduledForDay) { s in
                                ScheduledPreviewRow(scheduled: s) {
                                    let t = Transaction(
                                        amount: s.amount, type: s.type, category: s.category,
                                        paymentMethod: s.paymentMethod, memo: s.title, date: date
                                    )
                                    modelContext.insert(t)
                                    try? modelContext.save()
                                }
                                if s.id != scheduledForDay.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func dayString(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
    }
}

// MARK: - 예정 거래 행 (isPlanned == true인 Transaction)
struct PlannedTransactionRow: View {
    var transaction: Transaction
    var onConfirm: () -> Void

    var catColor: Color {
        Color(hex: Transaction.categoryColor[transaction.category] ?? "9CA3AF") ?? .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(catColor.opacity(0.08)).frame(width: 36, height: 36)
                Image(systemName: Transaction.categoryIcon[transaction.category] ?? "ellipsis.circle")
                    .font(.system(size: 15)).foregroundStyle(catColor.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.memo.isEmpty ? transaction.category : transaction.memo)
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                Text(transaction.category).font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(transaction.formattedAmount)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(transaction.type == "income" ? Color.blue.opacity(0.55) : Color.secondary)
            Button { onConfirm() } label: {
                Text("확정")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.orange).clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - 정기 거래 예정 행 (ScheduledTransaction)
struct ScheduledPreviewRow: View {
    var scheduled: ScheduledTransaction
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13)).foregroundStyle(Color.orange.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(scheduled.title)
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                Text("정기 \(scheduled.type == "income" ? "수입" : "지출") · \(scheduled.category)")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            Spacer()
            let sign = scheduled.type == "income" ? "+" : "-"
            Text("\(sign)\(formatPrice(scheduled.amount))")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(scheduled.type == "income" ? Color.blue.opacity(0.55) : Color.secondary)
            Button { onConfirm() } label: {
                Text("확정")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.orange).clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - 월 요약 카드
struct MonthSummaryCard: View {
    var income: Int
    var expense: Int
    var balance: Int { income - expense }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("수입")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(formatPrice(income))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("지출")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(formatPrice(expense))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("잔액")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(formatPrice(balance))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(balance >= 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 내역 섹션
struct TransactionListSection: View {
    var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    var grouped: [(Date, [Transaction])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: transactions) { cal.startOfDay(for: $0.date) }
        return dict.sorted { $0.key > $1.key }
    }

    var body: some View {
        if transactions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "creditcard")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.4))
                Text("이번 달 거래 내역이 없어요")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            VStack(spacing: 12) {
                ForEach(grouped, id: \.0) { date, dayTxns in
                    DayTransactionGroup(date: date, transactions: dayTxns)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - 일별 거래 그룹
struct DayTransactionGroup: View {
    var date: Date
    var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    var dayExpense: Int { transactions.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount } }
    var dayIncome:  Int { transactions.filter { $0.type == "income"  }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(dayString(date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if dayIncome > 0 {
                    Text("+\(formatPrice(dayIncome))")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
                if dayExpense > 0 {
                    Text("-\(formatPrice(dayExpense))")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .padding(.leading, 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            VStack(spacing: 0) {
                ForEach(transactions) { txn in
                    TransactionRow(transaction: txn)
                    if txn.id != transactions.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    func dayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
    }
}

// MARK: - 거래 행
struct TransactionRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var transaction: Transaction
    @State private var showEdit = false

    var catColor: Color {
        Color(hex: Transaction.categoryColor[transaction.category] ?? "9CA3AF") ?? .secondary
    }
    var catIcon: String {
        Transaction.categoryIcon[transaction.category] ?? "ellipsis.circle"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(catColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: catIcon)
                    .font(.system(size: 15))
                    .foregroundStyle(catColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.memo.isEmpty ? transaction.category : transaction.memo)
                    .font(.system(size: 15))
                HStack(spacing: 4) {
                    Text(transaction.category)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    if !transaction.subcategory.isEmpty {
                        Text("·").font(.system(size: 12)).foregroundStyle(.tertiary)
                        Text(transaction.subcategory)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !transaction.store.isEmpty {
                        Text("·").font(.system(size: 12)).foregroundStyle(.tertiary)
                        Text(transaction.store)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Text("·").font(.system(size: 12)).foregroundStyle(.tertiary)
                    Text(transaction.paymentMethod)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(transaction.formattedAmount)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(transaction.type == "income" ? Color.blue : Color.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { showEdit = true }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(transaction)
                try? modelContext.save()
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showEdit) {
            AddTransactionSheet(editTransaction: transaction)
        }
    }
}

// MARK: - 예산 섹션
struct BudgetSection: View {
    @Environment(\.modelContext) private var modelContext
    var transactions: [Transaction]
    var budgets: [MonthlyBudget]
    var yearMonth: Int

    @State private var showSetBudget: String? = nil

    var expenseByCategory: [String: Int] {
        Dictionary(grouping: transactions.filter { $0.type == "expense" }, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Transaction.expenseCategories, id: \.self) { cat in
                let spent = expenseByCategory[cat] ?? 0
                let budget = budgets.first(where: { $0.category == cat })
                BudgetCategoryRow(
                    category: cat,
                    spent: spent,
                    budget: budget,
                    onSetBudget: { showSetBudget = cat }
                )
            }
        }
        .padding(.horizontal, 16)
        .sheet(item: $showSetBudget) { cat in
            SetBudgetSheet(
                category: cat,
                existing: budgets.first(where: { $0.category == cat }),
                yearMonth: yearMonth
            )
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - 예산 카테고리 행
struct BudgetCategoryRow: View {
    var category: String
    var spent: Int
    var budget: MonthlyBudget?
    var onSetBudget: () -> Void

    var catColor: Color {
        Color(hex: Transaction.categoryColor[category] ?? "9CA3AF") ?? .secondary
    }
    var catIcon: String {
        Transaction.categoryIcon[category] ?? "ellipsis.circle"
    }
    var ratio: Double {
        guard let b = budget, b.limitAmount > 0 else { return 0 }
        return min(Double(spent) / Double(b.limitAmount), 1.0)
    }
    var isOver: Bool {
        guard let b = budget else { return false }
        return spent > b.limitAmount
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(catColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: catIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(catColor)
                }

                Text(category)
                    .font(.system(size: 14))

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatPrice(spent))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOver ? .red : .primary)
                    if let b = budget {
                        Text("/ \(formatPrice(b.limitAmount))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Button("예산 설정") { onSetBudget() }
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, budget != nil ? 8 : 12)

            if budget != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isOver ? Color.red : catColor)
                            .frame(width: max(geo.size.width * ratio, ratio > 0 ? 6 : 0), height: 6)
                            .animation(.spring(duration: 0.4), value: ratio)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { if budget != nil { onSetBudget() } }
    }
}

// MARK: - 예산 설정 시트
struct SetBudgetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var category: String
    var existing: MonthlyBudget?
    var yearMonth: Int

    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("\(category) 예산") {
                    HStack {
                        Image(systemName: "wonsign").foregroundStyle(.secondary)
                        TextField("월 예산 금액", text: $amountText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }
                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            if let b = existing { modelContext.delete(b); try? modelContext.save() }
                            dismiss()
                        } label: {
                            Text("예산 삭제")
                        }
                    }
                }
            }
            .navigationTitle("예산 설정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { submit() }
                        .disabled(amountText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let b = existing { amountText = "\(b.limitAmount)" }
        }
    }

    func submit() {
        let amount = Int(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        guard amount > 0 else { return }
        if let b = existing {
            b.limitAmount = amount
        } else {
            let b = MonthlyBudget(category: category, limitAmount: amount, yearMonth: yearMonth)
            modelContext.insert(b)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 분석 섹션
struct SpendingChartSection: View {
    var transactions: [Transaction]

    var expenseByCategory: [(String, Int)] {
        let dict = Dictionary(grouping: transactions.filter { $0.type == "expense" }, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return dict.sorted { $0.value > $1.value }.filter { $0.value > 0 }
    }

    var totalExpense: Int { expenseByCategory.reduce(0) { $0 + $1.1 } }

    var body: some View {
        VStack(spacing: 16) {
            if expenseByCategory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("지출 내역이 없어요")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                // 도넛 차트
                VStack(spacing: 12) {
                    ZStack {
                        Chart(expenseByCategory, id: \.0) { cat, amount in
                            SectorMark(
                                angle: .value("금액", amount),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(Color(hex: Transaction.categoryColor[cat] ?? "9CA3AF") ?? .secondary)
                        }
                        .frame(height: 200)

                        VStack(spacing: 2) {
                            Text(formatPrice(totalExpense))
                                .font(.system(size: 18, weight: .bold))
                            Text("총 지출")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(16)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)

                // 카테고리 리스트
                VStack(spacing: 0) {
                    ForEach(expenseByCategory, id: \.0) { cat, amount in
                        let catColor = Color(hex: Transaction.categoryColor[cat] ?? "9CA3AF") ?? Color.secondary
                        HStack(spacing: 12) {
                            Circle()
                                .fill(catColor)
                                .frame(width: 10, height: 10)
                            Text(cat)
                                .font(.system(size: 14))
                            Spacer()
                            Text(formatPrice(amount))
                                .font(.system(size: 14, weight: .medium))
                            Text(totalExpense > 0 ? "\(Int(Double(amount) / Double(totalExpense) * 100))%" : "")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if cat != expenseByCategory.last?.0 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - 거래 추가/편집 시트
struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editTransaction: Transaction? = nil
    var defaultDate: Date = Date()
    var defaultIsPlanned: Bool = false

    @State private var type = "expense"
    @State private var amountText = ""
    @State private var category = "중고거래"
    @State private var subcategory = ""
    @State private var paymentMethod = "카드"
    @State private var store = ""
    @State private var customStores: [String] = UserDefaults.standard.stringArray(forKey: "customStores") ?? []
    @State private var showManageStores = false
    @State private var customExpenseCategories: [String] = UserDefaults.standard.stringArray(forKey: "customExpenseCategories") ?? []
    @State private var customIncomeCategories: [String] = UserDefaults.standard.stringArray(forKey: "customIncomeCategories") ?? []
    @State private var showManageCategories = false
    @State private var memo = ""
    @State private var date = Date()
    @State private var isPlanned = false

    var isEditing: Bool { editTransaction != nil }
    var accentColor: Color { type == "expense" ? .red : .blue }
    var categories: [String] {
        type == "expense"
            ? Transaction.expenseCategories + customExpenseCategories
            : Transaction.incomeCategories + customIncomeCategories
    }

    @State private var showDatePicker = false

    var formattedAmount: String {
        let n = Int(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        let f = NumberFormatter(); f.numberStyle = .decimal
        return "₩" + (f.string(from: NSNumber(value: n)) ?? "0")
    }

    var dateChip: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy. M. d."
        let prefix = Calendar.current.isDateInToday(date) ? "오늘, " : ""
        return prefix + f.string(from: date)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: 수입 / 지출 세그먼트
                HStack(spacing: 0) {
                    ForEach([("수입", "income"), ("지출", "expense")], id: \.1) { label, val in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                type = val
                                category = val == "expense"
                                    ? Transaction.expenseCategories[0]
                                    : Transaction.incomeCategories[0]
                                subcategory = ""
                            }
                        } label: {
                            Text(label)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(type == val
                                    ? (val == "expense" ? Color.red : Color.blue)
                                    : Color.clear)
                                .foregroundStyle(type == val ? .white : Color.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // MARK: 금액
                VStack(alignment: .leading, spacing: 4) {
                    TextField("금액 입력", text: $amountText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1))

                    if !amountText.isEmpty {
                        Text(formattedAmount)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.leading, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // MARK: 분류
                infoRow(label: type == "expense" ? "지출 분류" : "수입 분류") {
                    let catColor = Color(hex: Transaction.categoryColor[category] ?? "9CA3AF") ?? .secondary
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(categories, id: \.self) { cat in
                                Button { withAnimation { category = cat } } label: {
                                    Label(cat, systemImage: Transaction.categoryIcon[cat] ?? "tag")
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Circle().fill(catColor).frame(width: 8, height: 8)
                                Text(category)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button { showManageCategories = true } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .sheet(isPresented: $showManageCategories, onDismiss: {
                    customExpenseCategories = UserDefaults.standard.stringArray(forKey: "customExpenseCategories") ?? []
                    customIncomeCategories  = UserDefaults.standard.stringArray(forKey: "customIncomeCategories")  ?? []
                }) {
                    ManageCategoriesSheet()
                }

                // 구독 서브카테고리
                if category == "구독" {
                    infoRow(label: "구독 서비스") {
                        Menu {
                            Button { subcategory = "" } label: {
                                HStack {
                                    Text("선택 안 함")
                                    if subcategory.isEmpty { Image(systemName: "checkmark") }
                                }
                            }
                            Divider()
                            ForEach(Transaction.subscriptionSubcategories, id: \.self) { sub in
                                Button { subcategory = sub } label: {
                                    HStack {
                                        Text(sub)
                                        if subcategory == sub { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(subcategory.isEmpty ? "서비스 선택" : subcategory)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(subcategory.isEmpty ? .secondary : .primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().padding(.horizontal, 16)

                // MARK: 결제수단
                if type == "expense" {
                    infoRow(label: "결제 수단") {
                        HStack(spacing: 6) {
                            ForEach(Transaction.paymentMethods, id: \.self) { method in
                                let isSel = paymentMethod == method
                                Button { withAnimation { paymentMethod = method } } label: {
                                    Text(method)
                                        .font(.system(size: 12, weight: isSel ? .semibold : .regular))
                                        .foregroundStyle(isSel ? accentColor : .secondary)
                                        .padding(.horizontal, 9).padding(.vertical, 4)
                                        .background(isSel ? accentColor.opacity(0.1) : Color.clear)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(isSel ? accentColor.opacity(0.4) : Color.secondary.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider().padding(.horizontal, 16)

                    // MARK: 구매처
                    infoRow(label: "판매처") {
                        HStack(spacing: 8) {
                            Menu {
                                Button { withAnimation { store = "" } } label: {
                                    Label("없음", systemImage: "xmark")
                                }
                                Divider()
                                ForEach(Transaction.stores, id: \.self) { s in
                                    Button { withAnimation { store = s } } label: {
                                        Label(s, systemImage: Transaction.storeIcon[s] ?? "bag")
                                    }
                                }
                                if !customStores.isEmpty {
                                    Divider()
                                    ForEach(customStores, id: \.self) { s in
                                        Button { withAnimation { store = s } } label: {
                                            Label(s, systemImage: "tag")
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    if store.isEmpty {
                                        Text("선택 안 함")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Image(systemName: Transaction.storeIcon[store] ?? "tag")
                                            .font(.system(size: 11))
                                        Text(store)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.primary)
                                    }
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Button { showManageStores = true } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .sheet(isPresented: $showManageStores, onDismiss: {
                        customStores = UserDefaults.standard.stringArray(forKey: "customStores") ?? []
                    }) {
                        ManageStoresSheet()
                    }

                    Divider().padding(.horizontal, 16)
                }

                // MARK: 날짜
                infoRow(label: "날짜") {
                    Button { showDatePicker.toggle() } label: {
                        Text(dateChip)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDatePicker, arrowEdge: .trailing) {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                            .frame(width: 220)
                            .scaleEffect(0.88, anchor: .center)
                            .frame(width: 200, height: 210).clipped()
                            .padding(8)
                            .onChange(of: date) { _, _ in showDatePicker = false }
                    }
                }

                Divider().padding(.horizontal, 16)

                // MARK: 메모
                TextField("메모", text: $memo)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider().padding(.horizontal, 16)

                // MARK: 예정 여부
                infoRow(label: "예정으로 저장") {
                    Toggle("", isOn: $isPlanned)
                        .labelsHidden()
                        .tint(.orange)
                }

                Spacer()

                // MARK: 취소 / 기록
                let canSubmit = !amountText.trimmingCharacters(in: .whitespaces).isEmpty
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        Text("취소")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain)

                    Button { submit() } label: {
                        Text(isEditing ? "저장" : "기록")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(canSubmit ? .white : .secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(canSubmit ? accentColor : Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain).disabled(!canSubmit)
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
        }
        .onAppear {
            if editTransaction == nil {
                date = defaultDate
                isPlanned = defaultIsPlanned
            }
            loadEdit()
        }
    }

    @ViewBuilder
    func infoRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    func loadEdit() {
        guard let t = editTransaction else { return }
        type = t.type
        amountText = "\(t.amount)"
        category = t.category
        subcategory = t.subcategory
        paymentMethod = t.paymentMethod
        memo = t.memo
        date = t.date
        isPlanned = t.isPlanned
        store = t.store
    }

    var resolvedStore: String { store }

    func submit() {
        let amount = Int(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        guard amount > 0 else { return }
        if let t = editTransaction {
            t.type = type; t.amount = amount; t.category = category
            t.subcategory = subcategory
            t.paymentMethod = paymentMethod; t.memo = memo; t.date = date
            t.isPlanned = isPlanned; t.store = resolvedStore
        } else {
            let t = Transaction(
                amount: amount, type: type, category: category,
                paymentMethod: paymentMethod, memo: memo, date: date,
                isPlanned: isPlanned, store: resolvedStore, subcategory: subcategory
            )
            modelContext.insert(t)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 적금 섹션
struct SavingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsAccount.startDate, order: .reverse) private var accounts: [SavingsAccount]
    @State private var showAdd = false

    var totalSaved: Int { accounts.reduce(0) { $0 + $1.totalPaid } }
    var totalTarget: Int { accounts.filter { $0.targetAmount > 0 }.reduce(0) { $0 + $1.targetAmount } }

    var body: some View {
        VStack(spacing: 16) {

            // 요약 카드
            if !accounts.isEmpty {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("총 납입액")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(formatPrice(totalSaved))
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(.indigo)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().frame(height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("계좌 수")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("\(accounts.count)개")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)

                    Divider().frame(height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("이번 달 미납")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        let unpaid = accounts.filter { !$0.isPaidThisMonth && $0.remainingMonths > 0 }.count
                        Text(unpaid == 0 ? "없음" : "\(unpaid)건")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(unpaid == 0 ? .green : .orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                }
                .padding(16)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }

            // 계좌 목록
            if accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("등록된 적금 계좌가 없어요")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                    Button { showAdd = true } label: {
                        Text("적금 추가")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.indigo).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
            } else {
                VStack(spacing: 12) {
                    ForEach(accounts) { account in
                        SavingsAccountCard(account: account)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            #endif
        }
        .sheet(isPresented: $showAdd) {
            AddSavingsAccountSheet()
        }
    }
}

// MARK: - 적금 계좌 카드
struct SavingsAccountCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var account: SavingsAccount
    @State private var showDetail = false
    @State private var showEdit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 상단: 이름 + 은행 + 만기까지
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.indigo.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 6) {
                        if !account.bank.isEmpty {
                            Text(account.bank)
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        if account.interestRate > 0 {
                            Text("연 \(String(format: "%.1f", account.interestRate))%")
                                .font(.system(size: 12)).foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if account.remainingMonths > 0 {
                        Text("D-\(account.remainingMonths * 30)")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                        Text("만기 \(monthString(account.endDate))")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        Text("만기 완료")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // 진행 바
            if account.targetAmount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.indigo, .purple],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(geo.size.width * account.progressRatio, account.progressRatio > 0 ? 8 : 0),
                                    height: 8
                                )
                                .animation(.spring(duration: 0.5), value: account.progressRatio)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text(formatPrice(account.totalPaid))
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.indigo)
                        Spacer()
                        Text("목표 \(formatPrice(account.targetAmount))")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("(\(Int(account.progressRatio * 100))%)")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            Divider().opacity(0.3)

            // 하단: 월 납입액 + 이번 달 납입 버튼 + 내역 보기
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("월 납입액")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(formatPrice(account.monthlyAmount))
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 32)

                // 이번 달 납입 버튼
                Button {
                    if account.isPaidThisMonth {
                        // 이번 달 납입 취소
                        let cal = Calendar.current
                        if let payment = account.payments.first(where: { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }) {
                            modelContext.delete(payment)
                            try? modelContext.save()
                        }
                    } else {
                        let payment = SavingsPayment(
                            amount: account.monthlyAmount,
                            date: Date(),
                            account: account
                        )
                        account.payments.append(payment)
                        modelContext.insert(payment)
                        try? modelContext.save()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: account.isPaidThisMonth ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text(account.isPaidThisMonth ? "납입 완료" : "이번 달 납입")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(account.isPaidThisMonth ? .green : .indigo)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        account.isPaidThisMonth
                        ? Color.green.opacity(0.12)
                        : Color.indigo.opacity(0.12)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)

                Divider().frame(height: 32)

                // 내역 보기
                Button { showDetail = true } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button { showEdit = true } label: { Label("편집", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                modelContext.delete(account)
                try? modelContext.save()
            } label: { Label("삭제", systemImage: "trash") }
        }
        .sheet(isPresented: $showDetail) {
            SavingsDetailSheet(account: account)
        }
        .sheet(isPresented: $showEdit) {
            AddSavingsAccountSheet(editAccount: account)
        }
    }

    func monthString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yy년 M월"
        return f.string(from: d)
    }
}

// MARK: - 적금 납입 내역 시트
struct SavingsDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var account: SavingsAccount
    @State private var showAddPayment = false

    var sortedPayments: [SavingsPayment] {
        account.payments.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("총 납입액", systemImage: "wonsign.circle")
                        Spacer()
                        Text(formatPrice(account.totalPaid))
                            .foregroundStyle(.indigo).fontWeight(.semibold)
                    }
                    HStack {
                        Label("납입 횟수", systemImage: "number.circle")
                        Spacer()
                        Text("\(account.payments.count)회")
                    }
                    if account.targetAmount > 0 {
                        HStack {
                            Label("달성률", systemImage: "chart.bar")
                            Spacer()
                            Text("\(Int(account.progressRatio * 100))%")
                                .foregroundStyle(.purple)
                        }
                    }
                } header: { Text("요약") }

                Section {
                    if sortedPayments.isEmpty {
                        Text("납입 기록이 없어요")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    } else {
                        ForEach(sortedPayments) { payment in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dateString(payment.date))
                                        .font(.system(size: 14))
                                    if !payment.memo.isEmpty {
                                        Text(payment.memo)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(formatPrice(payment.amount))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { i in
                                modelContext.delete(sortedPayments[i])
                            }
                            try? modelContext.save()
                        }
                    }
                } header: { Text("납입 내역") }
            }
            .navigationTitle(account.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddPayment = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPayment) {
            AddPaymentSheet(account: account)
        }
    }

    func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: d)
    }
}

// MARK: - 납입 기록 추가 시트
struct AddPaymentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var account: SavingsAccount

    @State private var amountText: String = ""
    @State private var date = Date()
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("납입 금액") {
                    HStack {
                        Image(systemName: "wonsign").foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }
                Section("상세") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    TextField("메모 (선택)", text: $memo)
                }
            }
            .navigationTitle("납입 기록 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { submit() }
                        .disabled(amountText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            amountText = account.monthlyAmount > 0 ? "\(account.monthlyAmount)" : ""
        }
    }

    func submit() {
        let amount = Int(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        guard amount > 0 else { return }
        let payment = SavingsPayment(amount: amount, date: date, memo: memo, account: account)
        account.payments.append(payment)
        modelContext.insert(payment)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 적금 계좌 추가/편집 시트
struct AddSavingsAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editAccount: SavingsAccount? = nil

    @State private var name = ""
    @State private var bank = ""
    @State private var monthlyText = ""
    @State private var targetText = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 12, to: Date()) ?? Date()
    @State private var rateText = ""
    @State private var memo = ""

    var isEditing: Bool { editAccount != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("적금 이름 (예: 청년희망적금)", text: $name)
                    TextField("은행 (예: 국민은행)", text: $bank)
                }
                Section("금액") {
                    HStack {
                        Text("월 납입액")
                        Spacer()
                        TextField("0", text: $monthlyText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                        Text("원").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("목표 금액")
                        Spacer()
                        TextField("0 (선택)", text: $targetText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                        Text("원").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("연 금리")
                        Spacer()
                        TextField("0.0", text: $rateText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                        Text("%").foregroundStyle(.secondary)
                    }
                }
                Section("기간") {
                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    DatePicker("만기일", selection: $endDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }
                Section("메모") {
                    TextField("메모 (선택)", text: $memo, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "적금 편집" : "적금 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "저장" : "추가") { submit() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { loadEdit() }
    }

    func loadEdit() {
        guard let a = editAccount else { return }
        name = a.name; bank = a.bank
        monthlyText = a.monthlyAmount > 0 ? "\(a.monthlyAmount)" : ""
        targetText = a.targetAmount > 0 ? "\(a.targetAmount)" : ""
        startDate = a.startDate; endDate = a.endDate
        rateText = a.interestRate > 0 ? String(format: "%.1f", a.interestRate) : ""
        memo = a.memo
    }

    func submit() {
        let monthly = Int(monthlyText.replacingOccurrences(of: ",", with: "")) ?? 0
        let target  = Int(targetText.replacingOccurrences(of: ",", with: "")) ?? 0
        let rate    = Double(rateText) ?? 0
        if let a = editAccount {
            a.name = name.trimmingCharacters(in: .whitespaces)
            a.bank = bank; a.monthlyAmount = monthly
            a.targetAmount = target; a.startDate = startDate
            a.endDate = endDate; a.interestRate = rate; a.memo = memo
        } else {
            let a = SavingsAccount(
                name: name.trimmingCharacters(in: .whitespaces),
                bank: bank, monthlyAmount: monthly, targetAmount: target,
                startDate: startDate, endDate: endDate, interestRate: rate, memo: memo
            )
            modelContext.insert(a)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 정기 거래 섹션
struct ScheduledTransactionSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduledTransaction.createdAt) private var items: [ScheduledTransaction]
    @State private var showAdd = false

    var activeIncome:  Int { items.filter { $0.isActive && $0.type == "income"  }.reduce(0) { $0 + $1.amount } }
    var activeExpense: Int { items.filter { $0.isActive && $0.type == "expense" }.reduce(0) { $0 + $1.amount } }
    var incomeItems:  [ScheduledTransaction] { items.filter { $0.type == "income"  } }
    var expenseItems: [ScheduledTransaction] { items.filter { $0.type == "expense" } }

    var body: some View {
        VStack(spacing: 16) {
            // 요약 카드
            if !items.isEmpty {
                let net = activeIncome - activeExpense
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("월 정기 수입").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("+\(formatPrice(activeIncome))")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(.blue)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Divider().frame(height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("월 정기 지출").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("-\(formatPrice(activeExpense))")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(.red)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 16)
                    Divider().frame(height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("순 정기").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text((net >= 0 ? "+" : "") + formatPrice(net))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(net >= 0 ? Color.primary : Color.red)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 16)
                }
                .padding(16)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }

            // 헤더
            HStack {
                Text("정기 거래 목록")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { showAdd = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text("추가").font(.system(size: 13))
                    }.foregroundStyle(.orange)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 40)).foregroundStyle(.secondary.opacity(0.35))
                    Text("등록된 정기 거래가 없어요")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                    Text("매달 반복되는 수입·지출을 등록하면\n캘린더에 예정으로 자동 표시돼요")
                        .font(.system(size: 13)).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Button { showAdd = true } label: {
                        Text("정기 거래 추가")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.orange).clipShape(Capsule())
                    }.buttonStyle(.plain).padding(.top, 4)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    if !incomeItems.isEmpty  { ScheduledGroup(title: "정기 수입",  items: incomeItems) }
                    if !expenseItems.isEmpty { ScheduledGroup(title: "정기 지출", items: expenseItems) }
                }
                .padding(.horizontal, 16)
            }
            Spacer().frame(height: 100)
        }
        .sheet(isPresented: $showAdd) { AddScheduledTransactionSheet() }
    }
}

// MARK: - 정기 거래 그룹
struct ScheduledGroup: View {
    var title: String
    var items: [ScheduledTransaction]
    @State private var editItem: ScheduledTransaction? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    ScheduledTransactionRow(item: item) { editItem = item }
                    if item.id != items.last?.id { Divider().padding(.leading, 52) }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(item: $editItem) { item in AddScheduledTransactionSheet(editItem: item) }
    }
}

// MARK: - 정기 거래 행
struct ScheduledTransactionRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ScheduledTransaction
    var onEdit: () -> Void

    var catColor: Color {
        Color(hex: Transaction.categoryColor[item.category] ?? "9CA3AF") ?? .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(catColor.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: Transaction.categoryIcon[item.category] ?? "ellipsis.circle")
                    .font(.system(size: 15)).foregroundStyle(catColor)
            }
            .opacity(item.isActive ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15))
                    .foregroundStyle(item.isActive ? .primary : .secondary)
                Text("매달 \(item.dayOfMonth)일 · \(item.category)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            Spacer()

            let sign = item.type == "income" ? "+" : "-"
            Text("\(sign)\(formatPrice(item.amount))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.type == "income" ? Color.blue : Color.primary)
                .opacity(item.isActive ? 1 : 0.4)

            Toggle("", isOn: $item.isActive)
                .labelsHidden()
                .tint(item.type == "income" ? Color.blue : Color.red)
                .scaleEffect(0.8)
                .onChange(of: item.isActive) { _, _ in try? modelContext.save() }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .contextMenu {
            Button { onEdit() } label: { Label("편집", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                modelContext.delete(item); try? modelContext.save()
            } label: { Label("삭제", systemImage: "trash") }
        }
    }
}

// MARK: - 정기 거래 추가/편집 시트
struct AddScheduledTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editItem: ScheduledTransaction? = nil

    @State private var title = ""
    @State private var type = "expense"
    @State private var amountText = ""
    @State private var category = "중고거래"
    @State private var paymentMethod = "카드"
    @State private var dayOfMonth = 1
    @State private var memo = ""

    var isEditing: Bool { editItem != nil }
    var categories: [String] { type == "expense" ? Transaction.expenseCategories : Transaction.incomeCategories }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("거래 이름 (예: 월급, 넷플릭스)", text: $title)
                    Picker("종류", selection: $type) {
                        Text("지출").tag("expense")
                        Text("수입").tag("income")
                    }
                    .onChange(of: type) { _, _ in
                        category = type == "expense"
                            ? Transaction.expenseCategories[0]
                            : Transaction.incomeCategories[0]
                    }
                }
                Section("금액 및 분류") {
                    HStack {
                        Image(systemName: "wonsign").foregroundStyle(.secondary)
                        TextField("금액", text: $amountText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    Picker("카테고리", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat, systemImage: Transaction.categoryIcon[cat] ?? "tag").tag(cat)
                        }
                    }
                    if type == "expense" {
                        Picker("결제 수단", selection: $paymentMethod) {
                            ForEach(Transaction.paymentMethods, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                Section("반복 일정") {
                    Stepper(value: $dayOfMonth, in: 1...31) {
                        HStack {
                            Text("반복일")
                            Spacer()
                            Text("매달 \(dayOfMonth)일")
                                .foregroundStyle(.orange).fontWeight(.medium)
                        }
                    }
                }
                Section("메모") {
                    TextField("메모 (선택)", text: $memo, axis: .vertical).lineLimit(2...3)
                }
            }
            .navigationTitle(isEditing ? "정기 거래 편집" : "정기 거래 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "저장" : "추가") { submit() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amountText.isEmpty)
                }
            }
        }
        .onAppear { loadEdit() }
    }

    func loadEdit() {
        guard let item = editItem else { return }
        title = item.title; type = item.type
        amountText = item.amount > 0 ? "\(item.amount)" : ""
        category = item.category; paymentMethod = item.paymentMethod
        dayOfMonth = item.dayOfMonth; memo = item.memo
    }

    func submit() {
        let amount = Int(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        guard amount > 0, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let item = editItem {
            item.title = title.trimmingCharacters(in: .whitespaces)
            item.type = type; item.amount = amount; item.category = category
            item.paymentMethod = paymentMethod; item.dayOfMonth = dayOfMonth; item.memo = memo
        } else {
            let item = ScheduledTransaction(
                title: title.trimmingCharacters(in: .whitespaces),
                amount: amount, type: type, category: category,
                paymentMethod: paymentMethod, dayOfMonth: dayOfMonth, memo: memo
            )
            modelContext.insert(item)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 공용 포맷 헬퍼
func formatPrice(_ p: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return (f.string(from: NSNumber(value: p)) ?? "\(p)") + "원"
}

// MARK: - 판매처 관리 시트
struct ManageStoresSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customStores: [String] = UserDefaults.standard.stringArray(forKey: "customStores") ?? []
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("판매처 이름 입력", text: $newName)
                        Button {
                            let name = newName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty, !customStores.contains(name),
                                  !Transaction.stores.contains(name) else { return }
                            customStores.append(name)
                            UserDefaults.standard.set(customStores, forKey: "customStores")
                            newName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: { Text("새 판매처 추가") }

                if !customStores.isEmpty {
                    Section {
                        ForEach(customStores, id: \.self) { s in
                            Label(s, systemImage: "tag")
                        }
                        .onDelete { idxs in
                            customStores.remove(atOffsets: idxs)
                            UserDefaults.standard.set(customStores, forKey: "customStores")
                        }
                    } header: { Text("내가 추가한 판매처") }
                }

                Section {
                    ForEach(Transaction.stores, id: \.self) { s in
                        Label(s, systemImage: Transaction.storeIcon[s] ?? "bag")
                            .foregroundStyle(.secondary)
                    }
                } header: { Text("기본 판매처") }
            }
            .navigationTitle("판매처 관리")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 카테고리 관리 시트
struct ManageCategoriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType = "expense"
    @State private var customExpense: [String] = UserDefaults.standard.stringArray(forKey: "customExpenseCategories") ?? []
    @State private var customIncome:  [String] = UserDefaults.standard.stringArray(forKey: "customIncomeCategories")  ?? []
    @State private var newName = ""

    var customList: [String] { selectedType == "expense" ? customExpense : customIncome }
    var defaultList: [String] { selectedType == "expense" ? Transaction.expenseCategories : Transaction.incomeCategories }

    var body: some View {
        NavigationStack {
            List {
                // 타입 선택
                Section {
                    Picker("", selection: $selectedType) {
                        Text("지출").tag("expense")
                        Text("수입").tag("income")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                // 추가
                Section {
                    HStack {
                        TextField("카테고리 이름", text: $newName)
                        Button {
                            let name = newName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty,
                                  !customList.contains(name),
                                  !defaultList.contains(name) else { return }
                            if selectedType == "expense" {
                                customExpense.append(name)
                                UserDefaults.standard.set(customExpense, forKey: "customExpenseCategories")
                            } else {
                                customIncome.append(name)
                                UserDefaults.standard.set(customIncome, forKey: "customIncomeCategories")
                            }
                            newName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: { Text("새 카테고리 추가") }

                // 내가 추가한 것
                if !customList.isEmpty {
                    Section {
                        ForEach(customList, id: \.self) { cat in
                            Label(cat, systemImage: "tag")
                        }
                        .onDelete { idxs in
                            if selectedType == "expense" {
                                customExpense.remove(atOffsets: idxs)
                                UserDefaults.standard.set(customExpense, forKey: "customExpenseCategories")
                            } else {
                                customIncome.remove(atOffsets: idxs)
                                UserDefaults.standard.set(customIncome, forKey: "customIncomeCategories")
                            }
                        }
                    } header: { Text("내가 추가한 카테고리") }
                }

                // 기본 카테고리
                Section {
                    ForEach(defaultList, id: \.self) { cat in
                        Label(cat, systemImage: Transaction.categoryIcon[cat] ?? "tag")
                            .foregroundStyle(.secondary)
                    }
                } header: { Text("기본 카테고리") }
            }
            .navigationTitle("카테고리 관리")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
