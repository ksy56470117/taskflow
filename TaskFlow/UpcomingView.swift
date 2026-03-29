import SwiftUI
import SwiftData

// MARK: - Upcoming View
struct UpcomingView: View {
    @Query(sort: \Task.dueDate) private var allTasks: [Task]
    @Query private var projects: [Project]

    var calendar: Calendar { Calendar.current }

    var upcomingDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        var dates = Set<Date>()
        for task in allTasks {
            if let due = task.dueDate, calendar.startOfDay(for: due) >= today {
                dates.insert(calendar.startOfDay(for: due))
            }
        }
        for (date, _) in projects.upcomingExamEvents(from: Date()) {
            dates.insert(date)
        }
        return dates.sorted()
    }

    func tasksFor(_ date: Date) -> [Task] {
        allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }.sorted { ($0.isCompleted ? 1 : 0) < ($1.isCompleted ? 1 : 0) }
    }

    func examsFor(_ date: Date) -> [ExamEvent] { projects.examEvents(on: date) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ghGreen)
                    Text("Upcoming")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

                if upcomingDates.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary.opacity(0.3))
                        Text("예정된 태스크 없음")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    ForEach(upcomingDates, id: \.self) { date in
                        UpcomingDaySection(date: date, tasks: tasksFor(date), exams: examsFor(date))
                    }
                }

                Spacer().frame(height: 30)
            }
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Day Section
struct UpcomingDaySection: View {
    var date: Date
    var tasks: [Task]
    var exams: [ExamEvent] = []

    var cal: Calendar { Calendar.current }
    var isToday: Bool    { cal.isDateInToday(date) }
    var isTomorrow: Bool { cal.isDateInTomorrow(date) }
    var dayNumber: String { "\(cal.component(.day, from: date))" }

    var dayLabel: String {
        if isToday    { return "오늘" }
        if isTomorrow { return "내일" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 날짜 헤더
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(dayNumber)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isToday ? Color.ghGreen : .primary)
                Text(dayLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                if !isToday && !isTomorrow {
                    Text(monthLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 20)

            ForEach(exams) { exam in
                UpcomingExamRow(exam: exam)
            }
            ForEach(tasks) { task in
                UpcomingTaskRow(task: task)
            }
        }
    }
}

// MARK: - Task Row
struct UpcomingTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    @State private var showEdit = false
    @State private var showDeleteAlert = false

    var projColor: Color {
        guard let proj = task.project else { return Color.secondary.opacity(0.4) }
        return Color(hex: proj.colorHex) ?? .secondary
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

            Text(task.title)
                .font(.system(size: 13, weight: task.isCompleted ? .regular : .medium))
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))
                .lineLimit(1)

            ForEach(task.tags) { tag in
                TagChip(tag: tag)
            }

            Spacer()

            // D-day 배지
            if let due = task.dueDate {
                let days = daysFromToday(due)
                if days > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 9))
                        Text("\(days)일 후")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.secondary.opacity(0.5))
                } else if days == 1 {
                    Text("내일")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.orange.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 3)
        .contextMenu {
            Button { showEdit = true } label: { Label("편집", systemImage: "pencil") }
            Button {
                task.isCompleted.toggle(); try? modelContext.save()
            } label: {
                Label(task.isCompleted ? "미완료로 표시" : "완료로 표시",
                      systemImage: task.isCompleted ? "circle" : "checkmark.circle")
            }
            Divider()
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showEdit) { TaskEditSheet(task: task) }
        .alert("태스크를 삭제할까요?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) { modelContext.delete(task); try? modelContext.save() }
            Button("취소", role: .cancel) {}
        }
    }

    func daysFromToday(_ date: Date) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }
}

// MARK: - 시험 이벤트 행 (Upcoming)
struct UpcomingExamRow: View {
    var exam: ExamEvent
    var col: Color { Color(hex: exam.colorHex) ?? .orange }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(col.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: exam.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(col)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(exam.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                if let area = exam.project.area {
                    Text(area.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            let days = Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: exam.date)).day ?? 0
            if days > 1 {
                HStack(spacing: 2) {
                    Image(systemName: "flag.fill").font(.system(size: 9))
                    Text("\(days)일 후").font(.system(size: 11))
                }.foregroundStyle(col.opacity(0.7))
            } else if days == 1 {
                Text("내일").font(.system(size: 11, weight: .medium)).foregroundStyle(.orange)
            } else if days == 0 {
                Text("D-Day").font(.system(size: 11, weight: .bold)).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}
