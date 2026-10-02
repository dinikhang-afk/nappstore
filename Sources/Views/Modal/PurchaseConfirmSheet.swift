import SwiftUI

public struct PurchaseConfirmSheet: View {
    public let item: IAPItem
    @Binding public var isPresented: Bool

    @State private var selectedMode: PaymentMode = .appStore
    @State private var isProcessing: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var errorDetail: String = ""
    @AppStorage("defaultPaymentMode") private var defaultPaymentMode = PaymentMode.appStore.rawValue

    public var body: some View {
        ZStack {
            Color.iappayBackground.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentBlue)

                    Spacer()

                    Text("Xác nhận mua")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.iappayTextPrimary)

                    Spacer()

                    // Balance placeholder
                    Button("") {}
                        .frame(width: 50)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Product Card Box
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                // App Icon
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red)
                                        .frame(width: 48, height: 48)
                                    Image(systemName: item.appIconSystem)
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.appName)
                                        .font(.system(size: 13))
                                        .foregroundColor(.iappayTextSecondary)

                                    Text(item.title)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.iappayTextPrimary)

                                    HStack(spacing: 6) {
                                        if let trial = item.trialBadge {
                                            Text(trial)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.iappayGreen)
                                                .cornerRadius(4)
                                        }

                                        if item.isHidden {
                                            Text("ẨN")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.iappayTextSecondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.iappayBadgeHidden)
                                                .cornerRadius(4)
                                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.iappayBorder, lineWidth: 0.5))
                                        }
                                    }
                                }

                                Spacer()

                                // Price Badge top-right
                                Text(item.formattedPrice)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(item.isFree ? .black : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(item.isFree ? Color.iappayYellow : Color.iappayPurple)
                                    .cornerRadius(16)
                            }

                            Divider().background(Color.iappayBorder)

                            // Subtitle description
                            Text(item.subtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.iappayTextSecondary)
                        }
                        .padding(16)
                        .background(Color.iappayCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.iappayBorder, lineWidth: 1))

                        // Payment Mode Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CHẾ ĐỘ THANH TOÁN")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.iappayTextMuted)

                            // Custom Segmented Control
                            HStack(spacing: 0) {
                                ForEach(PaymentMode.allCases) { mode in
                                    Button(action: { selectedMode = mode }) {
                                        Text(mode.rawValue)
                                            .font(.system(size: 13, weight: selectedMode == mode ? .bold : .medium))
                                            .foregroundColor(selectedMode == mode ? .white : .iappayTextSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selectedMode == mode ? Color.iappayCard : Color.clear)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(3)
                            .background(Color.iappaySurface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.iappayBorder, lineWidth: 1))

                            // Mode Description Text
                            Text(selectedMode.descriptionText)
                                .font(.system(size: 12))
                                .foregroundColor(.iappayTextSecondary)
                                .lineSpacing(3)
                                .padding(.horizontal, 4)
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                }

                // Bottom Action Button
                VStack {
                    Button(action: handlePurchase) {
                        Text("Mua \(item.formattedPrice)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.iappayPurple)
                            .cornerRadius(14)
                    }
                    .disabled(isProcessing)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // Spinner Loading HUD
            if isProcessing {
                Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                VStack(spacing: 14) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                    Text("Đang xử lý giao dịch...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.iappayCard.opacity(0.95))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.iappayBorder, lineWidth: 1))
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(displayErrorMessage),
                primaryButton: .default(Text("OK")),
                secondaryButton: .default(Text("Copy chi tiết"), action: {
                    UIPasteboard.general.string = errorDetail
                })
            )
        }
        .onAppear {
            selectedMode = PaymentMode(rawValue: defaultPaymentMode) ?? .appStore
        }
    }

    private func handlePurchase() {
        isProcessing = true

        StoreKitService.shared.executePurchase(item: item, mode: selectedMode) { result in
            isProcessing = false
            switch result {
            case .success:
                // Dismiss sheet and open target app
                isPresented = false
            case .failure(let err):
                self.errorMessage = err.localizedDescription
                self.errorDetail = "mode=\(selectedMode.rawValue)\nproduct=\(item.storeProductIdentifier)\nadam=\(item.id)\nbundle=\(item.appBundleId)\n\(err.localizedDescription)"
                self.showErrorAlert = true
            }
        }
    }

    private var isPendingHandoff: Bool {
        errorMessage.hasPrefix("Đã gửi lệnh")
    }

    private var isOfferEligibilityError: Bool {
        let lower = errorMessage.lowercased()
        let hasAMS301 = lower.contains("amserrordomain") && lower.contains("301")
        return lower.contains("http 500")
            || lower.contains("http status 500")
            || lower.contains("invalid status code")
            || lower.contains("ams errordomain 301")
            || hasAMS301
            || lower.contains("đã đăng ký gói này")
            || lower.contains("gói cùng nhóm")
    }

    private var alertTitle: String {
        if isPendingHandoff { return "Đang chờ xác nhận" }
        if isOfferEligibilityError { return "Offer không đủ điều kiện" }
        return "Thất bại"
    }

    private var displayErrorMessage: String {
        guard isOfferEligibilityError else { return errorMessage }
        let guidance = item.isTrial
            ? "Apple từ chối offer dùng thử. Tài khoản có thể đã dùng gói này hoặc một gói cùng nhóm. Hãy chọn mục cùng nhóm không có nhãn DÙNG THỬ để mua theo giá thường."
            : "Apple từ chối offer của gói này. Kiểm tra tài khoản App Store, quốc gia cửa hàng và trạng thái thuê bao trước khi thử lại."
        return "\(guidance)\n\nChi tiết Apple: \(errorMessage)"
    }
}
