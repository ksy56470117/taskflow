import SwiftUI
import SwiftData

// MARK: - Notes Landing

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteDocument.updatedAt, order: .reverse) private var documents: [NoteDocument]
    @State private var showingAdd = false
    @State private var newTitle = ""
    @State private var openNote: NoteDocument? = nil

    var body: some View {
        List {
            ForEach(documents) { doc in
                Button { openNote = doc } label: {
                    HStack(spacing: 12) {
                        Image(systemName: noteIcon(doc))
                            .font(.title3)
                            .foregroundStyle(noteColor(doc))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(noteSubtitle(doc))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .onDelete { idxs in idxs.forEach { modelContext.delete(documents[$0]) } }

            if documents.isEmpty {
                ContentUnavailableView(
                    "노트 없음",
                    systemImage: "note.text",
                    description: Text("+ 버튼으로 노트를 추가하세요")
                )
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("노트")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddNoteSheet(title: $newTitle) {
                let doc = NoteDocument(title: newTitle, type: "note")
                modelContext.insert(doc)
                try? modelContext.save()
                showingAdd = false
                newTitle = ""
                openNote = doc
            } onCancel: { showingAdd = false; newTitle = "" }
        }
        .sheet(item: $openNote) { note in
            NavigationStack {
                noteEditorView(for: note)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") { openNote = nil }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    func noteEditorView(for doc: NoteDocument) -> some View {
        switch doc.type {
        case "spreadsheet": SpreadsheetEditorView(document: doc)
        case "mindmap":     MindMapEditorView(document: doc)
        default:            NoteEditorView(document: doc)
        }
    }

    func noteIcon(_ doc: NoteDocument) -> String {
        switch doc.type {
        case "spreadsheet": return "tablecells"
        case "mindmap":     return "circle.hexagongrid"
        default:            return "doc.text"
        }
    }
    func noteColor(_ doc: NoteDocument) -> Color {
        switch doc.type {
        case "spreadsheet": return .green
        case "mindmap":     return .purple
        default:            return .blue
        }
    }
    func noteSubtitle(_ doc: NoteDocument) -> String {
        switch doc.type {
        case "spreadsheet": return "스프레드시트"
        case "mindmap":     return "마인드맵"
        default:
            let count = doc.blocks.count
            return count > 0 ? "노트 \(count)개 항목" : "빈 노트"
        }
    }
}

// MARK: - Spreadsheet Editor

struct SpreadsheetEditorView: View {
    @Bindable var document: NoteDocument
    @Environment(\.modelContext) private var modelContext

    private let totalCols = 10
    private let totalRows = 100
    private let cellW: CGFloat = 130
    private let cellH: CGFloat = 38
    private let rowHeaderW: CGFloat = 44

    @State private var grid: [[String]] = []

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Column headers (A, B, C...)
                HStack(spacing: 0) {
                    cornerCell
                    ForEach(0..<totalCols, id: \.self) { col in
                        headerCell(colLabel(col))
                    }
                }
                // Data rows
                ForEach(0..<totalRows, id: \.self) { row in
                    HStack(spacing: 0) {
                        rowHeader(row + 1)
                        ForEach(0..<totalCols, id: \.self) { col in
                            dataCell(row: row, col: col)
                        }
                    }
                }
            }
        }
        .navigationTitle(document.title)
        #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        .onAppear { loadGrid() }
    }

    // MARK: Cell Views

    var cornerCell: some View {
        Color.gray.opacity(0.12)
            .frame(width: rowHeaderW, height: cellH)
            .border(Color.gray.opacity(0.25))
    }

    func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: cellW, height: cellH)
            .background(Color.gray.opacity(0.12))
            .border(Color.gray.opacity(0.25))
    }

    func rowHeader(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(width: rowHeaderW, height: cellH)
            .background(Color.gray.opacity(0.12))
            .border(Color.gray.opacity(0.25))
    }

    func dataCell(row: Int, col: Int) -> some View {
        TextField("", text: Binding(
            get: {
                guard row < grid.count, col < grid[row].count else { return "" }
                return grid[row][col]
            },
            set: { val in
                ensureGrid(row: row, col: col)
                grid[row][col] = val
                saveCell(row: row, col: col, content: val)
            }
        ))
        .font(.system(size: 13))
        .padding(.horizontal, 6)
        .frame(width: cellW, height: cellH, alignment: .leading)
        .background(Color(white: 1.0, opacity: 0.01))
        .border(Color.gray.opacity(0.2))
        .autocorrectionDisabled()
    }

    // MARK: Helpers

    func colLabel(_ col: Int) -> String {
        var result = ""
        var n = col
        repeat {
            result = String(UnicodeScalar(65 + (n % 26))!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    func ensureGrid(row: Int, col: Int) {
        while grid.count <= row {
            grid.append(Array(repeating: "", count: totalCols))
        }
        while grid[row].count <= col {
            grid[row].append("")
        }
    }

    func loadGrid() {
        grid = Array(repeating: Array(repeating: "", count: totalCols), count: totalRows)
        for cell in document.cells {
            guard cell.row < totalRows, cell.col < totalCols else { continue }
            ensureGrid(row: cell.row, col: cell.col)
            grid[cell.row][cell.col] = cell.content
        }
    }

    func saveCell(row: Int, col: Int, content: String) {
        document.updatedAt = Date()
        if let existing = document.cells.first(where: { $0.row == row && $0.col == col }) {
            if content.isEmpty {
                modelContext.delete(existing)
                document.cells.removeAll { $0.row == row && $0.col == col }
            } else {
                existing.content = content
            }
        } else if !content.isEmpty {
            let cell = SpreadsheetCell(row: row, col: col, content: content)
            cell.document = document
            document.cells.append(cell)
            modelContext.insert(cell)
        }
    }
}

// MARK: - Mind Map Editor

struct MindMapEditorView: View {
    @Bindable var document: NoteDocument
    @Environment(\.modelContext) private var modelContext

    @State private var positions: [UUID: CGPoint] = [:]
    @State private var selectedId: UUID? = nil
    @State private var editingId: UUID? = nil
    @State private var editText = ""

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background — tap to deselect
                Color(white: 0.97)
                    .ignoresSafeArea()
                    .onTapGesture { selectedId = nil }

                // Connection lines
                Canvas { ctx, _ in
                    for node in document.mapNodes {
                        guard let pid = node.parentNodeId,
                              let pPos = positions[pid],
                              let nPos = positions[node.id] else { continue }
                        var path = Path()
                        path.move(to: pPos)
                        let midX = (pPos.x + nPos.x) / 2
                        path.addCurve(
                            to: nPos,
                            control1: CGPoint(x: midX, y: pPos.y),
                            control2: CGPoint(x: midX, y: nPos.y)
                        )
                        ctx.stroke(path, with: .color(.blue.opacity(0.45)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                // Nodes
                ForEach(document.mapNodes) { node in
                    MindMapNodeBubble(
                        node: node,
                        position: Binding(
                            get: { positions[node.id] ?? CGPoint(x: node.x, y: node.y) },
                            set: { p in
                                positions[node.id] = p
                                node.x = p.x
                                node.y = p.y
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
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .navigationTitle(document.title)
        #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        .toolbar { toolbarContent }
        .sheet(isPresented: Binding(
            get: { editingId != nil },
            set: { if !$0 { editingId = nil } }
        )) {
            editSheet
        }
        .onAppear {
            for node in document.mapNodes {
                positions[node.id] = CGPoint(x: node.x, y: node.y)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let selId = selectedId {
                Button {
                    addChild(parentId: selId)
                } label: {
                    Label("자식 추가", systemImage: "plus.circle")
                }
                Button {
                    editText = document.mapNodes.first(where: { $0.id == selId })?.text ?? ""
                    editingId = selId
                } label: {
                    Label("편집", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteNode(id: selId)
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            } else {
                Button { addRoot() } label: {
                    Label("노드 추가", systemImage: "plus")
                }
            }
        }
    }

    // MARK: Edit Sheet

    var editSheet: some View {
        NavigationStack {
            Form {
                TextField("노드 텍스트", text: $editText)
            }
            .navigationTitle("노드 편집")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { editingId = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        if let id = editingId,
                           let node = document.mapNodes.first(where: { $0.id == id }) {
                            node.text = editText
                            document.updatedAt = Date()
                        }
                        editingId = nil
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
    }

    // MARK: Actions

    func addRoot() {
        let node = MindMapNode(text: "새 노드", x: 200, y: 200)
        node.document = document
        document.mapNodes.append(node)
        modelContext.insert(node)
        positions[node.id] = CGPoint(x: node.x, y: node.y)
        selectedId = node.id
    }

    func addChild(parentId: UUID) {
        guard let parent = document.mapNodes.first(where: { $0.id == parentId }) else { return }
        let siblingCount = document.mapNodes.filter { $0.parentNodeId == parentId }.count
        let x = parent.x + 220
        let y = parent.y + Double(siblingCount) * 90 - Double(siblingCount) * 45
        let node = MindMapNode(text: "새 노드", x: x, y: y, parentNodeId: parentId)
        node.document = document
        document.mapNodes.append(node)
        modelContext.insert(node)
        positions[node.id] = CGPoint(x: x, y: y)
        selectedId = node.id
        editText = "새 노드"
        editingId = node.id
        document.updatedAt = Date()
    }

    func deleteNode(id: UUID) {
        var toDelete: [UUID] = []
        func collect(_ nid: UUID) {
            toDelete.append(nid)
            document.mapNodes.filter { $0.parentNodeId == nid }.forEach { collect($0.id) }
        }
        collect(id)
        for nid in toDelete {
            if let node = document.mapNodes.first(where: { $0.id == nid }) {
                modelContext.delete(node)
                positions.removeValue(forKey: nid)
            }
        }
        document.mapNodes.removeAll { toDelete.contains($0.id) }
        selectedId = nil
        document.updatedAt = Date()
    }
}

// MARK: - Mind Map Node Bubble

struct MindMapNodeBubble: View {
    let node: MindMapNode
    @Binding var position: CGPoint
    let isRoot: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    @GestureState private var dragDelta: CGSize = .zero

    var body: some View {
        Text(node.text)
            .font(.system(size: isRoot ? 16 : 14, weight: isRoot ? .bold : .medium))
            .foregroundStyle(isRoot ? .white : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isRoot ? Color.blue : Color.white)
                    .shadow(
                        color: isSelected ? .blue.opacity(0.5) : .black.opacity(0.12),
                        radius: isSelected ? 10 : 4,
                        x: 0, y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
            .position(
                x: position.x + dragDelta.width,
                y: position.y + dragDelta.height
            )
            .gesture(
                DragGesture(minimumDistance: 3)
                    .updating($dragDelta) { val, state, _ in state = val.translation }
                    .onEnded { val in
                        position = CGPoint(
                            x: position.x + val.translation.width,
                            y: position.y + val.translation.height
                        )
                    }
            )
            .onTapGesture(count: 2) { onDoubleTap() }
            .onTapGesture(count: 1) { onTap() }
    }
}
