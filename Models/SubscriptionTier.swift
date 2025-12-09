import Foundation

/// 订阅层级
enum SubscriptionTier: String, Codable {
    case free = "free"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free: return "免费版"
        case .pro: return "Pro 版"
        }
    }
    
    /// 账单数量限制
    var billLimit: Int? {
        switch self {
        case .free: return 500
        case .pro: return nil // 无限制
        }
    }
    
    /// 是否支持云同步
    var supportsCloudSync: Bool {
        switch self {
        case .free: return false
        case .pro: return true
        }
    }
    
    /// 是否支持数据导出
    var supportsExport: Bool {
        switch self {
        case .free: return false
        case .pro: return true
        }
    }
}

/// 购买类型
enum PurchaseType: String, Codable {
    case none = "none"
    case annual = "annual"
    case lifetime = "lifetime"
    
    var displayName: String {
        switch self {
        case .none: return "未购买"
        case .annual: return "年订阅"
        case .lifetime: return "终身买断"
        }
    }
}

/// 订阅状态
struct SubscriptionStatus: Codable {
    var tier: SubscriptionTier
    var purchaseType: PurchaseType
    var expirationDate: Date?
    var purchaseDate: Date?
    
    var isActive: Bool {
        switch purchaseType {
        case .none:
            return false
        case .lifetime:
            return true
        case .annual:
            guard let expiration = expirationDate else { return false }
            return expiration > Date()
        }
    }
    
    var displayStatus: String {
        switch purchaseType {
        case .none:
            return "免费版"
        case .lifetime:
            return "终身会员"
        case .annual:
            if let expiration = expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "订阅至 \(formatter.string(from: expiration))"
            }
            return "年订阅"
        }
    }
}
