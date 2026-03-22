import SwiftUI
import SwiftData

// MARK: - Upcoming View
struct UpcomingView: View {
    @Query(sort: \Task.dueDate) private var allTasks: [Task]

    var calendar: Calendar { Calendar.current }

    var upcomingGroups: [(Date, [Task])] {
        let today = calendar.startOfDay(for: Date())
        let tasks = allTasks.filter { task in
            guard let due = task.dueDate, !task.isCompleted else { return false }
            return calendar.startOfDay(for: due) >= today
        }
        let grouped = Dictionary(grouping: tasks) { calendar.startOfDay(for: $0.dueDate!) }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                    Text("Upcoming")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

                if upcomingGroups.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary.opacity(0.3))
                        Text("예정된 태스크 없음")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    ForEach(upcomingGroups, id: \.0) { date, tasks in
                        UpcomingDaySection(date: date, tasks: tasks)
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
                    .foregroundStyle(isToday ? Color.blue : Color.primary)
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
        HStack(spacing: 10) {
            // 체크박스
            ZStack {
                Circle()
                    .strokeBorder(projColor.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                if task.isCompleted {
                    Circle().fill(projColor).frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
            .onTapGesture {
                task.isCompleted.toggle()
                try? modelContext.save()
            }

            // 내용
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13))
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))

                HStack(spacing: 5) {
                    if let proj = task.project {
                        HStack(spacing: 3) {
                            Circle().fill(projColor).frame(width: 5, height: 5)
                            Text(proj.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(task.tags) { tag in
                        TagChip(tag: tag)
                    }
                }
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
        .padding(.vertical, 6)
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
