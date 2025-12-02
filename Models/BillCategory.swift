import Foundation

/// 账单类型
struct BillCategory: Identifiable, Equatable {
    let id: UUID
    var name: String
    var transactionType: TransactionType
    
    init(id: UUID = UUID(), name: String, transactionType: TransactionType = .expense) {
        self.id = id
        self.name = name
        self.transactionType = transactionType
    }
}

// MARK: - Codable
extension BillCategory: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case transactionType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // 如果旧数据中没有 transactionType，使用默认值 .expense
        transactionType = try container.decodeIfPresent(TransactionType.self, forKey: .transactionType) ?? .expense
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(transactionType, forKey: .transactionType)
    }
}
