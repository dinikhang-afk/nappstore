import SwiftUI

/// Shared visual language for the NappStore UI. The reference app uses a
/// near-black canvas, cool indigo cards and a translucent floating tab bar.
extension Color {
    static let iappayBackground = Color(hex: 0x080A12)
    static let iappaySurface = Color(hex: 0x111321)
    static let iappayCard = Color(hex: 0x1A1D30)
    static let iappayCardRaised = Color(hex: 0x242840)
    static let iappayBorder = Color(hex: 0x343852)

    static let iappayPurple = Color(hex: 0x9993FF)
    static let iappayPurpleDark = Color(hex: 0x5854A7)
    static let iappayGreen = Color(hex: 0x20D6A0)
    static let iappayYellow = Color(hex: 0xFFC117)
    static let iappayOrange = Color(hex: 0xFFB20C)
    static let iappayRed = Color(hex: 0xFF5E6C)
    static let iappayCyan = Color(hex: 0x32D5E8)

    static let iappayBadgeHidden = Color(hex: 0x33384D)
    static let iappayBadgeTrialBg = Color(hex: 0x113F3A)

    static let iappayTextPrimary = Color.white
    static let iappayTextSecondary = Color(hex: 0xB7B9CC)
    static let iappayTextMuted = Color(hex: 0x777C99)

    // Compatibility aliases used by the secondary inspector screens.
    static let darkBackground = iappayBackground
    static let darkSurface = iappaySurface
    static let darkCard = iappayCard
    static let darkBorder = iappayBorder
    static let accentBlue = iappayPurple
    static let purpleTrial = iappayGreen
    static let successGreen = iappayGreen
    static let errorRed = iappayRed
    static let warningYellow = iappayYellow
    static let textPrimary = iappayTextPrimary
    static let textSecondary = iappayTextSecondary
    static let textMuted = iappayTextMuted

    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension View {
    func referenceCard(cornerRadius: CGFloat = 22, stroke: Color = .iappayBorder) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.iappayCard.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke.opacity(0.8), lineWidth: 1)
            )
    }

    func sectionLabelStyle() -> some View {
        self
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.iappayTextSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
