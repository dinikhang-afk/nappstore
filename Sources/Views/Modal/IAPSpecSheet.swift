import SwiftUI

public struct IAPSpecSheet: View {
    public let item: IAPItem
    @Binding public var isPresented: Bool
    public let onBuyTapped: () -> Void

    @State private var copied: Bool = false

    public var body: some View {
        ZStack {
            Color.iappayBackground.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Thông Tin Gói IAP")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.iappayTextPrimary)

                    Spacer()

                    Button("Đóng") {
                        isPresented = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.iappayPurple)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title Card
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.iappayCard)
                                    .frame(width: 50, height: 50)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.iappayBorder, lineWidth: 1))
                                Image(systemName: item.appIconSystem)
                                    .font(.system(size: 24))
                                    .foregroundColor(.iappayPurple)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.iappayTextPrimary)
                                Text(item.appName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.iappayTextSecondary)
                            }

                            Spacer()

                            Text(item.formattedPrice)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(item.isFree ? .black : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(item.isFree ? Color.iappayYellow : Color.iappayPurple)
                                .cornerRadius(12)
                        }
                        .padding(14)
                        .background(Color.iappayCard)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.iappayBorder, lineWidth: 1))

                        // Specs Table matching video IMG_3174
                        VStack(spacing: 0) {
                            specRow(label: "Tình trạng", value: item.isTrial ? "Dùng thử" : (item.trialBadge != nil ? "Giảm giá" : "Nguyên giá"))
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Kind", value: item.isTrial ? "Dùng thử" : "Nguyên giá")
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Type", value: item.groupName.contains("SUBS") ? "Thuê bao" : "1 năm / Chu kỳ")
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Period", value: item.subtitle)
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Price", value: item.formattedPrice)
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Product ID", value: item.id)
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Product Number", value: item.productNumber ?? "N/A")
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Family", value: item.family)
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Offer ID", value: item.offerId ?? "None")
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Store Country", value: item.storeCountry)
                            Divider().background(Color.iappayBorder)

                            specRow(label: "Listed Status", value: item.isHidden ? "Hidden (Gói ẩn)" : "Public (Công khai)")
                            Divider().background(Color.iappayBorder)

                            specRow(label: "App Target", value: "\(item.appName) (\(item.appBundleId))")
                        }
                        .background(Color.iappayCard)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.iappayBorder, lineWidth: 1))

                        // Copy ID Button
                        Button(action: {
                            UIPasteboard.general.string = item.id
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copied = false
                            }
                        }) {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Đã sao chép ID gói!" : "Sao chép ID gói")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.iappayPurple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.iappayCard)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.iappayBorder, lineWidth: 1))
                        }

                        // Purchase Button
                        Button(action: {
                            isPresented = false
                            onBuyTapped()
                        }) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Mở Sheet Kích Hoạt (\(item.formattedPrice))")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.iappayPurple)
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.iappayTextSecondary)
                .frame(width: 110, alignment: .leading)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.iappayTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
