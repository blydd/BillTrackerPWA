import Foundation

/// 应用错误类型定义
enum AppError: Error, LocalizedError {
    case invalidAmount
    case missingPaymentMethod
    case missingCategory
    case missingOwner
    case duplicateName(entityType: String)
    case creditLimitExceeded
    case insufficientBalance
    case invalidCreditLimit
    case dataNotFound
    case ownerMismatch
    case persistenceError(underlying: Error)
    case exportError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "账单金额必须大于0"
        case .missingPaymentMethod:
            return "请选择支付方式"
        case .missingCategory:
            return "请选择至少一个账单类型"
        case .missingOwner:
            return "请选择归属人"
        case .duplicateName(let entityType):
            return "\(entityType)名称已存在"
        case .creditLimitExceeded:
            return "信用额度不足"
        case .insufficientBalance:
            return "余额不足"
        case .invalidCreditLimit:
            return "信用额度必须大于等于初始欠费金额"
        case .dataNotFound:
            return "数据不存在"
        case .ownerMismatch:
            return "信贷方式的归属人与账单归属人不匹配"
        case .persistenceError(let error):
            return "数据保存失败: \(error.localizedDescription)"
        case .exportError(let error):
            return "导出失败: \(error.localizedDescription)"
        }
    }
}
