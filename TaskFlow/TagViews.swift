import SwiftUI
import SwiftData

// MARK: - Tag Chip (display only)
struct TagChip: View {
    var tag: Tag
    var isRemovable: Bool = false
    var onRemove: (() -> Void)? = nil

    var chipColor: Color { Color(hex: tag.colorHex) ?? .ghGreen }

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(chipColor)
                .frame(width: 6, height: 6)
            Text(tag.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(chipColor)
            if isRemovable {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(chipColor.opacity(0.6))
                    .onTapGesture { onRemove?() }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(chipColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Tag Picker Button (inline row widget)
struct TagPickerButton: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Bindable var task: Task

    @State private var showCreate = false

    var body: some View {
        HStack(spacing: 6) {
            // Selected tag chips
            ForEach(task.tags) { tag in
                TagChip(tag: tag, isRemovable: true) {
                    task.tags.removeAll { $0.id == tag.id }
                    try? modelContext.save()
                }
            }

            // Dropdown button
            Menu {
                if allTags.isEmpty {
                    Text("태그 없음").foregroundStyle(.secondary)
                }
                ForEach(allTags) { tag in
                    Button {
                        toggleTag(tag)
                    } label: {
                        HStack {
                            Label(tag.name, systemImage: "circle.fill")
                            if task.tags.contains(where: { $0.id == tag.id }) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button {
                    showCreate = true
                } label: {
                    Label("새 태그 만들기", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "tag")
                        .font(.system(size: 11))
                    if task.tags.isEmpty {
                        Text("태그 추가")
                            .font(.system(size: 12))
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showCreate) {
            CreateTagSheet()
                .presentationDetents([.height(320)])
        }
    }

    func toggleTag(_ tag: Tag) {
        if task.tags.contains(where: { $0.id == tag.id }) {
            task.tags.removeAll { $0.id == tag.id }
        } else {
            task.tags.append(tag)
        }
        try? modelContext.save()
    }
}

// MARK: - Create Tag Sheet
struct CreateTagSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    @State private var name = ""
    @State private var selectedColor = "6366F1"

    let presetColors = [
        "6366F1", "3B82F6", "10B981", "F59E0B",
        "EF4444", "EC4899", "8B5CF6", "F97316",
        "06B6D4", "84CC16"
    ]

    var canCreate: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)

            Text("새 태그 만들기")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 12)

            Divider()

            // Name
            TextField("태그 이름", text: $name)
                .focused($focused)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onSubmit { if canCreate { createTag() } }

            Divider()

            // Color picker
            VStack(alignment: .leading, spacing: 10) {
                Text("색상")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(presetColors, id: \.self) { hex in
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex) ?? .ghGreen)
                                .frame(width: 28, height: 28)
                            if selectedColor == hex {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .scaleEffect(selectedColor == hex ? 1.12 : 1.0)
                        .animation(.spring(response: 0.2), value: selectedColor)
                        .onTapGesture { selectedColor = hex }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
            Spacer()

            // Preview
            if !name.isEmpty {
                HStack {
                    Text("미리보기")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TagChip(tag: Tag(name: name, colorHex: selectedColor))
                }
                .padding(.bottom, 8)
            }

            // Buttons
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

                Button { createTag() } label: {
                    Text("만들기")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canCreate ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canCreate ? Color.ghGreen : Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.background)
        .onAppear { focused = true }
    }

    func createTag() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, colorHex: selectedColor)
        modelContext.insert(tag)
        try? modelContext.save()
        dismiss()
    }
}
