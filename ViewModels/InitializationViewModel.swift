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
            // 1. 清除所有现有数据
            try await clearAllData()
            
            // 2. 初始化账单类型
            try await initializeCategories()
            
            // 3. 初始化归属人
            try await initializeOwners()
            
            // 4. 初始化支付方式
            try await initializePaymentMethods()
            
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
            throw error
        }
        
        isInitializing = false
    }
    
    // MARK: - Private Methods
    
    /// 清除所有数据
    private func clearAllData() async throws {
        // 获取所有数据
        let bills = try await repository.fetchBills()
        let categories = try await repository.fetchCategories()
        let owners = try await repository.fetchOwners()
        let paymentMethods = try await repository.fetchPaymentMethods()
        
        // 删除所有账单
        for bill in bills {
            try await repository.deleteBill(bill)
        }
        
        // 删除所有账单类型
        for category in categories {
            try await repository.deleteCategory(category)
        }
        
        // 删除所有归属人
        for owner in owners {
            try await repository.deleteOwner(owner)
        }
        
        // 删除所有支付方式
        for method in paymentMethods {
            try await repository.deletePaymentMethod(method)
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
        // 信贷方式
        let creditMethods = [
            "花呗", "白条", "招商信用卡", "广发信用卡",
            "兴业信用卡", "农行信用卡", "光大信用卡"
        ]
        
        for name in creditMethods {
            let method = CreditMethod(
                name: name,
                transactionType: .expense,
                creditLimit: 10000,
                outstandingBalance: 0,
                billingDate: 1
            )
            try await repository.savePaymentMethod(.credit(method))
        }
        
        // 储蓄方式
        let savingsMethods = ["微信零钱", "余额宝"]
        
        for name in savingsMethods {
            let method = SavingsMethod(
                name: name,
                transactionType: .expense,
                balance: 0
            )
            try await repository.savePaymentMethod(.savings(method))
        }
    }
}
