import SwiftUI

public struct HistoryView: View {
    @ObservedObject var bridge = TweakBridge.shared
    @State private var searchText = ""

    public var filteredSnapshots: [ScanSnapshot] {
        if searchText.isEmpty { return bridge.snapshots }
        return bridge.snapshots.filter { $0.bundleId.localizedCaseInsensitiveContains(searchText) }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.textMuted)
                    TextField("Tìm theo bundle ID...", text: $searchText)
                        .foregroundColor(.textPrimary)
                }
                .padding(10)
                .background(Color.darkCard)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.darkBorder, lineWidth: 1))
                .padding(16)

                if bridge.snapshots.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 36))
                            .foregroundColor(.textMuted)
                        Text("Chưa có lịch sử")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredSnapshots) { snapshot in
                            NavigationLink(destination: ProductDetailListView(snapshot: snapshot)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(snapshot.bundleId)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.textPrimary)

                                        Spacer()

                                        Text(snapshot.formattedDate)
                                            .font(.system(size: 11))
                                            .foregroundColor(.textMuted)
                                    }

                                    HStack(spacing: 6) {
                                        BadgeTag("\(snapshot.totalProducts) Gói IAP", bg: .accentBlue)
                                        if snapshot.totalFreeTrials > 0 {
                                            BadgeTag("★ \(snapshot.totalFreeTrials) Trial", bg: .purpleTrial)
                                        }
                                        if snapshot.totalDiscounts > 0 {
                                            BadgeTag("\(snapshot.totalDiscounts) Discount", bg: .warningYellow)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.darkCard)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let item = filteredSnapshots[index]
                                bridge.deleteSnapshot(item)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .background(Color.darkBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("Lịch Sử Quét")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { bridge.loadAllSnapshots() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.accentBlue)
                    }
                }
            }
        }
    }
}
