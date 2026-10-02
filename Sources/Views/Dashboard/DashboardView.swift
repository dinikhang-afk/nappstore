import SwiftUI

public struct DashboardView: View {
    @ObservedObject var bridge = TweakBridge.shared
    @State private var showingImportModal = false
    @State private var pastedJSON = ""
    @State private var importError = false

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Status
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DINI PAY")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.textPrimary)
                            Text("Apple StoreKit Official Inspector")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textMuted)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Circle()
                                .fill(bridge.snapshots.isEmpty ? Color.warningYellow : Color.successGreen)
                                .frame(width: 8, height: 8)
                            Text(bridge.snapshots.isEmpty ? "Waiting Scan" : "Tweak Ready")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(bridge.snapshots.isEmpty ? .warningYellow : .successGreen)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.darkCard)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.darkBorder, lineWidth: 1))
                    }

                    // Metrics Grid (2x2)
                    let latest = bridge.snapshots.first
                    let totalProducts = latest?.totalProducts ?? 0
                    let totalSubs = latest?.totalSubscriptions ?? 0
                    let totalTrials = latest?.totalFreeTrials ?? 0
                    let totalDiscounts = latest?.totalDiscounts ?? 0

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(
                            title: "Sản phẩm",
                            value: "\(totalProducts)",
                            subtitle: "Gói đã phát hiện",
                            accentColor: .accentBlue,
                            systemImage: "cart.fill"
                        )
                        MetricCard(
                            title: "Thuê bao",
                            value: "\(totalSubs)",
                            subtitle: "Auto-renewable",
                            accentColor: .accentBlue,
                            systemImage: "repeat.circle.fill"
                        )
                        MetricCard(
                            title: "Free Trials",
                            value: "\(totalTrials)",
                            subtitle: "Dùng thử ẩn",
                            accentColor: .purpleTrial,
                            systemImage: "bolt.shield.fill"
                        )
                        MetricCard(
                            title: "Discounts",
                            value: "\(totalDiscounts)",
                            subtitle: "Gói ưu đãi",
                            accentColor: .warningYellow,
                            systemImage: "tag.fill"
                        )
                    }

                    // Quick Actions
                    HStack(spacing: 12) {
                        Button(action: { bridge.loadAllSnapshots() }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Đồng bộ Tweak")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentBlue)
                            .cornerRadius(10)
                        }

                        Button(action: { showingImportModal = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Dán JSON")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.darkCard)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.darkBorder, lineWidth: 1))
                        }
                    }

                    // Recent Snapshots
                    SectionHeaderView("Lịch sử quét gần đây", count: bridge.snapshots.count)

                    if bridge.snapshots.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 38))
                                .foregroundColor(.textMuted)
                            Text("Chưa có dữ liệu từ Tweak")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textSecondary)
                            Text("Hãy mở app đích trên iPhone có companion bridge để bắt gói StoreKit.")
                                .font(.system(size: 12))
                                .foregroundColor(.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                        .background(Color.darkCard.opacity(0.5))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.darkBorder, lineWidth: 1))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(bridge.snapshots) { snapshot in
                                NavigationLink(destination: ProductDetailListView(snapshot: snapshot)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(snapshot.bundleId)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.textPrimary)
                                            Text(snapshot.formattedDate)
                                                .font(.system(size: 11))
                                                .foregroundColor(.textMuted)
                                        }

                                        Spacer()

                                        HStack(spacing: 6) {
                                            if snapshot.totalFreeTrials > 0 {
                                                BadgeTag("★ \(snapshot.totalFreeTrials) Trial", bg: .purpleTrial)
                                            }
                                            BadgeTag("\(snapshot.totalProducts) IAP", bg: .accentBlue)
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.textMuted)
                                    }
                                    .padding(14)
                                    .background(Color.darkCard)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.darkBorder, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.darkBackground.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingImportModal) {
                ImportJSONSheet(pastedJSON: $pastedJSON, isPresented: $showingImportModal)
            }
        }
    }
}

struct ImportJSONSheet: View {
    @Binding var pastedJSON: String
    @Binding var isPresented: Bool
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dán nội dung JSON xuất từ Tweak hoặc In-App HUD:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)

                TextEditor(text: $pastedJSON)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Color.darkCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.darkBorder, lineWidth: 1))

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.errorRed)
                }

                Button(action: {
                    let success = TweakBridge.shared.importJSONString(pastedJSON)
                    if success {
                        isPresented = false
                    } else {
                        errorMessage = "JSON không đúng định dạng ScanSnapshot!"
                    }
                }) {
                    Text("Lưu Snapshot")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentBlue)
                        .cornerRadius(10)
                }
            }
            .padding(16)
            .background(Color.darkBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("Nhập JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { isPresented = false }
                        .foregroundColor(.accentBlue)
                }
            }
        }
    }
}
