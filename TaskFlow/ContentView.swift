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
                UpcomingView().navigationTitle("Upcoming").navigationBarTitleDisplayMode(.large)
            }
            .tabItem { Label("Upcoming", systemImage: "calendar.badge.clock") }.tag(1)

            NavigationStack {
                CalendarView().navigationTitle("캘린더").navigationBarTitleDisplayMode(.large)
            }
            .tabItem { Label("캘린더", systemImage: "calendar") }.tag(2)

            NavigationStack {
                StatsView().navigationTitle("통계").navigationBarTitleDisplayMode(.large)
            }
            .tabItem { Label("통계", systemImage: "chart.bar") }.tag(3)

            NavigationStack {
                SpendingView()
            }
            .tabItem { Label("가계부", systemImage: "wonsign.circle") }.tag(4)

            NavigationStack {
                WishlistView()
            }
            .tabItem { Label("위시리스트", systemImage: "heart") }.tag(5)

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
    @State private var sidebarTapCount = 0
    @State private var showAddArea = false
    @State private var showAddProject: Area? = nil

    var body: some View {
        NavigationSplitView {
            ThingsSidebar(
                selection: $selection,
                showAddArea: $showAddArea,
                showAddProject: $showAddProject,
                onTap: { item in
                    selection = item
                    sidebarTapCount += 1
                }
            )
            .navigationSplitViewColumnWidth(min: 160, ideal: 175, max: 200)
        } detail: {
            Group {
                switch selection {
                case .today:
                    TodayView(timerManager: timerManager, showAddTask: .constant(nil))
                case .upcoming:
                    UpcomingView()
                case .stats:
                    StatsView()
                case .calendar:
                    CalendarView()
                case .studyPlan:
                    StudyPlanListView()
                case .spending:
                    SpendingView()
                case .wishlist:
                    WishlistView()
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
            .id(sidebarTapCount)
        }
        .onAppear { timerManager.setup(context: modelContext) }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showAddArea) { AddAreaSheet() }
        .sheet(item: $showAddProject) { AddProjectSheet(area: $0) }
    }
}

// MARK: - Sidebar Item
enum SidebarItem: Hashable {
    case today, upcoming, stats, calendar, studyPlan, spending, wishlist
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
    var onTap: ((SidebarItem) -> Void)? = nil

    var body: some View {
        List(selection: $selection) {
            // LIFE
            Section("Life") {
                Label("오늘", systemImage: "star.fill")
                    .foregroundStyle(.primary).lineLimit(1)
                    .tag(SidebarItem.today)
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.today) })
                Label("Upcoming", systemImage: "calendar.badge.clock")
                    .foregroundStyle(.primary).lineLimit(1)
                    .tag(SidebarItem.upcoming)
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.upcoming) })
                Label("캘린더", systemImage: "calendar")
                    .foregroundStyle(.primary).lineLimit(1)
                    .tag(SidebarItem.calendar)
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.calendar) })
                Label("가계부", systemImage: "wonsign.circle.fill")
                    .foregroundStyle(.primary).lineLimit(1)
                    .tag(SidebarItem.spending)
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.spending) })
                Label("위시리스트", systemImage: "heart")
                    .foregroundStyle(.primary).lineLimit(1)
                    .tag(SidebarItem.wishlist)
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.wishlist) })
            }

            // STUDY
            Section("Study") {
                Label("통계", systemImage: "chart.bar.fill")
                    .foregroundStyle(.primary).lineLimit(1)
                    .tag(SidebarItem.stats)
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.stats) })
                Label("학습 계획", systemImage: "books.vertical.fill")
                    .foregroundStyle(.primary).lineLimit(1)
                    .tag(SidebarItem.studyPlan)
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.studyPlan) })
            }

            // Area별 프로젝트
            ForEach(areas.sorted { $0.order < $1.order }) { area in
                Section {
                    // Area 행
                    HStack(spacing: 8) {
                        Image(systemName: "tray.2")
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
                    .simultaneousGesture(TapGesture().onEnded { onTap?(.area(area.id)) })

                    // 하위 프로젝트
                    ForEach(area.projects.sorted { $0.order < $1.order }) { project in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: project.colorHex) ?? .blue)
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
                        .simultaneousGesture(TapGesture().onEnded { onTap?(.project(project.id)) })
                    }
                }
            }

            // Area 없는 프로젝트
            if !looseProjects.isEmpty {
                Section("프로젝트") {
                    ForEach(looseProjects) { project in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: project.colorHex) ?? .blue)
                            Text(project.name).font(.system(size: 13)).lineLimit(1)
                            Spacer()
                            let pending = project.pendingCount
                            if pending > 0 {
                                Text("\(pending)").font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                        }
                        .tag(SidebarItem.project(project.id))
                        .simultaneousGesture(TapGesture().onEnded { onTap?(.project(project.id)) })
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
    @Query private var allEvents: [SchoolEvent]

    var areaEvents: [SchoolEvent] {
        allEvents.filter { $0.area?.id == area.id }.sorted { $0.date < $1.date }
    }

    var isSchoolArea: Bool { area.name == "학교" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "tray.2.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text(area.name)
                            .font(.system(size: 26, weight: .bold))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 32)

                // ── 주요 행사 섹션 (학교 Area 전용)
                if isSchoolArea {
                    SchoolEventsSection(area: area, events: areaEvents)
                        .padding(.top, 8)

                    Divider().padding(.horizontal, 32).padding(.top, 4)
                }

                // 하위 프로젝트 목록
                if !area.projects.isEmpty {
                    HStack {
                        Text("프로젝트")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .padding(.bottom, 6)
                }

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
                Button { showAddProject = true } label: {
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

// MARK: - 주요 행사 섹션
struct SchoolEventsSection: View {
    @Environment(\.modelContext) private var modelContext
    var area: Area
    var events: [SchoolEvent]
    @State private var showAddEvent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 섹션 헤더
            HStack {
                Text("주요 행사")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showAddEvent = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(events) { event in
                SchoolEventRow(event: event)
            }

            if events.isEmpty {
                Text("행사를 추가해주세요")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddSchoolEventSheet(area: area)
        }
    }
}

// MARK: - 행사 행
struct SchoolEventRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: SchoolEvent
    @State private var showDatePicker = false

    var typeColor: Color {
        switch event.type {
        case "midterm": return .orange
        case "final":   return .red
        default:        return .blue
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 아이콘
            Image(systemName: event.icon)
                .font(.system(size: 13))
                .foregroundStyle(typeColor)
                .frame(width: 28)

            // 제목
            Text(event.title)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)

            // D-Day 뱃지
            Text(event.dDay)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(event.dDay == "D-Day" ? .white : typeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(event.dDay == "D-Day" ? typeColor : typeColor.opacity(0.12))
                .clipShape(Capsule())

            // 날짜
            Button {
                showDatePicker.toggle()
            } label: {
                Text(formatDate(event.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker, arrowEdge: .trailing) {
                DatePicker("", selection: Binding(
                    get: { event.date },
                    set: { event.date = $0; try? modelContext.save(); showDatePicker = false }
                ), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .frame(width: 280)
                .padding(8)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 32) }
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
    }
}

// MARK: - 행사 추가 시트
struct AddSchoolEventSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var area: Area

    @State private var title = ""
    @State private var date = Date()
    @State private var type = "custom"

    let presets = [
        ("중간고사", "midterm"),
        ("기말고사", "final"),
        ("수행평가", "custom"),
        ("현장학습", "custom"),
        ("학교 행사", "custom"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("행사명") {
                    TextField("행사 이름", text: $title)

                    // 빠른 선택
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.0) { name, t in
                                Button {
                                    title = name
                                    type = t
                                } label: {
                                    Text(name)
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(title == name ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("날짜") {
                    DatePicker("날짜 선택", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("종류") {
                    Picker("종류", selection: $type) {
                        Text("중간고사").tag("midterm")
                        Text("기말고사").tag("final")
                        Text("기타").tag("custom")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("행사 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { submit() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    func submit() {
        let event = SchoolEvent(title: title, date: date, type: type, area: area)
        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 시험일 섹션
struct ExamDatesSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    var projColor: Color

    @State private var showMidtermPicker = false
    @State private var showFinalPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("시험일")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // 중간고사
            ExamDateRow(
                label: "중간고사",
                icon: "doc.text.fill",
                color: .orange,
                date: project.midtermDate,
                showPicker: $showMidtermPicker
            ) { newDate in
                project.midtermDate = newDate
                try? modelContext.save()
            } onClear: {
                project.midtermDate = nil
                try? modelContext.save()
            }

            Divider().padding(.leading, 32)

            // 기말고사
            ExamDateRow(
                label: "기말고사",
                icon: "checkmark.seal.fill",
                color: .red,
                date: project.finalDate,
                showPicker: $showFinalPicker
            ) { newDate in
                project.finalDate = newDate
                try? modelContext.save()
            } onClear: {
                project.finalDate = nil
                try? modelContext.save()
            }
        }
        .padding(.bottom, 4)
    }
}

struct ExamDateRow: View {
    var label: String
    var icon: String
    var color: Color
    var date: Date?
    @Binding var showPicker: Bool
    var onSet: (Date) -> Void
    var onClear: () -> Void

    var dDay: String? {
        guard let date else { return nil }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "D-Day" }
        if days > 0  { return "D-\(days)" }
        return "D+\(-days)"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 14))

            Spacer()

            // D-Day 뱃지
            if let dDay {
                Text(dDay)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(dDay == "D-Day" ? .white : color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(dDay == "D-Day" ? color : color.opacity(0.12))
                    .clipShape(Capsule())
            }

            // 날짜 버튼
            Button {
                showPicker.toggle()
            } label: {
                Text(date.map { formatDate($0) } ?? "날짜 미정")
                    .font(.system(size: 12))
                    .foregroundStyle(date != nil ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPicker, arrowEdge: .trailing) {
                VStack(spacing: 0) {
                    DatePicker("", selection: Binding(
                        get: { date ?? Date() },
                        set: { onSet($0); showPicker = false }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .frame(width: 280)
                    .padding(8)

                    if date != nil {
                        Divider()
                        Button {
                            onClear(); showPicker = false
                        } label: {
                            Text("날짜 삭제")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 10)
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
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
    var isSchoolProject: Bool { project.area?.name == "학교" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // 프로젝트 헤더
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(projColor)
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

                // 시험일 섹션 (학교 소속 프로젝트만)
                if isSchoolProject {
                    ExamDatesSection(project: project, projColor: projColor)
                    Divider().padding(.horizontal, 32)
                }

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
    @State private var showEdit = false
    @State private var showDeleteAlert = false

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
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 15))
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.5))

                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar").font(.system(size: 12))
                                Text(formatDate(due)).font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                        }
                        if task.totalSeconds > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "clock").font(.system(size: 12))
                                Text(task.formattedTime).font(.system(size: 12))
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
            .padding(.vertical, 13)

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
        .contextMenu {
            Button {
                showEdit = true
            } label: {
                Label("편집", systemImage: "pencil")
            }
            Button {
                task.isCompleted.toggle()
                if task.isCompleted && timerManager.isRunning(task: task) { timerManager.stop() }
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
