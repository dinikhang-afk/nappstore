import Foundation

public struct DiffEngine {

    public static func compare(older: ScanSnapshot, newer: ScanSnapshot) -> DiffResult {
        let oldMap = Dictionary(uniqueKeysWithValues: older.products.map { ($0.productId, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: newer.products.map { ($0.productId, $0) })

        let addedProducts = newer.products.filter { oldMap[$0.productId] == nil }
        let removedProducts = older.products.filter { newMap[$0.productId] == nil }

        var modified = [ProductDiffDetail]()
        var summaryChanges = [String]()

        if newer.totalFreeTrials != older.totalFreeTrials {
            summaryChanges.append("Số lượng Trial thay đổi: \(older.totalFreeTrials) ➔ \(newer.totalFreeTrials)")
        }
        if newer.totalDiscounts != older.totalDiscounts {
            summaryChanges.append("Số lượng Discount thay đổi: \(older.totalDiscounts) ➔ \(newer.totalDiscounts)")
        }
        if newer.totalProducts != older.totalProducts {
            summaryChanges.append("Tổng gói sản phẩm: \(older.totalProducts) ➔ \(newer.totalProducts)")
        }

        for (productId, newProd) in newMap {
            guard let oldProd = oldMap[productId] else { continue }

            let oldOfferIds = Set(oldProd.offers.map { $0.offerId ?? $0.summaryText })
            let newOfferIds = Set(newProd.offers.map { $0.offerId ?? $0.summaryText })

            let addedOffers = Array(newOfferIds.subtracting(oldOfferIds))
            let removedOffers = Array(oldOfferIds.subtracting(newOfferIds))

            var notes = [String]()
            if oldProd.formattedBasePrice != newProd.formattedBasePrice {
                notes.append("Giá niêm yết: \(oldProd.formattedBasePrice) ➔ \(newProd.formattedBasePrice)")
            }
            if oldProd.hasFreeTrial != newProd.hasFreeTrial {
                notes.append("Trạng thái Free Trial: \(oldProd.hasFreeTrial ? "Có" : "Không") ➔ \(newProd.hasFreeTrial ? "Có" : "Không")")
            }

            if !addedOffers.isEmpty || !removedOffers.isEmpty || !notes.isEmpty {
                modified.append(
                    ProductDiffDetail(
                        productId: productId,
                        addedOffers: addedOffers,
                        removedOffers: removedOffers,
                        notes: notes
                    )
                )
            }
        }

        return DiffResult(
            addedProducts: addedProducts,
            removedProducts: removedProducts,
            modifiedProducts: modified,
            summaryChanges: summaryChanges
        )
    }
}
