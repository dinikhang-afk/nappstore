import Foundation
import Combine
import UIKit

public final class InstalledAppsScanner: ObservableObject {
    public static let shared = InstalledAppsScanner()

    @Published public private(set) var installedApps: [InstalledAppInfo] = []
    @Published public private(set) var isScanning = false

    private init() {}

    public func scanApps(includeSystem: Bool = false) {
        DispatchQueue.main.async { self.isScanning = true }
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [InstalledAppInfo] = []
            var seen = Set<String>()

            // In a jailbroken/full-access environment, `LSApplicationWorkspace`
            // is the primary source for the installed app list. This keeps the
            // scanner useful on rooted devices without fabricating app data.
            if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as AnyObject as? NSObjectProtocol {
                let defaultSelector = NSSelectorFromString("defaultWorkspace")
                if workspaceClass.responds(to: defaultSelector),
                   let workspace = workspaceClass.perform(defaultSelector)?.takeUnretainedValue() as AnyObject? {
                    let selector = NSSelectorFromString("allInstalledApplications")
                    if workspace.responds(to: selector),
                       let proxies = workspace.perform(selector)?.takeUnretainedValue() as? [AnyObject] {
                        for proxy in proxies {
                            guard let bundleID = (proxy.value(forKey: "bundleIdentifier") as? String), !bundleID.isEmpty else { continue }
                            let name = (proxy.value(forKey: "localizedName") as? String) ?? bundleID
                            let version = (proxy.value(forKey: "shortVersionString") as? String) ?? "1.0"
                            let applicationType = (proxy.value(forKey: "applicationType") as? String) ?? "User"
                            let system = applicationType.lowercased().contains("system")
                            if system && !includeSystem { continue }
                            if seen.insert(bundleID).inserted {
                                results.append(InstalledAppInfo(bundleId: bundleID, appName: name, version: version, isSystemApp: system, hasIAPSupport: true, containerPath: (proxy.value(forKey: "bundleURL") as? URL)?.path))
                            }
                        }
                    }
                }
            }

            // The current app is always a real user app. Keep it visible so the
            // UI remains useful without pretending other apps are discoverable when
            // the environment does not expose them.
            if let ownBundleID = Bundle.main.bundleIdentifier,
               seen.insert(ownBundleID).inserted {
                let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? ownBundleID
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
                results.append(InstalledAppInfo(bundleId: ownBundleID, appName: name, version: version, isSystemApp: false, hasIAPSupport: false, containerPath: nil))
            }
            results.sort { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }

            DispatchQueue.main.async {
                self.installedApps = results
                self.isScanning = false
            }
        }
    }

    public func addCustomApp(bundleId: String, appName: String) {
        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !installedApps.contains(where: { $0.bundleId == trimmed }) else { return }
        let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        installedApps.insert(
            InstalledAppInfo(bundleId: trimmed, appName: name.isEmpty ? trimmed : name, version: "Custom", isSystemApp: false, hasIAPSupport: true, containerPath: nil),
            at: 0
        )
    }

    public func launchApp(bundleId: String) {
        // Public URL schemes are the supported path in a normal iOS build.
        // The bundle-ID scheme is retained as a fallback for apps that expose
        // it; many App Store apps use a branded scheme instead.
        let knownSchemes: [String: String] = [
            "com.lemon.lvoverseas": "capcut",
            "com.openai.chat": "chatgpt",
            "com.google.ios.youtube": "youtube",
            "com.duolingo.DuolingoMobile": "duolingo",
            "com.canva.canva": "canva",
            "ph.telegra.Telegraph": "tg"
        ]
        let scheme = knownSchemes[bundleId] ?? bundleId
        guard let url = URL(string: "\(scheme)://") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

}
