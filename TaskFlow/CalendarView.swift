import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var projects: [Project]
    @State private var selectedDate = Date()
    @State private var displayMonth = Date()
    @State private var showAddTask = false

    var calendar: Calendar { Calendar.current }
    var allTasks: [Task] { projects.flatMap { $0.tasks } }

    func tasksForDate(_ date: Date) -> [Task] {
        allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }
    }

    func dotColors(on date: Date) -> [Color] {
        tasksForDate(date).compactMap { task in
            guard let proj = task.project else { return nil }
            return Color(hex: proj.colorHex)
        }
    }

    var tasksForSelected: [Task] { tasksForDate(selectedDate) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button {
                        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(monthTitle(displayMonth))
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button {
                        displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth)!
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(["일","월","화","수","목","금","토"], id: \.self) { d in
                            Text(d)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)

                    let days = generateDays(for: displayMonth)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                        ForEach(days, id: \.self) { date in
                            DayCell(
                                date: date,
                                isCurrentMonth: calendar.isDate(date, equalTo: displayMonth, toGranularity: .month),
                                isToday: calendar.isDateInToday(date),
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                dotColors: dotColors(on: date)
                            )
                            .onTapGesture { selectedDate = date }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(selectedDateLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if tasksForSelected.isEmpty {
                        Text("태스크 없음")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    } else {
                        ForEach(tasksForSelected) { task in
                            CalendarTaskRow(task: task)
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(Color.secondary.opacity(0.1))
        .sheet(isPresented: $showAddTask) {
            CalendarAddTaskSheet(date: selectedDate, projects: projects)
                .presentationDetents([.medium])
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
    var date: Date
    var isCurrentMonth: Bool
    var isToday: Bool
    var isSelected: Bool
    var dotColors: [Color]

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    Circle().fill(Color.blue).frame(width: 30, height: 30)
                } else if isToday {
                    Circle().stroke(Color.blue, lineWidth: 1.5).frame(width: 30, height: 30)
                }
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? Color.white :
                        isToday ? Color.blue :
                        isCurrentMonth ? Color.primary : Color.primary.opacity(0.2)
                    )
            }
            .frame(width: 34, height: 34)

            HStack(spacing: 2) {
                ForEach(dotColors.prefix(3), id: \.self) { color in
                    Circle().fill(color).frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

struct CalendarTaskRow: View {
    var task: Task

    var projColor: Color {
        guard let proj = task.project else { return .gray }
        return Color(hex: proj.colorHex) ?? .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(projColor).frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14))
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted)
                if let proj = task.project {
                    Text(proj.name).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if task.totalSeconds > 0 {
                Text(task.formattedTime).font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 36) }
    }
}
