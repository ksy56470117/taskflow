import SwiftUI
import SwiftData

// MARK: - Main Wishlist View
struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishItem.createdAt, order: .reverse) private var items: [WishItem]

    @State private var showAdd = false
    @State private var selectedCategory: String? = nil
    @State private var showPurchased = false

    var filteredItems: [WishItem] {
        items.filter { item in
            let catMatch = selectedCategory == nil || item.category == selectedCategory
            let purchasedMatch = showPurchased ? item.isPurchased : !item.isPurchased
            return catMatch && purchasedMatch
        }
    }

    var groupedItems: [(String, [WishItem])] {
        let cats = WishItem.categories
        let grouped = Dictionary(grouping: filteredItems) { $0.category }
        return cats.compactMap { cat in
            guard let list = grouped[cat], !list.isEmpty else { return nil }
            return (cat, list)
        }
    }

    var totalPrice: Int {
        filteredItems.filter { !$0.isPurchased }.reduce(0) { $0 + $1.price }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 상단 요약 카드
                SummaryBanner(
                    total: items.filter { !$0.isPurchased }.count,
                    totalPrice: totalPrice,
                    purchased: items.filter { $0.isPurchased }.count
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // 카테고리 필터
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "전체", icon: "list.bullet", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(WishItem.categories, id: \.self) { cat in
                            FilterChip(
                                label: cat,
                                icon: WishItem.categoryIcon[cat] ?? "tag",
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // 구매완료 토글
                HStack {
                    Toggle(isOn: $showPurchased) {
                        Text("구매 완료 보기")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.switch)
                    .tint(.green)
                }
                .padding(.horizontal, 16)

                // 아이템 목록
                if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text(showPurchased ? "구매 완료 항목이 없어요" : "위시리스트가 비어있어요")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 16) {
                        ForEach(groupedItems, id: \.0) { category, catItems in
                            CategorySection(
                                category: category,
                                items: catItems,
                                onDelete: deleteItem
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 100)
            }
        }
        .background(Color.secondary.opacity(0.08))
        .navigationTitle("위시리스트")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        #endif
        .sheet(isPresented: $showAdd) {
            AddWishItemSheet(defaultCategory: selectedCategory ?? "기타")
                .presentationDetents([.height(540)])
        }
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button { showAdd = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                        Text("항목 추가").font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
        #endif
    }

    func deleteItem(_ item: WishItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - 상단 요약 배너
struct SummaryBanner: View {
    var total: Int
    var totalPrice: Int
    var purchased: Int

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("찜한 항목")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("\(total)개")
                    .font(.system(size: 22, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("예상 금액")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(totalPrice == 0 ? "-" : formatPrice(totalPrice))
                    .font(.system(size: 22, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("구매 완료")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("\(purchased)개")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func formatPrice(_ p: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return (f.string(from: NSNumber(value: p)) ?? "\(p)") + "원"
    }
}

// MARK: - 카테고리 필터 칩
struct FilterChip: View {
    var label: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.08))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 카테고리 섹션
struct CategorySection: View {
    var category: String
    var items: [WishItem]
    var onDelete: (WishItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 카테고리 헤더
            HStack(spacing: 6) {
                Image(systemName: WishItem.categoryIcon[category] ?? "tag")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(category)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(items.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // 아이템들
            VStack(spacing: 0) {
                ForEach(items) { item in
                    WishItemRow(item: item, onDelete: { onDelete(item) })
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 위시 아이템 행
struct WishItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: WishItem
    var onDelete: () -> Void
    @State private var showEdit = false

    var body: some View {
        HStack(spacing: 12) {
            // 구매 체크
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.isPurchased.toggle()
                    try? modelContext.save()
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(item.isPurchased ? Color.green : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if item.isPurchased {
                        Circle().fill(Color.green).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // 제품 정보
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15))
                    .foregroundStyle(item.isPurchased ? .secondary : .primary)
                    .strikethrough(item.isPurchased, color: .secondary.opacity(0.5))

                HStack(spacing: 8) {
                    if !item.store.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "storefront").font(.system(size: 10))
                            Text(item.store).font(.system(size: 12))
                        }
                        .foregroundStyle(.secondary)
                    }
                    if item.price > 0 {
                        Text(item.formattedPrice)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            // 더보기 메뉴
            Menu {
                Button { showEdit = true } label: {
                    Label("편집", systemImage: "pencil")
                }
                if !item.url.isEmpty, let url = URL(string: item.url) {
                    Link(destination: url) {
                        Label("링크 열기", systemImage: "safari")
                    }
                }
                Divider()
                Button(role: .destructive) { onDelete() } label: {
                    Label("삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sheet(isPresented: $showEdit) {
            AddWishItemSheet(editItem: item)
        }
    }
}

// MARK: - 추가/편집 시트
struct AddWishItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editItem: WishItem? = nil

    @State private var name = ""
    @State private var category = "기타"
    @State private var store = ""
    @State private var priceText = ""
    @State private var url = ""
    @State private var notes = ""

    var isEditing: Bool { editItem != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("제품 정보") {
                    TextField("제품명", text: $name)

                    Picker("카테고리", selection: $category) {
                        ForEach(WishItem.categories, id: \.self) { cat in
                            HStack {
                                Image(systemName: WishItem.categoryIcon[cat] ?? "tag")
                                Text(cat)
                            }
                            .tag(cat)
                        }
                    }
                }

                Section("구매 정보") {
                    HStack {
                        Image(systemName: "storefront").foregroundStyle(.secondary)
                        TextField("판매처 (예: 쿠팡, 무신사)", text: $store)
                    }

                    HStack {
                        Image(systemName: "wonsign").foregroundStyle(.secondary)
                        TextField("가격", text: $priceText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }

                    HStack {
                        Image(systemName: "link").foregroundStyle(.secondary)
                        TextField("링크 (선택)", text: $url)
                            #if os(iOS)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                }

                Section("메모") {
                    TextField("메모 (선택)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "편집" : "새 항목")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "저장" : "추가") { submit() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { loadEditItem() }
    }

    func loadEditItem() {
        guard let item = editItem else { return }
        name = item.name
        category = item.category
        store = item.store
        priceText = item.price > 0 ? "\(item.price)" : ""
        url = item.url
        notes = item.notes
    }

    func submit() {
        let price = Int(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
        if let item = editItem {
            item.name = name.trimmingCharacters(in: .whitespaces)
            item.category = category
            item.store = store
            item.price = price
            item.url = url
            item.notes = notes
        } else {
            let item = WishItem(
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                store: store,
                price: price,
                url: url,
                notes: notes
            )
            modelContext.insert(item)
        }
        try? modelContext.save()
        dismiss()
    }
}
