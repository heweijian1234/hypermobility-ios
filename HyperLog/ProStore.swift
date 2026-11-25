import Foundation
import StoreKit

// MARK: - Pro 买断（$4.99 一次性，非消耗型）
// 免费：记录、照片、Beighton、本周概览、点柱看当天
// Pro：导出医生报告（PDF/CSV/文本）、照片并排对比、全部记录页

@MainActor
final class ProStore: ObservableObject {

    static let productID = "com.zeronelabs.hyperlog.pro"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published var message: String?

    /// 商店没返回价格时的兜底显示（仅文案，不参与计价）
    var priceText: String {
        product?.displayPrice ?? "$4.99"
    }

    func load() async {
        await refresh()
        do {
            let items = try await Product.products(for: [Self.productID])
            product = items.first
        } catch {
            // 拉不到商品不阻塞使用：已购用户照常解锁，未购用户点了会提示重试
        }
    }

    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID && transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    func purchase() async {
        guard let product else {
            message = L("Product is unavailable right now. Please try again in a moment.")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = L("The purchase could not be verified.")
                    return
                }
                await transaction.finish()
                isPro = true
            case .userCancelled:
                break
            case .pending:
                message = L("The purchase is pending approval.")
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            // 用户中途取消也会走到这里，不当作错误
        }
        await refresh()
        if !isPro {
            message = L("No previous purchase was found for this Apple ID.")
        }
    }
}
