import Foundation

/// 归属人
struct Owner: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), name: String, sortOrder: Int = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
