import SwiftUI
import SwiftData

// MARK: - AddAreaSheet
struct AddAreaSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "hexagon")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .leading) {
                    if name.isEmpty {
                        Text("새 Area")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primary.opacity(0.28))
                    }
                    TextField("", text: $name)
                        .font(.system(size: 16))
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit { submit() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider()

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button { submit() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(name.isEmpty ? Color.secondary : Color.white)
                        .frame(width: 26, height: 26)
                        .background(name.isEmpty ? Color.secondary.opacity(0.12) : Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { focused = true }
    }

    func submit() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let area = Area(name: name, order: 0)
        modelContext.insert(area)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - AddProjectSheet
struct AddProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var area: Area? = nil
    var parentProject: Project? = nil

    @State private var name = ""
    @State private var selectedColor = "A8C8E8"

    let presets = [
        "A8C8E8", // 블루
        "BBA8E8", // 라벤더
        "F5C8A0", // 피치
        "A0D4B0", // 민트
        "F5AAAA", // 로즈
        "E8A8BC", // 모브
        "B8B8E8", // 페리윙클
        "A0D8D4", // 틸
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: selectedColor) ?? .blue)
                    .frame(width: 10, height: 10)

                ZStack(alignment: .leading) {
                    if name.isEmpty {
                        Text("새 프로젝트")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary.opacity(0.28))
                    }
                    TextField("", text: $name)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit { submit() }
                }

                if let area = area {
                    Spacer()
                    Text(area.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            // 색상 프리셋
            HStack(spacing: 0) {
                ForEach(presets, id: \.self) { hex in
                    ZStack {
                        Circle()
                            .fill(Color(hex: hex) ?? .blue)
                            .frame(width: 17, height: 17)
                        if selectedColor == hex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(selectedColor == hex ? 1.15 : 1.0)
                    .animation(.spring(duration: 0.15), value: selectedColor)
                    .onTapGesture { selectedColor = hex }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Divider().opacity(0.4)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button { submit() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(name.isEmpty ? Color.secondary : Color.white)
                        .frame(width: 22, height: 22)
                        .background(name.isEmpty ? Color.secondary.opacity(0.12) : Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .frame(width: 280)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 6)
        .onAppear { focused = true }
    }

    func submit() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let project = Project(name: name, colorHex: selectedColor, area: area)
        if let area = area {
            area.projects.append(project)
        }
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - AddTaskSheet (iOS용)
struct AddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    var project: Project

    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var showDatePicker = false

    var projColor: Color { Color(hex: project.colorHex) ?? .blue }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .strokeBorder(projColor, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    ZStack(alignment: .leading) {
                        if title.isEmpty {
                            Text("새 태스크")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primary.opacity(0.28))
                        }
                        TextField("", text: $title)
                            .font(.system(size: 16))
                            .textFieldStyle(.plain)
                            .focused($titleFocused)
                            .onSubmit { submit() }
                    }
                    ZStack(alignment: .leading) {
                        if notes.isEmpty {
                            Text("메모")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.primary.opacity(0.2))
                        }
                        TextField("", text: $notes)
                            .font(.system(size: 13))
                            .textFieldStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if showDatePicker {
                Divider()
                DatePicker("", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .padding(.horizontal, 8)
                    .onChange(of: dueDate) { _, _ in
                        withAnimation { showDatePicker = false }
                    }
            }

            Divider()

            HStack(spacing: 4) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Circle().fill(projColor).frame(width: 7, height: 7)
                    Text(project.name).font(.system(size: 12, weight: .medium)).foregroundStyle(projColor).lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(projColor.opacity(0.1)).clipShape(Capsule())

                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        showDatePicker.toggle()
                        hasDueDate = showDatePicker
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar").font(.system(size: 12))
                        if hasDueDate { Text(formatDate(dueDate)).font(.system(size: 12, weight: .medium)) }
                    }
                    .foregroundStyle(hasDueDate ? Color.blue : Color.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(hasDueDate ? Color.blue.opacity(0.1) : Color.clear).clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button { submit() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(title.isEmpty ? Color.secondary : Color.white)
                        .frame(width: 26, height: 26)
                        .background(title.isEmpty ? Color.secondary.opacity(0.12) : Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 340)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { titleFocused = true }
    }

    func submit() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let finalDueDate = hasDueDate ? dueDate : nil
        let task = Task(title: title, notes: notes, project: project, dueDate: finalDueDate)
        project.tasks.append(task)
        modelContext.insert(task)
        try? modelContext.save()
        if let date = finalDueDate {
            _Concurrency.Task {
                await CalendarManager.shared.addEvent(
                    title: title,
                    dueDate: date,
                    notes: notes
                )
            }
        }
        dismiss()
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}
