import SwiftUI

public struct LibraryView: View {
    @ObservedObject private var store = StoreKitService.shared
    @State private var query = ""
    @State private var selectedItem: IAPItem?

    private var starredItems: [IAPItem] {
        store.items.filter { $0.isStarred && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.appName.localizedCaseInsensitiveContains(query)) }
    }

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Thư viện")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.iappayTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 46)
                    SearchField("Tìm trong thư viện", text: $query)
                    if starredItems.isEmpty {
                        VStack(spacing: 13) {
                            Image(systemName: "folder")
                                .font(.system(size: 42, weight: .medium))
                                .foregroundColor(.iappayPurple)
                            Text("Thư viện trống")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.iappayTextPrimary)
                            Text("Lưu gói IAP bằng nút ngôi sao để truy cập nhanh ở đây.")
                                .font(.system(size: 13))
                                .foregroundColor(.iappayTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 58)
                    } else {
                        Text("ĐÃ LƯU (\(starredItems.count))")
                            .sectionLabelStyle()
                        ForEach(starredItems) { item in
                            IAPItemRow(item: item) { selectedItem = item }
                        }
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
        }
    }
}
