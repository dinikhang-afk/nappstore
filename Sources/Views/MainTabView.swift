import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: AppTab = .explore

    public init() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = UIColor(Color.iappayBackground)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    public var body: some View {
        ZStack {
            Color.iappayBackground.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .explore:
            ExploreStoreView()
        case .installed:
            InstalledView()
        case .library:
            LibraryView()
        case .settings:
            SettingsView()
        }
    }
}

private enum AppTab: Int, CaseIterable, Identifiable {
    case explore, installed, library, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .explore: return "Khám phá"
        case .installed: return "Đã cài đặt"
        case .library: return "Thư viện"
        case .settings: return "Cài đặt"
        }
    }

    var icon: String {
        switch self {
        case .explore: return "magnifyingglass"
        case .installed: return "square.stack.3d.up.fill"
        case .library: return "folder"
        case .settings: return "gearshape"
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 5) {
            ForEach(AppTab.allCases) { tab in
                Button { withAnimation(.easeInOut(duration: 0.2)) { selection = tab } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 23, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(selection == tab ? .iappayPurple : .iappayTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selection == tab ? Color.iappayPurple.opacity(0.24) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial)
        .background(Color.iappayCard.opacity(0.72))
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}
