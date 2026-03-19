import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timerManager = TimerManager()
    @State private var showAddProject = false
    @State private var showAddTask: Project? = nil

    var body: some View {
#if os(macOS)
        MacContentView(timerManager: timerManager)
#else
        iOSContentView(timerManager: timerManager, showAddProject: $showAddProject, showAddTask: $showAddTask)
#endif
    }
}

// MARK: - iOS
#if os(iOS)
struct iOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    var timerManager: TimerManager
    @Binding var showAddProject: Bool
    @Binding var showAddTask: Project?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(timerManager: timerManager, showAddTask: $showAddTask)
                    .navigationTitle("오늘")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem { Label("오늘", systemImage: "star") }.tag(0)

            NavigationStack {
                StatsView().navigationTitle("통계").navigationBarTitleDisplayMode(.large)
            }
            .tabItem { Label("통계", systemImage: "chart.bar") }.tag(1)

            NavigationStack {
                CalendarView().navigationTitle("캘린더").navigationBarTitleDisplayMode(.large)
            }
            .tabItem { Label("캘린더", systemImage: "calendar") }.tag(2)
        }
        .onAppear { timerManager.setup(context: modelContext) }
    }
}
#endif

// MARK: - macOS
#if os(macOS)
struct MacContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var areas: [Area]
    @Query private var projects: [Project]
    var timerManager: TimerManager

    @State private var selection: SidebarItem? = .today
    @State private var showAddArea = false
    @State private var showAddProject: Area? = nil

    var body: some View {
        NavigationSplitView {
            ThingsSidebar(
                selection: $selection,
                showAddArea: $showAddArea,
                showAddProject: $showAddProject
            )
        } detail: {
            Group {
                switch selection {
                case .today:
                    TodayView(timerManager: timerManager, showAddTask: .constant(nil))
                case .stats:
                    StatsView()
                case .calendar:
                    CalendarView()
                case .studyPlan:
                    StudyPlanListView()
                case .project(let id):
                    if let project = projects.first(where: { $0.id == id }) {
                        ProjectDetailView(project: project, timerManager: timerManager)
                            .id(project.id)
                    }
                case .area(let id):
                    if let area = areas.first(where: { $0.id == id }) {
                        AreaDetailView(area: area, timerManager: timerManager)
                    }
                case .none:
                    TodayView(timerManager: timerManager, showAddTask: .constant(nil))
                }
            }
        }
        .onAppear { timerManager.setup(context: modelContext) }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showAddArea) { AddAreaSheet() }
        .sheet(item: $showAddProject) { AddProjectSheet(area: $0) }
    }
}

// MARK: - Sidebar Item
enum SidebarItem: Hashable {
    case today, stats, calendar, studyPlan
    case area(UUID)
    case project(UUID)
}

// MARK: - Sidebar
struct ThingsSidebar: View {
    @Query private var areas: [Area]
    @Query(filter: #Predicate<Project> { $0.area == nil }) private var looseProjects: [Project]
    @Binding var selection: SidebarItem?
    @Binding var showAddArea: Bool
    @Binding var showAddProject: Area?

    var body: some View {
        List(selection: $selection) {
            // 스마트 리스트
            Section {
                Label("오늘", systemImage: "star.fill")
                    .foregroundStyle(.primary)
                    .tag(SidebarItem.today)
                Label("통계", systemImage: "chart.bar.fill")
                    .foregroundStyle(.primary)
                    .tag(SidebarItem.stats)
                Label("캘린더", systemImage: "calendar")
                    .foregroundStyle(.primary)
                    .tag(SidebarItem.calendar)
                Label("학습 계획", systemImage: "books.vertical.fill")
                    .foregroundStyle(.primary)
                    .tag(SidebarItem.studyPlan)
            }

            // Area별 프로젝트
            ForEach(areas.sorted { $0.order < $1.order }) { area in
                Section {
                    // Area 행
                    HStack(spacing: 8) {
                        Image(systemName: "hexagon")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(area.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            showAddProject = area
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .tag(SidebarItem.area(area.id))

                    // 하위 프로젝트
                    ForEach(area.projects.sorted { $0.order < $1.order }) { project in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: project.colorHex) ?? .blue)
                                .frame(width: 8, height: 8)
                                .padding(.leading, 8)
                            Text(project.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Spacer()
                            let pending = project.pendingCount
                            if pending > 0 {
                                Text("\(pending)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(SidebarItem.project(project.id))
                    }
                }
            }

            // Area 없는 프로젝트
            if !looseProjects.isEmpty {
                Section("프로젝트") {
                    ForEach(looseProjects) { project in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: project.colorHex) ?? .blue)
                                .frame(width: 8, height: 8)
                            Text(project.name).font(.system(size: 13)).lineLimit(1)
                            Spacer()
                            let pending = project.pendingCount
                            if pending > 0 {
                                Text("\(pending)").font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                        }
                        .tag(SidebarItem.project(project.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    showAddArea = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                        Text("새 Area").font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Spacer()
            }
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }
}

// MARK: - Area Detail
struct AreaDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var area: Area
    var timerManager: TimerManager
    @State private var showAddProject = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text(area.name)
                            .font(.system(size: 26, weight: .bold))
                    }
                    // Notes
                    TextField("Notes", text: Binding(
                        get: { "" },
                        set: { _ in }
                    ), axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 32)

                // 하위 프로젝트 목록
                ForEach(area.projects.sorted { $0.order < $1.order }) { project in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: project.colorHex) ?? .blue)
                            .frame(width: 10, height: 10)
                        Text(project.name).font(.system(size: 15))
                        Spacer()
                        if project.pendingCount > 0 {
                            Text("\(project.pendingCount)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Divider().padding(.leading, 32) }
                }
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle(area.name)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    showAddProject = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                        Text("새 프로젝트").font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.vertical, 10)
                Spacer()
            }
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
        .sheet(isPresented: $showAddProject) { AddProjectSheet(area: area) }
    }
}

// MARK: - Project Detail
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    var timerManager: TimerManager

    @State private var newTaskTitle = ""
    @State private var isAddingTask = false
    @State private var selectedTask: Task? = nil

    var pendingTasks: [Task] { project.tasks.filter { !$0.isCompleted } }
    var completedTasks: [Task] { project.tasks.filter { $0.isCompleted } }
    var projColor: Color { Color(hex: project.colorHex) ?? .blue }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // 프로젝트 헤더
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Circle().fill(projColor).frame(width: 14, height: 14)
                        Text(project.name)
                            .font(.system(size: 26, weight: .bold))
                    }

                    // Notes
                    TextField("Notes", text: Binding(
                        get: { project.notes },
                        set: { project.notes = $0; try? modelContext.save() }
                    ), axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 32)

                // 태스크 목록
                VStack(spacing: 0) {
                    ForEach(pendingTasks) { task in
                        ThingsTaskRow(
                            task: task,
                            project: project,
                            timerManager: timerManager,
                            isSelected: selectedTask?.id == task.id,
                            onSelect: { selectedTask = selectedTask?.id == task.id ? nil : task }
                        )
                    }

                    // 인라인 태스크 추가
                    if isAddingTask {
                        HStack(spacing: 14) {
                            Circle()
                                .strokeBorder(projColor, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            TextField("새 태스크", text: $newTaskTitle)
                                .font(.system(size: 14))
                                .textFieldStyle(.plain)
                                .onSubmit { submitNewTask() }
                            Spacer()
                            Button { isAddingTask = false } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                    }
                }

                // 완료된 태스크
                if !completedTasks.isEmpty {
                    HStack {
                        Text("완료됨")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .padding(.bottom, 6)

                    ForEach(completedTasks) { task in
                        ThingsTaskRow(
                            task: task,
                            project: project,
                            timerManager: timerManager,
                            isSelected: false,
                            onSelect: { }
                        )
                    }
                }
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    isAddingTask = true
                    newTaskTitle = ""
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .medium))
                        Text("새 태스크").font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 32)
                Spacer()

                // 실행 중 타이머
                if timerManager.activeEntry != nil {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(timerManager.clockString)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    .padding(.trailing, 20)
                }
            }
            .padding(.vertical, 12)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    func submitNewTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            isAddingTask = false
            return
        }
        let task = Task(title: newTaskTitle, project: project)
        project.tasks.append(task)
        modelContext.insert(task)
        try? modelContext.save()
        newTaskTitle = ""
    }
}

// MARK: - Things Task Row
struct ThingsTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    var project: Project
    var timerManager: TimerManager
    var isSelected: Bool
    var onSelect: () -> Void

    var isRunning: Bool { timerManager.isRunning(task: task) }
    var projColor: Color { Color(hex: project.colorHex) ?? .blue }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // 체크박스
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        task.isCompleted.toggle()
                        if task.isCompleted && isRunning { timerManager.stop() }
                        try? modelContext.save()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(task.isCompleted ? projColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if task.isCompleted {
                            Circle().fill(projColor).frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                // 제목 + 서브텍스트 — 클릭하면 펼치기
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 14))
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))

                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar").font(.system(size: 10))
                                Text(formatDate(due)).font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                        }
                        if task.totalSeconds > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "clock").font(.system(size: 10))
                                Text(task.formattedTime).font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !task.isCompleted { onSelect() }
                }

                // 타이머
                if !task.isCompleted {
                    Button {
                        isRunning ? timerManager.stop() : timerManager.start(task: task)
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isRunning ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 24, height: 24)
                            .background(isRunning ? Color.green.opacity(0.1) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 9)

            // 선택 시 인라인 상세 — Things 3 스타일
            if isSelected {
                VStack(alignment: .leading, spacing: 10) {
                    // Notes
                    TextField("Notes", text: Binding(
                        get: { task.notes },
                        set: { task.notes = $0; try? modelContext.save() }
                    ), axis: .vertical)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.plain)
                    .padding(.leading, 68)
                    .padding(.trailing, 32)

                    Divider().padding(.leading, 68)

                    // 하단 툴바 — When / 태그 / 체크리스트
                    HStack(spacing: 12) {
                        Spacer().frame(width: 68)
                        WhenButton(task: task)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                .background(Color.secondary.opacity(0.04))
            }

            Divider().padding(.leading, 68)
        }
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

// MARK: - When Button (날짜 선택)
struct WhenButton: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(task.dueDate.map { formatDate($0) } ?? "When")
                    .font(.system(size: 12))
            }
            .foregroundStyle(task.dueDate != nil ? Color.blue : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(task.dueDate != nil ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                // 오늘 / 저녁
                Button {
                    task.dueDate = Calendar.current.startOfDay(for: Date())
                    try? modelContext.save()
                    showPicker = false
                } label: {
                    HStack {
                        Text("⭐️").font(.system(size: 14))
                        Text("오늘").font(.system(size: 14))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider()

                DatePicker("", selection: Binding(
                    get: { task.dueDate ?? Date() },
                    set: { task.dueDate = $0; try? modelContext.save(); showPicker = false }
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
                    HStack {
                        Text("🗂️").font(.system(size: 14))
                        Text("Someday").font(.system(size: 14))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
#endif
