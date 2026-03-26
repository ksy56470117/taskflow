import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Note Editor

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: NoteDocument
    @FocusState private var focusedId: UUID?
    @State private var showImageImporter = false
    @State private var showMindMap = false

    var sortedBlocks: [NoteBlock] {
        document.blocks.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 제목
                TextField("제목 없음", text: Binding(
                    get: { document.title },
                    set: { document.title = $0; document.updatedAt = Date() }
                ))
                .font(.system(size: 20, weight: .bold))
                .textFieldStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 28)
                .padding(.bottom, 4)

                Text(formatDate(document.updatedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 14)

                Divider().padding(.horizontal, 40).padding(.bottom, 6)

                // 블록들
                ForEach(Array(sortedBlocks.enumerated()), id: \.element.id) { idx, block in
                    NoteBlockRow(
                        block: block,
                        allBlocks: sortedBlocks,
                        focusedId: $focusedId,
                        onReturn: {
                            let nb = insertBlock(after: block, inheritIndent: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedId = nb.id }
                        },
                        onIndent: { indentBlock(block) },
                        onDedent: { dedentBlock(block) },
                        onDeleteEmpty: {
                            let prevId = idx > 0 ? sortedBlocks[idx - 1].id : nil
                            deleteBlock(block)
                            if let pid = prevId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedId = pid }
                            }
                        }
                    )
                }

                // 빈 영역 탭 → 새 블록
                Color.clear
                    .frame(maxWidth: .infinity).frame(height: 120)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let nb = insertBlock(after: sortedBlocks.last, inheritIndent: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedId = nb.id }
                    }
            }
        }
        .navigationTitle("")
        #if os(macOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 들여쓰기 (현재 포커스된 텍스트 블록에만)
                if let fid = focusedId,
                   let block = document.blocks.first(where: { $0.id == fid }),
                   block.blockType == "text" {
                    Button { dedentBlock(block) } label: {
                        Image(systemName: "decrease.indent")
                    }
                    .help("내어쓰기 (⌘[)")
                    .keyboardShortcut("[", modifiers: .command)

                    Button { indentBlock(block) } label: {
                        Image(systemName: "increase.indent")
                    }
                    .help("들여쓰기 (⌘])")
                    .keyboardShortcut("]", modifiers: .command)

                    Divider()
                }

                Button { addTextBox() } label: {
                    Label("텍스트박스", systemImage: "text.viewfinder")
                }
                .help("텍스트 박스 추가")

                Button { showImageImporter = true } label: {
                    Label("이미지", systemImage: "photo.badge.plus")
                }
                .help("이미지 추가")

                Button { showMindMap = true } label: {
                    Label("마인드맵", systemImage: "circle.hexagongrid")
                }
                .help("마인드맵 열기")
            }
        }
        #endif
        .fileImporter(isPresented: $showImageImporter, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result,
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    insertImageBlock(data: data)
                }
            }
        }
        .sheet(isPresented: $showMindMap) {
            NavigationStack {
                MindMapEditorView(document: document)
                #if os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") { showMindMap = false }
                        }
                    }
                #endif
            }
        }
        .onAppear {
            if document.blocks.isEmpty {
                let b = NoteBlock(order: 0)
                b.document = document
                document.blocks.append(b)
                modelContext.insert(b)
                try? modelContext.save()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusedId = b.id }
            }
        }
    }

    // MARK: - Block operations

    @discardableResult
    func insertBlock(after prev: NoteBlock?, inheritIndent: Bool) -> NoteBlock {
        let blocks = sortedBlocks
        let indent = inheritIndent ? (prev?.indentLevel ?? 0) : 0
        let newOrder: Int

        if let prev, let idx = blocks.firstIndex(where: { $0.id == prev.id }) {
            newOrder = prev.order + 1
            for i in (idx + 1)..<blocks.count { blocks[i].order += 1 }
        } else {
            newOrder = (blocks.map(\.order).max() ?? -1) + 1
        }

        let b = NoteBlock(order: newOrder, blockType: "text", content: "", indentLevel: indent)
        b.document = document
        document.blocks.append(b)
        modelContext.insert(b)
        document.updatedAt = Date()
        try? modelContext.save()
        return b
    }

    func insertImageBlock(data: Data) {
        let maxOrder = (document.blocks.map(\.order).max() ?? -1) + 1
        let b = NoteBlock(order: maxOrder, blockType: "image", content: "")
        b.imageData = data
        b.document = document
        document.blocks.append(b)
        modelContext.insert(b)
        document.updatedAt = Date()
        try? modelContext.save()
    }

    func addTextBox() {
        let maxOrder = (document.blocks.map(\.order).max() ?? -1) + 1
        let b = NoteBlock(order: maxOrder, blockType: "textbox", content: "")
        b.document = document
        document.blocks.append(b)
        modelContext.insert(b)
        try? modelContext.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedId = b.id }
    }

    func indentBlock(_ block: NoteBlock) {
        block.indentLevel = min(block.indentLevel + 1, 11)
        document.updatedAt = Date()
        try? modelContext.save()
    }

    func dedentBlock(_ block: NoteBlock) {
        block.indentLevel = max(block.indentLevel - 1, 0)
        document.updatedAt = Date()
        try? modelContext.save()
    }

    func deleteBlock(_ block: NoteBlock) {
        document.blocks.removeAll { $0.id == block.id }
        modelContext.delete(block)
        document.updatedAt = Date()
        try? modelContext.save()
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 수정"
        return f.string(from: d)
    }
}

// MARK: - Note Block Row

struct NoteBlockRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: NoteBlock
    var allBlocks: [NoteBlock]
    var focusedId: FocusState<UUID?>.Binding
    var onReturn: () -> Void
    var onIndent: () -> Void
    var onDedent: () -> Void
    var onDeleteEmpty: () -> Void

    var body: some View {
        switch block.blockType {
        case "image":   imageView
        case "textbox": textBoxView
        default:        textView
        }
    }

    // MARK: 텍스트 블록 (개요 번호 포함)
    var textView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // 들여쓰기 공간
            Spacer().frame(width: CGFloat(block.indentLevel) * 22)

            // 개요 번호
            Text(outlinePrefix())
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
                .padding(.trailing, 5)

            // 텍스트 필드
            TextField("", text: Binding(
                get: { block.content },
                set: { block.content = $0; try? modelContext.save() }
            ))
            .font(.system(size: 14))
            .textFieldStyle(.plain)
            .focused(focusedId, equals: block.id)
            .onSubmit { onReturn() }
            #if os(macOS)
            .onKeyPress(phases: .down) { press in
                if press.key == .tab {
                    if press.modifiers.contains(.shift) { onDedent() } else { onIndent() }
                    return .handled
                }
                if press.key == .delete && block.content.isEmpty {
                    onDeleteEmpty()
                    return .handled
                }
                return .ignored
            }
            #endif
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 3)
    }

    // MARK: 텍스트박스
    var textBoxView: some View {
        #if os(macOS)
        TextEditor(text: Binding(
            get: { block.content },
            set: { block.content = $0; try? modelContext.save() }
        ))
        .font(.system(size: 14))
        .scrollDisabled(true)
        .frame(minHeight: 56)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 40)
        .padding(.vertical, 5)
        #else
        TextEditor(text: Binding(
            get: { block.content },
            set: { block.content = $0; try? modelContext.save() }
        ))
        .font(.system(size: 14))
        .frame(minHeight: 56)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 40)
        .padding(.vertical, 5)
        #endif
    }

    // MARK: 이미지 블록
    @ViewBuilder
    var imageView: some View {
        #if os(macOS)
        if let data = block.imageData, let nsImg = NSImage(data: data) {
            Image(nsImage: nsImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 500)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 40)
                .padding(.vertical, 6)
                .contextMenu {
                    Button(role: .destructive) {
                        block.imageData = nil
                        block.blockType = "text"
                        try? modelContext.save()
                    } label: { Label("이미지 삭제", systemImage: "trash") }
                }
        }
        #else
        if let data = block.imageData, let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 40)
                .padding(.vertical, 6)
        }
        #endif
    }

    // MARK: 개요 번호 계산 (1. → 1) → (1) → ①)
    func outlinePrefix() -> String {
        guard let idx = allBlocks.firstIndex(where: { $0.id == block.id }) else { return "" }
        let level = block.indentLevel
        var count = 1
        for j in stride(from: idx - 1, through: 0, by: -1) {
            let prev = allBlocks[j]
            if prev.blockType == "image" { continue }
            if prev.indentLevel < level { break }
            if prev.indentLevel == level { count += 1 }
        }
        switch level % 4 {
        case 0: return "\(count)."
        case 1: return "\(count))"
        case 2: return "(\(count))"
        case 3:
            let c = ["①","②","③","④","⑤","⑥","⑦","⑧","⑨","⑩",
                     "⑪","⑫","⑬","⑭","⑮","⑯","⑰","⑱","⑲","⑳"]
            return count <= 20 ? c[count - 1] : "(\(count))"
        default: return "\(count)."
        }
    }
}
