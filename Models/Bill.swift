import Foundation

/// 账单
struct Bill: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Decimal                 // 金额
    var paymentMethodId: UUID           // 支付方式ID
    var categoryIds: [UUID]             // 账单类型ID列表
    var ownerId: UUID                   // 归属人ID
    var note: String?                   // 备注
    var createdAt: Date                 // 创建时间
    var updatedAt: Date                 // 更新时间
    
    init(id: UUID = UUID(),
         amount: Decimal,
         paymentMethodId: UUID,
         categoryIds: [UUID],
         ownerId: UUID,
         note: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.amount = amount
        self.paymentMethodId = paymentMethodId
        self.categoryIds = categoryIds
        self.ownerId = ownerId
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
