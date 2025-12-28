import Foundation
import Combine
import SwiftUI

/// 支付方式管理ViewModel
/// 负责信贷方式和储蓄方式的创建、编辑、删除和验证
@MainActor
class PaymentMethodViewModel: ObservableObject {
    @Published var paymentMethods: [PaymentMethodWrapper] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    /// 加载所有支付方式
    func loadPaymentMethods() async {
        isLoading = true
        errorMessage = nil
        
        do {
            paymentMethods = try await repository.fetchPaymentMethods()
        } catch {
            errorMessage = "加载支付方式失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Credit Method Operations
    
    /// 创建新的信贷方式
    /// - Parameters:
    ///   - name: 方式名称
    ///   - transactionType: 交易类型
    ///   - creditLimit: 信用额度
    ///   - outstandingBalance: 初始欠费金额
    ///   - billingDate: 账单日
    ///   - ownerId: 归属人ID
    /// - Throws: AppError.invalidCreditLimit 如果信用额度小于初始欠费金额
    func createCreditMethod(
        name: String,
        transactionType: TransactionType,
        creditLimit: Decimal,
        outstandingBalance: Decimal,
        billingDate: Int,
        ownerId: UUID
    ) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw AppError.duplicateName(entityType: "支付方式")
        }
        
        // 验证信用额度必须大于等于初始欠费金额 (Requirement 4.2)
        guard creditLimit >= outstandingBalance else {
            throw AppError.invalidCreditLimit
        }
        
        let creditMethod = CreditMethod(
            name: trimmedName,
            transactionType: transactionType,
            creditLimit: creditLimit,
            outstandingBalance: outstandingBalance,
            billingDate: billingDate,
            ownerId: ownerId
        )
        
        let wrapper = PaymentMethodWrapper.credit(creditMethod)
        
        do {
            try await repository.savePaymentMethod(wrapper)
            paymentMethods.append(wrapper)
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 更新信贷方式
    /// - Parameters:
    ///   - id: 支付方式ID
    ///   - name: 新名称（可选）
    ///   - transactionType: 新交易类型（可选）
    ///   - creditLimit: 新信用额度（可选）
    ///   - billingDate: 新账单日（可选）
    ///   - ownerId: 新归属人ID（可选）
    /// - Throws: AppError.dataNotFound 如果支付方式不存在
    func updateCreditMethod(
        id: UUID,
        name: String? = nil,
        transactionType: TransactionType? = nil,
        creditLimit: Decimal? = nil,
        billingDate: Int? = nil,
        ownerId: UUID? = nil
    ) async throws {
        guard let index = paymentMethods.firstIndex(where: { $0.id == id }),
              case .credit(var creditMethod) = paymentMethods[index] else {
            throw AppError.dataNotFound
        }
        
        // 更新字段
        if let name = name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw AppError.duplicateName(entityType: "支付方式")
            }
            creditMethod.name = trimmedName
        }
        
        if let transactionType = transactionType {
            creditMethod.transactionType = transactionType
        }
        
        if let creditLimit = creditLimit {
            // 验证新的信用额度必须大于等于当前欠费金额
            guard creditLimit >= creditMethod.outstandingBalance else {
                throw AppError.invalidCreditLimit
            }
            creditMethod.creditLimit = creditLimit
        }
        
        if let billingDate = billingDate {
            creditMethod.billingDate = billingDate
        }
        
        if let ownerId = ownerId {
            creditMethod.ownerId = ownerId
        }
        
        let updatedWrapper = PaymentMethodWrapper.credit(creditMethod)
        
        do {
            try await repository.updatePaymentMethod(updatedWrapper)
            paymentMethods[index] = updatedWrapper
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Savings Method Operations
    
    /// 创建新的储蓄方式
    /// - Parameters:
    ///   - name: 方式名称
    ///   - transactionType: 交易类型
    ///   - balance: 初始余额
    ///   - ownerId: 归属人ID
    /// - Throws: AppError.insufficientBalance 如果初始余额为负数
    func createSavingsMethod(
        name: String,
        transactionType: TransactionType,
        balance: Decimal,
        ownerId: UUID
    ) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw AppError.duplicateName(entityType: "支付方式")
        }
        
        // 验证初始余额不能为负数 (Requirement 5.2)
        guard balance >= 0 else {
            throw AppError.insufficientBalance
        }
        
        let savingsMethod = SavingsMethod(
            name: trimmedName,
            transactionType: transactionType,
            balance: balance,
            ownerId: ownerId
        )
        
        let wrapper = PaymentMethodWrapper.savings(savingsMethod)
        
        do {
            try await repository.savePaymentMethod(wrapper)
            paymentMethods.append(wrapper)
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 更新储蓄方式
    /// - Parameters:
    ///   - id: 支付方式ID
    ///   - name: 新名称（可选）
    ///   - transactionType: 新交易类型（可选）
    ///   - ownerId: 新归属人ID（可选）
    /// - Throws: AppError.dataNotFound 如果支付方式不存在
    func updateSavingsMethod(
        id: UUID,
        name: String? = nil,
        transactionType: TransactionType? = nil,
        ownerId: UUID? = nil
    ) async throws {
        guard let index = paymentMethods.firstIndex(where: { $0.id == id }),
              case .savings(var savingsMethod) = paymentMethods[index] else {
            throw AppError.dataNotFound
        }
        
        // 更新字段
        if let name = name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw AppError.duplicateName(entityType: "支付方式")
            }
            savingsMethod.name = trimmedName
        }
        
        if let transactionType = transactionType {
            savingsMethod.transactionType = transactionType
        }
        
        if let ownerId = ownerId {
            savingsMethod.ownerId = ownerId
        }
        
        let updatedWrapper = PaymentMethodWrapper.savings(savingsMethod)
        
        do {
            try await repository.updatePaymentMethod(updatedWrapper)
            paymentMethods[index] = updatedWrapper
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Common Operations
    
    /// 删除支付方式
    /// - Parameter id: 支付方式ID
    /// - Throws: AppError.dataNotFound 如果支付方式仍被账单使用
    /// - Note: 根据需求4.6和5.6，如果支付方式仍被账单使用，应该阻止删除
    func deletePaymentMethod(id: UUID) async throws {
        guard let method = paymentMethods.first(where: { $0.id == id }) else {
            throw AppError.dataNotFound
        }
        
        // 检查是否有账单使用该支付方式
        let bills = try await repository.fetchBills()
        let isUsedByBills = bills.contains(where: { $0.paymentMethodId == id })
        
        if isUsedByBills {
            throw AppError.dataNotFound // 使用dataNotFound表示无法删除
        }
        
        do {
            try await repository.deletePaymentMethod(method)
            paymentMethods.removeAll { $0.id == id }
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取信贷方式列表
    var creditMethods: [CreditMethod] {
        paymentMethods.compactMap { wrapper in
            if case .credit(let method) = wrapper {
                return method
            }
            return nil
        }
    }
    
    /// 获取储蓄方式列表
    var savingsMethods: [SavingsMethod] {
        paymentMethods.compactMap { wrapper in
            if case .savings(let method) = wrapper {
                return method
            }
            return nil
        }
    }
    
    /// 根据ID获取支付方式
    /// - Parameter id: 支付方式ID
    /// - Returns: 支付方式包装器，如果不存在返回nil
    func getPaymentMethod(by id: UUID) -> PaymentMethodWrapper? {
        return paymentMethods.first(where: { $0.id == id })
    }
    
    /// 计算信贷方式的可用额度
    /// - Parameter creditMethod: 信贷方式
    /// - Returns: 可用额度
    func availableCredit(for creditMethod: CreditMethod) -> Decimal {
        return creditMethod.creditLimit - creditMethod.outstandingBalance
    }
    
    // MARK: - Delete Operations
    
    /// 删除信贷方式
    /// - Parameter id: 信贷方式ID
    func deleteCreditMethod(id: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.deleteCreditMethod(id: id)
            await loadPaymentMethods()
        } catch {
            errorMessage = "删除信贷方式失败: \(error.localizedDescription)"
            throw error
        }
        
        isLoading = false
    }
    
    /// 删除储蓄方式
    /// - Parameter id: 储蓄方式ID
    func deleteSavingsMethod(id: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.deleteSavingsMethod(id: id)
            await loadPaymentMethods()
        } catch {
            errorMessage = "删除储蓄方式失败: \(error.localizedDescription)"
            throw error
        }
        
        isLoading = false
    }
    
    /// 移动信贷方式排序
    /// - Parameters:
    ///   - source: 源索引集（基于排序后的数组）
    ///   - destination: 目标索引（基于排序后的数组）
    ///   - ownerId: 归属人ID（用于筛选）
    func moveCreditMethods(from source: IndexSet, to destination: Int, ownerId: UUID?) {
        // 获取筛选后的信贷方式，按 sortOrder 排序
        var filtered: [CreditMethod]
        if let ownerId = ownerId {
            filtered = creditMethods.filter { $0.ownerId == ownerId }
        } else {
            filtered = creditMethods
        }
        filtered.sort { $0.sortOrder < $1.sortOrder }
        
        // 移动
        filtered.move(fromOffsets: source, toOffset: destination)
        
        // 更新 sortOrder 并写回主数组
        for (newIndex, item) in filtered.enumerated() {
            if let mainIndex = paymentMethods.firstIndex(where: { $0.id == item.id }) {
                if case .credit(var method) = paymentMethods[mainIndex] {
                    method.sortOrder = newIndex
                    paymentMethods[mainIndex] = .credit(method)
                }
            }
        }
        
        // 异步保存到数据库
        let itemsToSave = filtered.enumerated().map { (index, item) -> CreditMethod in
            var updated = item
            updated.sortOrder = index
            return updated
        }
        
        Task {
            for item in itemsToSave {
                do {
                    try await repository.updatePaymentMethod(.credit(item))
                } catch {
                    print("更新信贷方式排序失败: \(error)")
                }
            }
        }
    }
    
    /// 移动储蓄方式排序
    /// - Parameters:
    ///   - source: 源索引集（基于排序后的数组）
    ///   - destination: 目标索引（基于排序后的数组）
    ///   - ownerId: 归属人ID（用于筛选）
    func moveSavingsMethods(from source: IndexSet, to destination: Int, ownerId: UUID?) {
        // 获取筛选后的储蓄方式，按 sortOrder 排序
        var filtered: [SavingsMethod]
        if let ownerId = ownerId {
            filtered = savingsMethods.filter { $0.ownerId == ownerId }
        } else {
            filtered = savingsMethods
        }
        filtered.sort { $0.sortOrder < $1.sortOrder }
        
        // 移动
        filtered.move(fromOffsets: source, toOffset: destination)
        
        // 更新 sortOrder 并写回主数组
        for (newIndex, item) in filtered.enumerated() {
            if let mainIndex = paymentMethods.firstIndex(where: { $0.id == item.id }) {
                if case .savings(var method) = paymentMethods[mainIndex] {
                    method.sortOrder = newIndex
                    paymentMethods[mainIndex] = .savings(method)
                }
            }
        }
        
        // 异步保存到数据库
        let itemsToSave = filtered.enumerated().map { (index, item) -> SavingsMethod in
            var updated = item
            updated.sortOrder = index
            return updated
        }
        
        Task {
            for item in itemsToSave {
                do {
                    try await repository.updatePaymentMethod(.savings(item))
                } catch {
                    print("更新储蓄方式排序失败: \(error)")
                }
            }
        }
    }
}
