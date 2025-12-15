import Foundation
import StoreKit
import Combine

/// IAP 产品标识符
enum IAPProduct: String, CaseIterable {
    case annualSubscription = "com.expensetracker.pro.annual"
    case lifetimePurchase = "com.expensetracker.pro.lifetime"
    
    var displayName: String {
        switch self {
        case .annualSubscription: return "年订阅"
        case .lifetimePurchase: return "终身买断"
        }
    }
    
    var displayPrice: String {
        switch self {
        case .annualSubscription: return "¥12/年"
        case .lifetimePurchase: return "¥40"
        }
    }
    
    var description: String {
        switch self {
        case .annualSubscription: return "自动续订，随时取消"
        case .lifetimePurchase: return "一次购买，永久使用"
        }
    }
}

/// IAP 管理器
/// 负责处理应用内购买流程、产品查询和购买验证
@MainActor
class IAPManager: NSObject, ObservableObject {
    static let shared = IAPManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private override init() {
        super.init()
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    /// 加载可用产品
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = IAPProduct.allCases.map { $0.rawValue }
            print("🔍 尝试加载产品 IDs: \(productIDs)")
            
            products = try await Product.products(for: productIDs)
            
            print("✅ 成功加载了 \(products.count) 个产品")
            for product in products {
                print("📦 产品: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
            
            // 检查缺失的产品
            let loadedIDs = Set(products.map { $0.id })
            let requestedIDs = Set(productIDs)
            let missingIDs = requestedIDs.subtracting(loadedIDs)
            
            if !missingIDs.isEmpty {
                print("⚠️ 未找到的产品: \(missingIDs)")
                errorMessage = "测试模式：部分产品未在 StoreKit 配置中找到"
            }
            
        } catch {
            errorMessage = "产品加载失败: \(error.localizedDescription)"
            print("❌ 加载产品失败: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    /// 购买产品
    /// - Parameter product: 要购买的产品
    /// - Returns: 购买是否成功
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 验证购买
                let transaction = try checkVerified(verification)
                
                // 更新购买状态
                await updatePurchasedProducts()
                
                // 完成交易
                await transaction.finish()
                
                print("✅ 购买成功: \(product.id)")
                isLoading = false
                return true
                
            case .userCancelled:
                print("⚠️ 用户取消购买")
                isLoading = false
                return false
                
            case .pending:
                print("⏳ 购买待处理")
                isLoading = false
                return false
                
            @unknown default:
                print("❌ 未知购买结果")
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "购买失败: \(error.localizedDescription)"
            print("❌ 购买失败: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    /// 恢复购买
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            
            if purchasedProductIDs.isEmpty {
                errorMessage = "未找到可恢复的购买"
                print("⚠️ 未找到可恢复的购买")
                isLoading = false
                return false
            }
            
            print("✅ 恢复购买成功")
            isLoading = false
            return true
        } catch {
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
            print("❌ 恢复购买失败: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Transaction Listener
    
    /// 监听交易更新
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("❌ 交易验证失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - Update Purchased Products
    
    /// 更新已购买产品列表
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 检查订阅是否过期
                if let expirationDate = transaction.expirationDate,
                   expirationDate < Date() {
                    continue
                }
                
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("❌ 验证交易失败: \(error)")
            }
        }
        
        purchasedProductIDs = purchasedIDs
        print("📦 已购买产品: \(purchasedIDs)")
    }
    
    // MARK: - Verification
    
    /// 验证交易
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IAPError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Product Helpers
    
    /// 获取产品
    func product(for productID: IAPProduct) -> Product? {
        products.first { $0.id == productID.rawValue }
    }
    
    /// 检查是否已购买
    func isPurchased(_ productID: IAPProduct) -> Bool {
        purchasedProductIDs.contains(productID.rawValue)
    }
}

// MARK: - IAP Errors

enum IAPError: Error, LocalizedError {
    case verificationFailed
    case productNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "购买验证失败"
        case .productNotFound:
            return "产品不存在"
        case .purchaseFailed:
            return "购买失败"
        }
    }
}
