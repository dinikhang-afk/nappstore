import Foundation
import Combine

/// File/notification bridge used by an optional companion tweak.
///
/// A sandboxed App Store build can read its own Documents folder. Cross-app
/// purchase handoff requires an external companion that can see one of the
/// shared bridge paths below; writing a local Documents file is not enough
/// because the target app has a separate iOS sandbox.
public final class TweakBridge: ObservableObject {
    public static let shared = TweakBridge()

    @Published public private(set) var snapshots: [ScanSnapshot] = []
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var lastBridgeMessage = "Chưa kết nối bridge"

    private let fileManager = FileManager.default

    public init() {
        loadAllSnapshots()
    }

    public var searchPaths: [URL] {
        var paths: [URL] = []
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            paths.append(documents.appendingPathComponent("IAPCheck", isDirectory: true))
        }
        paths.append(URL(fileURLWithPath: "/var/mobile/Documents/IAPCheck", isDirectory: true))
        paths.append(URL(fileURLWithPath: "/var/jb/var/mobile/Documents/IAPCheck", isDirectory: true))
        paths.append(URL(fileURLWithPath: "/tmp/IAPCheck", isDirectory: true))
        return paths
    }

    private var externalBridgePaths: [URL] {
        Array(searchPaths.dropFirst())
    }

    public func loadAllSnapshots() {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [ScanSnapshot] = []
            var seen = Set<String>()
            for folder in self.searchPaths {
                guard self.fileManager.fileExists(atPath: folder.path),
                      let files = try? self.fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
                for file in files where file.pathExtension.lowercased() == "json" && !file.lastPathComponent.contains("pending_buy") {
                    guard let data = try? Data(contentsOf: file),
                          let snapshot = self.decodeSnapshot(data: data, file: file) else { continue }
                    if seen.insert(snapshot.id).inserted { found.append(snapshot) }
                }
            }
            DispatchQueue.main.async {
                self.snapshots = found.sorted { $0.timestamp > $1.timestamp }
                self.lastSyncDate = Date()
                self.lastBridgeMessage = found.isEmpty ? "Chưa có snapshot" : "Đã đồng bộ \(found.count) snapshot"
            }
        }
    }

    public func importJSONString(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        do {
            guard let snapshot = decodeSnapshot(data: data, file: nil) else {
                throw IAPError.failed("JSON không có snapshot hoặc danh sách products hợp lệ.")
            }
            saveSnapshotLocally(snapshot)
            loadAllSnapshots()
            return true
        } catch {
            DispatchQueue.main.async { self.lastBridgeMessage = "JSON không hợp lệ: \(error.localizedDescription)" }
            return false
        }
    }

    public func saveSnapshotLocally(_ snapshot: ScanSnapshot) {
        guard let folder = searchPaths.first else { return }
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: folder.appendingPathComponent("\(snapshot.bundleId)_\(snapshot.timestamp).json"), options: .atomic)
        } catch {
            DispatchQueue.main.async { self.lastBridgeMessage = "Không thể lưu snapshot: \(error.localizedDescription)" }
        }
    }

    /// Writes a command that the companion tweak can consume while its target
    /// app is running. No receipt or transaction is fabricated here.
    @discardableResult
    public func triggerRemotePurchase(
        bundleId: String,
        productId: String,
        mode: PaymentMode = .direct,
        launchTarget: Bool = false,
        adamID: String? = nil
    ) -> Bool {
        var payload: [String: Any] = [
            "bundleId": bundleId,
            "productId": productId,
            "mode": mode.rawValue.lowercased(),
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        if let adamID { payload["adamId"] = adamID }
        var writeSucceeded = false
        // Only an external bridge path can be consumed by another app. The
        // app-owned Documents folder is intentionally excluded here so a
        // missing bridge is reported instead of looking like a queued buy.
        for folder in externalBridgePaths {
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: folder.appendingPathComponent("pending_buy.json"), options: .atomic)
                writeSucceeded = true
                break
            } catch {
                continue
            }
        }

        if writeSucceeded {
            DispatchQueue.main.async { self.lastBridgeMessage = "Đã gửi lệnh \(mode.rawValue) tới \(bundleId)" }
            let notificationName = CFNotificationName("com.adr.checkiap.trigger_buy" as CFString)
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, nil, nil, true)
            if launchTarget { InstalledAppsScanner.shared.launchApp(bundleId: bundleId) }
            return true
        } else {
            DispatchQueue.main.async { self.lastBridgeMessage = "Chưa có companion bridge có thể nhận lệnh cross-app" }
            return false
        }
    }

    public func deleteSnapshot(_ snapshot: ScanSnapshot) {
        snapshots.removeAll { $0.id == snapshot.id }
        for folder in searchPaths {
            guard let files = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.lastPathComponent.contains(snapshot.bundleId) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    public func clearCache() {
        for folder in searchPaths {
            guard fileManager.fileExists(atPath: folder.path) else { continue }
            try? fileManager.removeItem(at: folder)
        }
        snapshots = []
        lastBridgeMessage = "Đã xóa cache bridge"
    }

    // The tweak writes a compact `<bundle>_iap.json` export containing
    // `timestamp`, `totalProducts`, and `products`. Older bridge versions
    // wrote the ScanSnapshot shape directly. Accept both shapes so a valid
    // tweak export is not silently discarded just because its wrapper differs.
    private func decodeSnapshot(data: Data, file: URL?) -> ScanSnapshot? {
        if let snapshot = try? JSONDecoder().decode(ScanSnapshot.self, from: data) {
            return snapshot
        }

        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return nil }

        let rawProducts = productPayloads(from: dictionary)
        guard !rawProducts.isEmpty else { return nil }

        let bundleID = bridgeString(dictionary, keys: ["bundleId", "bundleID", "bundleIdentifier"])
            ?? file.flatMap { bundleIDFromFilename($0) }
            ?? "unknown.app"
        let timestamp = bridgeDouble(dictionary["timestamp"])
            ?? (file.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSince1970 })
            ?? Date().timeIntervalSince1970
        let products = rawProducts.compactMap(decodeProduct)
        guard !products.isEmpty else { return nil }
        return ScanSnapshot(bundleId: bundleID, timestamp: timestamp, products: products)
    }

    private func productPayloads(from dictionary: [String: Any]) -> [[String: Any]] {
        for key in ["products", "items", "inAppPurchases", "in_app_purchases", "catalog", "iap"] {
            guard let value = dictionary[key] else { continue }
            if let array = value as? [[String: Any]] { return array }
            if let array = value as? [Any] {
                let mapped = array.compactMap { $0 as? [String: Any] }
                if !mapped.isEmpty { return mapped }
            }
            if let map = value as? [String: Any] {
                let direct = map.compactMap { key, item -> [String: Any]? in
                    guard var product = item as? [String: Any] else { return nil }
                    if bridgeString(product, keys: ["productId", "productID", "productIdentifier", "identifier", "id"]) == nil {
                        product["productId"] = key
                    }
                    return product
                }
                if !direct.isEmpty { return direct }
                if bridgeString(map, keys: ["productId", "productID", "productIdentifier", "identifier", "id"]) != nil {
                    return [map]
                }
            }
        }
        return []
    }

    private func decodeProduct(_ dictionary: [String: Any]) -> ProductModel? {
        guard let productID = bridgeString(dictionary, keys: ["productId", "productID", "productIdentifier", "identifier", "id"]),
              !productID.isEmpty else { return nil }
        let rawType = bridgeString(dictionary, keys: ["productType", "type", "kind"])?.uppercased() ?? "INAPP"
        let productType: ProductType = rawType.contains("SUBS") ? .subs : .inapp
        let title = bridgeString(dictionary, keys: ["title", "displayName", "localizedTitle", "name"]) ?? productID
        let description = bridgeString(dictionary, keys: ["description", "localizedDescription"]) ?? ""
        let price = bridgeString(dictionary, keys: ["formattedBasePrice", "formattedPrice", "displayPrice", "priceString"]) ?? "N/A"
        let offers = dictionary["offers"] as? [[String: Any]] ?? []
        let offerText = offers.compactMap { bridgeString($0, keys: ["classification", "offerType", "summaryText", "type"]) }.joined(separator: " ").uppercased()
        let hasTrial = bridgeBool(dictionary, keys: ["hasFreeTrial", "hasTrial", "freeTrial", "isTrial"])
            ?? offerText.contains("TRIAL")
            || offerText.contains("FREE")
        let hasDiscount = bridgeBool(dictionary, keys: ["hasIntroDiscount", "hasDiscount", "isDiscounted", "introDiscount"])
            ?? offerText.contains("INTRO")
            || offerText.contains("DISCOUNT")
            || offerText.contains("PROMO")
        return ProductModel(
            productId: productID,
            productType: productType,
            title: title,
            description: description,
            formattedBasePrice: price,
            hasFreeTrial: hasTrial,
            hasIntroDiscount: hasDiscount
        )
    }

    private func bundleIDFromFilename(_ file: URL) -> String? {
        let name = file.deletingPathExtension().lastPathComponent
        let candidate = name.hasSuffix("_iap") ? String(name.dropLast(4)) : name
        return candidate.contains(".") ? candidate : nil
    }

    private func bridgeString(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty { return value }
            if let value = dictionary[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }

    private func bridgeBool(_ dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dictionary[key] as? Bool { return value }
            if let value = dictionary[key] as? NSNumber { return value.boolValue }
            if let value = dictionary[key] as? String {
                if ["true", "yes", "1"].contains(value.lowercased()) { return true }
                if ["false", "no", "0"].contains(value.lowercased()) { return false }
            }
        }
        return nil
    }

    private func bridgeDouble(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
