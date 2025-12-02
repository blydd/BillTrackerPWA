import Foundation

/// 支付方式协议
protocol PaymentMethod: Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var transactionType: TransactionType { get set }
    var accountType: AccountType { get }
}

/// 信贷方式
struct CreditMethod: PaymentMethod, Equatable {
    let id: UUID
    var name: String
    var transactionType: TransactionType
    var accountType: AccountType { .credit }
    var creditLimit: Decimal           // 信用额度
    var outstandingBalance: Decimal    // 欠费金额
    var billingDate: Int               // 账单日
    var ownerId: UUID                  // 归属人ID
    
    init(id: UUID = UUID(), 
         name: String, 
         transactionType: TransactionType,
         creditLimit: Decimal,
         outstandingBalance: Decimal,
         billingDate: Int,
         ownerId: UUID) {
        self.id = id
        self.name = name
        self.transactionType = transactionType
        self.creditLimit = creditLimit
        self.outstandingBalance = outstandingBalance
        self.billingDate = billingDate
        self.ownerId = ownerId
    }
}

// MARK: - Codable
extension CreditMethod: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, transactionType, creditLimit, outstandingBalance, billingDate, ownerId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        transactionType = try container.decode(TransactionType.self, forKey: .transactionType)
        creditLimit = try container.decode(Decimal.self, forKey: .creditLimit)
        outstandingBalance = try container.decode(Decimal.self, forKey: .outstandingBalance)
        billingDate = try container.decode(Int.self, forKey: .billingDate)
        // 兼容旧数据：如果没有ownerId，使用一个默认值（需要后续手动设置）
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId) ?? UUID()
    }
}

/// 储蓄方式
struct SavingsMethod: PaymentMethod, Equatable {
    let id: UUID
    var name: String
    var transactionType: TransactionType
    var accountType: AccountType { .savings }
    var balance: Decimal                // 余额
    var ownerId: UUID                   // 归属人ID
    
    init(id: UUID = UUID(),
         name: String,
         transactionType: TransactionType,
         balance: Decimal,
         ownerId: UUID) {
        self.id = id
        self.name = name
        self.transactionType = transactionType
        self.balance = balance
        self.ownerId = ownerId
    }
}

// MARK: - Codable
extension SavingsMethod: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, transactionType, balance, ownerId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        transactionType = try container.decode(TransactionType.self, forKey: .transactionType)
        balance = try container.decode(Decimal.self, forKey: .balance)
        // 兼容旧数据：如果没有ownerId，使用一个默认值
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId) ?? UUID()
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
    
    var ownerId: UUID {
        switch self {
        case .credit(let method): return method.ownerId
        case .savings(let method): return method.ownerId
        }
    }
}
