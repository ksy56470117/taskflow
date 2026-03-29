import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var allTasks: [Task]
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Header (GitHub Dashboard style)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Date(), format: .dateTime.month(.wide).day())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(greeting)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if totalSecondsToday > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.ghGreen)
                                Text(formatSeconds(totalSecondsToday))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.ghGreen.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        Button {
                            showAddTaskNoProject = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("New")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.ghGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }

                    if totalCount > 0 && pendingCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.dotted")
                                .font(.system(size: 11))
                            Text("\(pendingCount) open")
                                .font(.system(size: 12, weight: .medium))
                            Text("·")
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 11))
                            Text("\(totalCount - pendingCount) closed")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)

                // MARK: - Git-style Study Time
                TimeCommitSection(
                    stagedEntries: stagedEntries,
                    committedEntriesToday: committedEntriesToday,
                    projects: projects
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // MARK: - 오늘 시험
                if !todayExams.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
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
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.ghGreen.opacity(0.8))
                        Text("오늘 할 일을 모두 마쳤어요!")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    // 프로젝트 없는 태스크
                    if !orphanPending.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "tray.and.arrow.down")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text("Inbox")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.04))

                            Divider().opacity(0.5)

                            ForEach(orphanPending) { task in
                                TaskRow(task: task, project: nil)
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                    VStack(spacing: 12) {
                        ForEach(pendingGroups, id: \.0.id) { project, tasks in
                            ProjectSection(
                                project: project,
                                tasks: tasks,
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
                .presentationDetents([.height(250)])
        }
    }
}

// MARK: - Git-style Study Time Section
struct TimeCommitSection: View {
    @Environment(\.modelContext) private var modelContext
    var stagedEntries: [TimeEntry]
    var committedEntriesToday: [TimeEntry]
    var projects: [Project]

    @State private var showInlineEntry = false
    @State private var selectedTask: Task?
    @State private var startTime = Date().addingTimeInterval(-3600)
    @State private var endTime = Date()

    var stagedTotal: Int { stagedEntries.reduce(0) { $0 + $1.seconds } }
    var committedTotal: Int { committedEntriesToday.reduce(0) { $0 + $1.seconds } }
    var durationSecs: Int { max(0, Int(endTime.timeIntervalSince(startTime))) }
    var canStage: Bool { selectedTask != nil && endTime > startTime }

    var allTasks: [Task] {
        projects.flatMap { $0.tasks }.sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── New Entry (인라인) ──
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.ghGreen)
                    Text("New Entry")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    if !stagedEntries.isEmpty {
                        Text("\(stagedEntries.count)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.ghGreen)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showInlineEntry.toggle()
                            if showInlineEntry {
                                startTime = Date().addingTimeInterval(-3600)
                                endTime = Date()
                                selectedTask = nil
                            }
                        }
                    } label: {
                        Image(systemName: showInlineEntry ? "xmark" : "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(showInlineEntry ? .secondary : Color.ghGreen)
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

                // ── 인라인 입력 폼 ──
                if showInlineEntry {
                    VStack(spacing: 0) {
                        // 태스크 선택 (수평 스크롤)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(allTasks) { task in
                                    let isSelected = selectedTask?.id == task.id
                                    let col = task.project.flatMap { Color(hex: $0.colorHex) } ?? Color.secondary
                                    Button { selectedTask = task } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                                                .font(.system(size: 9))
                                                .foregroundStyle(isSelected ? .white : (task.isCompleted ? Color.secondary : col))
                                            Text(task.title)
                                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .monospaced))
                                                .lineLimit(1)
                                                .strikethrough(task.isCompleted && !isSelected, color: .secondary)
                                        }
                                        .foregroundStyle(isSelected ? .white : (task.isCompleted ? .secondary : .primary))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? Color.ghGreen : Color.secondary.opacity(0.08))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                        .padding(.vertical, 8)

                        Divider().opacity(0.3).padding(.horizontal, 14)

                        // 시간 입력
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("START")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .scaleEffect(0.85, anchor: .leading)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("END")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .scaleEffect(0.85, anchor: .leading)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("DURATION")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("+\(fmtHM(durationSecs))")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.ghGreen)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)

                        // Stage 버튼
                        Button {
                            guard let task = selectedTask, endTime > startTime else { return }
                            let entry = TimeEntry(task: task, startedAt: startTime, endedAt: endTime, committed: false)
                            task.timeEntries.append(entry)
                            modelContext.insert(entry)
                            try? modelContext.save()
                            withAnimation {
                                selectedTask = nil
                                startTime = Date().addingTimeInterval(-3600)
                                endTime = Date()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.system(size: 12))
                                Text("Stage")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(canStage ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(canStage ? Color.ghGreen : Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canStage)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }

                    Divider().opacity(0.5)
                }

                // ── Staged entries ──
                if stagedEntries.isEmpty && !showInlineEntry {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("Nothing to commit")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                } else if !stagedEntries.isEmpty {
                    ForEach(stagedEntries) { entry in
                        GitStagedRow(entry: entry)
                    }

                    Divider().opacity(0.3)

                    // Commit area
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text("+\(fmtHM(stagedTotal))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.ghGreen)
                            Text("\(stagedEntries.count) change\(stagedEntries.count == 1 ? "" : "s")")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                for entry in stagedEntries { entry.isCommitted = true }
                                try? modelContext.save()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text("Commit")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.ghGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
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
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.ghGreen)
                        Text("Commits")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                        Spacer()
                        Text(fmtHM(committedTotal))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.ghGreen)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.04))

                    Divider().opacity(0.5)

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

// MARK: - Git Staged Row
struct GitStagedRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: TimeEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("+")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.ghGreen)
                .frame(width: 16)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: entry.task?.project?.colorHex ?? "8E8E93") ?? .secondary)
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.task?.title ?? "unknown")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                Text("\(timeStr(entry.startedAt))~\(timeStr(entry.endedAt ?? Date()))  \(fmtHM(entry.seconds))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { modelContext.delete(entry); try? modelContext.save() }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { Divider().opacity(0.3).padding(.leading, 40) }
    }

    func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - Git Commit Row
struct GitCommitRow: View {
    var entry: TimeEntry

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.ghGreen)
                .frame(width: 8, height: 8)
                .frame(width: 16)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: entry.task?.project?.colorHex ?? "8E8E93") ?? .secondary)
                .frame(width: 3, height: 20)

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
                .foregroundStyle(Color.ghGreen)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.ghGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { Divider().opacity(0.3).padding(.leading, 40) }
    }

    func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - 프로젝트 섹션 (GitHub repo style)

struct ProjectSection: View {
    var project: Project
    var tasks: [Task]
    var onAddTask: () -> Void

    var projColor: Color { Color(hex: project.colorHex) ?? Color.ghGreen }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — GitHub repo header style
            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Circle().fill(projColor).frame(width: 8, height: 8)
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onAddTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))

            Divider().opacity(0.5)

            // Tasks — GitHub issue list style
            ForEach(tasks) { task in
                TaskRow(task: task, project: project)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}

// MARK: - 태스크 행 (GitHub issue style)

struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    var project: Project?
    @State private var isExpanded = false
    @State private var showEdit = false
    @State private var showDeleteAlert = false

    var checkColor: Color { project.flatMap { Color(hex: $0.colorHex) } ?? Color.ghGreen }

    var body: some View {
        HStack(spacing: 8) {
            // GitHub issue icon style
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 14))
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.ghGreen)
                .frame(width: 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        task.isCompleted.toggle()
                        if task.isCompleted && !task.recurrence.isEmpty {
                            spawnNextRecurrence()
                        }
                        try? modelContext.save()
                    }
                }

            // 내용
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: task.isCompleted ? .regular : .medium))
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    ForEach(task.tags) { tag in
                        TagChip(tag: tag)
                    }
                    if !task.recurrence.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "repeat")
                                .font(.system(size: 8))
                            Text(task.recurrence == "daily" ? "매일" : "매주")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.ghGreen)
                    }
                    if let due = task.dueDate {
                        Text(formatDate(due))
                            .font(.system(size: 10))
                            .foregroundStyle(isPast(due) ? .red : .secondary)
                    }
                    if task.totalSeconds > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(task.formattedTime)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
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
            .foregroundStyle(task.dueDate != nil ? Color.ghGreen : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(task.dueDate != nil ? Color.ghGreen.opacity(0.12) : Color.white.opacity(0.08))
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

    /// GitHub green — 앱 전체 메인 포인트 색상
    static let ghGreen = Color(hex: "2DA44E")!
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
                .tint(Color.ghGreen)
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
                        .background(Color.ghGreen)
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
