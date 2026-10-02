import SwiftUI

public struct InstalledAppsView: View {
    @ObservedObject var scanner = InstalledAppsScanner.shared
    @ObservedObject var bridge = TweakBridge.shared
    @State private var searchText: String = ""
    @State private var includeSystemApps: Bool = false

    public var filteredApps: [InstalledAppInfo] {
        scanner.installedApps.filter { app in
            if !includeSystemApps && app.isSystemApp { return false }
            if searchText.isEmpty { return true }
            return app.appName.localizedCaseInsensitiveContains(searchText) ||
                   app.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search & Filter Bar
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.textMuted)
                        TextField("Tìm app theo tên, bundle ID...", text: $searchText)
                            .foregroundColor(.textPrimary)
                    }
                    .padding(10)
                    .background(Color.darkCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.darkBorder, lineWidth: 1))

                    HStack {
                        Toggle("Bao gồm app hệ thống", isOn: $includeSystemApps)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .onChange(of: includeSystemApps) { _ in
                                scanner.scanApps(includeSystem: includeSystemApps)
                            }

                        Spacer()

                        Button(action: { scanner.scanApps(includeSystem: includeSystemApps) }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.accentBlue)
                        }
                    }
                }
                .padding(16)
                .background(Color.darkSurface)

                // List
                if scanner.isScanning {
                    Spacer()
                    ProgressView("Đang quét ứng dụng...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentBlue))
                        .foregroundColor(.textSecondary)
                    Spacer()
                } else {
                    List {
                        ForEach(filteredApps) { app in
                            InstalledAppRow(app: app, snapshot: bridge.snapshots.first { $0.bundleId == app.bundleId })
                                .listRowBackground(Color.darkBackground)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.darkBackground)
                }
            }
            .background(Color.darkBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("Ứng Dụng Đã Cài")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if scanner.installedApps.isEmpty {
                    scanner.scanApps(includeSystem: includeSystemApps)
                }
            }
        }
    }
}

struct InstalledAppRow: View {
    let app: InstalledAppInfo
    let snapshot: ScanSnapshot?

    var body: some View {
        HStack(spacing: 12) {
            // App Icon Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.darkCard)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.darkBorder, lineWidth: 1))
                Image(systemName: app.isSystemApp ? "gear" : "app.fill")
                    .font(.system(size: 20))
                    .foregroundColor(app.isSystemApp ? .textMuted : .accentBlue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(app.appName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text(app.bundleId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textMuted)

                HStack(spacing: 6) {
                    Text("v\(app.version)")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)

                    if let snap = snapshot {
                        BadgeTag("✓ \(snap.totalProducts) IAP", bg: .successGreen)
                        if snap.totalFreeTrials > 0 {
                            BadgeTag("★ Trial", bg: .purpleTrial)
                        }
                    }
                }
            }

            Spacer()

            Button(action: {
                InstalledAppsScanner.shared.launchApp(bundleId: app.bundleId)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Mở App")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentBlue)
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.darkCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.darkBorder, lineWidth: 1))
    }
}
