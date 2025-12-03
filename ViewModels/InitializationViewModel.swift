import Foundation
import Combine

/// 初始化管理ViewModel
/// 负责清除所有数据并初始化基础数据
@MainActor
class InitializationViewModel: ObservableObject {
    @Published var isInitializing: Bool = false
    @Published var errorMessage: String?
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    /// 初始化系统数据
    /// 清除所有现有数据并创建基础数据
    func initializeData() async throws {
        isInitializing = true
        errorMessage = nil
        
        do {
            // 1. 直接清空数据库（使用 SQL DELETE）
            print("🔄 开始清空数据库...")
            try await clearDatabaseDirectly()
            print("✅ 数据库清空完成")
            
            // 2. 初始化账单类型
            print("🔄 开始初始化账单类型...")
            try await initializeCategories()
            print("✅ 账单类型初始化完成")
            
            // 3. 初始化归属人
            print("🔄 开始初始化归属人...")
            try await initializeOwners()
            print("✅ 归属人初始化完成")
            
            // 4. 初始化支付方式
            print("🔄 开始初始化支付方式...")
            try await initializePaymentMethods()
            print("✅ 支付方式初始化完成")
            
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
            throw error
        }
        
        isInitializing = false
    }
    
    // MARK: - Private Methods
    
    /// 直接清空数据库（使用 SQL DELETE）
    private func clearDatabaseDirectly() async throws {
        // 如果 repository 是 SQLiteRepository，使用 SQL 直接删除
        if let sqliteRepo = repository as? SQLiteRepository {
            try await sqliteRepo.clearAllTables()
        } else {
            // 否则使用传统方法
            try await clearAllData()
        }
    }
    
    /// 清除所有数据
    private func clearAllData() async throws {
        do {
            // 获取所有数据
            let bills = try await repository.fetchBills()
            let paymentMethods = try await repository.fetchPaymentMethods()
            let categories = try await repository.fetchCategories()
            let owners = try await repository.fetchOwners()
            
            // 按照外键依赖顺序删除
            // 1. 先删除账单（依赖支付方式和归属人）
            for bill in bills {
                try await repository.deleteBill(bill)
            }
            
            // 2. 删除支付方式（依赖归属人）
            for method in paymentMethods {
                try await repository.deletePaymentMethod(method)
            }
            
            // 3. 删除账单类型（无依赖）
            for category in categories {
                try await repository.deleteCategory(category)
            }
            
            // 4. 最后删除归属人（被支付方式依赖）
            for owner in owners {
                try await repository.deleteOwner(owner)
            }
        } catch {
            // 如果是空数据库，忽略错误继续
            print("⚠️ 清除数据时出错（可能是空数据库）: \(error)")
        }
    }
    
    /// 初始化账单类型
    private func initializeCategories() async throws {
        // 支出类型
        let expenseCategories = [
            "衣", "食", "住", "行", "教育", "医疗", "娱乐", "保险",
            "购物", "燃气", "水费", "话费", "电费", "人情", "其他"
        ]
        
        for name in expenseCategories {
            let category = BillCategory(name: name, transactionType: .expense)
            print("  📝 保存支出分类: \(name), ID: \(category.id)")
            try await repository.saveCategory(category)
        }
        
        // 收入类型
        let incomeCategories = ["工资", "其他"]
        
        for name in incomeCategories {
            let category = BillCategory(name: name, transactionType: .income)
            try await repository.saveCategory(category)
        }
        
        // 不计入类型
        let excludedCategories = ["还信用卡"]
        
        for name in excludedCategories {
            let category = BillCategory(name: name, transactionType: .excluded)
            try await repository.saveCategory(category)
        }
    }
    
    /// 初始化归属人
    private func initializeOwners() async throws {
        let ownerNames = ["男主", "女主", "公主", "少主"]
        
        for name in ownerNames {
            let owner = Owner(name: name)
            try await repository.saveOwner(owner)
        }
    }
    
    /// 初始化支付方式
    private func initializePaymentMethods() async throws {
        // 获取归属人列表
        let owners = try await repository.fetchOwners()
        print("📋 获取到 \(owners.count) 个归属人")
        
        // 找到"男主"和"女主"
        guard let maleOwner = owners.first(where: { $0.name == "男主" }),
              let femaleOwner = owners.first(where: { $0.name == "女主" }) else {
            print("❌ 未找到男主或女主")
            throw AppError.missingOwner
        }
        
        print("✅ 找到男主: \(maleOwner.id), 女主: \(femaleOwner.id)")
        
        // 为"男主"和"女主"各创建一套支付方式
        let targetOwners = [maleOwner, femaleOwner]
        
        for owner in targetOwners {
            print("🔄 为 \(owner.name) 创建支付方式...")
            
            // 信贷方式
            let creditMethods = [
                "花呗", "白条", "招商信用卡", "广发信用卡",
                "兴业信用卡", "农行信用卡", "光大信用卡"
            ]
            
            for name in creditMethods {
                let method = CreditMethod(
                    name: "\(owner.name)-\(name)",
                    transactionType: .expense,
                    creditLimit: 10000,
                    outstandingBalance: 0,
                    billingDate: 1,
                    ownerId: owner.id
                )
                print("  💳 保存信贷: \(method.name)")
                try await repository.savePaymentMethod(.credit(method))
            }
            
            // 储蓄方式
            let savingsMethods = ["微信零钱", "余额宝"]
            
            for name in savingsMethods {
                let method = SavingsMethod(
                    name: "\(owner.name)-\(name)",
                    transactionType: .expense,
                    balance: 0,
                    ownerId: owner.id
                )
                print("  💰 保存储蓄: \(method.name)")
                try await repository.savePaymentMethod(.savings(method))
            }
        }
    }
}
