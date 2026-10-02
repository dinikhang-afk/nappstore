import SwiftUI

public struct AppIAPDetailView: View {
    public let appName: String
    public let bundleId: String
    public let appIconSystem: String
    public let initialItems: [IAPItem]

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreKitService.shared
    @State private var filter = DetailFilter.all
    @State private var query = ""
    @State private var expandedID: String?
    @State private var selectedItemForPurchase: IAPItem?
    @State private var selectedItemForSpec: IAPItem?
    @State private var showingLogs = false
    @State private var showingFilter = false

    public init(appName: String, bundleId: String, appIconSystem: String, initialItems: [IAPItem]) {
        self.appName = appName
        self.bundleId = bundleId
        self.appIconSystem = appIconSystem
        self.initialItems = initialItems
    }

    private var appItems: [IAPItem] {
        // The detail screen must follow a fresh bridge scan. `initialItems`
        // only keeps the sheet useful while the first scan is still pending.
        let liveItems = store.items.filter { $0.appBundleId == bundleId }
        let source = liveItems.isEmpty ? initialItems : liveItems
        return source.filter { item in
            let filterMatches: Bool
            switch filter {
            case .all: filterMatches = true
            case .trial: filterMatches = item.isTrial
            case .discount: filterMatches = item.trialBadge != nil && !item.isTrial
            case .hidden: filterMatches = item.isHidden
            }
            guard filterMatches else { return false }
            guard !query.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(query) || item.id.localizedCaseInsensitiveContains(query) || item.formattedPrice.localizedCaseInsensitiveContains(query)
        }
    }

    private var sourceItems: [IAPItem] {
        let liveItems = store.items.filter { $0.appBundleId == bundleId }
        return liveItems.isEmpty ? initialItems : liveItems
    }

    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    topBar
                    appHeader
                    filterPills
                    SearchField("Tìm gói in-app purchase…", text: $query)

                    if appItems.isEmpty {
                        emptyProducts
                    } else {
                        Text("\(appName.uppercased()) PRO  •  \(appItems.count) GÓI")
                            .sectionLabelStyle()
                            .padding(.top, 4)
                        ForEach(appItems) { item in
                            DetailProductRow(
                                item: item,
                                isExpanded: expandedID == item.id,
                                onTap: { withAnimation(.easeInOut(duration: 0.2)) { expandedID = expandedID == item.id ? nil : item.id } },
                                onBuy: { selectedItemForPurchase = item },
                                onSpec: { selectedItemForSpec = item },
                                onStar: { store.toggleFavorite(item) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Color.iappayBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedItemForPurchase) { item in
                PurchaseConfirmSheet(item: item, isPresented: Binding(get: { selectedItemForPurchase != nil }, set: { if !$0 { selectedItemForPurchase = nil } }))
            }
            .sheet(item: $selectedItemForSpec) { item in
                IAPSpecSheet(item: item, isPresented: Binding(get: { selectedItemForSpec != nil }, set: { if !$0 { selectedItemForSpec = nil } }), onBuyTapped: { selectedItemForPurchase = item })
            }
            .sheet(isPresented: $showingLogs) { LogsView() }
            .confirmationDialog("Bộ lọc & Sắp xếp", isPresented: $showingFilter, titleVisibility: .visible) {
                ForEach(DetailFilter.allCases) { option in
                    Button(option.title) { filter = option }
                }
                Button("Hủy", role: .cancel) {}
            }
            .onAppear { store.loadRealData() }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.iappayTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.iappayCardRaised.opacity(0.9)))
                    .overlay(Circle().stroke(Color.iappayBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Text(appName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.iappayTextPrimary)
                .lineLimit(1)
            Spacer()
            Button { showingFilter = true } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.iappayTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.iappayCardRaised.opacity(0.9)))
                    .overlay(Circle().stroke(Color.iappayBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button("Logs") { showingLogs = true }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.iappayTextPrimary)
                .padding(.horizontal, 15)
                .frame(height: 44)
                .background(Capsule().fill(Color.iappayCardRaised.opacity(0.9)))
                .overlay(Capsule().stroke(Color.iappayBorder, lineWidth: 1))
        }
    }

    private var appHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                AppIconView(systemName: appIconSystem, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.iappayTextPrimary)
                        .lineLimit(1)
                    Text(publisher)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.iappayTextSecondary)
                    Text(bundleId)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.iappayTextMuted)
                }
                Spacer()
                Button {
                    InstalledAppsScanner.shared.launchApp(bundleId: bundleId)
                } label: {
                    Label("Mở", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.iappayPurple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.iappayPurple.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                DetailMetric(value: "\(sourceItems.count)", title: "GÓI IAP", color: .iappayTextPrimary)
                DetailMetric(value: "\(sourceItems.filter(\.isTrial).count)", title: "DÙNG THỬ", color: .iappayGreen)
                DetailMetric(value: "\(sourceItems.filter { $0.trialBadge != nil && !$0.isTrial }.count)", title: "GIẢM GIÁ", color: .iappayYellow)
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 17).fill(Color.iappayCardRaised.opacity(0.82)))
        }
        .padding(15)
        .referenceCard(cornerRadius: 24)
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "Tất cả (\(sourceItems.count))", isSelected: filter == .all) { filter = .all }
                FilterPill(title: "Dùng thử (\(sourceItems.filter(\.isTrial).count))", isSelected: filter == .trial) { filter = .trial }
                FilterPill(title: "Giảm giá (\(sourceItems.filter { $0.trialBadge != nil && !$0.isTrial }.count))", isSelected: filter == .discount) { filter = .discount }
                FilterPill(title: "Ẩn (\(sourceItems.filter(\.isHidden).count))", isSelected: filter == .hidden) { filter = .hidden }
            }
        }
    }

    private var emptyProducts: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 38))
                .foregroundColor(.iappayPurple)
            Text("Chưa có snapshot IAP")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.iappayTextPrimary)
            Text("Mở app đích để companion bridge ghi danh mục StoreKit, sau đó quay lại và nhấn đồng bộ.")
                .font(.system(size: 13))
                .foregroundColor(.iappayTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var publisher: String {
        let lower = bundleId.lowercased()
        if lower.contains("lemon") { return "Bytedance Pte. Ltd" }
        if lower.contains("openai") { return "OpenAI" }
        if lower.contains("duolingo") { return "Duolingo" }
        return "App Store developer"
    }
}

private enum DetailFilter: String, CaseIterable, Identifiable {
    case all, trial, discount, hidden
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Tất cả"
        case .trial: return "Dùng thử"
        case .discount: return "Giảm giá kỳ đầu"
        case .hidden: return "Hiển thị gói ẩn"
        }
    }
}

private struct DetailMetric: View {
    let value: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(color)
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.iappayTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DetailProductRow: View {
    let item: IAPItem
    let isExpanded: Bool
    let onTap: () -> Void
    let onBuy: () -> Void
    let onSpec: () -> Void
    let onStar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button(action: onTap) { AppIconView(systemName: item.appIconSystem, url: item.appIconURL, size: 46) }
                    .buttonStyle(.plain)
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.system(size: 16, weight: .bold)).foregroundColor(.iappayTextPrimary).lineLimit(1)
                        HStack(spacing: 6) {
                            if let badge = item.trialBadge { BadgeTag(badge, bg: .iappayYellow, fg: .black) }
                            if item.isHidden { BadgeTag("ẨN", bg: .iappayBadgeHidden) }
                        }
                        Text(item.subtitle).font(.system(size: 12)).foregroundColor(.iappayTextSecondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button(action: onStar) {
                    Image(systemName: item.isStarred ? "star.fill" : "star")
                        .foregroundColor(item.isStarred ? .iappayYellow : .iappayTextMuted)
                }
                .buttonStyle(.plain)
                Button(action: onBuy) {
                    Text(item.formattedPrice)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(item.isFree ? .black : .white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(item.isFree ? Color.iappayYellow : (item.isTrial ? Color.iappayGreen : Color.iappayPurple)))
                }
                .buttonStyle(.plain)
            }
            .padding(13)
            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    detailLine("Tình trạng", item.isTrial ? "Dùng thử" : (item.isHidden ? "Nguyên giá" : "Đang bán"))
                    detailLine("Kind", item.isTrial ? "Free trial" : "Regular")
                    detailLine("Type", item.family)
                    detailLine("Price", item.formattedPrice)
                    detailLine("Trial", item.isTrial ? "Có" : "Không")
                    detailLine("Offer", item.offerId ?? "—")
                    detailLine("Product", item.productNumber ?? item.id)
                    detailLine("Store", item.storeCountry)
                    Button(action: onSpec) {
                        Label("Xem đầy đủ & sao chép ID", systemImage: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.iappayPurple)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 5)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
                .transition(.opacity)
            }
        }
        .referenceCard(cornerRadius: 20)
    }

    private func detailLine(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key).frame(width: 78, alignment: .leading).foregroundColor(.iappayTextSecondary)
            Text(value).foregroundColor(.iappayTextPrimary).lineLimit(2)
            Spacer()
        }
        .font(.system(size: 12, weight: .medium))
    }
}
