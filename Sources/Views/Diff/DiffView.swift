import SwiftUI

public struct DiffView: View {
    @ObservedObject var bridge = TweakBridge.shared
    @State private var selectedOlderIndex: Int = 0
    @State private var selectedNewerIndex: Int = 0

    public var diffResult: DiffResult? {
        guard bridge.snapshots.count >= 2,
              selectedOlderIndex < bridge.snapshots.count,
              selectedNewerIndex < bridge.snapshots.count,
              selectedOlderIndex != selectedNewerIndex else {
            return nil
        }
        let older = bridge.snapshots[selectedOlderIndex]
        let newer = bridge.snapshots[selectedNewerIndex]
        return DiffEngine.compare(older: older, newer: newer)
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if bridge.snapshots.count < 2 {
                        VStack(spacing: 12) {
                            Image(systemName: "square.split.2x1")
                                .font(.system(size: 38))
                                .foregroundColor(.textMuted)
                            Text("Cần tối thiểu 2 Snapshot")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.textPrimary)
                            Text("Hãy thực hiện quét ít nhất 2 lần (hoặc 2 app) để so sánh biến động giá và offer.")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        // Pickers for snapshots
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BẢN GỐC (CŨ HƠN):")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.textMuted)

                            Picker("Older", selection: $selectedOlderIndex) {
                                ForEach(0..<bridge.snapshots.count, id: \.self) { idx in
                                    Text("\(bridge.snapshots[idx].bundleId) (\(bridge.snapshots[idx].formattedDate))").tag(idx)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(10)
                            .background(Color.darkCard)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.darkBorder, lineWidth: 1))

                            Text("BẢN ĐỐI CHIẾU (MỚI HƠN):")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.textMuted)

                            Picker("Newer", selection: $selectedNewerIndex) {
                                ForEach(0..<bridge.snapshots.count, id: \.self) { idx in
                                    Text("\(bridge.snapshots[idx].bundleId) (\(bridge.snapshots[idx].formattedDate))").tag(idx)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(10)
                            .background(Color.darkCard)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.darkBorder, lineWidth: 1))
                        }

                        if let diff = diffResult {
                            // Summary Cards
                            HStack(spacing: 10) {
                                MetricCard(title: "Thêm Mới", value: "\(diff.addedProducts.count)", subtitle: "Gói mới", accentColor: .successGreen, systemImage: "plus.circle.fill")
                                MetricCard(title: "Gỡ Bỏ", value: "\(diff.removedProducts.count)", subtitle: "Gói bị ẩn", accentColor: .errorRed, systemImage: "minus.circle.fill")
                                MetricCard(title: "Thay Đổi", value: "\(diff.modifiedProducts.count)", subtitle: "Biến động", accentColor: .warningYellow, systemImage: "pencil.circle.fill")
                            }

                            // Summary Changes List
                            if !diff.summaryChanges.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("TỔNG QUAN THAY ĐỔI:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.textMuted)

                                    ForEach(diff.summaryChanges, id: \.self) { change in
                                        Text("• \(change)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.warningYellow)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.darkCard)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.darkBorder, lineWidth: 1))
                            }

                            // Added Products
                            if !diff.addedProducts.isEmpty {
                                SectionHeaderView("Gói IAP Mới Thêm (+)", count: diff.addedProducts.count)
                                ForEach(diff.addedProducts) { p in
                                    ProductCardView(product: p)
                                }
                            }

                            // Removed Products
                            if !diff.removedProducts.isEmpty {
                                SectionHeaderView("Gói IAP Bị Gỡ (-)", count: diff.removedProducts.count)
                                ForEach(diff.removedProducts) { p in
                                    ProductCardView(product: p)
                                }
                            }

                            // Modified Details
                            if !diff.modifiedProducts.isEmpty {
                                SectionHeaderView("Chi Tiết Biến Động Offer", count: diff.modifiedProducts.count)
                                ForEach(diff.modifiedProducts) { detail in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(detail.productId)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.textPrimary)

                                        ForEach(detail.notes, id: \.self) { note in
                                            Text("  ➜ \(note)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.accentBlue)
                                        }

                                        ForEach(detail.addedOffers, id: \.self) { offer in
                                            Text("  + Offer mới: \(offer)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.successGreen)
                                        }

                                        ForEach(detail.removedOffers, id: \.self) { offer in
                                            Text("  - Offer bị xoá: \(offer)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.errorRed)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.darkCard)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.darkBorder, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.darkBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("So Sánh Biến Động")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
