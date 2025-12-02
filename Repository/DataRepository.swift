import Foundation

/// 数据仓库协议
protocol DataRepository {
    // Bill CRUD operations
    func saveBill(_ bill: Bill) async throws
    func fetchBills() async throws -> [Bill]
    func updateBill(_ bill: Bill) async throws
    func deleteBill(_ bill: Bill) async throws
    func fetchBill(by id: UUID) async throws -> Bill?
    
    // PaymentMethod CRUD operations
    func savePaymentMethod(_ method: PaymentMethodWrapper) async throws
    func fetchPaymentMethods() async throws -> [PaymentMethodWrapper]
    func updatePaymentMethod(_ method: PaymentMethodWrapper) async throws
    func deletePaymentMethod(_ method: PaymentMethodWrapper) async throws
    func fetchPaymentMethod(by id: UUID) async throws -> PaymentMethodWrapper?
    
    // BillCategory CRUD operations
    func saveCategory(_ category: BillCategory) async throws
    func fetchCategories() async throws -> [BillCategory]
    func updateCategory(_ category: BillCategory) async throws
    func deleteCategory(_ category: BillCategory) async throws
    func fetchCategory(by id: UUID) async throws -> BillCategory?
    
    // Owner CRUD operations
    func saveOwner(_ owner: Owner) async throws
    func fetchOwners() async throws -> [Owner]
    func updateOwner(_ owner: Owner) async throws
    func deleteOwner(_ owner: Owner) async throws
    func fetchOwner(by id: UUID) async throws -> Owner?
}
