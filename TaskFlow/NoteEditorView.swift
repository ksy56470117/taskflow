import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

// MARK: - Cross-platform background color
enum NoteEditorColors {
    #if os(macOS)
    static let background = NSColor.windowBackgroundColor
    #else
    static let background = UIColor.systemBackground
    #endif
}

// MARK: - Color palettes
let postitColorPalette: [(name: String, hex: String)] = [
    ("노랑", "FEF3C7"), ("분홍", "FCE7F3"), ("연두", "D1FAE5"),
    ("하늘", "DBEAFE"), ("보라", "EDE9FE"), ("주황", "FFEDD5")
]

let textColorPalette: [(name: String, hex: String)] = [
    ("기본", ""), ("빨강", "EF4444"), ("주황", "F97316"), ("노랑", "EAB308"),
    ("초록", "22C55E"), ("파랑", "3B82F6"), ("보라", "8B5CF6"), ("회색", "6B7280")
]

let highlightPalette: [(name: String, hex: String)] = [
    ("없음", ""), ("노랑", "FEF08A"), ("초록", "BBF7D0"), ("파랑", "BFDBFE"),
    ("분홍", "FBCFE8"), ("보라", "DDD6FE"), ("주황", "FED7AA")
]

let nodeColorPalette: [(name: String, hex: String)] = [
    ("기본", ""), ("빨강", "FCA5A5"), ("주황", "FDBA74"), ("노랑", "FDE047"),
    ("초록", "86EFAC"), ("파랑", "93C5FD"), ("보라", "C4B5FD"), ("분홍", "F9A8D4")
]

// MARK: - Note Editor

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: NoteDocument
    @FocusState private var focusedId: UUID?
    @State private var showImageImporter = false
    @State private var showPDFImporter = false

    var sortedBlocks: [NoteBlock] {
        document.blocks.sorted { $0.order < $1.order }
    }

    /// 포커스된 블록 (없으면 마지막 블록)
    var anchorBlock: NoteBlock? {
        if let fid = focusedId, let b = document.blocks.first(where: { $0.id == fid }) { return b }
        return sortedBlocks.last
    }

    var body: some View {
        VStack(spacing: 0) {
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
                                let nb = insertBlock(after: block, type: "text", inheritIndent: true)
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
                            let nb = insertBlock(after: sortedBlocks.last, type: "text", inheritIndent: false)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedId = nb.id }
                        }
                }
            }

            // iOS 하단 삽입 툴바
            #if os(iOS)
            Divider()
            HStack(spacing: 20) {
                Button { insertTextBox() } label: {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                Button { showImageImporter = true } label: {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                Button { insertMindMap() } label: {
                    Image(systemName: "circle.hexagongrid")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                Button { insertPostit() } label: {
                    Image(systemName: "note.text")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                Button { showPDFImporter = true } label: {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let fid = focusedId,
                   let block = document.blocks.first(where: { $0.id == fid }),
                   block.blockType == "text" {
                    Button { dedentBlock(block) } label: {
                        Image(systemName: "decrease.indent")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    Button { indentBlock(block) } label: {
                        Image(systemName: "increase.indent")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            #endif
        }
        .navigationTitle("")
        #if os(macOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 들여쓰기
                if let fid = focusedId,
                   let block = document.blocks.first(where: { $0.id == fid }),
                   block.blockType == "text" {
                    Button { dedentBlock(block) } label: { Image(systemName: "decrease.indent") }
                        .help("내어쓰기 (⌘[)")
                        .keyboardShortcut("[", modifiers: .command)
                    Button { indentBlock(block) } label: { Image(systemName: "increase.indent") }
                        .help("들여쓰기 (⌘])")
                        .keyboardShortcut("]", modifiers: .command)
                    Divider()
                }

                Button { insertTextBox() } label: { Label("텍스트박스", systemImage: "text.viewfinder") }
                    .help("텍스트박스 삽입")

                Button { showImageImporter = true } label: { Label("이미지", systemImage: "photo.badge.plus") }
                    .help("이미지 삽입")

                Button { insertMindMap() } label: { Label("마인드맵", systemImage: "circle.hexagongrid") }
                    .help("마인드맵 삽입")

                Button { insertPostit() } label: { Label("포스트잇", systemImage: "note.text") }
                    .help("포스트잇 삽입")

                Button { showPDFImporter = true } label: { Label("PDF", systemImage: "doc.richtext") }
                    .help("PDF 삽입 (페이지별 이미지)")
            }
        }
        #endif
        .fileImporter(isPresented: $showImageImporter, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result,
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    insertImage(data: data)
                }
            }
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result,
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                insertPDFPages(from: url)
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

    // MARK: - Block Insert (포커스된 블록 다음에 삽입)

    @discardableResult
    func insertBlock(after prev: NoteBlock?, type: String, inheritIndent: Bool) -> NoteBlock {
        let blocks = sortedBlocks
        let indent = (inheritIndent && type == "text") ? (prev?.indentLevel ?? 0) : 0
        let newOrder: Int

        if let prev, let idx = blocks.firstIndex(where: { $0.id == prev.id }) {
            newOrder = prev.order + 1
            for i in (idx + 1)..<blocks.count { blocks[i].order += 1 }
        } else {
            newOrder = (blocks.map(\.order).max() ?? -1) + 1
        }

        let b = NoteBlock(order: newOrder, blockType: type, content: "", indentLevel: indent)
        b.document = document
        document.blocks.append(b)
        modelContext.insert(b)
        document.updatedAt = Date()
        try? modelContext.save()
        return b
    }

    func insertImage(data: Data) {
        let b = insertBlock(after: anchorBlock, type: "image", inheritIndent: false)
        b.imageData = data
        try? modelContext.save()
    }

    func insertTextBox() {
        let b = insertBlock(after: anchorBlock, type: "textbox", inheritIndent: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedId = b.id }
    }

    func insertMindMap() {
        let b = insertBlock(after: anchorBlock, type: "mindmap", inheritIndent: false)
        let root = MindMapNode(text: "주제", x: 200, y: 120)
        root.noteBlock = b
        b.mindMapNodes.append(root)
        modelContext.insert(root)
        try? modelContext.save()
    }

    func insertPostit() {
        let b = insertBlock(after: anchorBlock, type: "postit", inheritIndent: false)
        b.content = "메모"
        try? modelContext.save()
    }

    func insertPDFPages(from url: URL) {
        guard let pdfDoc = PDFDocument(url: url) else { return }
        let pageCount = pdfDoc.pageCount
        var lastBlock = anchorBlock

        for i in 0..<pageCount {
            guard let page = pdfDoc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // 레티나 품질
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            #if os(macOS)
            let image = NSImage(size: size)
            image.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx)
            }
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
            else { continue }
            #else
            let renderer = UIGraphicsImageRenderer(size: size)
            let uiImage = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            guard let data = uiImage.jpegData(compressionQuality: 0.85) else { continue }
            #endif

            let b = insertBlock(after: lastBlock, type: "image", inheritIndent: false)
            b.imageData = data
            lastBlock = b
        }
        try? modelContext.save()
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
        case "image":   ResizableImageBlock(block: block, onDelete: onDeleteEmpty)
        case "textbox": DraggableBlockWrapper(block: block) { textBoxContent }
        case "mindmap": DraggableBlockWrapper(block: block) { InlineMindMapBlock(block: block) }
        case "postit":  PostitBlock(block: block, onDelete: onDeleteEmpty)
        default:        DraggableBlockWrapper(block: block, resizable: false) { textView }
        }
    }

    // MARK: 텍스트 블록 (개요 번호 + 색상/하이라이트)
    private var textColor: Color {
        if !block.textColorHex.isEmpty, let c = Color(hex: block.textColorHex) { return c }
        return .primary
    }
    private var highlightColor: Color? {
        if !block.highlightHex.isEmpty, let c = Color(hex: block.highlightHex) { return c }
        return nil
    }

    var textView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Spacer().frame(width: CGFloat(block.indentLevel) * 22)
            Text(outlinePrefix())
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
                .padding(.trailing, 5)
            TextField("", text: Binding(
                get: { block.content },
                set: { block.content = $0; try? modelContext.save() }
            ))
            .font(.system(size: 14))
            .foregroundStyle(textColor)
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
        .background(highlightColor?.opacity(0.5))
        .contextMenu {
            Menu {
                ForEach(textColorPalette, id: \.hex) { c in
                    Button(c.name) {
                        block.textColorHex = c.hex
                        try? modelContext.save()
                    }
                }
            } label: {
                Label("텍스트 색상", systemImage: "textformat")
            }
            Menu {
                ForEach(highlightPalette, id: \.hex) { c in
                    Button(c.name) {
                        block.highlightHex = c.hex
                        try? modelContext.save()
                    }
                }
            } label: {
                Label("하이라이트", systemImage: "highlighter")
            }
        }
    }

    // MARK: 텍스트박스 (래퍼 안에서 사용)
    var textBoxContent: some View {
        TextEditor(text: Binding(
            get: { block.content },
            set: { block.content = $0; try? modelContext.save() }
        ))
        .font(.system(size: 14))
        .scrollDisabled(true)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    // MARK: 개요 번호
    func outlinePrefix() -> String {
        guard let idx = allBlocks.firstIndex(where: { $0.id == block.id }) else { return "" }
        let level = block.indentLevel
        var count = 1
        for j in stride(from: idx - 1, through: 0, by: -1) {
            let prev = allBlocks[j]
            if prev.blockType != "text" { continue }
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

// MARK: - Draggable Block Wrapper (자유 이동 + 리사이즈 공통 래퍼)

struct DraggableBlockWrapper<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: NoteBlock
    var resizable: Bool = true
    @ViewBuilder var content: Content

    @State private var dragOffset: CGSize = .zero
    @State private var isMoving = false

    // 리사이즈
    @State private var resizeDelta: CGSize = .zero
    @State private var isResizing = false

    private let minW: CGFloat = 100
    private let minH: CGFloat = 40

    var body: some View {
        let savedX = CGFloat(block.imageOffsetX)
        let savedY = CGFloat(block.imageOffsetY)
        let totalX = savedX + (isMoving ? dragOffset.width : 0)
        let totalY = savedY + (isMoving ? dragOffset.height : 0)

        GeometryReader { geo in
            let containerW = geo.size.width - 80
            let baseW: CGFloat = block.imageWidth > 0 ? CGFloat(block.imageWidth) : containerW
            let baseH: CGFloat = block.blockHeight > 0 ? CGFloat(block.blockHeight) : defaultHeight
            let curW = isResizing ? max(baseW + resizeDelta.width, minW) : baseW
            let curH = isResizing ? max(baseH + resizeDelta.height, minH) : baseH

            ZStack(alignment: .bottomTrailing) {
                content
                    .frame(width: min(curW, containerW))
                    .frame(height: curH)
                    .clipped()

                if resizable {
                    // 리사이즈 핸들
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.blue.opacity(0.7)))
                        .offset(x: -4, y: -4)
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { val in
                                    isResizing = true
                                    resizeDelta = val.translation
                                }
                                .onEnded { val in
                                    let newW = max(baseW + val.translation.width, minW)
                                    let newH = max(baseH + val.translation.height, minH)
                                    block.imageWidth = Double(min(newW, containerW))
                                    block.blockHeight = Double(newH)
                                    resizeDelta = .zero
                                    isResizing = false
                                    try? modelContext.save()
                                }
                        )
                }
            }
            .offset(x: totalX, y: totalY)
            .frame(width: geo.size.width, alignment: .leading)
            .padding(.leading, 40)
        }
        .frame(height: displayHeight + 12)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { val in
                    isMoving = true
                    dragOffset = val.translation
                }
                .onEnded { val in
                    block.imageOffsetX = Double(savedX + val.translation.width)
                    block.imageOffsetY = Double(savedY + val.translation.height)
                    dragOffset = .zero
                    isMoving = false
                    try? modelContext.save()
                }
        )
        .contextMenu {
            if block.imageWidth > 0 || block.blockHeight > 0 {
                Button {
                    block.imageWidth = 0; block.blockHeight = 0
                    try? modelContext.save()
                } label: {
                    Label("원래 크기로", systemImage: "arrow.uturn.backward")
                }
            }
            if block.imageOffsetX != 0 || block.imageOffsetY != 0 {
                Button {
                    block.imageOffsetX = 0; block.imageOffsetY = 0
                    try? modelContext.save()
                } label: {
                    Label("원래 위치로", systemImage: "arrow.uturn.backward.circle")
                }
            }
        }
    }

    private var defaultHeight: CGFloat {
        switch block.blockType {
        case "mindmap": return 260
        case "textbox": return 80
        default: return 30
        }
    }

    private var displayHeight: CGFloat {
        let base = block.blockHeight > 0 ? CGFloat(block.blockHeight) : defaultHeight
        return isResizing ? max(base + resizeDelta.height, minH) : base
    }
}

// MARK: - Postit Block (포스트잇 - 자유 이동 가능)

struct PostitBlock: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: NoteBlock
    var onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isMoving = false
    @State private var isEditing = false
    @State private var editText = ""

    private var bgColor: Color {
        Color(hex: block.postitColor) ?? Color.yellow.opacity(0.3)
    }

    var body: some View {
        let savedX = CGFloat(block.imageOffsetX)
        let savedY = CGFloat(block.imageOffsetY)
        let totalX = savedX + (isMoving ? dragOffset.width : 0)
        let totalY = savedY + (isMoving ? dragOffset.height : 0)

        VStack(alignment: .leading, spacing: 6) {
            Text(block.content.isEmpty ? "메모" : block.content)
                .font(.system(size: 13))
                .foregroundStyle(block.content.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .frame(minWidth: 100, maxWidth: 180, minHeight: 40, alignment: .topLeading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(bgColor)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 1, y: 3)
        )
        .overlay(alignment: .topTrailing) {
            // 접힌 모서리 효과
            Triangle()
                .fill(Color.black.opacity(0.06))
                .frame(width: 14, height: 14)
        }
        .offset(x: totalX, y: totalY)
        .padding(.horizontal, 40)
        .padding(.vertical, 6)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { val in
                    isMoving = true
                    dragOffset = val.translation
                }
                .onEnded { val in
                    block.imageOffsetX = Double(savedX + val.translation.width)
                    block.imageOffsetY = Double(savedY + val.translation.height)
                    dragOffset = .zero
                    isMoving = false
                    try? modelContext.save()
                }
        )
        .onTapGesture(count: 2) {
            editText = block.content
            isEditing = true
        }
        .contextMenu {
            // 색상 변경
            Menu {
                ForEach(postitColorPalette, id: \.hex) { c in
                    Button(c.name) {
                        block.postitColor = c.hex
                        try? modelContext.save()
                    }
                }
            } label: {
                Label("색상 변경", systemImage: "paintpalette")
            }
            Button {
                editText = block.content
                isEditing = true
            } label: {
                Label("편집", systemImage: "pencil")
            }
            Button {
                block.imageOffsetX = 0; block.imageOffsetY = 0
                try? modelContext.save()
            } label: {
                Label("원래 위치로", systemImage: "arrow.uturn.backward.circle")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                Form {
                    TextField("메모 내용", text: $editText, axis: .vertical)
                        .lineLimit(5...10)
                }
                .navigationTitle("포스트잇 편집")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { isEditing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
                            block.content = editText
                            isEditing = false
                            try? modelContext.save()
                        }
                    }
                }
            }
            .presentationDetents([.height(240)])
        }
    }
}

// 포스트잇 접힌 모서리 삼각형
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Resizable Image Block (사이즈 조정 + 자유 이동)

struct ResizableImageBlock: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: NoteBlock
    var onDelete: () -> Void

    // 리사이즈
    @State private var currentWidth: CGFloat = 0
    @State private var isResizing = false

    // 이동
    @State private var dragOffset: CGSize = .zero
    @State private var isMoving = false

    private let minWidth: CGFloat = 80
    private let maxWidth: CGFloat = 600

    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width - 80
            let displayWidth = block.imageWidth > 0
                ? min(CGFloat(block.imageWidth), containerWidth)
                : min(containerWidth, 400)
            let savedOffsetX = CGFloat(block.imageOffsetX)
            let savedOffsetY = CGFloat(block.imageOffsetY)
            let totalOffsetX = savedOffsetX + (isMoving ? dragOffset.width : 0)
            let totalOffsetY = savedOffsetY + (isMoving ? dragOffset.height : 0)

            ZStack(alignment: .bottomTrailing) {
                imageContent(width: isResizing ? currentWidth : displayWidth)

                // 우하단: 리사이즈 핸들
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.blue.opacity(0.8)))
                    .offset(x: -6, y: -6)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { val in
                                if !isResizing {
                                    isResizing = true
                                    currentWidth = displayWidth
                                }
                                let newW = currentWidth + val.translation.width
                                currentWidth = min(max(newW, minWidth), min(maxWidth, containerWidth))
                            }
                            .onEnded { _ in
                                block.imageWidth = Double(currentWidth)
                                isResizing = false
                                try? modelContext.save()
                            }
                    )
            }
            .offset(x: totalOffsetX, y: totalOffsetY)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { val in
                        isMoving = true
                        dragOffset = val.translation
                    }
                    .onEnded { val in
                        block.imageOffsetX = Double(savedOffsetX + val.translation.width)
                        block.imageOffsetY = Double(savedOffsetY + val.translation.height)
                        dragOffset = .zero
                        isMoving = false
                        try? modelContext.save()
                    }
            )
            .frame(width: geo.size.width, height: calculatedHeight, alignment: .center)
        }
        .frame(height: calculatedHeight + abs(CGFloat(block.imageOffsetY)) + 10)
        .padding(.vertical, 6)
        .contextMenu {
            Button { block.imageWidth = 0; try? modelContext.save() } label: {
                Label("원래 크기로", systemImage: "arrow.uturn.backward")
            }
            Button {
                block.imageOffsetX = 0; block.imageOffsetY = 0
                try? modelContext.save()
            } label: {
                Label("원래 위치로", systemImage: "arrow.uturn.backward.circle")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("이미지 삭제", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    func imageContent(width: CGFloat) -> some View {
        #if os(macOS)
        if let data = block.imageData, let nsImg = NSImage(data: data) {
            Image(nsImage: nsImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        #else
        if let data = block.imageData, let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        #endif
    }

    var calculatedHeight: CGFloat {
        let baseWidth: CGFloat = block.imageWidth > 0 ? CGFloat(block.imageWidth) : 400
        #if os(macOS)
        if let data = block.imageData, let nsImg = NSImage(data: data) {
            let aspect = nsImg.size.height / max(nsImg.size.width, 1)
            return (isResizing ? currentWidth : baseWidth) * aspect
        }
        #else
        if let data = block.imageData, let uiImg = UIImage(data: data) {
            let aspect = uiImg.size.height / max(uiImg.size.width, 1)
            return (isResizing ? currentWidth : baseWidth) * aspect
        }
        #endif
        return 200
    }
}

// MARK: - Inline Mind Map Block

struct InlineMindMapBlock: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: NoteBlock

    @State private var positions: [UUID: CGPoint] = [:]
    @State private var selectedId: UUID? = nil
    @State private var editingId: UUID? = nil
    @State private var editText = ""

    var nodes: [MindMapNode] { block.mindMapNodes }

    var body: some View {
        VStack(spacing: 0) {
            // 마인드맵 캔버스
            ZStack {
                Color(NoteEditorColors.background)
                    .onTapGesture { selectedId = nil }

                // 연결선
                Canvas { ctx, _ in
                    for node in nodes {
                        guard let pid = node.parentNodeId,
                              let pPos = positions[pid],
                              let nPos = positions[node.id] else { continue }
                        var path = Path()
                        path.move(to: pPos)
                        let midX = (pPos.x + nPos.x) / 2
                        path.addCurve(to: nPos,
                                       control1: CGPoint(x: midX, y: pPos.y),
                                       control2: CGPoint(x: midX, y: nPos.y))
                        ctx.stroke(path, with: .color(.blue.opacity(0.4)),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                .allowsHitTesting(false)

                // 노드들
                ForEach(nodes) { node in
                    InlineMindMapNodeView(
                        node: node,
                        position: Binding(
                            get: { positions[node.id] ?? CGPoint(x: node.x, y: node.y) },
                            set: { p in
                                positions[node.id] = p
                                node.x = p.x; node.y = p.y
                            }
                        ),
                        isRoot: node.parentNodeId == nil,
                        isSelected: selectedId == node.id,
                        onTap: { selectedId = node.id },
                        onDoubleTap: {
                            selectedId = node.id
                            editText = node.text
                            editingId = node.id
                        }
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 하단 툴바
            HStack(spacing: 12) {
                if let selId = selectedId {
                    Button { addChild(parentId: selId) } label: {
                        Label("자식 추가", systemImage: "plus.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    Button {
                        editText = nodes.first(where: { $0.id == selId })?.text ?? ""
                        editingId = selId
                    } label: {
                        Label("편집", systemImage: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    Menu {
                        ForEach(nodeColorPalette, id: \.hex) { c in
                            Button(c.name) {
                                if let node = nodes.first(where: { $0.id == selId }) {
                                    node.colorHex = c.hex
                                    try? modelContext.save()
                                }
                            }
                        }
                    } label: {
                        Label("색상", systemImage: "paintpalette")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    Button { deleteNode(id: selId) } label: {
                        Label("삭제", systemImage: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { addRoot() } label: {
                        Label("노드 추가", systemImage: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.06))
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        .onAppear {
            for node in nodes {
                positions[node.id] = CGPoint(x: node.x, y: node.y)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingId != nil },
            set: { if !$0 { editingId = nil } }
        )) {
            NavigationStack {
                Form { TextField("노드 텍스트", text: $editText) }
                    .navigationTitle("노드 편집")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("취소") { editingId = nil } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("완료") {
                                if let id = editingId, let node = nodes.first(where: { $0.id == id }) {
                                    node.text = editText
                                }
                                editingId = nil
                                try? modelContext.save()
                            }
                        }
                    }
            }
            .presentationDetents([.height(180)])
        }
    }

    func addRoot() {
        let node = MindMapNode(text: "새 노드", x: 200, y: 130)
        node.noteBlock = block
        block.mindMapNodes.append(node)
        modelContext.insert(node)
        positions[node.id] = CGPoint(x: node.x, y: node.y)
        selectedId = node.id
        editText = node.text
        editingId = node.id
        try? modelContext.save()
    }

    func addChild(parentId: UUID) {
        guard let parent = nodes.first(where: { $0.id == parentId }) else { return }
        let sib = nodes.filter { $0.parentNodeId == parentId }.count
        let x = parent.x + 180
        let y = parent.y + Double(sib) * 60 - Double(sib) * 30
        let node = MindMapNode(text: "새 노드", x: x, y: y, parentNodeId: parentId)
        node.noteBlock = block
        block.mindMapNodes.append(node)
        modelContext.insert(node)
        positions[node.id] = CGPoint(x: x, y: y)
        selectedId = node.id
        editText = node.text
        editingId = node.id
        try? modelContext.save()
    }

    func deleteNode(id: UUID) {
        var toDelete: [UUID] = []
        func collect(_ nid: UUID) {
            toDelete.append(nid)
            nodes.filter { $0.parentNodeId == nid }.forEach { collect($0.id) }
        }
        collect(id)
        for nid in toDelete {
            if let node = nodes.first(where: { $0.id == nid }) {
                modelContext.delete(node)
                positions.removeValue(forKey: nid)
            }
        }
        block.mindMapNodes.removeAll { toDelete.contains($0.id) }
        selectedId = nil
        try? modelContext.save()
    }
}

// MARK: - Inline Mind Map Node

struct InlineMindMapNodeView: View {
    let node: MindMapNode
    @Binding var position: CGPoint
    let isRoot: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    @GestureState private var dragDelta: CGSize = .zero

    private var nodeFill: Color {
        if !node.colorHex.isEmpty, let c = Color(hex: node.colorHex) { return c }
        return isRoot ? Color.blue : Color(NoteEditorColors.background)
    }

    private var textStyle: Color {
        if !node.colorHex.isEmpty { return .primary }
        return isRoot ? .white : .primary
    }

    var body: some View {
        Text(node.text)
            .font(.system(size: isRoot ? 14 : 12, weight: isRoot ? .bold : .medium))
            .foregroundStyle(textStyle)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(nodeFill)
                    .shadow(color: isSelected ? .blue.opacity(0.4) : .black.opacity(0.1),
                            radius: isSelected ? 6 : 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .position(
                x: position.x + dragDelta.width,
                y: position.y + dragDelta.height
            )
            .gesture(
                DragGesture(minimumDistance: 3)
                    .updating($dragDelta) { val, state, _ in state = val.translation }
                    .onEnded { val in
                        position = CGPoint(x: position.x + val.translation.width,
                                           y: position.y + val.translation.height)
                    }
            )
            .onTapGesture(count: 2) { onDoubleTap() }
            .onTapGesture(count: 1) { onTap() }
    }
}
