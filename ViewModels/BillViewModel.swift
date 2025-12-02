import Foundation
import Combine

/// 账单管理ViewModel
/// 负责账单的创建、编辑、删除和验证，以及支付方式余额的自动更新
@MainActor
class BillViewModel: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    /// 加载所有账单
    func loadBills() async {
        isLoading = true
        errorMessage = nil
        
        do {
            bills = try await repository.fetchBills()
        } catch {
            errorMessage = "加载账单失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Bill Filtering
    
    /// 筛选账单
    /// - Parameters:
    ///   - categoryIds: 账单类型ID列表（可选）
    ///   - ownerIds: 归属人ID列表（可选）
    ///   - paymentMethodIds: 支付方式ID列表（可选）
    ///   - startDate: 开始日期（可选）
    ///   - endDate: 结束日期（可选）
    /// - Returns: 符合筛选条件的账单列表
    /// - Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6
    func filterBills(
        categoryIds: [UUID]? = nil,
        ownerIds: [UUID]? = nil,
        paymentMethodIds: [UUID]? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [Bill] {
        var filteredBills = bills
        
        // 按账单类型筛选 (Requirement 7.1)
        // 返回包含任一所选类型的所有账单记录
        if let categoryIds = categoryIds, !categoryIds.isEmpty {
            filteredBills = filteredBills.filter { bill in
                // 账单的类型列表中包含任一所选类型
                !Set(bill.categoryIds).isDisjoint(with: Set(categoryIds))
            }
        }
        
        // 按归属人筛选 (Requirement 7.2)
        // 返回任一所选归属人的所有账单记录
        if let ownerIds = ownerIds, !ownerIds.isEmpty {
            filteredBills = filteredBills.filter { bill in
                ownerIds.contains(bill.ownerId)
            }
        }
        
        // 按支付方式筛选 (Requirement 7.3)
        // 返回使用任一所选支付方式的所有账单记录
        if let paymentMethodIds = paymentMethodIds, !paymentMethodIds.isEmpty {
            filteredBills = filteredBills.filter { bill in
                paymentMethodIds.contains(bill.paymentMethodId)
            }
        }
        
        // 按时间范围筛选 (Requirement 7.4)
        // 返回账单时间在指定时间段内的所有账单记录
        if let startDate = startDate {
            filteredBills = filteredBills.filter { bill in
                bill.createdAt >= startDate
            }
        }
        
        if let endDate = endDate {
            filteredBills = filteredBills.filter { bill in
                bill.createdAt <= endDate
            }
        }
        
        // Requirement 7.5: 组合多个筛选条件时，返回同时满足所有条件的账单记录
        // 上述实现通过链式filter实现了AND逻辑
        
        // Requirement 7.6: 筛选结果为空时，返回空数组（不抛出错误）
        return filteredBills
    }
    
    // MARK: - Bill Creation
    
    /// 创建新账单
    /// - Parameters:
    ///   - amount: 账单金额
    ///   - paymentMethodId: 支付方式ID
    ///   - categoryIds: 账单类型ID列表
    ///   - ownerId: 归属人ID
    ///   - note: 备注（可选）
    /// - Throws: AppError 如果验证失败或保存失败
    /// - Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
    func createBill(
        amount: Decimal,
        paymentMethodId: UUID,
        categoryIds: [UUID],
        ownerId: UUID,
        note: String? = nil
    ) async throws {
        // 验证金额必须大于0 (Requirement 1.2)
        guard amount > 0 else {
            throw AppError.invalidAmount
        }
        
        // 验证必须选择支付方式 (Requirement 1.3)
        guard try await repository.fetchPaymentMethod(by: paymentMethodId) != nil else {
            throw AppError.missingPaymentMethod
        }
        
        // 验证必须选择至少一个账单类型 (Requirement 1.4)
        guard !categoryIds.isEmpty else {
            throw AppError.missingCategory
        }
        
        // 验证必须选择归属人 (Requirement 1.5)
        guard try await repository.fetchOwner(by: ownerId) != nil else {
            throw AppError.missingOwner
        }
        
        // 获取支付方式以确定交易类型
        guard let paymentMethod = try await repository.fetchPaymentMethod(by: paymentMethodId) else {
            throw AppError.missingPaymentMethod
        }
        
        // 在创建账单前，先更新支付方式余额（如果不是"不计入"类型）
        // Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
        if paymentMethod.transactionType != .excluded {
            try await updatePaymentMethodBalance(
                paymentMethod: paymentMethod,
                amount: amount,
                isCreating: true
            )
        }
        
        // 创建账单，自动记录时间戳 (Requirement 1.6)
        let now = Date()
        let bill = Bill(
            amount: amount,
            paymentMethodId: paymentMethodId,
            categoryIds: categoryIds,
            ownerId: ownerId,
            note: note,
            createdAt: now,
            updatedAt: now
        )
        
        do {
            try await repository.saveBill(bill)
            bills.append(bill)
        } catch {
            // 如果保存失败，需要回滚余额更新
            if paymentMethod.transactionType != .excluded {
                try? await updatePaymentMethodBalance(
                    paymentMethod: paymentMethod,
                    amount: -amount,
                    isCreating: true
                )
            }
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 创建不计入类型的账单（更新支付方式余额但不参与统计）
    /// - Parameters:
    ///   - amount: 账单金额（可以为负数）
    ///   - paymentMethodId: 支付方式ID
    ///   - categoryIds: 账单类型ID列表
    ///   - ownerId: 归属人ID
    ///   - note: 备注（可选）
    /// - Throws: AppError 如果验证失败或保存失败
    func createBillWithExcludedType(
        amount: Decimal,
        paymentMethodId: UUID,
        categoryIds: [UUID],
        ownerId: UUID,
        note: String? = nil
    ) async throws {
        // 验证金额不能为0
        guard amount != 0 else {
            throw AppError.invalidAmount
        }
        
        // 验证必须选择支付方式
        guard let paymentMethod = try await repository.fetchPaymentMethod(by: paymentMethodId) else {
            throw AppError.missingPaymentMethod
        }
        
        // 验证必须选择至少一个账单类型
        guard !categoryIds.isEmpty else {
            throw AppError.missingCategory
        }
        
        // 验证必须选择归属人
        guard try await repository.fetchOwner(by: ownerId) != nil else {
            throw AppError.missingOwner
        }
        
        // 更新支付方式余额
        var updatedMethod = paymentMethod
        
        switch paymentMethod {
        case .credit(var creditMethod):
            // 信贷方式：正数增加欠费，负数减少欠费
            let newBalance = creditMethod.outstandingBalance + amount
            
            // 检查是否超过信用额度
            if newBalance > creditMethod.creditLimit {
                throw AppError.creditLimitExceeded
            }
            
            // 确保欠费不为负数
            creditMethod.outstandingBalance = max(0, newBalance)
            updatedMethod = .credit(creditMethod)
            
        case .savings(var savingsMethod):
            // 储蓄方式：正数减少余额，负数增加余额
            savingsMethod.balance -= amount
            updatedMethod = .savings(savingsMethod)
        }
        
        // 保存更新后的支付方式
        try await repository.updatePaymentMethod(updatedMethod)
        
        // 创建账单
        let now = Date()
        let bill = Bill(
            amount: amount,
            paymentMethodId: paymentMethodId,
            categoryIds: categoryIds,
            ownerId: ownerId,
            note: note,
            createdAt: now,
            updatedAt: now
        )
        
        do {
            try await repository.saveBill(bill)
            bills.append(bill)
        } catch {
            // 如果保存失败，回滚余额更新
            switch paymentMethod {
            case .credit(var creditMethod):
                creditMethod.outstandingBalance = max(0, creditMethod.outstandingBalance - amount)
                try? await repository.updatePaymentMethod(.credit(creditMethod))
                
            case .savings(var savingsMethod):
                savingsMethod.balance += amount
                try? await repository.updatePaymentMethod(.savings(savingsMethod))
            }
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Bill Deletion
    
    /// 删除账单
    /// - Parameter bill: 要删除的账单
    /// - Throws: AppError 如果删除失败
    /// - Requirements: 9.4
    func deleteBill(_ bill: Bill) async throws {
        // 获取支付方式
        guard let paymentMethod = try await repository.fetchPaymentMethod(by: bill.paymentMethodId) else {
            throw AppError.missingPaymentMethod
        }
        
        // 恢复支付方式余额（如果不是"不计入"类型）
        if paymentMethod.transactionType != .excluded {
            try await updatePaymentMethodBalance(
                paymentMethod: paymentMethod,
                amount: -bill.amount,
                isCreating: false
            )
        }
        
        do {
            try await repository.deleteBill(bill)
            bills.removeAll { $0.id == bill.id }
        } catch {
            // 如果删除失败，回滚余额
            if paymentMethod.transactionType != .excluded {
                try? await updatePaymentMethodBalance(
                    paymentMethod: paymentMethod,
                    amount: bill.amount,
                    isCreating: false
                )
            }
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Payment Method Balance Update
    
    /// 更新支付方式余额
    /// - Parameters:
    ///   - paymentMethod: 支付方式
    ///   - amount: 金额
    ///   - isCreating: 是否是创建操作
    /// - Throws: AppError 如果更新失败
    private func updatePaymentMethodBalance(
        paymentMethod: PaymentMethodWrapper,
        amount: Decimal,
        isCreating: Bool
    ) async throws {
        var updatedMethod = paymentMethod
        
        switch paymentMethod {
        case .credit(var creditMethod):
            // 信贷方式余额更新逻辑
            switch creditMethod.transactionType {
            case .expense:
                // 支出：增加欠费，减少可用额度
                let newBalance = creditMethod.outstandingBalance + amount
                
                // 检查是否超过信用额度 (Requirement 6.2)
                if newBalance > creditMethod.creditLimit {
                    throw AppError.creditLimitExceeded
                }
                
                creditMethod.outstandingBalance = newBalance
                
            case .income:
                // 收入：减少欠费，增加可用额度
                creditMethod.outstandingBalance = max(0, creditMethod.outstandingBalance - amount)
                
            case .excluded:
                // 不计入类型不更新余额
                return
            }
            
            updatedMethod = .credit(creditMethod)
            
        case .savings(var savingsMethod):
            // 储蓄方式余额更新逻辑
            switch savingsMethod.transactionType {
            case .expense:
                // 支出：减少余额
                savingsMethod.balance -= amount
                
            case .income:
                // 收入：增加余额
                savingsMethod.balance += amount
                
            case .excluded:
                // 不计入类型不更新余额
                return
            }
            
            updatedMethod = .savings(savingsMethod)
        }
        
        // 保存更新后的支付方式
        try await repository.updatePaymentMethod(updatedMethod)
    }
}
