import Foundation
import Combine
import SwiftUI

/// 账单类型管理ViewModel
/// 负责账单类型的创建、编辑、删除和名称唯一性验证
@MainActor
class CategoryViewModel: ObservableObject {
    @Published var categories: [BillCategory] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    /// 加载所有账单类型
    func loadCategories() async {
        isLoading = true
        errorMessage = nil
        
        do {
            categories = try await repository.fetchCategories()
        } catch {
            errorMessage = "加载账单类型失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 创建新的账单类型
    /// - Parameters:
    ///   - name: 类型名称
    ///   - transactionType: 交易类型
    /// - Throws: AppError.duplicateName 如果名称已存在
    func createCategory(name: String, transactionType: TransactionType = .expense) async throws {
        // 验证名称唯一性
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw AppError.duplicateName(entityType: "账单类型")
        }
        
        // 检查名称是否已存在
        if categories.contains(where: { $0.name == trimmedName }) {
            throw AppError.duplicateName(entityType: "账单类型")
        }
        
        let newCategory = BillCategory(name: trimmedName, transactionType: transactionType)
        
        do {
            try await repository.saveCategory(newCategory)
            categories.append(newCategory)
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 编辑账单类型
    /// - Parameters:
    ///   - category: 要编辑的类型
    ///   - newName: 新名称
    ///   - newTransactionType: 新交易类型
    /// - Throws: AppError.duplicateName 如果新名称已存在
    func updateCategory(_ category: BillCategory, newName: String, newTransactionType: TransactionType? = nil) async throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw AppError.duplicateName(entityType: "账单类型")
        }
        
        // 检查新名称是否与其他类型重复（排除自己）
        if categories.contains(where: { $0.id != category.id && $0.name == trimmedName }) {
            throw AppError.duplicateName(entityType: "账单类型")
        }
        
        var updatedCategory = category
        updatedCategory.name = trimmedName
        if let transactionType = newTransactionType {
            updatedCategory.transactionType = transactionType
        }
        
        do {
            try await repository.updateCategory(updatedCategory)
            
            // 更新本地列表
            if let index = categories.firstIndex(where: { $0.id == category.id }) {
                categories[index] = updatedCategory
            }
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 删除账单类型
    /// - Parameter category: 要删除的类型
    /// - Note: 根据需求2.5，删除类型会从所有使用该类型的账单中移除该类型引用
    func deleteCategory(_ category: BillCategory) async throws {
        do {
            try await repository.deleteCategory(category)
            categories.removeAll { $0.id == category.id }
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 检查名称是否唯一
    /// - Parameter name: 要检查的名称
    /// - Returns: 如果名称唯一返回true，否则返回false
    func isNameUnique(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !categories.contains(where: { $0.name == trimmedName })
    }
    
    /// 检查名称是否唯一（排除指定的类型）
    /// - Parameters:
    ///   - name: 要检查的名称
    ///   - excludingId: 要排除的类型ID
    /// - Returns: 如果名称唯一返回true，否则返回false
    func isNameUnique(_ name: String, excludingId: UUID) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !categories.contains(where: { $0.id != excludingId && $0.name == trimmedName })
    }
    
    /// 移动账单类型排序（在指定交易类型内）
    /// - Parameters:
    ///   - source: 源索引集（基于排序后的数组）
    ///   - destination: 目标索引（基于排序后的数组）
    ///   - transactionType: 交易类型
    func moveCategories(from source: IndexSet, to destination: Int, transactionType: TransactionType) {
        // 获取当前类型的分类，按 sortOrder 排序
        var filtered = categories
            .filter { $0.transactionType == transactionType }
            .sorted { $0.sortOrder < $1.sortOrder }
        
        // 移动
        filtered.move(fromOffsets: source, toOffset: destination)
        
        // 更新 sortOrder 并写回主数组
        for (newIndex, item) in filtered.enumerated() {
            if let mainIndex = categories.firstIndex(where: { $0.id == item.id }) {
                categories[mainIndex].sortOrder = newIndex
            }
        }
        
        // 异步保存到数据库
        let itemsToSave = filtered.enumerated().map { (index, item) -> BillCategory in
            var updated = item
            updated.sortOrder = index
            return updated
        }
        
        Task {
            for item in itemsToSave {
                do {
                    try await repository.updateCategory(item)
                } catch {
                    print("更新账单类型排序失败: \(error)")
                }
            }
        }
    }
}
