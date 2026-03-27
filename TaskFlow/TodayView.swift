import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var allTasks: [Task]
    var timerManager: TimerManager
    @Binding var showAddTask: Project?

    func isForToday(_ task: Task) -> Bool {
        if let due = task.dueDate {
            if Calendar.current.isDateInToday(due) { return true }
            return due < Date() && !task.isCompleted  // 오늘 이전 미완료 (overdue)
        }
        return !task.isCompleted
    }

    var orphanPending: [Task] {
        allTasks.filter { task in
            task.project == nil && isForToday(task)
        }
        .sorted { ($0.isCompleted ? 1 : 0, $0.createdAt) < ($1.isCompleted ? 1 : 0, $1.createdAt) }
    }

    var pendingGroups: [(Project, [Task])] {
        projects.compactMap { project in
            let tasks = project.tasks.filter { isForToday($0) }
                .sorted { ($0.isCompleted ? 1 : 0, $0.createdAt) < ($1.isCompleted ? 1 : 0, $1.createdAt) }
            return tasks.isEmpty ? nil : (project, tasks)
        }
    }

    var totalSecondsToday: Int {
        allTasks.flatMap { $0.timeEntries }
            .filter { Calendar.current.isDateInToday($0.startedAt) && $0.isCommitted }
            .reduce(0) { $0 + $1.seconds }
    }

    var stagedEntries: [TimeEntry] {
        allTasks.flatMap { $0.timeEntries }
            .filter { !$0.isCommitted && !$0.isRunning && $0.endedAt != nil }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var committedEntriesToday: [TimeEntry] {
        allTasks.flatMap { $0.timeEntries }
            .filter { $0.isCommitted && Calendar.current.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var completedCount: Int { allTasks.filter { $0.isCompleted }.count }
    var totalCount: Int { allTasks.count }
    var pendingCount: Int {
        allTasks.filter { task in
            guard !task.isCompleted else { return false }
            if let due = task.dueDate { return Calendar.current.isDateInToday(due) }
            return true
        }.count
    }

    var todayExams: [ExamEvent] { projects.examEvents(on: Date()) }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "좋은 아침이에요"
        case 12..<18: return "좋은 오후예요"
        default: return "좋은 저녁이에요"
        }
    }

    @State private var showAddTaskNoProject = false
    @State private var showManualEntry = false

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

                // MARK: - 활성 타이머 (Working tree)
                if let entry = timerManager.activeEntry, let taskName = entry.task?.title {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(timerManager.displaySeconds % 2 == 0 ? 1 : 0.3)
                        Text(taskName)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(timerManager.clockString)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.green.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                // MARK: - Git-style Staging Area
                TimeCommitSection(
                    stagedEntries: stagedEntries,
                    committedEntriesToday: committedEntriesToday,
                    showManualEntry: $showManualEntry,
                    timerManager: timerManager
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // MARK: - 오늘 시험
                if !todayExams.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                            Text("오늘 시험")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)

                        ForEach(todayExams) { exam in
                            let col = Color(hex: exam.colorHex) ?? Color.orange
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(col.opacity(0.15)).frame(width: 26, height: 26)
                                    Image(systemName: exam.icon).font(.system(size: 11)).foregroundStyle(col)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(exam.title).font(.system(size: 13, weight: .medium))
                                    if let area = exam.project.area {
                                        Text(area.name).font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("D-Day").font(.system(size: 11, weight: .bold)).foregroundStyle(.red)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.bottom, 16)
                }

                // MARK: - 태스크 목록
                if pendingGroups.isEmpty && orphanPending.isEmpty {
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
                    // 프로젝트 없는 태스크 (캘린더에서 추가된 것 등)
                    if !orphanPending.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "tray")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text("받은편지함")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 6)

                            ForEach(orphanPending) { task in
                                TaskRow(task: task, project: nil, timerManager: timerManager)
                            }
                        }
                        .padding(.bottom, 16)
                    }

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
        .sheet(isPresented: $showManualEntry) {
            ManualTimeEntrySheet(projects: projects)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Git-style Time Commit Section
struct TimeCommitSection: View {
    @Environment(\.modelContext) private var modelContext
    var stagedEntries: [TimeEntry]
    var committedEntriesToday: [TimeEntry]
    @Binding var showManualEntry: Bool
    var timerManager: TimerManager

    @State private var commitMessage = ""

    var stagedTotal: Int { stagedEntries.reduce(0) { $0 + $1.seconds } }
    var committedTotal: Int { committedEntriesToday.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        VStack(spacing: 0) {
            // ── Staged Changes ──
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "plus.square.dashed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                    Text("Staged Changes")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    if !stagedEntries.isEmpty {
                        Text("\(stagedEntries.count)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button { showManualEntry = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.04))

                Divider().opacity(0.5)

                if stagedEntries.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("Nothing to commit")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                } else {
                    // Staged entries (git diff style)
                    ForEach(stagedEntries) { entry in
                        GitStagedRow(entry: entry)
                    }

                    Divider().opacity(0.3)

                    // Commit area
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            // Additions summary
                            Text("+\(fmtHM(stagedTotal))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                            Text("\(stagedEntries.count) file\(stagedEntries.count == 1 ? "" : "s") changed")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        // Commit button
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                for entry in stagedEntries { entry.isCommitted = true }
                                try? modelContext.save()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text("Commit \(stagedEntries.count) change\(stagedEntries.count == 1 ? "" : "s")")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))

            Spacer().frame(height: 12)

            // ── Commit History (오늘) ──
            if !committedEntriesToday.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)
                        Text("Commits")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                        Spacer()
                        Text(fmtHM(committedTotal))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.04))

                    Divider().opacity(0.5)

                    // Timeline
                    ForEach(committedEntriesToday) { entry in
                        GitCommitRow(entry: entry)
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
            }
        }
    }
}

// MARK: - Git Staged Row (diff style)
struct GitStagedRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: TimeEntry

    var body: some View {
        HStack(spacing: 10) {
            // + indicator (like git diff)
            Text("+")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)
                .frame(width: 16)

            // Project color
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: entry.task?.project?.colorHex ?? "8E8E93") ?? .secondary)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.task?.title ?? "unknown")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                Text("\(timeStr(entry.startedAt))~\(timeStr(entry.endedAt ?? Date()))  \(fmtHM(entry.seconds))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Unstage (remove)
            Button {
                withAnimation { modelContext.delete(entry); try? modelContext.save() }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider().opacity(0.3).padding(.leading, 40) }
    }

    func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - Git Commit Row (history style)
struct GitCommitRow: View {
    var entry: TimeEntry

    var body: some View {
        HStack(spacing: 10) {
            // Commit dot on timeline
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 16)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: entry.task?.project?.colorHex ?? "8E8E93") ?? .secondary)
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.task?.title ?? "unknown")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                Text("\(timeStr(entry.startedAt))~\(timeStr(entry.endedAt ?? Date()))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(fmtHM(entry.seconds))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider().opacity(0.3).padding(.leading, 40) }
    }

    func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - 수동 시간 입력 시트
struct ManualTimeEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var projects: [Project]

    @State private var selectedTask: Task?
    @State private var startTime = Date().addingTimeInterval(-3600)
    @State private var endTime = Date()
    @State private var expandedProject: Project?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Entry")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // 태스크 선택
            VStack(alignment: .leading, spacing: 6) {
                Text("TASK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(projects) { project in
                            let tasks = project.tasks.filter { !$0.isCompleted }
                            if !tasks.isEmpty {
                                VStack(spacing: 0) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            expandedProject = expandedProject?.id == project.id ? nil : project
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(hex: project.colorHex) ?? .blue)
                                                .frame(width: 3, height: 16)
                                            Text(project.name)
                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 9, weight: .semibold))
                                                .rotationEffect(.degrees(expandedProject?.id == project.id ? 90 : 0))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 7)
                                    }
                                    .buttonStyle(.plain)

                                    if expandedProject?.id == project.id {
                                        ForEach(tasks) { task in
                                            Button { selectedTask = task } label: {
                                                HStack(spacing: 8) {
                                                    Image(systemName: selectedTask?.id == task.id ? "checkmark.square.fill" : "square")
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(selectedTask?.id == task.id ? .green : .secondary)
                                                    Text(task.title)
                                                        .font(.system(size: 12, design: .monospaced))
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 28)
                                                .padding(.vertical, 5)
                                                .background(selectedTask?.id == task.id ? Color.green.opacity(0.06) : Color.clear)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
            .padding(.top, 10)

            Divider().padding(.top, 6)

            // 시간 선택
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("START")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("END")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DURATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    let secs = max(0, Int(endTime.timeIntervalSince(startTime)))
                    Text("+\(fmtHM(secs))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()
            Spacer()

            // Stage button
            Button {
                guard let task = selectedTask, endTime > startTime else { return }
                let entry = TimeEntry(task: task, startedAt: startTime, endedAt: endTime, committed: false)
                task.timeEntries.append(entry)
                modelContext.insert(entry)
                try? modelContext.save()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.square.dashed")
                        .font(.system(size: 13))
                    Text("Stage Change")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedTask != nil && endTime > startTime ? Color.green : Color.secondary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(selectedTask == nil || endTime <= startTime)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.background)
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
    @Bindable var task: Task
    var project: Project?
    var timerManager: TimerManager
    @State private var isExpanded = false
    @State private var showEdit = false
    @State private var showDeleteAlert = false

    var isRunning: Bool { timerManager.isRunning(task: task) }
    var checkColor: Color { project.flatMap { Color(hex: $0.colorHex) } ?? Color.secondary.opacity(0.5) }

    var body: some View {
        HStack(spacing: 10) {
            // 체크박스
            ZStack {
                Circle()
                    .strokeBorder(checkColor.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                if task.isCompleted {
                    Circle().fill(checkColor).frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    task.isCompleted.toggle()
                    if task.isCompleted && isRunning { timerManager.stop() }
                    // 반복 태스크: 완료 시 다음 태스크 자동 생성
                    if task.isCompleted && !task.recurrence.isEmpty {
                        spawnNextRecurrence()
                    }
                    try? modelContext.save()
                }
            }

            // 내용
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13))
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))

                HStack(spacing: 5) {
                    if let proj = project {
                        HStack(spacing: 3) {
                            Circle().fill(checkColor).frame(width: 5, height: 5)
                            Text(proj.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !task.recurrence.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "repeat")
                                .font(.system(size: 9))
                            Text(task.recurrence == "daily" ? "매일" : "매주")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.blue.opacity(0.7))
                    }
                    if let due = task.dueDate {
                        Text(formatDate(due))
                            .font(.system(size: 11))
                            .foregroundStyle(isPast(due) ? .red : Color.secondary.opacity(0.7))
                    }
                    if task.totalSeconds > 0 {
                        Text(task.formattedTime)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(task.tags) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 타이머 버튼
            if !task.isCompleted {
                Button {
                    isRunning ? timerManager.stop() : timerManager.start(task: task)
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isRunning ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(isRunning ? Color.green.opacity(0.12) : Color.secondary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
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

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }

    func isPast(_ d: Date) -> Bool {
        d < Calendar.current.startOfDay(for: Date())
    }

    func spawnNextRecurrence() {
        let cal = Calendar.current
        let interval: Calendar.Component = task.recurrence == "daily" ? .day : .weekOfYear
        let base = task.dueDate ?? Date()
        let nextDue = cal.date(byAdding: interval, value: 1, to: base)!

        let next = Task(title: task.title, notes: task.notes, project: task.project, dueDate: nextDue, recurrence: task.recurrence)
        next.tags = task.tags
        task.project?.tasks.append(next)
        modelContext.insert(next)
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

// MARK: - 태스크 편집 시트 (공유)
struct TaskEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var recurrence: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // 제목
            TextField("제목", text: $title)
                .focused($titleFocused)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Divider()

            // 메모
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("메모", text: $notes, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3, reservesSpace: false)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // 태그
            HStack(spacing: 10) {
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TagPickerButton(task: task)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // 마감일
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Toggle(isOn: $hasDueDate) {
                    Text("마감일")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                .toggleStyle(.switch)
                .tint(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if hasDueDate {
                DatePicker("", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            Divider()

            // 반복
            HStack(spacing: 10) {
                Image(systemName: "repeat")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("반복")
                    .font(.system(size: 14))
                Spacer()
                Picker("", selection: $recurrence) {
                    Text("없음").tag("")
                    Text("매일").tag("daily")
                    Text("매주").tag("weekly")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()
            Spacer()

            // 버튼
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("취소")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    let trimmed = title.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    task.title = trimmed
                    task.notes = notes
                    task.dueDate = hasDueDate ? dueDate : nil
                    task.recurrence = recurrence
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Text("저장")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.background)
        .onAppear {
            title = task.title
            notes = task.notes
            recurrence = task.recurrence
            if let d = task.dueDate {
                hasDueDate = true
                dueDate = d
            }
            titleFocused = true
        }
    }
}
