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
            print("📋 加载账单完成: 共 \(bills.count) 条")
        } catch {
            errorMessage = "加载账单失败: \(error.localizedDescription)"
            print("❌ 加载账单失败: \(error)")
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
    ///   - createdAt: 账单时间（可选，默认为当前时间）
    /// - Throws: AppError 如果验证失败或保存失败
    /// - Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
    func createBill(
        amount: Decimal,
        paymentMethodId: UUID,
        categoryIds: [UUID],
        ownerId: UUID,
        note: String? = nil,
        createdAt: Date = Date()
    ) async throws {
        // 验证金额不能为0 (Requirement 1.2)
        guard amount != 0 else {
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
                isCreating: true,
                billOwnerId: ownerId
            )
        }
        
        // 创建账单，使用指定的时间或当前时间 (Requirement 1.6)
        let bill = Bill(
            amount: amount,
            paymentMethodId: paymentMethodId,
            categoryIds: categoryIds,
            ownerId: ownerId,
            note: note,
            createdAt: createdAt,
            updatedAt: Date()
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
                    isCreating: true,
                    billOwnerId: ownerId
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
    ///   - createdAt: 账单时间（可选，默认为当前时间）
    /// - Throws: AppError 如果验证失败或保存失败
    func createBillWithExcludedType(
        amount: Decimal,
        paymentMethodId: UUID,
        categoryIds: [UUID],
        ownerId: UUID,
        note: String? = nil,
        createdAt: Date = Date()
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
            // 验证信贷方式的归属人是否与账单的归属人匹配
            guard creditMethod.ownerId == ownerId else {
                throw AppError.ownerMismatch
            }
            
            // 信贷方式：
            // 正数：还款，减少欠费，增加可用额度（允许溢缴款，欠费可以为负数）
            // 负数：消费，增加欠费，减少可用额度
            let newBalance = creditMethod.outstandingBalance - amount
            
            // 检查是否超过信用额度（只在消费时检查，还款不限制）
            // 可用额度 = 信用额度 - 欠费，当欠费为负数时，可用额度会超过信用额度
            if newBalance > creditMethod.creditLimit {
                throw AppError.creditLimitExceeded
            }
            
            // 允许欠费为负数（溢缴款）
            creditMethod.outstandingBalance = newBalance
            updatedMethod = .credit(creditMethod)
            
        case .savings(var savingsMethod):
            // 验证储蓄方式的归属人是否与账单的归属人匹配
            guard savingsMethod.ownerId == ownerId else {
                throw AppError.ownerMismatch
            }
            
            // 储蓄方式：
            // 正数：存入，增加余额
            // 负数：取出，减少余额
            savingsMethod.balance += amount
            updatedMethod = .savings(savingsMethod)
        }
        
        // 保存更新后的支付方式
        try await repository.updatePaymentMethod(updatedMethod)
        
        // 创建账单，使用指定的时间或当前时间
        let bill = Bill(
            amount: amount,
            paymentMethodId: paymentMethodId,
            categoryIds: categoryIds,
            ownerId: ownerId,
            note: note,
            createdAt: createdAt,
            updatedAt: Date()
        )
        
        do {
            try await repository.saveBill(bill)
            bills.append(bill)
        } catch {
            // 如果保存失败，回滚余额更新
            switch paymentMethod {
            case .credit(var creditMethod):
                creditMethod.outstandingBalance = max(0, creditMethod.outstandingBalance + amount)
                try? await repository.updatePaymentMethod(.credit(creditMethod))
                
            case .savings(var savingsMethod):
                savingsMethod.balance -= amount
                try? await repository.updatePaymentMethod(.savings(savingsMethod))
            }
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Bill Update
    
    /// 更新账单
    /// - Parameters:
    ///   - bill: 原账单
    ///   - amount: 新金额
    ///   - paymentMethodId: 新支付方式ID
    ///   - categoryIds: 新账单类型ID列表
    ///   - ownerId: 新归属人ID
    ///   - note: 新备注
    ///   - createdAt: 新账单时间
    /// - Throws: AppError 如果更新失败
    func updateBill(
        _ bill: Bill,
        amount: Decimal,
        paymentMethodId: UUID,
        categoryIds: [UUID],
        ownerId: UUID,
        note: String? = nil,
        createdAt: Date
    ) async throws {
        // 先恢复旧账单的余额影响
        if let oldPaymentMethod = try await repository.fetchPaymentMethod(by: bill.paymentMethodId),
           oldPaymentMethod.transactionType != .excluded {
            try await updatePaymentMethodBalance(
                paymentMethod: oldPaymentMethod,
                amount: -bill.amount,
                isCreating: false,
                billOwnerId: bill.ownerId
            )
        }
        
        // 验证新数据
        guard amount != 0 else {
            throw AppError.invalidAmount
        }
        
        guard try await repository.fetchPaymentMethod(by: paymentMethodId) != nil else {
            throw AppError.missingPaymentMethod
        }
        
        guard !categoryIds.isEmpty else {
            throw AppError.missingCategory
        }
        
        guard try await repository.fetchOwner(by: ownerId) != nil else {
            throw AppError.missingOwner
        }
        
        // 应用新账单的余额影响
        if let newPaymentMethod = try await repository.fetchPaymentMethod(by: paymentMethodId),
           newPaymentMethod.transactionType != .excluded {
            try await updatePaymentMethodBalance(
                paymentMethod: newPaymentMethod,
                amount: amount,
                isCreating: true,
                billOwnerId: ownerId
            )
        }
        
        // 更新账单
        let updatedBill = Bill(
            id: bill.id,
            amount: amount,
            paymentMethodId: paymentMethodId,
            categoryIds: categoryIds,
            ownerId: ownerId,
            note: note,
            createdAt: createdAt,
            updatedAt: Date()
        )
        
        do {
            try await repository.updateBill(updatedBill)
            if let index = bills.firstIndex(where: { $0.id == bill.id }) {
                bills[index] = updatedBill
            }
        } catch {
            // 回滚余额变化
            if let oldPaymentMethod = try? await repository.fetchPaymentMethod(by: bill.paymentMethodId),
               oldPaymentMethod.transactionType != .excluded {
                try? await updatePaymentMethodBalance(
                    paymentMethod: oldPaymentMethod,
                    amount: bill.amount,
                    isCreating: true,
                    billOwnerId: bill.ownerId
                )
            }
            if let newPaymentMethod = try? await repository.fetchPaymentMethod(by: paymentMethodId),
               newPaymentMethod.transactionType != .excluded {
                try? await updatePaymentMethodBalance(
                    paymentMethod: newPaymentMethod,
                    amount: -amount,
                    isCreating: false,
                    billOwnerId: ownerId
                )
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
        print("🗑️ 开始删除账单: ID=\(bill.id), 金额=\(bill.amount)")
        
        // 获取支付方式
        guard let paymentMethod = try await repository.fetchPaymentMethod(by: bill.paymentMethodId) else {
            print("❌ 删除失败: 找不到支付方式")
            throw AppError.missingPaymentMethod
        }
        
        print("💳 支付方式: \(paymentMethod.name), 类型: \(paymentMethod.transactionType)")
        
        // 恢复支付方式余额（如果不是"不计入"类型）
        if paymentMethod.transactionType != .excluded {
            print("💰 恢复余额: -\(bill.amount)")
            try await updatePaymentMethodBalance(
                paymentMethod: paymentMethod,
                amount: -bill.amount,
                isCreating: false,
                billOwnerId: bill.ownerId
            )
        } else {
            print("⚠️ 不计入类型，需要手动恢复余额")
            // 对于不计入类型，也需要恢复余额
            var updatedMethod = paymentMethod
            
            switch paymentMethod {
            case .credit(var creditMethod):
                // 验证归属人
                guard creditMethod.ownerId == bill.ownerId else {
                    print("❌ 归属人不匹配")
                    throw AppError.ownerMismatch
                }
                
                // 恢复余额：删除账单时，需要反向操作
                // 如果原来是还款（正数），删除后欠费应该增加
                // 如果原来是消费（负数），删除后欠费应该减少
                creditMethod.outstandingBalance += bill.amount
                updatedMethod = .credit(creditMethod)
                
            case .savings(var savingsMethod):
                // 验证归属人
                guard savingsMethod.ownerId == bill.ownerId else {
                    print("❌ 归属人不匹配")
                    throw AppError.ownerMismatch
                }
                
                // 恢复余额：删除账单时，需要反向操作
                savingsMethod.balance -= bill.amount
                updatedMethod = .savings(savingsMethod)
            }
            
            try await repository.updatePaymentMethod(updatedMethod)
            print("✅ 不计入类型余额恢复完成")
        }
        
        do {
            print("🗄️ 从数据库删除账单...")
            try await repository.deleteBill(bill)
            print("✅ 数据库删除成功")
            
            print("📝 从内存列表删除账单...")
            bills.removeAll { $0.id == bill.id }
            print("✅ 内存删除成功，当前账单数: \(bills.count)")
        } catch {
            print("❌ 删除失败: \(error)")
            // 如果删除失败，回滚余额
            if paymentMethod.transactionType != .excluded {
                print("🔄 回滚余额...")
                try? await updatePaymentMethodBalance(
                    paymentMethod: paymentMethod,
                    amount: bill.amount,
                    isCreating: false,
                    billOwnerId: bill.ownerId
                )
            } else {
                // 回滚不计入类型的余额
                var rollbackMethod = paymentMethod
                switch paymentMethod {
                case .credit(var creditMethod):
                    creditMethod.outstandingBalance -= bill.amount
                    rollbackMethod = .credit(creditMethod)
                case .savings(var savingsMethod):
                    savingsMethod.balance += bill.amount
                    rollbackMethod = .savings(savingsMethod)
                }
                try? await repository.updatePaymentMethod(rollbackMethod)
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
    ///   - billOwnerId: 账单的归属人ID（用于匹配信贷方式）
    /// - Throws: AppError 如果更新失败
    private func updatePaymentMethodBalance(
        paymentMethod: PaymentMethodWrapper,
        amount: Decimal,
        isCreating: Bool,
        billOwnerId: UUID
    ) async throws {
        print("💰 更新支付方式余额: \(paymentMethod.name), 金额: \(amount)")
        
        var updatedMethod = paymentMethod
        
        switch paymentMethod {
        case .credit(var creditMethod):
            // 验证信贷方式的归属人是否与账单的归属人匹配
            guard creditMethod.ownerId == billOwnerId else {
                print("❌ 归属人不匹配")
                throw AppError.ownerMismatch
            }
            
            // 信贷方式余额更新逻辑
            // 金额为负数表示支出，正数表示收入
            // 支出（负数）：增加欠费
            // 收入（正数）：减少欠费（允许溢缴款，欠费可以为负数）
            let oldBalance = creditMethod.outstandingBalance
            let newBalance = creditMethod.outstandingBalance - amount
            
            print("  信贷: 旧欠费=\(oldBalance), 新欠费=\(newBalance)")
            
            // 检查是否超过信用额度 (Requirement 6.2)
            // 只在消费（欠费增加）时检查，还款不限制
            if newBalance > creditMethod.creditLimit {
                print("❌ 超过信用额度")
                throw AppError.creditLimitExceeded
            }
            
            // 允许欠费为负数（溢缴款）
            creditMethod.outstandingBalance = newBalance
            updatedMethod = .credit(creditMethod)
            
        case .savings(var savingsMethod):
            // 验证储蓄方式的归属人是否与账单的归属人匹配
            guard savingsMethod.ownerId == billOwnerId else {
                print("❌ 归属人不匹配")
                throw AppError.ownerMismatch
            }
            
            // 储蓄方式余额更新逻辑
            // 金额为负数表示支出，正数表示收入
            // 支出（负数）：减少余额
            // 收入（正数）：增加余额
            let oldBalance = savingsMethod.balance
            savingsMethod.balance += amount
            let newBalance = savingsMethod.balance
            
            print("  储蓄: 旧余额=\(oldBalance), 新余额=\(newBalance)")
            
            updatedMethod = .savings(savingsMethod)
        }
        
        // 保存更新后的支付方式
        try await repository.updatePaymentMethod(updatedMethod)
        print("✅ 支付方式余额更新完成")
    }
}
