import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var projects: [Project]
    @Query private var allTasks: [Task]   // 프로젝트 없는 태스크 포함
    @Query(sort: \Tag.name) private var allTagsList: [Tag]
    @State private var selectedDate = Date()
    @State private var displayMonth = Date()
    @State private var showAddTask = false
    @State private var selectedTagFilter: Tag? = nil

    var calendar: Calendar { Calendar.current }

    func tasksForDate(_ date: Date) -> [Task] {
        allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }
    }

    func examsForDate(_ date: Date) -> [ExamEvent] { projects.examEvents(on: date) }

    var tasksForSelectedAll: [Task]    { tasksForDate(selectedDate) }
    var tasksForSelected: [Task] {
        guard let tag = selectedTagFilter else { return tasksForSelectedAll }
        return tasksForSelectedAll.filter { $0.tags.contains(where: { $0.id == tag.id }) }
    }
    var examsForSelected: [ExamEvent] { examsForDate(selectedDate) }

    // 선택 날짜에 사용된 태그들
    var usedTagsForSelected: [Tag] {
        var seenNames = Set<String>()
        var result: [Tag] = []
        for task in tasksForSelectedAll {
            for tag in task.tags {
                if seenNames.insert(tag.name).inserted {
                    result.append(tag)
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    // 해당 월 전체 태스크 수 기준 contribution level
    func contributionLevel(_ date: Date) -> Int {
        let count = tasksForDate(date).count
        if count == 0 { return 0 }
        if count <= 1 { return 1 }
        if count <= 3 { return 2 }
        if count <= 5 { return 3 }
        return 4
    }

    var openCount: Int { tasksForSelected.filter { !$0.isCompleted }.count }
    var closedCount: Int { tasksForSelected.filter { $0.isCompleted }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                calendarCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                issueListCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
            }
        }
        .background(Color.secondary.opacity(0.06))
        .sheet(isPresented: $showAddTask) {
            CalendarAddTaskSheet(date: selectedDate, projects: projects)
                .presentationDetents([.height(310)])
        }
    }

    // MARK: - Calendar Card
    private var calendarCard: some View {
        VStack(spacing: 0) {
            calendarHeader
            Divider().opacity(0.5)
            weekdayHeader
            Divider().opacity(0.3)
            calendarGrid
            contributionLegend
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    private var calendarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.ghGreen)
            Text(monthTitle(displayMonth))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            Spacer()
            monthNavButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.04))
    }

    private var monthNavButtons: some View {
        HStack(spacing: 2) {
            Button {
                displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 26)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.none) {
                    displayMonth = Date()
                    selectedDate = Date()
                }
            } label: {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            Button {
                displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 26)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.02))
    }

    private var calendarGrid: some View {
        let weeks = generateDays(for: displayMonth).chunked(into: 7)
        return VStack(spacing: 0) {
            ForEach(weeks.indices, id: \.self) { wi in
                calendarWeekRow(weeks[wi])
                if wi < weeks.count - 1 {
                    Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)
                }
            }
        }
    }

    private func calendarWeekRow(_ week: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { di in
                let date = week[di]
                DayCell(
                    date: date,
                    isCurrentMonth: calendar.isDate(date, equalTo: displayMonth, toGranularity: .month),
                    isToday: calendar.isDateInToday(date),
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    tasks: tasksForDate(date),
                    exams: examsForDate(date),
                    colIndex: di,
                    contributionLevel: contributionLevel(date)
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { selectedDate = date })
                if di < 6 {
                    Rectangle().fill(Color.secondary.opacity(0.1)).frame(width: 1)
                }
            }
        }
    }

    private var contributionLegend: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("Less")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(ghContribColor(level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.02))
    }

    // MARK: - Issue List Card
    private var issueListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            issueListHeader
            if !usedTagsForSelected.isEmpty {
                tagFilterBar
            }
            Divider().opacity(0.5)
            ForEach(examsForSelected) { exam in
                ExamEventRow(exam: exam)
            }
            if tasksForSelected.isEmpty && examsForSelected.isEmpty {
                emptyIssueView
            } else {
                ForEach(tasksForSelected) { task in
                    CalendarTaskRow(task: task)
                }
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    private var tagFilterBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    // All 버튼
                    Button {
                        selectedTagFilter = nil
                    } label: {
                        Text("All")
                            .font(.system(size: 11, weight: selectedTagFilter == nil ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(selectedTagFilter == nil ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(selectedTagFilter == nil ? Color.ghGreen : Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(usedTagsForSelected) { tag in
                        let isSel = selectedTagFilter?.id == tag.id
                        let col = Color(hex: tag.colorHex) ?? Color.ghGreen
                        Button { selectedTagFilter = isSel ? nil : tag } label: {
                            HStack(spacing: 4) {
                                Circle().fill(col).frame(width: 6, height: 6)
                                Text(tag.name)
                                    .font(.system(size: 11, weight: isSel ? .semibold : .regular, design: .monospaced))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSel ? .white : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isSel ? col : col.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 6)
        }
    }

    private var issueListHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ghGreen)
                Text("\(openCount) Open")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            Spacer().frame(width: 16)
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("\(closedCount) Closed")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(selectedDateLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer().frame(width: 8)
            Button { showAddTask = true } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("New")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.ghGreen)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.04))
    }

    private var emptyIssueView: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 16))
            Text("No issues for this date")
                .font(.system(size: 13, design: .monospaced))
        }
        .foregroundStyle(.secondary.opacity(0.4))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    func ghContribColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color.secondary.opacity(0.1)
        case 1: return Color.ghGreen.opacity(0.3)
        case 2: return Color.ghGreen.opacity(0.55)
        case 3: return Color.ghGreen.opacity(0.8)
        default: return Color.ghGreen
        }
    }

    var selectedDateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: selectedDate)
    }

    func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: date)
    }

    func generateDays(for month: Date) -> [Date] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: month)!
        let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let firstWeekday = cal.component(.weekday, from: firstDay) - 1
        var days: [Date] = []
        for i in 0..<firstWeekday { days.append(cal.date(byAdding: .day, value: i - firstWeekday, to: firstDay)!) }
        for d in range { days.append(cal.date(byAdding: .day, value: d - 1, to: firstDay)!) }
        while days.count % 7 != 0 { days.append(cal.date(byAdding: .day, value: days.count - firstWeekday, to: firstDay)!) }
        return days
    }
}


struct DayCell: View {
    @Environment(\.modelContext) private var modelContext
    var date: Date
    var isCurrentMonth: Bool
    var isToday: Bool
    var isSelected: Bool
    var tasks: [Task]
    var exams: [ExamEvent] = []
    var colIndex: Int = 0
    var contributionLevel: Int = 0

    var dayNum: Int { Calendar.current.component(.day, from: date) }
    var numColor: Color {
        if isSelected { return .white }
        if isToday    { return Color.ghGreen }
        if !isCurrentMonth { return Color.primary.opacity(0.18) }
        return .primary
    }

    func contribColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color.secondary.opacity(0.08)
        case 1: return Color.ghGreen.opacity(0.3)
        case 2: return Color.ghGreen.opacity(0.55)
        case 3: return Color.ghGreen.opacity(0.8)
        default: return Color.ghGreen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 날짜 숫자 + contribution dot
            HStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.ghGreen)
                            .frame(width: 20, height: 18)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.ghGreen, lineWidth: 1.5)
                            .frame(width: 20, height: 18)
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 10, weight: isToday || isSelected ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(numColor)
                }
                .frame(width: 20, height: 18)

                if isCurrentMonth && contributionLevel > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(contribColor(contributionLevel))
                        .frame(width: 8, height: 8)
                }
            }

            // 태스크 칩
            ForEach(tasks) { task in
                let col: Color = task.tags.first.flatMap { Color(hex: $0.colorHex) }
                    ?? task.project.flatMap { Color(hex: $0.colorHex) }
                    ?? Color.gray
                Button {
                    task.isCompleted.toggle()
                    try? modelContext.save()
                } label: {
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(col)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                        Text(task.title)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(
                                task.isCompleted
                                    ? Color.secondary.opacity(0.5)
                                    : (isCurrentMonth ? Color.primary.opacity(0.85) : Color.secondary)
                            )
                            .strikethrough(task.isCompleted, color: .secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(col.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // 시험 칩 (읽기 전용)
            ForEach(exams) { exam in
                let col = Color(hex: exam.colorHex) ?? Color.orange
                HStack(spacing: 2) {
                    Image(systemName: exam.icon)
                        .font(.system(size: 6))
                        .foregroundStyle(col)
                    Text(exam.title)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(isCurrentMonth ? col.opacity(0.9) : col.opacity(0.4))
                        .lineLimit(1)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
                .background(col.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct CalendarTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    @State private var showEdit = false
    @State private var showDeleteAlert = false

    var projColor: Color {
        guard let proj = task.project else { return .gray }
        return Color(hex: proj.colorHex) ?? .gray
    }

    var body: some View {
        HStack(spacing: 8) {
            // GitHub issue icon
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 14))
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.ghGreen)
                .frame(width: 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    task.isCompleted.toggle()
                    try? modelContext.save()
                }

            // 태그 색상 dot
            if !task.tags.isEmpty {
                HStack(spacing: 2) {
                    ForEach(task.tags) { tag in
                        Circle()
                            .fill(Color(hex: tag.colorHex) ?? Color.ghGreen)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Text(task.title)
                .font(.system(size: 13, weight: task.isCompleted ? .regular : .medium, design: .monospaced))
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))
                .lineLimit(1)

            Spacer()

            if task.totalSeconds > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock").font(.system(size: 8))
                    Text(task.formattedTime).font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider().opacity(0.3).padding(.leading, 42) }
        .contextMenu {
            Button {
                showEdit = true
            } label: {
                Label("편집", systemImage: "pencil")
            }
            Button {
                task.isCompleted.toggle()
                try? modelContext.save()
            } label: {
                Label(task.isCompleted ? "미완료로 표시" : "완료로 표시",
                      systemImage: task.isCompleted ? "circle" : "checkmark.circle")
            }
            Divider()
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showEdit) {
            TaskEditSheet(task: task)
        }
        .alert("태스크를 삭제할까요?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                modelContext.delete(task)
                try? modelContext.save()
            }
            Button("취소", role: .cancel) {}
        }
    }
}

// MARK: - 할일 추가 시트 (compact)
struct CalendarAddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var date: Date
    var projects: [Project]

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var title = ""
    @State private var selectedProject: Project? = nil
    @State private var tagInput = ""
    @State private var selectedTags: [Tag] = []

    var sortedProjects: [Project] { projects.sorted { $0.name < $1.name } }
    var canSubmit: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    var tagSuggestions: [Tag] {
        guard !tagInput.isEmpty else { return [] }
        let q = tagInput.lowercased()
        return allTags.filter { tag in tag.name.lowercased().contains(q) && !selectedTags.contains(where: { s in s.id == tag.id }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHandle
            titleField
            Divider()
            projectSelector
            Divider()
            tagInputSection
            Divider()
            dateRow
            Divider()
            Spacer()
            actionButtons
        }
        .background(.background)
        .onAppear { focused = true }
    }

    private var sheetHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 10)
    }

    private var titleField: some View {
        let borderColor = selectedProject.flatMap { Color(hex: $0.colorHex) } ?? Color.secondary.opacity(0.4)
        return HStack(spacing: 8) {
            Circle()
                .strokeBorder(borderColor, lineWidth: 1.5)
                .frame(width: 18, height: 18)
            TextField("새 태스크", text: $title)
                .focused($focused)
                .font(.system(size: 15))
                .onSubmit { if canSubmit { submit() } }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var projectSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button { selectedProject = nil } label: {
                    Text("없음")
                        .font(.system(size: 12, weight: selectedProject == nil ? .semibold : .regular))
                        .foregroundStyle(selectedProject == nil ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedProject == nil ? Color.ghGreen : Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(sortedProjects) { proj in
                    let isSel = selectedProject?.id == proj.id
                    let col = Color(hex: proj.colorHex) ?? Color.ghGreen
                    Button { selectedProject = proj } label: {
                        HStack(spacing: 4) {
                            Circle().fill(col).frame(width: 6, height: 6)
                            Text(proj.name)
                                .font(.system(size: 12, weight: isSel ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSel ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isSel ? col : col.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private var tagInputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                ForEach(selectedTags) { tag in
                    tagChipView(tag)
                }
                TextField("태그 추가", text: $tagInput)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { addTagFromInput() }
            }
            if !tagSuggestions.isEmpty {
                tagSuggestionList
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func tagChipView(_ tag: Tag) -> some View {
        let col = Color(hex: tag.colorHex) ?? Color.ghGreen
        return HStack(spacing: 2) {
            Text(tag.name)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
            Button { selectedTags.removeAll { $0.id == tag.id } } label: {
                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(col)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(col.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var tagSuggestionList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tagSuggestions) { tag in
                    let col = Color(hex: tag.colorHex) ?? Color.ghGreen
                    Button {
                        selectedTags.append(tag)
                        tagInput = ""
                    } label: {
                        Text(tag.name)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(col)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(col.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dateRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12))
                .foregroundStyle(Color.ghGreen)
            Text(dateLabel(date))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Text("취소")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button { submit() } label: {
                Text("추가")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canSubmit ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(canSubmit ? Color.ghGreen : Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    func applyProjectTag(_ project: Project) {
        // 프로젝트명과 동일한 태그 찾거나 새로 생성
        let existing = allTags.first { $0.name == project.name }
        if existing == nil {
            let t = Tag(name: project.name, colorHex: project.colorHex)
            modelContext.insert(t)
            try? modelContext.save()
        }
    }

    func addTagFromInput() {
        let name = tagInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let existing = allTags.first(where: { $0.name.lowercased() == name.lowercased() }) {
            if !selectedTags.contains(where: { $0.id == existing.id }) {
                selectedTags.append(existing)
            }
        } else {
            let col = selectedProject.map { $0.colorHex } ?? "8E8E93"
            let newTag = Tag(name: name, colorHex: col)
            modelContext.insert(newTag)
            selectedTags.append(newTag)
        }
        tagInput = ""
    }

    func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let task = Task(title: trimmed, project: selectedProject)
        task.dueDate = date
        // 프로젝트 태그 자동 적용
        if let p = selectedProject {
            applyProjectTag(p)
            if let tag = allTags.first(where: { $0.name == p.name }) {
                task.tags.append(tag)
            }
            p.tasks.append(task)
        }
        // 직접 입력/선택한 태그 추가
        for tag in selectedTags {
            if !task.tags.contains(where: { $0.id == tag.id }) {
                task.tags.append(tag)
            }
        }
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }

    func dateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
    }
}

// MARK: - 시험 이벤트 행
struct ExamEventRow: View {
    var exam: ExamEvent

    var col: Color { Color(hex: exam.colorHex) ?? .orange }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: exam.icon)
                .font(.system(size: 14))
                .foregroundStyle(col)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(exam.title)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                if let area = exam.project.area {
                    Text(area.name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("exam")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(col)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(col.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider().opacity(0.3).padding(.leading, 42) }
    }
}
