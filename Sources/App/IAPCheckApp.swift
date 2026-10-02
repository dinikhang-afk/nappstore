import SwiftUI

@main
struct NappStoreApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = "Tối"

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(appearanceMode == "Sáng" ? .light : (appearanceMode == "Tối" ? .dark : nil))
        }
    }
}
