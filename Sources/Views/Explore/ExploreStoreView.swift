import SwiftUI

public struct ExploreStoreView: View {
    @ObservedObject private var store = StoreKitService.shared
    @ObservedObject private var searchService = AppStoreSearchService.shared

    @State private var query = ""
    @State private var selectedCategory = "Tất cả"
    @State private var selectedApp: SuggestedApp?
    @State private var selectedItem: IAPItem?
    @State private var copied = false

    private let categories = ["Tất cả", "AI & Trợ lý", "Video & Ảnh", "Học tập", "Mạng xã hội", "Tiện ích"]

    private var visibleSuggestions: [SuggestedApp] {
        let catalogApps = Dictionary(grouping: store.items, by: \.appBundleId).compactMap { bundleID, items -> SuggestedApp? in
            guard let first = items.first else { return nil }
            let known = SuggestedApp.all.first { $0.bundleID == bundleID }
            return SuggestedApp(
                name: known?.name ?? first.appName,
                bundleID: bundleID,
                publisher: known?.publisher ?? bundleID,
                description: "\(items.count) gói IAP đã đồng bộ",
                category: known?.category ?? "Tất cả",
                icon: first.appIconSystem,
                iconURL: first.appIconURL
            )
        }
        let dynamicIDs = Set(catalogApps.map(\.bundleID))
        let base = catalogApps + SuggestedApp.all.filter { !dynamicIDs.contains($0.bundleID) }
        guard selectedCategory != "Tất cả" else { return base }
        return base.filter { $0.category == selectedCategory }
    }

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    SearchField("Tên app, Bundle ID hoặc link App Store", text: $query) {
                        searchService.searchAppStore(query: query)
                    }
                    categoriesRow

                    if searchService.isSearching {
                        ProgressView("Đang tìm trên App Store…")
                            .frame(maxWidth: .infinity)
                            .tint(.iappayPurple)
                            .foregroundColor(.iappayTextSecondary)
                            .padding(.vertical, 24)
                    } else if !searchService.searchResults.isEmpty {
                        onlineResults
                    } else {
                        suggestions
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color.iappayBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedItem) { item in
                PurchaseConfirmSheet(item: item, isPresented: Binding(get: { selectedItem != nil }, set: { if !$0 { selectedItem = nil } }))
            }
            .sheet(item: $selectedApp) { app in
                AppIAPDetailView(
                    appName: app.name,
                    bundleId: app.bundleID,
                    appIconSystem: app.icon,
                    initialItems: store.items.filter { $0.appBundleId == app.bundleID }
                )
            }
            .onAppear {
                if store.items.isEmpty { store.loadRealData() }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Khám phá")
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(.iappayTextPrimary)
            HStack {
                Spacer()
                Button {
                    UIPasteboard.general.string = "https://apps.apple.com"
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.iappayPurple)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.iappayCardRaised.opacity(0.9)))
                        .overlay(Circle().stroke(Color.iappayBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 46)
    }

    private var categoriesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    FilterPill(title: category, isSelected: category == selectedCategory) {
                        selectedCategory = category
                        if category != "Tất cả" { searchService.searchAppStore(query: category) }
                        else { searchService.clear() }
                    }
                }
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GỢI Ý HÀNG ĐẦU (\(visibleSuggestions.count))")
                .sectionLabelStyle()
                .padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(visibleSuggestions) { app in
                    Button { selectedApp = app } label: {
                        HStack(spacing: 13) {
                            AppIconView(systemName: app.icon, url: app.iconURL, size: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.iappayTextPrimary)
                                    .lineLimit(1)
                                Text("\(app.publisher) • \(app.description)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.iappayTextSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.iappayTextSecondary)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if app.id != visibleSuggestions.last?.id {
                        Divider().overlay(Color.iappayBorder.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.iappayCard.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.iappayBorder, lineWidth: 1))
        }
    }

    private var onlineResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KẾT QUẢ APP STORE (\(searchService.searchResults.count))")
                .sectionLabelStyle()
            ForEach(searchService.searchResults) { app in
                Button {
                    selectedApp = SuggestedApp(name: app.appName, bundleID: app.bundleId, publisher: app.artistName, description: app.genres.first ?? "Ứng dụng", category: "Tất cả", icon: "app.fill", iconURL: app.iconURL)
                } label: {
                    HStack(spacing: 13) {
                        AppIconView(systemName: "app.fill", url: app.iconURL, size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.appName).font(.system(size: 16, weight: .bold)).foregroundColor(.iappayTextPrimary)
                            Text("\(app.artistName) • \(app.bundleId)").font(.system(size: 12)).foregroundColor(.iappayTextSecondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.iappayTextSecondary)
                    }
                    .padding(12)
                    .referenceCard(cornerRadius: 18)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SuggestedApp: Identifiable, Hashable {
    let name: String
    let bundleID: String
    let publisher: String
    let description: String
    let category: String
    let icon: String
    let iconURL: URL?

    var id: String { bundleID }

    init(name: String, bundleID: String, publisher: String, description: String, category: String, icon: String, iconURL: URL? = nil) {
        self.name = name
        self.bundleID = bundleID
        self.publisher = publisher
        self.description = description
        self.category = category
        self.icon = icon
        self.iconURL = iconURL
    }

    static let all: [SuggestedApp] = [
        SuggestedApp(name: "CapCut - Video Editor", bundleID: "com.lemon.lvoverseas", publisher: "Bytedance", description: "Chỉnh sửa video chuyên nghiệp", category: "Video & Ảnh", icon: "video.fill"),
        SuggestedApp(name: "ChatGPT", bundleID: "com.openai.chat", publisher: "OpenAI", description: "Trợ lý AI thông minh", category: "AI & Trợ lý", icon: "bubble.left.and.bubble.right.fill"),
        SuggestedApp(name: "Duolingo: Học Ngoại Ngữ", bundleID: "com.duolingo.DuolingoMobile", publisher: "Duolingo", description: "Giáo dục & Ngoại ngữ", category: "Học tập", icon: "bird.fill"),
        SuggestedApp(name: "Canva: Thiết kế & Video", bundleID: "com.canva.canva", publisher: "Canva Pty Ltd", description: "Thiết kế đồ họa dễ dàng", category: "Video & Ảnh", icon: "paintpalette.fill"),
        SuggestedApp(name: "Adobe Lightroom", bundleID: "com.adobe.lightroom", publisher: "Adobe Inc.", description: "Chỉnh sửa ảnh & màu sắc", category: "Video & Ảnh", icon: "photo.fill"),
        SuggestedApp(name: "Telegram Messenger", bundleID: "ph.telegra.Telegraph", publisher: "FZ-LLC", description: "Nhắn tin bảo mật", category: "Mạng xã hội", icon: "paperplane.fill"),
        SuggestedApp(name: "Picsart AI Photo Editor", bundleID: "com.picsart.studio", publisher: "PicsArt, Inc.", description: "Chỉnh sửa ảnh & AI", category: "Video & Ảnh", icon: "wand.and.stars"),
        SuggestedApp(name: "Remini - AI Photo Enhancer", bundleID: "com.bigwinepot.nwdn.international", publisher: "Bending Spoons", description: "Làm nét ảnh bằng AI", category: "AI & Trợ lý", icon: "sparkles"),
    ]
}
