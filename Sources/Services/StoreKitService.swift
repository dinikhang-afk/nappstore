import Foundation
import Combine
import StoreKit

/// Owns the local IAP catalog and the StoreKit 2 purchase flow.
///
/// A normal iOS app cannot read another app's StoreKit catalogue or receipt
/// container. This service therefore has two explicit sources:
/// 1. JSON snapshots written by the companion tweak/bridge, and
/// 2. StoreKit 2 for products belonging to this app's own bundle ID.
///
/// The bridge command is deliberately kept separate from StoreKit purchase so
/// a Direct activation never fabricates a receipt in this process.
public final class StoreKitService: ObservableObject {
    public static let shared = StoreKitService()

    @Published public private(set) var items: [IAPItem] = []
    @Published public private(set) var logs: [IAPLogEntry] = []
    @Published public private(set) var isProcessing = false
    @Published public private(set) var isScanning = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var dataSource = "Đang khởi tạo"

    private let fileManager = FileManager.default
    private let favoritesKey = "nappstore.favoriteProductIDs"
    private var favoriteIDs: Set<String>
    private var metadataTasks: [String: URLSessionDataTask] = [:]

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favoriteIDs = Set(stored)
        loadRealData()
    }

    public func addLog(level: String = "INFO", tag: String = "NappStore", message: String) {
        let entry = IAPLogEntry(level: level, tag: tag, message: message)
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            if self.logs.count > 500 { self.logs.removeLast(self.logs.count - 500) }
        }
    }

    // MARK: Catalog loading

    public func loadRealData() {
        DispatchQueue.main.async {
            self.isScanning = true
            self.addLog(message: "Bắt đầu đồng bộ catalog IAP…")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var parsed: [IAPItem] = []
            for folder in self.catalogFolders {
                self.scanFolder(folder, into: &parsed)
            }

            // Product IDs are globally unique only within an app. Keep the
            // bundle ID in the deduplication key to avoid dropping products
            // shared by different apps.
            var seen = Set<String>()
            parsed = parsed.filter { seen.insert("\($0.appBundleId)|\($0.id)").inserted }

            let hasCatalog = !parsed.isEmpty
            let result = parsed.map(self.applyFavorite)

            DispatchQueue.main.async {
                self.items = result
                self.lastSyncDate = Date()
                self.isScanning = false
                self.dataSource = hasCatalog
                    ? "Snapshot từ companion tweak"
                    : "Chưa có catalog — cài IAPDumper và mở app để dump"
                self.addLog(
                    level: hasCatalog ? "INFO" : "WARN",
                    message: hasCatalog
                        ? "Đã đọc \(result.count) gói từ \(Set(result.map(\.appBundleId)).count) ứng dụng."
                        : "Chưa có snapshot catalog. Cài IAPDumper tweak rồi mở app bất kỳ."
                )

                for bundleID in Set(result.map(\.appBundleId)) {
                    self.fetchAppMetadata(bundleID: bundleID)
                }
            }
        }
    }

    public func toggleFavorite(_ item: IAPItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
        items = items.map { current in
            guard current.id == item.id else { return current }
            return self.replacing(current, isStarred: self.favoriteIDs.contains(current.id))
        }
    }

    public func isFavorite(_ item: IAPItem) -> Bool {
        favoriteIDs.contains(item.id)
    }

    /// Projects every catalog bundle into an app row. A normal IPA cannot
    /// enumerate another app's installation container, so the catalog itself
    /// is the source of truth for apps that arrived through a bridge/export.
    /// This keeps ChatGPT, YouTube, or any future bundle visible alongside
    /// CapCut without hard-coding an app list.
    public var catalogAppInfos: [InstalledAppInfo] {
        let groups = Dictionary(grouping: items, by: \.appBundleId)
        return groups.compactMap { bundleID, appItems in
            guard !appItems.isEmpty else { return nil }
            let first = appItems[0]
            return InstalledAppInfo(
                bundleId: bundleID,
                appName: first.appName,
                version: "Catalog",
                isSystemApp: false,
                hasIAPSupport: true,
                containerPath: nil
            )
        }
        .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    public func clearCachedCatalog() {
        // Only remove the app-owned cache. The other paths may belong to a
        // companion process and deleting them from Settings would be unsafe.
        if let folder = catalogFolders.first {
            try? fileManager.removeItem(at: folder)
        }
        items = []
        addLog(message: "Đã xóa cache catalog cục bộ.")
        loadRealData()
    }

    public func clearLogs() {
        logs = []
    }

    /// Imports a catalog export copied from a companion or another device.
    /// The file is kept in this app's Documents directory and is parsed by
    /// the same code path as bridge snapshots.
    @discardableResult
    public func importCatalogJSON(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is [String: Any] || object is [[String: Any]] else {
            addLog(level: "ERROR", tag: "Catalog", message: "JSON catalog không hợp lệ.")
            return false
        }
        guard let folder = catalogFolders.first else { return false }
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent("imported-catalog.json"), options: .atomic)
            loadRealData()
            addLog(tag: "Catalog", message: "Đã nhập catalog JSON từ clipboard.")
            return true
        } catch {
            addLog(level: "ERROR", tag: "Catalog", message: "Không thể lưu catalog: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: StoreKit 2

    /// Refreshes price/title metadata for IDs configured in the current app.
    /// StoreKit intentionally returns no products for another app's bundle ID.
    public func refreshStoreKitProducts(for identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        Task {
            do {
                let products = try await Product.products(for: identifiers)
                guard !products.isEmpty else {
                    addLog(level: "WARN", tag: "StoreKit", message: "StoreKit không trả về sản phẩm cho bundle hiện tại.")
                    return
                }
                let byID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
                DispatchQueue.main.async {
                    self.items = self.items.map { item in
                        guard let product = byID[item.storeProductIdentifier] else { return item }
                        return self.replacing(
                            item,
                            title: product.displayName,
                            formattedPrice: product.displayPrice,
                            rawPrice: NSDecimalNumber(decimal: product.price).doubleValue
                        )
                    }
                    self.addLog(tag: "StoreKit", message: "Đã đồng bộ giá cho \(products.count) sản phẩm.")
                }
            } catch {
                addLog(level: "ERROR", tag: "StoreKit", message: "Không thể tải sản phẩm: \(error.localizedDescription)")
            }
        }
    }

    /// Executes the appropriate authorized flow for the selected mode.
    public func executePurchase(
        item: IAPItem,
        mode: PaymentMode,
        completion: @escaping (Result<Void, IAPError>) -> Void
    ) {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.addLog(tag: "Purchase", message: "Bắt đầu \(mode.rawValue) cho \(item.storeProductIdentifier) (Adam \(item.id))")
        }

        switch mode {
        case .direct:
            let queued = TweakBridge.shared.triggerRemotePurchase(
                bundleId: item.appBundleId,
                productId: item.storeProductIdentifier,
                mode: .direct,
                launchTarget: true,
                adamID: item.id
            )
            complete(
                queued ? .failure(.pending("Đã gửi lệnh tới bridge; giao dịch chưa được Apple xác nhận.")) : .failure(.failed("Không thể ghi lệnh Direct vào bridge. Kiểm tra quyền truy cập thư mục IAPCheck.")),
                completion,
                message: queued ? "Đã gửi lệnh Direct tới bridge; chờ giao dịch xác nhận." : "Gửi lệnh Direct thất bại.",
                level: queued ? "INFO" : "ERROR"
            )

        case .appStore, .sandbox:
            let currentBundle = Bundle.main.bundleIdentifier ?? ""
            if item.appBundleId != currentBundle {
                // StoreKit purchase is bound to the signed app. For another
                // bundle, this process can only send a command to an external
                // companion; it cannot present that app's StoreKit sheet.
                let queued = TweakBridge.shared.triggerRemotePurchase(
                    bundleId: item.appBundleId,
                    productId: item.storeProductIdentifier,
                    mode: mode,
                    launchTarget: true,
                    adamID: item.id
                )
                complete(
                    queued
                        ? .failure(.pending("Đã gửi lệnh \(mode.rawValue) tới \(item.appBundleId); xác nhận trong sheet Apple của app đích."))
                        : .failure(.failed("Chưa có companion bridge cho \(item.appBundleId). IPA dev không thể tự mở StoreKit của app khác.")),
                    completion,
                    message: queued
                        ? "Đã gửi lệnh \(mode.rawValue) tới app đích; chờ sheet Apple xác nhận."
                        : "Không có companion bridge cho app đích.",
                    level: queued ? "INFO" : "WARN"
                )
                return
            }

            Task {
                do {
                    let products = try await Product.products(for: [item.storeProductIdentifier])
                    guard let product = products.first else {
                        throw IAPError.failed("Không tìm thấy Product ID \(item.storeProductIdentifier) trong StoreKit configuration của app hiện tại.")
                    }
                    let purchaseResult = try await product.purchase()
                    switch purchaseResult {
                    case .success(let verification):
                        switch verification {
                        case .verified(let transaction):
                            await transaction.finish()
                            self.complete(.success(()), completion, message: "StoreKit xác thực giao dịch thành công.")
                        case .unverified(_, let error):
                            self.complete(.failure(.failed("Giao dịch chưa xác thực: \(error.localizedDescription)")), completion, level: "ERROR")
                        }
                    case .userCancelled:
                        self.complete(.failure(.failed("Người dùng đã hủy giao dịch.")), completion, level: "INFO")
                    case .pending:
                        self.complete(.failure(.failed("Giao dịch đang chờ phê duyệt.")), completion, level: "INFO")
                    @unknown default:
                        self.complete(.failure(.failed("StoreKit trả về trạng thái không xác định.")), completion, level: "ERROR")
                    }
                } catch {
                    self.complete(.failure(.failed(error.localizedDescription)), completion, level: "ERROR")
                }
            }
        }
    }

    // MARK: Private parsing and metadata

    private var catalogFolders: [URL] {
        var result: [URL] = []
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            result.append(documents.appendingPathComponent("IAPCheck", isDirectory: true))
        }
        result.append(URL(fileURLWithPath: "/var/mobile/Documents/IAPCheck", isDirectory: true))
        result.append(URL(fileURLWithPath: "/var/jb/var/mobile/Documents/IAPCheck", isDirectory: true))
        result.append(URL(fileURLWithPath: "/tmp/IAPCheck", isDirectory: true))
        return result
    }

    private func scanFolder(_ folder: URL, into output: inout [IAPItem]) {
        guard fileManager.fileExists(atPath: folder.path),
              let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) else { return }

        for case let file as URL in enumerator {
            let ext = file.pathExtension.lowercased()
            guard (ext == "json" || ext == "plist"),
                  !file.lastPathComponent.lowercased().contains("pending_buy") else { continue }
            guard let data = try? Data(contentsOf: file) else { continue }

            let bundleHint = bundleIDHint(for: file)
            if ext == "json", let object = try? JSONSerialization.jsonObject(with: data) {
                if let dictionary = object as? [String: Any] {
                    output.append(contentsOf: parse(dictionary, inheritedBundleID: bundleHint))
                } else if let dictionaries = object as? [[String: Any]] {
                    for dictionary in dictionaries { output.append(contentsOf: parse(dictionary, inheritedBundleID: bundleHint)) }
                }
            } else if ext == "plist",
                      let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                      let dictionary = object as? [String: Any] {
                output.append(contentsOf: parse(dictionary, inheritedBundleID: bundleHint))
            }
        }
    }

    private func bundleIDHint(for file: URL) -> String? {
        let name = file.deletingPathExtension().lastPathComponent
        guard !name.isEmpty else { return nil }
        if let range = name.range(of: "_v", options: .backwards), range.lowerBound > name.startIndex {
            let candidate = String(name[..<range.lowerBound])
            return candidate.contains(".") ? candidate : nil
        }
        if name.hasSuffix("_iap") {
            let candidate = String(name.dropLast(4))
            return candidate.contains(".") ? candidate : nil
        }
        return name.contains(".") ? name : nil
    }

    /// Accepts the current ScanSnapshot shape plus the older tweak exports
    /// used by the reference app (productIdentifier, discounts, data/items
    /// wrappers, and dictionaries keyed by product ID).
    private func parse(
        _ dictionary: [String: Any],
        depth: Int = 0,
        inheritedBundleID: String? = nil,
        inheritedMetadata: [String: Any] = [:]
    ) -> [IAPItem] {
        guard depth < 5 else { return [] }
        let bundleID = firstString(dictionary, keys: [
            "bundleId", "bundleID", "bundle_id", "appBundleId", "appBundleID",
            "applicationIdentifier", "applicationId", "bundleIdentifier"
        ]) ?? inheritedBundleID ?? "unknown.app"
        var metadata = inheritedMetadata
        for (key, value) in dictionary { metadata[key] = value }

        if let rawProducts = firstValue(dictionary, keys: ["products", "items", "iap", "inAppPurchases", "in_app_purchases"]) {
            let products = normalizedDictionaries(rawProducts)
            if !products.isEmpty {
                return products.compactMap { makeItem(product: $0, bundleID: bundleID, totalCount: products.count, parent: metadata) }
            }
        }

        // Some exporters wrap the catalogue under data/payload/snapshot or
        // return one dictionary per app. Walk those wrappers as well.
        var result: [IAPItem] = []
        for key in ["data", "payload", "snapshot", "catalog", "result", "app", "application", "apps"] {
            guard let value = dictionary[key] else { continue }
            if let nested = value as? [String: Any] {
                result.append(contentsOf: parse(nested, depth: depth + 1, inheritedBundleID: bundleID, inheritedMetadata: metadata))
            } else if let nestedApps = value as? [[String: Any]] {
                for app in nestedApps {
                    result.append(contentsOf: parse(app, depth: depth + 1, inheritedBundleID: bundleID, inheritedMetadata: metadata))
                }
            }
        }
        return result
    }

    private func makeItem(product: [String: Any], bundleID: String, totalCount: Int, parent: [String: Any]) -> IAPItem? {
        guard let id = firstString(product, keys: ["productId", "productID", "productIdentifier", "product_id", "identifier", "id"]), !id.isEmpty else { return nil }
        let appName = firstString(product, keys: ["appName", "applicationName", "trackName"])
            ?? firstString(parent, keys: ["appName", "applicationName", "trackName"])
            ?? friendlyName(for: bundleID)
        let type = firstString(product, keys: ["productType", "type", "kind", "product_kind"]) ?? "INAPP"
        let title = firstString(product, keys: ["title", "displayName", "localizedTitle", "name"]) ?? id
        let directSubtitle = firstString(product, keys: ["subtitle"])
        let description = firstString(product, keys: ["description", "localizedDescription"]) ?? ""
        let offers = normalizedOffers(product)
        let hasTrial = firstBool(product, keys: ["hasFreeTrial", "hasTrial", "freeTrial", "isTrial"]) ?? offers.contains { offerClassification($0) == "FREE_TRIAL" }
        let hasDiscount = firstBool(product, keys: ["hasIntroDiscount", "hasDiscount", "isDiscounted", "introDiscount"]) ?? offers.contains { offerClassification($0) == "INTRO_DISCOUNT" }
        let trialOffer = offers.first { offerClassification($0) == "FREE_TRIAL" } ?? (hasTrial ? product : nil)
        let trialText = trialOffer.flatMap { offer -> String? in
            let phase = firstDictionary(offer, keys: ["pricingPhases", "phases", "pricePhase", "trialPhase"]) ?? offer
            let period = firstString(phase, keys: ["billingPeriod", "period", "duration", "trialPeriod", "unit"]) ?? "P1M"
            let count = firstInt(phase, keys: ["billingCycleCount", "cycles", "count"]) ?? 1
            return "DÙNG THỬ \(formatPeriod(period, count: count))"
        }
        let basePrice = firstString(product, keys: ["formattedBasePrice", "displayPrice", "formattedPrice", "priceString", "localizedPrice", "price_formatted"]) ?? formattedNumericPrice(product["price"])
        let price = basePrice ?? "N/A"
        var subtitle = directSubtitle ?? (description.isEmpty ? (hasTrial ? "Dùng thử" : "Nguyên giá") : description)
        if directSubtitle == nil, let trialText {
            subtitle = trialText.replacingOccurrences(of: "DÙNG THỬ ", with: "Dùng thử ").lowercased()
        }
        if !hasTrial && price != "N/A" { subtitle += " • \(periodLabel(type)) • \(price)" }
        if hasDiscount { subtitle += " • Giảm kỳ đầu" }
        let isHidden = firstBool(product, keys: ["isHidden", "hidden"]) ?? !(firstBool(product, keys: ["isVisible", "listed", "isListed"]) ?? true)
        let offerID = firstString(product, keys: ["offerId", "offerID", "offerIdentifier"])
            ?? offers.compactMap { firstString($0, keys: ["offerId", "offerID", "offerIdentifier", "identifier"]) }.first
        let numeric = numericPrice(product["rawPrice"] ?? product["price"], formatted: price)
        let storeCountry = firstString(product, keys: ["storeCountry", "country", "countryCode"]) ?? "VN"
        let family = firstString(product, keys: ["family", "subscriptionGroup", "subscriptionGroupIdentifier"]) ?? (title.split(separator: " ").first.map(String.init) ?? "Pro")
        let productNumber = firstString(product, keys: ["productNumber", "storeProductId", "appleProductId", "numericId"])
        let appIconSystem = firstString(product, keys: ["appIconSystem"]) ?? icon(for: bundleID)
        let groupName = firstString(product, keys: ["groupName"])
            ?? firstString(parent, keys: ["groupName"])
            ?? "\(appName.uppercased()) • \(totalCount) gói"
        let trialBadge = firstString(product, keys: ["trialBadge"])
            ?? trialText
            ?? (hasDiscount ? "GIẢM KỲ ĐẦU" : nil)

        return IAPItem(
            id: id,
            appName: appName,
            appBundleId: bundleID,
            appIconSystem: appIconSystem,
            title: title,
            formattedPrice: price,
            rawPrice: numeric,
            isFree: numeric == 0,
            isTrial: hasTrial,
            trialBadge: trialBadge,
            isHidden: isHidden,
            subtitle: subtitle,
            isStarred: favoriteIDs.contains(id),
            groupName: groupName,
            family: family,
            offerId: offerID,
            storeCountry: storeCountry,
            productNumber: productNumber
        )
    }

    private func normalizedDictionaries(_ value: Any) -> [[String: Any]] {
        if let array = value as? [[String: Any]] { return array }
        if let array = value as? [Any] { return array.compactMap { $0 as? [String: Any] } }
        if let map = value as? [String: Any] {
            let productKeys = ["productId", "productID", "productIdentifier", "product_id", "identifier", "id"]
            if firstString(map, keys: productKeys) != nil {
                return [map]
            }
            return map.compactMap { key, value in
                guard var dictionary = value as? [String: Any] else { return nil }
                if firstString(dictionary, keys: productKeys) == nil { dictionary["productId"] = key }
                return dictionary
            }
        }
        return []
    }

    private func normalizedOfferDictionaries(_ value: Any) -> [[String: Any]] {
        if let array = value as? [[String: Any]] { return array }
        if let array = value as? [Any] { return array.compactMap { $0 as? [String: Any] } }
        if let dictionary = value as? [String: Any] {
            let offerKeys = ["offerId", "offerID", "offerIdentifier", "classification", "offerType", "trialPeriod", "discountPrice", "introductoryPrice"]
            if firstString(dictionary, keys: offerKeys) != nil || dictionary["pricingPhases"] != nil || dictionary["phases"] != nil {
                return [dictionary]
            }
            return dictionary.compactMap { key, value in
                guard var offer = value as? [String: Any] else { return nil }
                if firstString(offer, keys: ["offerId", "offerID", "offerIdentifier"]) == nil {
                    offer["offerId"] = key
                }
                return offer
            }
        }
        return []
    }

    private func normalizedOffers(_ product: [String: Any]) -> [[String: Any]] {
        var offers: [[String: Any]] = []
        for key in ["offers", "discounts", "subscriptionOffers", "introductoryOffers", "subscriptionOffer", "discount"] {
            if let value = product[key] { offers.append(contentsOf: normalizedOfferDictionaries(value)) }
        }
        if let offer = product["introductoryOffer"] as? [String: Any] { offers.append(offer) }
        if let offer = product["introOffer"] as? [String: Any] { offers.append(offer) }
        return offers
    }

    private func offerClassification(_ offer: [String: Any]) -> String {
        let explicit = firstString(offer, keys: ["classification", "offerType", "type", "kind"])?.uppercased() ?? ""
        if explicit.contains("TRIAL") || explicit.contains("FREE") { return "FREE_TRIAL" }
        if explicit.contains("INTRO") || explicit.contains("DISCOUNT") || explicit.contains("PROMO") { return "INTRO_DISCOUNT" }
        if firstValue(offer, keys: ["trialPeriod", "freeTrialPeriod"]) != nil { return "FREE_TRIAL" }
        if firstValue(offer, keys: ["discountPrice", "introductoryPrice", "introPrice"]) != nil { return "INTRO_DISCOUNT" }
        return "REGULAR"
    }

    private func firstValue(_ dictionary: [String: Any], keys: [String]) -> Any? {
        for key in keys where dictionary[key] != nil { return dictionary[key] }
        return nil
    }

    private func firstString(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let string = dictionary[key] as? String, !string.isEmpty { return string }
            if let number = dictionary[key] as? NSNumber { return number.stringValue }
        }
        return nil
    }

    private func firstBool(_ dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dictionary[key] as? Bool { return value }
            if let number = dictionary[key] as? NSNumber { return number.boolValue }
            if let string = dictionary[key] as? String {
                if ["true", "yes", "1"].contains(string.lowercased()) { return true }
                if ["false", "no", "0"].contains(string.lowercased()) { return false }
            }
        }
        return nil
    }

    private func firstInt(_ dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? Int { return value }
            if let number = dictionary[key] as? NSNumber { return number.intValue }
            if let string = dictionary[key] as? String, let value = Int(string) { return value }
        }
        return nil
    }

    private func firstDictionary(_ dictionary: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = dictionary[key] as? [String: Any] { return value }
            if let value = dictionary[key] as? [[String: Any]], let first = value.first { return first }
        }
        return nil
    }

    private func formattedNumericPrice(_ value: Any?) -> String? {
        guard let number = value as? NSNumber else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: number)
    }

    private func numericPrice(_ value: Any?, formatted: String) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        let digits = formatted.filter(\.isNumber)
        guard !digits.isEmpty else { return 0 }
        // StoreKit exports often use a localized thousands separator, for
        // example "179.000đ". Treating all digits as the minor-unit value
        // preserves the displayed VND amount instead of producing 179.
        return Double(digits) ?? 0
    }

    private func fetchAppMetadata(bundleID: String) {
        guard metadataTasks[bundleID] == nil else { return }
        guard var components = URLComponents(string: "https://itunes.apple.com/lookup") else { return }
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "vn")
        ]
        guard let url = components.url else { return }
        addLog(tag: "AppStore", message: "Tra cứu metadata \(bundleID)")
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { self.metadataTasks[bundleID] = nil }
            guard let data,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let first = (object["results"] as? [[String: Any]])?.first else { return }
            let name = first["trackName"] as? String
            let iconString = first["artworkUrl100"] as? String
            let iconURL = iconString.flatMap(URL.init(string:))
            DispatchQueue.main.async {
                self.items = self.items.map { item in
                    guard item.appBundleId == bundleID else { return item }
                    return self.replacing(item, appName: name ?? item.appName, appIconURL: iconURL)
                }
            }
        }
        metadataTasks[bundleID] = task
        task.resume()
    }

    private func applyFavorite(_ item: IAPItem) -> IAPItem {
        replacing(item, isStarred: favoriteIDs.contains(item.id))
    }

    private func replacing(
        _ item: IAPItem,
        appName: String? = nil,
        appIconURL: URL? = nil,
        title: String? = nil,
        formattedPrice: String? = nil,
        rawPrice: Double? = nil,
        isStarred: Bool? = nil
    ) -> IAPItem {
        IAPItem(
            id: item.id,
            appName: appName ?? item.appName,
            appBundleId: item.appBundleId,
            appIconSystem: item.appIconSystem,
            appIconURL: appIconURL ?? item.appIconURL,
            title: title ?? item.title,
            formattedPrice: formattedPrice ?? item.formattedPrice,
            rawPrice: rawPrice ?? item.rawPrice,
            isFree: item.isFree,
            isTrial: item.isTrial,
            trialBadge: item.trialBadge,
            isHidden: item.isHidden,
            subtitle: item.subtitle,
            isStarred: isStarred ?? item.isStarred,
            groupName: item.groupName,
            family: item.family,
            offerId: item.offerId,
            storeCountry: item.storeCountry,
            productNumber: item.productNumber,
            isPlaceholder: item.isPlaceholder
        )
    }

    private func complete(
        _ result: Result<Void, IAPError>,
        _ completion: @escaping (Result<Void, IAPError>) -> Void,
        message: String? = nil,
        level: String = "INFO"
    ) {
        DispatchQueue.main.async {
            self.isProcessing = false
            if let message { self.addLog(level: level, tag: "Purchase", message: message) }
            completion(result)
        }
    }

    private func friendlyName(for bundleID: String) -> String {
        let lower = bundleID.lowercased()
        if lower.contains("lemon") || lower.contains("capcut") { return "CapCut" }
        if lower.contains("openai") { return "ChatGPT" }
        if lower.contains("duolingo") { return "Duolingo" }
        if lower.contains("canva") { return "Canva" }
        if lower.contains("adobe") { return "Adobe Lightroom" }
        if lower.contains("telegram") { return "Telegram Messenger" }
        return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }

    private func icon(for bundleID: String) -> String {
        let lower = bundleID.lowercased()
        if lower.contains("lemon") || lower.contains("capcut") { return "video.fill" }
        if lower.contains("openai") { return "bubble.left.and.bubble.right.fill" }
        if lower.contains("duolingo") { return "bird.fill" }
        if lower.contains("canva") { return "paintpalette.fill" }
        if lower.contains("adobe") { return "photo.fill" }
        if lower.contains("telegram") { return "paperplane.fill" }
        return "app.fill"
    }

    private func periodLabel(_ type: String) -> String { type == "SUBS" ? "1 tháng" : "một lần" }

    private func formatPeriod(_ period: String, count: Int) -> String {
        let value = max(1, Int(period.filter(\.isNumber)) ?? 1) * max(1, count)
        let upper = period.uppercased()
        if upper.contains("D") { return "\(value) ngày" }
        if upper.contains("W") { return "\(value * 7) ngày" }
        if upper.contains("Y") { return "\(value) năm" }
        return "\(value) tháng"
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
