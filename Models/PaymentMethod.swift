import Foundation

/// 支付方式协议
protocol PaymentMethod: Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var transactionType: TransactionType { get set }
    var accountType: AccountType { get }
}

/// 信贷方式
struct CreditMethod: PaymentMethod, Codable, Equatable {
    let id: UUID
    var name: String
    var transactionType: TransactionType
    let accountType: AccountType = .credit
    var creditLimit: Decimal           // 信用额度
    var outstandingBalance: Decimal    // 欠费金额
    var billingDate: Int               // 账单日
    
    init(id: UUID = UUID(), 
         name: String, 
         transactionType: TransactionType,
         creditLimit: Decimal,
         outstandingBalance: Decimal,
         billingDate: Int) {
        self.id = id
        self.name = name
        self.transactionType = transactionType
        self.creditLimit = creditLimit
        self.outstandingBalance = outstandingBalance
        self.billingDate = billingDate
    }
}

/// 储蓄方式
struct SavingsMethod: PaymentMethod, Codable, Equatable {
    let id: UUID
    var name: String
    var transactionType: TransactionType
    let accountType: AccountType = .savings
    var balance: Decimal                // 余额
    
    init(id: UUID = UUID(),
         name: String,
         transactionType: TransactionType,
         balance: Decimal) {
        self.id = id
        self.name = name
        self.transactionType = transactionType
        self.balance = balance
    }
}

/// 支付方式包装器 - 用于统一存储和序列化
enum PaymentMethodWrapper: Codable, Equatable {
    case credit(CreditMethod)
    case savings(SavingsMethod)
    
    var id: UUID {
        switch self {
        case .credit(let method): return method.id
        case .savings(let method): return method.id
        }
    }
    
    var name: String {
        get {
            switch self {
            case .credit(let method): return method.name
            case .savings(let method): return method.name
            }
        }
        set {
            switch self {
            case .credit(var method):
                method.name = newValue
                self = .credit(method)
            case .savings(var method):
                method.name = newValue
                self = .savings(method)
            }
        }
    }
    
    var transactionType: TransactionType {
        get {
            switch self {
            case .credit(let method): return method.transactionType
            case .savings(let method): return method.transactionType
            }
        }
        set {
            switch self {
            case .credit(var method):
                method.transactionType = newValue
                self = .credit(method)
            case .savings(var method):
                method.transactionType = newValue
                self = .savings(method)
            }
        }
    }
    
    var accountType: AccountType {
        switch self {
        case .credit(let method): return method.accountType
        case .savings(let method): return method.accountType
        }
    }
}
