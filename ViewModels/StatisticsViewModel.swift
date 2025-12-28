import Foundation
import Combine

/// 统计分析ViewModel
/// 负责计算收支统计、按不同维度聚合数据
@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var totalIncome: Decimal = 0
    @Published var totalExpense: Decimal = 0
    @Published var categoryStatistics: [String: [TransactionType: Decimal]] = [:]
    @Published var ownerStatistics: [String: [TransactionType: Decimal]] = [:]
    @Published var paymentMethodStatistics: [String: [TransactionType: Decimal]] = [:]
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    // 存储筛选后的账单和相关数据，用于详情查看
    private(set) var filteredBills: [Bill] = []
    private(set) var categories: [BillCategory] = []
    private(set) var owners: [Owner] = []
    private(set) var paymentMethods: [PaymentMethodWrapper] = []
    
    let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    /// 获取按类型筛选的账单
    func getBillsForCategory(name: String, transactionType: TransactionType) -> [Bill] {
        let categoryIds = categories.filter { $0.name == name }.map { $0.id }
        return filteredBills.filter { bill in
            // 检查账单是否包含该类型
            let hasCategory = !Set(bill.categoryIds).isDisjoint(with: Set(categoryIds))
            guard hasCategory else { return false }
            
            // 检查交易类型
            let billCategories = bill.categoryIds.compactMap { id in
                categories.first(where: { $0.id == id })
            }
            let isExcluded = !billCategories.isEmpty && billCategories.allSatisfy { $0.transactionType == .excluded }
            
            let actualType: TransactionType
            if isExcluded {
                actualType = .excluded
            } else if bill.amount > 0 {
                actualType = .income
            } else {
                actualType = .expense
            }
            
            return actualType == transactionType
        }
    }
    
    /// 获取按归属人筛选的账单
    func getBillsForOwner(name: String, transactionType: TransactionType) -> [Bill] {
        let ownerIds = owners.filter { $0.name == name }.map { $0.id }
        return filteredBills.filter { bill in
            guard ownerIds.contains(bill.ownerId) else { return false }
            
            // 检查交易类型
            let billCategories = bill.categoryIds.compactMap { id in
                categories.first(where: { $0.id == id })
            }
            let isExcluded = !billCategories.isEmpty && billCategories.allSatisfy { $0.transactionType == .excluded }
            
            let actualType: TransactionType
            if isExcluded {
                actualType = .excluded
            } else if bill.amount > 0 {
                actualType = .income
            } else {
                actualType = .expense
            }
            
            return actualType == transactionType
        }
    }
    
    /// 获取按支付方式筛选的账单
    func getBillsForPaymentMethod(displayName: String, transactionType: TransactionType) -> [Bill] {
        // displayName 格式为 "归属人-支付方式名称"
        return filteredBills.filter { bill in
            let ownerName = owners.first(where: { $0.id == bill.ownerId })?.name ?? "未知"
            let paymentMethod = paymentMethods.first(where: { $0.id == bill.paymentMethodId })
            let paymentMethodName = paymentMethod?.name ?? "未知支付方式"
            let billDisplayName = "\(ownerName)-\(paymentMethodName)"
            
            guard billDisplayName == displayName else { return false }
            
            // 检查交易类型
            let billCategories = bill.categoryIds.compactMap { id in
                categories.first(where: { $0.id == id })
            }
            let isExcluded = !billCategories.isEmpty && billCategories.allSatisfy { $0.transactionType == .excluded }
            
            let actualType: TransactionType
            if isExcluded {
                actualType = .excluded
            } else if bill.amount > 0 {
                actualType = .income
            } else {
                actualType = .expense
            }
            
            return actualType == transactionType
        }
    }
    
    // MARK: - Statistics Calculation
    
    /// 计算统计数据
    /// - Parameters:
    ///   - startDate: 开始日期（可选）
    ///   - endDate: 结束日期（可选）
    func calculateStatistics(startDate: Date? = nil, endDate: Date? = nil) async {
        isLoading = true
        errorMessage = nil
        
        // 重置统计数据以防出错
        totalIncome = 0
        totalExpense = 0
        categoryStatistics = [:]
        ownerStatistics = [:]
        paymentMethodStatistics = [:]
        filteredBills = []
        
        do {
            // 获取所有数据
            var bills = try await repository.fetchBills()
            categories = try await repository.fetchCategories()
            owners = try await repository.fetchOwners()
            paymentMethods = try await repository.fetchPaymentMethods()
            
            // 筛选时间范围
            if let startDate = startDate {
                bills = bills.filter { $0.createdAt >= startDate }
            }
                       if let endDate = endDate {
                bills = bills.filter { $0.createdAt <= endDate }
            }
            
            // 保存筛选后的账单
            filteredBills = bills
            
            // 创建字典以便快速查找
            let categoryDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            let ownerDict = Dictionary(uniqueKeysWithValues: owners.map { ($0.id, $0.name) })
            let paymentMethodDict = Dictionary(uniqueKeysWithValues: paymentMethods.map { ($0.id, $0) })
            
            // 重置统计数据
            var income: Decimal = 0
            var expense: Decimal = 0
            var catStats: [String: [TransactionType: Decimal]] = [:]
            var ownStats: [String: [TransactionType: Decimal]] = [:]
            var pmStats: [String: [TransactionType: Decimal]] = [:]
            
            // 遍历账单计算统计
            for bill in bills {
                guard let paymentMethod = paymentMethodDict[bill.paymentMethodId] else {
                    continue
                }
                
                // 检查账单类型是否为"不计入"
                let billCategories = bill.categoryIds.compactMap { categoryId in
                    categories.first(where: { $0.id == categoryId })
                }
                
                // 如果账单的所有类型都是不计入，则在总览中排除 (Requirement 8.5)
                let isExcluded = !billCategories.isEmpty && billCategories.allSatisfy { $0.transactionType == .excluded }
                
                // 根据账单金额判断实际的交易类型
                // 正数 = 收入，负数 = 支出，不计入类型单独处理
                let actualTransactionType: TransactionType
                if isExcluded {
                    actualTransactionType = .excluded
                } else if bill.amount > 0 {
                    actualTransactionType = .income
                } else {
                    actualTransactionType = .expense
                }
                
                let amount = abs(bill.amount)
                
                if !isExcluded {
                    // 计算总收入和总支出
                    // 账单金额：正数表示收入，负数表示支出
                    if bill.amount > 0 {
                        income += bill.amount
                    } else if bill.amount < 0 {
                        expense += abs(bill.amount)
                    }
                }
                
                // 按账单类型统计 (Requirement 8.2)
                for categoryId in bill.categoryIds {
                    if let categoryName = categoryDict[categoryId] {
                        if catStats[categoryName] == nil {
                            catStats[categoryName] = [:]
                        }
                        catStats[categoryName]?[actualTransactionType, default: 0] += amount
                    }
                }
                
                // 按归属人统计 (Requirement 8.3)
                if let ownerName = ownerDict[bill.ownerId] {
                    if ownStats[ownerName] == nil {
                        ownStats[ownerName] = [:]
                    }
                    ownStats[ownerName]?[actualTransactionType, default: 0] += amount
                }
                
                // 按支付方式统计 (Requirement 8.4)
                // 格式：归属人-支付方式名称
                let ownerName = ownerDict[bill.ownerId] ?? "未知"
                let paymentMethodName = paymentMethod.name.isEmpty ? "未知支付方式" : paymentMethod.name
                let paymentMethodDisplayName = "\(ownerName)-\(paymentMethodName)"
                
                if pmStats[paymentMethodDisplayName] == nil {
                    pmStats[paymentMethodDisplayName] = [:]
                }
                pmStats[paymentMethodDisplayName]?[actualTransactionType, default: 0] += amount
            }
            
            // 更新发布的属性
            totalIncome = income
            totalExpense = expense
            categoryStatistics = catStats
            ownerStatistics = ownStats
            paymentMethodStatistics = pmStats
            
        } catch {
            print("❌ 统计计算失败: \(error)")
            errorMessage = "统计计算失败: \(error.localizedDescription)"
            
            // 确保即使出错也重置为安全状态
            totalIncome = 0
            totalExpense = 0
            categoryStatistics = [:]
            ownerStatistics = [:]
            paymentMethodStatistics = [:]
            filteredBills = []
        }
        
        isLoading = false
    }
}

