import Foundation

/// 账单类型
struct BillCategory: Identifiable, Equatable {
    let id: UUID
    var name: String
    var transactionType: TransactionType
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), name: String, transactionType: TransactionType = .expense, sortOrder: Int = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.transactionType = transactionType
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Codable
extension BillCategory: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case transactionType
        case sortOrder
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // 如果旧数据中没有 transactionType，使用默认值 .expense
        transactionType = try container.decodeIfPresent(TransactionType.self, forKey: .transactionType) ?? .expense
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(transactionType, forKey: .transactionType)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
