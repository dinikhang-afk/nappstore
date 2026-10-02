import SwiftUI

public struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let content: Content

    public init(cornerRadius: CGFloat = 22, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                    .background(Color.iappayCard.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.iappayBorder.opacity(0.9), lineWidth: 1)
            )
    }
}

public struct SearchField: View {
    public let placeholder: String
    @Binding public var text: String
    public var onSubmit: (() -> Void)?

    public init(_ placeholder: String, text: Binding<String>, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.iappayTextSecondary)

            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.iappayTextPrimary)
                .tint(.iappayPurple)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.iappayTextMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Capsule().fill(Color.iappayCardRaised.opacity(0.8)))
        .overlay(Capsule().stroke(Color.iappayBorder, lineWidth: 1))
    }
}

public struct AppIconView: View {
    public let systemName: String
    public let url: URL?
    public let size: CGFloat

    public init(systemName: String, url: URL? = nil, size: CGFloat = 48) {
        self.systemName = systemName
        self.url = url
        self.size = size
    }

    public var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
        )
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.iappayPurpleDark, .iappayCardRaised],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

public struct FilterPill: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void

    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : .iappayTextSecondary)
                .padding(.horizontal, 15)
                .frame(height: 38)
                .background(
                    Capsule().fill(isSelected ? Color.iappayPurple : Color.iappayCardRaised.opacity(0.78))
                )
                .overlay(Capsule().stroke(Color.iappayBorder.opacity(isSelected ? 0 : 0.9), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

public struct BadgeTag: View {
    public let text: String
    public let backgroundColor: Color
    public let textColor: Color

    public init(_ text: String, bg: Color, fg: Color = .white) {
        self.text = text
        self.backgroundColor = bg
        self.textColor = fg
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(backgroundColor.opacity(0.9)))
    }
}

public struct MetricCard: View {
    public let title: String
    public let value: String
    public let subtitle: String
    public let accentColor: Color
    public let systemImage: String

    public init(title: String, value: String, subtitle: String, accentColor: Color, systemImage: String) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.iappayTextMuted)
                Spacer()
                Image(systemName: systemImage)
                    .foregroundColor(accentColor)
            }
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(.iappayTextPrimary)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.iappayTextSecondary)
        }
        .padding(14)
        .referenceCard(cornerRadius: 16)
    }
}

public struct SectionHeaderView: View {
    public let title: String
    public let count: Int?

    public init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.iappayTextSecondary)
                .tracking(0.4)
            if let count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.iappayPurple)
            }
            Spacer()
        }
    }
}

public struct IAPItemRow: View {
    public let item: IAPItem
    public let action: () -> Void

    public init(item: IAPItem, action: @escaping () -> Void) {
        self.item = item
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                AppIconView(systemName: item.appIconSystem, url: item.appIconURL, size: 48)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.iappayTextPrimary)
                            .lineLimit(1)
                        if let badge = item.trialBadge { BadgeTag(badge, bg: .iappayGreen) }
                    }
                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.iappayTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(item.formattedPrice)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(item.isFree ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(item.isFree ? Color.iappayYellow : (item.isTrial ? Color.iappayGreen : Color.iappayPurple)))
            }
            .padding(12)
            .referenceCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}
