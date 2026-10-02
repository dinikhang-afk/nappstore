import SwiftUI

public struct ProductDetailListView: View {
    public let snapshot: ScanSnapshot
    @State private var filter: ProductFilter = .all
    @State private var searchText: String = ""
    @State private var showCopiedAlert = false

    enum ProductFilter: String, CaseIterable {
        case all = "Tất cả"
        case trials = "Free Trials"
        case subs = "Subscriptions"
        case inapp = "One-time"
    }

    public var filteredProducts: [ProductModel] {
        snapshot.products.filter { prod in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .trials: matchesFilter = prod.hasFreeTrial
            case .subs: matchesFilter = prod.productType == .subs
            case .inapp: matchesFilter = prod.productType == .inapp
            }

            if searchText.isEmpty { return matchesFilter }
            return matchesFilter && (
                prod.productId.localizedCaseInsensitiveContains(searchText) ||
                prod.title.localizedCaseInsensitiveContains(searchText)
            )
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header Card
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.bundleId)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Text("Quét lúc: \(snapshot.formattedDate)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)

                    HStack(spacing: 8) {
                        BadgeTag("\(snapshot.totalProducts) Gói IAP", bg: .accentBlue)
                        if snapshot.totalFreeTrials > 0 {
                            BadgeTag("★ \(snapshot.totalFreeTrials) Free Trial", bg: .purpleTrial)
                        }
                        if snapshot.totalDiscounts > 0 {
                            BadgeTag("\(snapshot.totalDiscounts) Discount", bg: .warningYellow)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.darkCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.darkBorder, lineWidth: 1))

                // Filter Picker
                Picker("Filter", selection: $filter) {
                    ForEach(ProductFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                // Product Items List
                ForEach(filteredProducts) { prod in
                    ProductCardView(product: prod, onBuyTapped: { p in
                        TweakBridge.shared.triggerRemotePurchase(bundleId: snapshot.bundleId, productId: p.productId)
                    })
                }
            }

            .padding(16)
        }
        .background(Color.darkBackground.edgesIgnoringSafeArea(.all))
        .navigationTitle("Chi tiết IAP")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if let data = try? JSONEncoder().encode(snapshot),
                       let str = String(data: data, encoding: .utf8) {
                        UIPasteboard.general.string = str
                        showCopiedAlert = true
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.accentBlue)
                }
            }
        }
        .alert(isPresented: $showCopiedAlert) {
            Alert(title: Text("Thành công"), message: Text("Đã copy dữ liệu JSON của app vào clipboard!"), dismissButton: .default(Text("OK")))
        }
    }
}

public struct ProductCardView: View {
    public let product: ProductModel
    public var onBuyTapped: ((ProductModel) -> Void)? = nil

    public init(product: ProductModel, onBuyTapped: ((ProductModel) -> Void)? = nil) {
        self.product = product
        self.onBuyTapped = onBuyTapped
    }

    public var body: some View {

        VStack(alignment: .leading, spacing: 10) {
            // Title & Price
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title.isEmpty ? product.productId : product.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Text(product.productId)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Text(product.formattedBasePrice)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.successGreen)
            }

            if !product.description.isEmpty {
                Text(product.description)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            // Badges & Action
            HStack(spacing: 6) {
                BadgeTag(product.productType == .subs ? "SUBSCRIPTION" : "ONE-TIME", bg: product.productType == .subs ? .accentBlue : .gray)

                if product.hasFreeTrial {
                    BadgeTag("★ FREE TRIAL DETECTED", bg: .purpleTrial)
                }

                if product.hasIntroDiscount {
                    BadgeTag("INTRO DISCOUNT", bg: .warningYellow)
                }

                Spacer()

                Button(action: {
                    onBuyTapped?(product)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Mua")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.successGreen)
                    .cornerRadius(6)
                }
            }


            // Offers breakdown
            if !product.offers.isEmpty {
                Divider().background(Color.darkBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text("OFFERS & PRICING PHASES:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textMuted)

                    ForEach(product.offers) { offer in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(offer.summaryText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(offer.classification == .freeTrial ? .purpleTrial : .textPrimary)
                                Spacer()
                                if let id = offer.offerId {
                                    Text("ID: \(id)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.textMuted)
                                }
                            }

                            ForEach(offer.pricingPhases) { phase in
                                Text("  • Giá: \(phase.formattedPrice) | Kỳ hạn: \(phase.billingPeriod) | Số chu kỳ: \(phase.billingCycleCount)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(8)
                        .background(Color.darkSurface)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.darkCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(product.hasFreeTrial ? Color.purpleTrial.opacity(0.6) : Color.darkBorder, lineWidth: 1)
        )
    }
}
