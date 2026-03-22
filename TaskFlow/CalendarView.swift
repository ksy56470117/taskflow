import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var projects: [Project]
    @Query private var allTasks: [Task]   // 프로젝트 없는 태스크 포함
    @State private var selectedDate = Date()
    @State private var displayMonth = Date()
    @State private var showAddTask = false

    var calendar: Calendar { Calendar.current }

    func tasksForDate(_ date: Date) -> [Task] {
        allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }
    }

    var tasksForSelected: [Task] { tasksForDate(selectedDate) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // 월 네비게이션
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

                // 달력 그리드
                VStack(spacing: 0) {
                    // 요일 헤더
                    HStack(spacing: 0) {
                        ForEach(Array(["일","월","화","수","목","금","토"].enumerated()), id: \.offset) { i, d in
                            Text(d)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(i == 0 ? Color.red.opacity(0.7) : i == 6 ? Color.blue.opacity(0.7) : Color.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 6)

                    Divider()

                    // 주 단위 행 — 각 행 높이가 독립적으로 늘어남
                    let weeks = generateDays(for: displayMonth).chunked(into: 7)
                    VStack(spacing: 0) {
                        ForEach(weeks.indices, id: \.self) { wi in
                            HStack(spacing: 0) {
                                ForEach(0..<7, id: \.self) { di in
                                    let date = weeks[wi][di]
                                    DayCell(
                                        date: date,
                                        isCurrentMonth: calendar.isDate(date, equalTo: displayMonth, toGranularity: .month),
                                        isToday: calendar.isDateInToday(date),
                                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                        tasks: tasksForDate(date),
                                        colIndex: di
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedDate = date }
                                    if di < 6 { Divider() }
                                }
                            }
                            if wi < weeks.count - 1 { Divider() }
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                // 선택 날짜 태스크 목록
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
                .presentationDetents([.height(340)])
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
    var tasks: [Task]
    var colIndex: Int = 0

    var dayNum: Int { Calendar.current.component(.day, from: date) }
    var numColor: Color {
        if isSelected { return .white }
        if isToday    { return .blue }
        if !isCurrentMonth { return Color.primary.opacity(0.18) }
        if colIndex == 0 { return Color.red.opacity(0.8) }
        if colIndex == 6 { return Color.blue.opacity(0.8) }
        return .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 날짜 숫자
            ZStack {
                if isSelected {
                    Circle().fill(Color.blue).frame(width: 24, height: 24)
                } else if isToday {
                    Circle().stroke(Color.blue, lineWidth: 1.5).frame(width: 24, height: 24)
                }
                Text("\(dayNum)")
                    .font(.system(size: 12, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(numColor)
            }
            .frame(width: 24, height: 24)

            // 태스크 칩
            ForEach(tasks) { task in
                let col: Color = task.project.flatMap { Color(hex: $0.colorHex) } ?? Color.gray
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(col)
                        .frame(width: 2.5)
                        .frame(maxHeight: .infinity)
                    Text(task.title)
                        .font(.system(size: 9.5))
                        .foregroundStyle(
                            task.isCompleted
                                ? Color.secondary.opacity(0.6)
                                : (isCurrentMonth ? Color.primary : Color.secondary)
                        )
                        .strikethrough(task.isCompleted, color: .secondary)
                        .lineLimit(nil)          // 줄넘김 제한 없음
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .background(col.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 5)
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
        HStack(spacing: 12) {
            Button {
                task.isCompleted.toggle()
                try? modelContext.save()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(projColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if task.isCompleted {
                        Circle().fill(projColor).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

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
        .overlay(alignment: .bottom) { Divider().padding(.leading, 52) }
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

// MARK: - 할일 추가 시트
struct CalendarAddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var date: Date
    var projects: [Project]

    @State private var title = ""
    @State private var selectedProject: Project? = nil

    var sortedProjects: [Project] { projects.sorted { $0.name < $1.name } }
    var canSubmit: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // 제목 입력
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selectedProject.flatMap { Color(hex: $0.colorHex) } ?? Color.secondary.opacity(0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                }

                TextField("제목 입력", text: $title)
                    .focused($focused)
                    .font(.system(size: 17))
                    .onSubmit { if canSubmit { submit() } }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            // 프로젝트 선택
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                Menu {
                    Button {
                        selectedProject = nil
                    } label: {
                        HStack {
                            Text("없음")
                            if selectedProject == nil { Image(systemName: "checkmark") }
                        }
                    }
                    if !sortedProjects.isEmpty { Divider() }
                    ForEach(sortedProjects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            HStack {
                                Text(project.name)
                                if selectedProject?.id == project.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let p = selectedProject {
                            Circle()
                                .fill(Color(hex: p.colorHex) ?? .blue)
                                .frame(width: 8, height: 8)
                            Text(p.name)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                        } else {
                            Text("프로젝트 선택")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // 날짜
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(dateLabel(date))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

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

                Button { submit() } label: {
                    Text("추가")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canSubmit ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canSubmit ? Color.blue : Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.background)
        .onAppear { focused = true }
    }

    func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let task = Task(title: trimmed, project: selectedProject)
        task.dueDate = date
        modelContext.insert(task)
        if let p = selectedProject {
            p.tasks.append(task)
        }
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
