import Foundation
import Combine
import StoreKit

/// 订阅管理器
/// 负责管理订阅状态、功能权限和本地缓存
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptionStatus: SubscriptionStatus
    @Published var isProUser: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let statusKey = "subscription_status"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 从本地加载订阅状态
        if let data = userDefaults.data(forKey: statusKey),
           let status = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
            self.subscriptionStatus = status
            self.isProUser = status.isActive && status.tier == .pro
        } else {
            // 默认为免费版
            self.subscriptionStatus = SubscriptionStatus(
                tier: .free,
                purchaseType: .none,
                expirationDate: nil,
                purchaseDate: nil
            )
            self.isProUser = false
        }
        
        // 监听 IAP 状态变化
        setupIAPObserver()
    }
    
    // MARK: - Setup
    
    private func setupIAPObserver() {
        IAPManager.shared.$purchasedProductIDs
            .sink { [weak self] purchasedIDs in
                Task { @MainActor in
                    await self?.updateSubscriptionStatus(purchasedIDs: purchasedIDs)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Update Status
    
    /// 更新订阅状态
    func updateSubscriptionStatus(purchasedIDs: Set<String>) async {
        var newStatus = subscriptionStatus
        
        // 检查终身购买
        if purchasedIDs.contains(IAPProduct.lifetimePurchase.rawValue) {
            newStatus.tier = .pro
            newStatus.purchaseType = .lifetime
            newStatus.expirationDate = nil
            if newStatus.purchaseDate == nil {
                newStatus.purchaseDate = Date()
            }
        }
        // 检查年订阅
        else if purchasedIDs.contains(IAPProduct.annualSubscription.rawValue) {
            newStatus.tier = .pro
            newStatus.purchaseType = .annual
            
            // 获取订阅过期时间
            if let expirationDate = await getSubscriptionExpirationDate() {
                newStatus.expirationDate = expirationDate
            } else {
                // 如果无法获取过期时间，默认设置为一年后
                newStatus.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
            }
            
            if newStatus.purchaseDate == nil {
                newStatus.purchaseDate = Date()
            }
        }
        // 没有购买
        else {
            newStatus.tier = .free
            newStatus.purchaseType = .none
            newStatus.expirationDate = nil
        }
        
        // 更新状态
        subscriptionStatus = newStatus
        isProUser = newStatus.isActive && newStatus.tier == .pro
        
        // 保存到本地
        saveSubscriptionStatus()
        
        print("📱 订阅状态更新: \(newStatus.tier.displayName) - \(newStatus.purchaseType.displayName)")
    }
    
    /// 获取订阅过期时间
    private func getSubscriptionExpirationDate() async -> Date? {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == IAPProduct.annualSubscription.rawValue {
                    return transaction.expirationDate
                }
            } catch {
                print("❌ 获取订阅过期时间失败: \(error)")
            }
        }
        return nil
    }
    
    /// 验证交易
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IAPError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Persistence
    
    /// 保存订阅状态到本地
    private func saveSubscriptionStatus() {
        if let data = try? JSONEncoder().encode(subscriptionStatus) {
            userDefaults.set(data, forKey: statusKey)
        }
    }
    
    // MARK: - Feature Gates
    
    /// 检查是否可以创建账单
    /// - Parameter currentBillCount: 当前账单数量
    /// - Returns: 是否可以创建
    func canCreateBill(currentBillCount: Int) -> Bool {
        if isProUser {
            return true
        }
        
        guard let limit = subscriptionStatus.tier.billLimit else {
            return true
        }
        
        return currentBillCount < limit
    }
    
    /// 获取账单限制提示
    /// - Parameter currentBillCount: 当前账单数量
    /// - Returns: 提示信息（如果需要）
    func getBillLimitWarning(currentBillCount: Int) -> String? {
        guard !isProUser else { return nil }
        
        guard let limit = subscriptionStatus.tier.billLimit else {
            return nil
        }
        
        if currentBillCount >= limit {
            return "已达到免费版账单上限（\(limit)条），升级到 Pro 版解锁无限账单"
        } else if currentBillCount >= limit - 50 {
            return "即将达到免费版账单上限（\(currentBillCount)/\(limit)条）"
        }
        
        return nil
    }
    
    /// 检查是否可以使用云同步
    var canUseCloudSync: Bool {
        isProUser && subscriptionStatus.tier.supportsCloudSync
    }
    
    /// 检查是否可以导出数据
    var canExportData: Bool {
        isProUser && subscriptionStatus.tier.supportsExport
    }
    
    // MARK: - Refresh
    
    /// 刷新订阅状态
    func refreshSubscriptionStatus() async {
        await IAPManager.shared.updatePurchasedProducts()
    }
}
