import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    var timerManager: TimerManager
    @Binding var showAddTask: Project?

    var pendingGroups: [(Project, [Task])] {
        projects.compactMap { project in
            let tasks = project.tasks.filter { !$0.isCompleted }.sorted { $0.createdAt < $1.createdAt }
            return tasks.isEmpty ? nil : (project, tasks)
        }
    }

    var totalSecondsToday: Int {
        projects.flatMap { $0.tasks }.flatMap { $0.timeEntries }
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.seconds }
    }

    var completedCount: Int { projects.flatMap { $0.tasks }.filter { $0.isCompleted }.count }
    var totalCount: Int { projects.flatMap { $0.tasks }.count }
    var pendingCount: Int { totalCount - completedCount }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "좋은 아침이에요"
        case 12..<18: return "좋은 오후예요"
        default: return "좋은 저녁이에요"
        }
    }

    @State private var showAddTaskNoProject = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline) {
                        Text(Date(), format: .dateTime.month(.wide).day())
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer()

                        if totalSecondsToday > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                Text(formatSeconds(totalSecondsToday))
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }

                        Button {
                            showAddTaskNoProject = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    if totalCount > 0 {
                        Text(pendingCount == 0 ? "모든 태스크를 완료했어요 🎉" : "남은 태스크 \(pendingCount)개")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)

                // MARK: - 활성 타이머
                if let entry = timerManager.activeEntry, let taskName = entry.task?.title {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(timerManager.displaySeconds % 2 == 0 ? 1 : 0.3)
                        Text(taskName)
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(timerManager.clockString)
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // MARK: - 태스크 목록
                if pendingGroups.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.yellow.opacity(0.8))
                        Text("오늘 할 일을 모두 마쳤어요!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    VStack(spacing: 22) {
                        ForEach(pendingGroups, id: \.0.id) { project, tasks in
                            ProjectSection(
                                project: project,
                                tasks: tasks,
                                timerManager: timerManager,
                                onAddTask: { showAddTask = project }
                            )
                        }
                    }
                }

                Spacer().frame(height: 100)
            }
        }
        .background(.clear)
        .sheet(isPresented: $showAddTaskNoProject) {
            CalendarAddTaskSheet(date: Date(), projects: projects)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - 프로젝트 섹션

struct ProjectSection: View {
    var project: Project
    var tasks: [Task]
    var timerManager: TimerManager
    var onAddTask: () -> Void

    var projColor: Color { Color(hex: project.colorHex) ?? .blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(projColor)
                Text(project.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onAddTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    TaskRow(task: task, project: project, timerManager: timerManager)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - 태스크 행

struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    var task: Task
    var project: Project
    var timerManager: TimerManager
    @State private var isExpanded = false

    var isRunning: Bool { timerManager.isRunning(task: task) }
    var checkColor: Color { Color(hex: project.colorHex) ?? .blue }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        task.isCompleted.toggle()
                        if task.isCompleted && isRunning { timerManager.stop() }
                        try? modelContext.save()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(checkColor.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        if task.isCompleted {
                            Circle().fill(checkColor).frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 17))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))

                    if task.totalSeconds > 0 || task.dueDate != nil {
                        HStack(spacing: 8) {
                            if let due = task.dueDate {
                                Label(formatDate(due), systemImage: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundStyle(isPast(due) ? .red : .secondary)
                            }
                            if task.totalSeconds > 0 {
                                Label(task.formattedTime, systemImage: "clock")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !task.isCompleted {
                        withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                    }
                }

                if !task.isCompleted {
                    Button {
                        isRunning ? timerManager.stop() : timerManager.start(task: task)
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(isRunning ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isRunning ? Color.green.opacity(0.15) : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("메모", text: Binding(
                        get: { task.notes },
                        set: { task.notes = $0; try? modelContext.save() }
                    ), axis: .vertical)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.plain)
                    .padding(.leading, 54)
                    .padding(.trailing, 16)

                    Divider().padding(.leading, 54).opacity(0.4)

                    HStack(spacing: 8) {
                        Spacer().frame(width: 54)
                        DatePickerPill(task: task)
                        Spacer()
                    }
                    .padding(.bottom, 10)
                }
                .background(Color.white.opacity(0.05))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().padding(.leading, 54).opacity(0.25)
        }
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }

    func isPast(_ d: Date) -> Bool {
        d < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - 날짜 선택 Pill

struct DatePickerPill: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    @State private var showPicker = false

    func setDueDate(_ date: Date) {
        task.dueDate = date
        try? modelContext.save()
        showPicker = false
        _Concurrency.Task {
            await CalendarManager.shared.addEvent(
                title: task.title,
                dueDate: date,
                notes: task.notes
            )
        }
    }

    var body: some View {
        Button { showPicker.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar").font(.system(size: 12))
                Text(task.dueDate.map { formatDate($0) } ?? "날짜 설정")
                    .font(.system(size: 12))
            }
            .foregroundStyle(task.dueDate != nil ? Color.blue : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(task.dueDate != nil ? Color.blue.opacity(0.12) : Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    setDueDate(Calendar.current.startOfDay(for: Date()))
                } label: {
                    HStack { Text("⭐️"); Text("오늘").font(.system(size: 14)); Spacer() }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Divider()
                DatePicker("", selection: Binding(
                    get: { task.dueDate ?? Date() },
                    set: { setDueDate($0) }
                ), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .frame(width: 280)
                Divider()
                Button {
                    task.dueDate = nil
                    try? modelContext.save()
                    showPicker = false
                } label: {
                    HStack { Text("🗂️"); Text("Someday").font(.system(size: 14)); Spacer() }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 280)
        }
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    var value: String
    var label: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

func formatSeconds(_ s: Int) -> String {
    let m = s / 60; let h = m / 60
    if h > 0 { return "\(h)h \(m % 60)m" }
    if m > 0 { return "\(m)m" }
    return "0m"
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double(val         & 0xFF) / 255
        )
    }
}
