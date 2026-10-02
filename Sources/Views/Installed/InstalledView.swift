import SwiftUI

public struct InstalledView: View {
    @ObservedObject private var scanner = InstalledAppsScanner.shared
    @ObservedObject private var store = StoreKitService.shared

    @State private var query = ""
    @State private var selectedSegment = 0
    @State private var selectedApp: InstalledAppInfo?
    @State private var showingLogs = false

    private var apps: [InstalledAppInfo] {
        allApps.filter { app in
            let segmentMatches = selectedSegment == 0 ? !app.isSystemApp : app.isSystemApp
            guard segmentMatches else { return false }
            guard !query.isEmpty else { return true }
            return app.appName.localizedCaseInsensitiveContains(query) || app.bundleId.localizedCaseInsensitiveContains(query)
        }
    }

    private var allApps: [InstalledAppInfo] {
        var byBundle = Dictionary(uniqueKeysWithValues: store.catalogAppInfos.map { ($0.bundleId, $0) })
        // Prefer the live installation metadata when the system scanner can
        // provide it; catalog-only apps still remain available for inspection.
        for app in scanner.installedApps { byBundle[app.bundleId] = app }
        return byBundle.values.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    SearchField("Filter by name or bundle ID", text: $query)
                    segmentControl

                    if scanner.isScanning {
                        ProgressView("Đang quét ứng dụng…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .tint(.iappayPurple)
                    } else if apps.isEmpty {
                        emptyState
                    } else {
                        Text(selectedSegment == 0 ? "\(apps.count) User Applications" : "\(apps.count) System Applications")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.iappayTextSecondary)
                            .padding(.top, 8)
                        VStack(spacing: 12) {
                            ForEach(apps) { app in
                                Button { selectedApp = app } label: { appRow(app) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color.iappayBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedApp) { app in
                AppIAPDetailView(
                    appName: app.appName,
                    bundleId: app.bundleId,
                    appIconSystem: icon(for: app.bundleId),
                    initialItems: store.items.filter { $0.appBundleId == app.bundleId }
                )
            }
            .sheet(isPresented: $showingLogs) { LogsView() }
            .onAppear {
                if scanner.installedApps.isEmpty { scanner.scanApps(includeSystem: selectedSegment == 1) }
                if store.items.isEmpty { store.loadRealData() }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Đã cài đặt")
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(.iappayTextPrimary)
            HStack {
                Spacer()
                Button {
                    scanner.scanApps(includeSystem: selectedSegment == 1)
                    store.loadRealData()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.iappayPurple)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.iappayCardRaised.opacity(0.9)))
                        .overlay(Circle().stroke(Color.iappayBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 46)
    }

    private var segmentControl: some View {
        HStack(spacing: 0) {
            segmentButton("User (\(allApps.filter { !$0.isSystemApp }.count))", index: 0)
            segmentButton("System (\(allApps.filter(\.isSystemApp).count))", index: 1)
        }
        .padding(3)
        .background(Capsule().fill(Color.iappayCardRaised.opacity(0.92)))
        .overlay(Capsule().stroke(Color.iappayBorder, lineWidth: 1))
    }

    private func segmentButton(_ title: String, index: Int) -> some View {
        Button {
            selectedSegment = index
            if index == 1 && !scanner.installedApps.contains(where: \.isSystemApp) { scanner.scanApps(includeSystem: true) }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: selectedSegment == index ? .bold : .medium))
                .foregroundColor(selectedSegment == index ? .white : .iappayTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Capsule().fill(selectedSegment == index ? Color.iappayPurple.opacity(0.26) : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private func appRow(_ app: InstalledAppInfo) -> some View {
        HStack(spacing: 13) {
            AppIconView(systemName: icon(for: app.bundleId), size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(app.appName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.iappayTextPrimary)
                    .lineLimit(1)
                Text("v\(app.version) • \(app.bundleId)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.iappayTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.iappayTextSecondary)
        }
        .padding(14)
        .referenceCard(cornerRadius: 22)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 36))
                .foregroundColor(.iappayPurple)
            Text("Không tìm thấy ứng dụng")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.iappayTextPrimary)
            Text("Cho phép companion bridge ghi snapshot hoặc thêm app bằng Bundle ID để xem dữ liệu IAP.")
                .font(.system(size: 13))
                .foregroundColor(.iappayTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func icon(for bundleID: String) -> String {
        let lower = bundleID.lowercased()
        if lower.contains("lemon") { return "video.fill" }
        if lower.contains("openai") { return "bubble.left.and.bubble.right.fill" }
        if lower.contains("duolingo") { return "bird.fill" }
        if lower.contains("canva") { return "paintpalette.fill" }
        if lower.contains("apple") { return "gearshape.fill" }
        return "app.fill"
    }
}
