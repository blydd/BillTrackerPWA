import Foundation

/// 基于UserDefaults的数据仓库实现
/// 提供简单的本地持久化存储
class UserDefaultsRepository: DataRepository {
    private let userDefaults: UserDefaults
    
    // Storage keys
    private enum StorageKey: String {
        case bills = "com.expensetracker.bills"
        case paymentMethods = "com.expensetracker.paymentMethods"
        case categories = "com.expensetracker.categories"
        case owners = "com.expensetracker.owners"
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Bill Operations
    
    func saveBill(_ bill: Bill) async throws {
        var bills = try await fetchBills()
        bills.append(bill)
        try saveBills(bills)
    }
    
    func fetchBills() async throws -> [Bill] {
        guard let data = userDefaults.data(forKey: StorageKey.bills.rawValue) else {
            return []
        }
        
        do {
            let bills = try JSONDecoder().decode([Bill].self, from: data)
            return bills
        } catch {
            throw RepositoryError.decodingFailed(error)
        }
    }
    
    func updateBill(_ bill: Bill) async throws {
        var bills = try await fetchBills()
        guard let index = bills.firstIndex(where: { $0.id == bill.id }) else {
            throw RepositoryError.notFound
        }
        bills[index] = bill
        try saveBills(bills)
    }
    
    func deleteBill(_ bill: Bill) async throws {
        var bills = try await fetchBills()
        bills.removeAll { $0.id == bill.id }
        try saveBills(bills)
    }
    
    func fetchBill(by id: UUID) async throws -> Bill? {
        let bills = try await fetchBills()
        return bills.first { $0.id == id }
    }
    
    private func saveBills(_ bills: [Bill]) throws {
        do {
            let data = try JSONEncoder().encode(bills)
            userDefaults.set(data, forKey: StorageKey.bills.rawValue)
        } catch {
            throw RepositoryError.encodingFailed(error)
        }
    }
    
    // MARK: - PaymentMethod Operations
    
    func savePaymentMethod(_ method: PaymentMethodWrapper) async throws {
        var methods = try await fetchPaymentMethods()
        methods.append(method)
        try savePaymentMethods(methods)
    }
    
    func fetchPaymentMethods() async throws -> [PaymentMethodWrapper] {
        guard let data = userDefaults.data(forKey: StorageKey.paymentMethods.rawValue) else {
            return []
        }
        
        do {
            let methods = try JSONDecoder().decode([PaymentMethodWrapper].self, from: data)
            return methods
        } catch {
            throw RepositoryError.decodingFailed(error)
        }
    }
    
    func updatePaymentMethod(_ method: PaymentMethodWrapper) async throws {
        var methods = try await fetchPaymentMethods()
        guard let index = methods.firstIndex(where: { $0.id == method.id }) else {
            throw RepositoryError.notFound
        }
        methods[index] = method
        try savePaymentMethods(methods)
    }
    
    func deletePaymentMethod(_ method: PaymentMethodWrapper) async throws {
        var methods = try await fetchPaymentMethods()
        methods.removeAll { $0.id == method.id }
        try savePaymentMethods(methods)
    }
    
    func fetchPaymentMethod(by id: UUID) async throws -> PaymentMethodWrapper? {
        let methods = try await fetchPaymentMethods()
        return methods.first { $0.id == id }
    }
    
    // MARK: - Specific PaymentMethod Delete Operations
    
    func deleteCreditMethod(id: UUID) async throws {
        var methods = try await fetchPaymentMethods()
        guard let index = methods.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        
        // 确保是信贷方式
        switch methods[index] {
        case .credit:
            methods.remove(at: index)
            try savePaymentMethods(methods)
        case .savings:
            throw RepositoryError.notFound // 不是信贷方式
        }
    }
    
    func deleteSavingsMethod(id: UUID) async throws {
        var methods = try await fetchPaymentMethods()
        guard let index = methods.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        
        // 确保是储蓄方式
        switch methods[index] {
        case .savings:
            methods.remove(at: index)
            try savePaymentMethods(methods)
        case .credit:
            throw RepositoryError.notFound // 不是储蓄方式
        }
    }
    
    private func savePaymentMethods(_ methods: [PaymentMethodWrapper]) throws {
        do {
            let data = try JSONEncoder().encode(methods)
            userDefaults.set(data, forKey: StorageKey.paymentMethods.rawValue)
        } catch {
            throw RepositoryError.encodingFailed(error)
        }
    }
    
    // MARK: - BillCategory Operations
    
    func saveCategory(_ category: BillCategory) async throws {
        var categories = try await fetchCategories()
        categories.append(category)
        try saveCategories(categories)
    }
    
    func fetchCategories() async throws -> [BillCategory] {
        guard let data = userDefaults.data(forKey: StorageKey.categories.rawValue) else {
            return []
        }
        
        do {
            let categories = try JSONDecoder().decode([BillCategory].self, from: data)
            return categories
        } catch {
            throw RepositoryError.decodingFailed(error)
        }
    }
    
    func updateCategory(_ category: BillCategory) async throws {
        var categories = try await fetchCategories()
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            throw RepositoryError.notFound
        }
        categories[index] = category
        try saveCategories(categories)
    }
    
    func deleteCategory(_ category: BillCategory) async throws {
        var categories = try await fetchCategories()
        categories.removeAll { $0.id == category.id }
        try saveCategories(categories)
    }
    
    func fetchCategory(by id: UUID) async throws -> BillCategory? {
        let categories = try await fetchCategories()
        return categories.first { $0.id == id }
    }
    
    private func saveCategories(_ categories: [BillCategory]) throws {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: StorageKey.categories.rawValue)
        } catch {
            throw RepositoryError.encodingFailed(error)
        }
    }
    
    // MARK: - Owner Operations
    
    func saveOwner(_ owner: Owner) async throws {
        var owners = try await fetchOwners()
        owners.append(owner)
        try saveOwners(owners)
    }
    
    func fetchOwners() async throws -> [Owner] {
        guard let data = userDefaults.data(forKey: StorageKey.owners.rawValue) else {
            return []
        }
        
        do {
            let owners = try JSONDecoder().decode([Owner].self, from: data)
            return owners
        } catch {
            throw RepositoryError.decodingFailed(error)
        }
    }
    
    func updateOwner(_ owner: Owner) async throws {
        var owners = try await fetchOwners()
        guard let index = owners.firstIndex(where: { $0.id == owner.id }) else {
            throw RepositoryError.notFound
        }
        owners[index] = owner
        try saveOwners(owners)
    }
    
    func deleteOwner(_ owner: Owner) async throws {
        var owners = try await fetchOwners()
        owners.removeAll { $0.id == owner.id }
        try saveOwners(owners)
    }
    
    func fetchOwner(by id: UUID) async throws -> Owner? {
        let owners = try await fetchOwners()
        return owners.first { $0.id == id }
    }
    
    private func saveOwners(_ owners: [Owner]) throws {
        do {
            let data = try JSONEncoder().encode(owners)
            userDefaults.set(data, forKey: StorageKey.owners.rawValue)
        } catch {
            throw RepositoryError.encodingFailed(error)
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: Error, LocalizedError {
    case notFound
    case encodingFailed(Error)
    case decodingFailed(Error)
    case persistenceFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "数据不存在"
        case .encodingFailed(let error):
            return "数据编码失败: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "数据解码失败: \(error.localizedDescription)"
        case .persistenceFailed(let error):
            return "数据保存失败: \(error.localizedDescription)"
        }
    }
}
