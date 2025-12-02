import Foundation
import Combine

/// 统计分析ViewModel
/// 负责计算收支统计、按不同维度聚合数据
@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var totalIncome: Decimal = 0
    @Published var totalExpense: Decimal = 0
    @Published var categoryStatistics: [String: Decimal] = [:]
    @Published var ownerStatistics: [String: Decimal] = [:]
    @Published var paymentMethodStatistics: [String: Decimal] = [:]
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    // MARK: - Statistics Calculation
    
    /// 计算统计数据
    /// - Parameters:
    ///   - startDate: 开始日期（可选）
    ///   - endDate: 结束日期（可选）
    func calculateStatistics(startDate: Date? = nil, endDate: Date? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 获取所有数据
            var bills = try await repository.fetchBills()
            let categories = try await repository.fetchCategories()
            let owners = try await repository.fetchOwners()
            let paymentMethods = try await repository.fetchPaymentMethods()
            
            // 筛选时间范围
            if let startDate = startDate {
                bills = bills.filter { $0.createdAt >= startDate }
            }
                       if let endDate = endDate {
                bills = bills.filter { $0.createdAt <= endDate }
            }
            
            // 创建字典以便快速查找
            let categoryDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            let ownerDict = Dictionary(uniqueKeysWithValues: owners.map { ($0.id, $0.name) })
            let paymentMethodDict = Dictionary(uniqueKeysWithValues: paymentMethods.map { ($0.id, $0) })
            
            // 重置统计数据
            var income: Decimal = 0
            var expense: Decimal = 0
            var catStats: [String: Decimal] = [:]
            var ownStats: [String: Decimal] = [:]
            var pmStats: [String: Decimal] = [:]
            
            // 遍历账单计算统计
            for bill in bills {
                guard let paymentMethod = paymentMethodDict[bill.paymentMethodId] else {
                    continue
                }
                
                // 排除"不计入"类型 (Requirement 8.5)
                guard paymentMethod.transactionType != .excluded else {
                    continue
                }
                
                // 计算总收入和总支出
                switch paymentMethod.transactionType {
                case .income:
                    income += bill.amount
                case .expense:
                    expense += bill.amount
                case .excluded:
                    break
                }
                
                // 按账单类型统计 (Requirement 8.2)
                for categoryId in bill.categoryIds {
                    if let categoryName = categoryDict[categoryId] {
                        catStats[categoryName, default: 0] += bill.amount
                    }
                }
                
                // 按归属人统计 (Requirement 8.3)
                if let ownerName = ownerDict[bill.ownerId] {
                    ownStats[ownerName, default: 0] += bill.amount
                }
                
                // 按支付方式统计 (Requirement 8.4)
                pmStats[paymentMethod.name, default: 0] += bill.amount
            }
            
            // 更新发布的属性
            totalIncome = income
            totalExpense = expense
            categoryStatistics = catStats
            ownerStatistics = ownStats
            paymentMethodStatistics = pmStats
            
        } catch {
            errorMessage = "统计计算失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

