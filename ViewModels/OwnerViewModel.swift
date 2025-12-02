import Foundation
import Combine

/// 归属人管理ViewModel
/// 负责归属人的创建、编辑、删除和名称唯一性验证
@MainActor
class OwnerViewModel: ObservableObject {
    @Published var owners: [Owner] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    /// 加载所有归属人
    func loadOwners() async {
        isLoading = true
        errorMessage = nil
        
        do {
            owners = try await repository.fetchOwners()
        } catch {
            errorMessage = "加载归属人失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 创建新的归属人
    /// - Parameter name: 归属人名称
    /// - Throws: AppError.duplicateName 如果名称已存在
    func createOwner(name: String) async throws {
        // 验证名称唯一性
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw AppError.duplicateName(entityType: "归属人")
        }
        
        // 检查名称是否已存在
        if owners.contains(where: { $0.name == trimmedName }) {
            throw AppError.duplicateName(entityType: "归属人")
        }
        
        let newOwner = Owner(name: trimmedName)
        
        do {
            try await repository.saveOwner(newOwner)
            owners.append(newOwner)
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 编辑归属人名称
    /// - Parameters:
    ///   - owner: 要编辑的归属人
    ///   - newName: 新名称
    /// - Throws: AppError.duplicateName 如果新名称已存在
    func updateOwner(_ owner: Owner, newName: String) async throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw AppError.duplicateName(entityType: "归属人")
        }
        
        // 检查新名称是否与其他归属人重复（排除自己）
        if owners.contains(where: { $0.id != owner.id && $0.name == trimmedName }) {
            throw AppError.duplicateName(entityType: "归属人")
        }
        
        var updatedOwner = owner
        updatedOwner.name = trimmedName
        
        do {
            try await repository.updateOwner(updatedOwner)
            
            // 更新本地列表
            if let index = owners.firstIndex(where: { $0.id == owner.id }) {
                owners[index] = updatedOwner
            }
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 删除归属人
    /// - Parameter owner: 要删除的归属人
    /// - Throws: AppError.dataNotFound 如果归属人仍被账单使用
    /// - Note: 根据需求3.5，如果归属人仍被账单使用，应该阻止删除
    func deleteOwner(_ owner: Owner) async throws {
        // 检查是否有账单使用该归属人
        let bills = try await repository.fetchBills()
        let isUsedByBills = bills.contains(where: { $0.ownerId == owner.id })
        
        if isUsedByBills {
            throw AppError.dataNotFound // 使用dataNotFound表示无法删除
        }
        
        do {
            try await repository.deleteOwner(owner)
            owners.removeAll { $0.id == owner.id }
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
    
    /// 检查名称是否唯一
    /// - Parameter name: 要检查的名称
    /// - Returns: 如果名称唯一返回true，否则返回false
    func isNameUnique(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !owners.contains(where: { $0.name == trimmedName })
    }
    
    /// 检查名称是否唯一（排除指定的归属人）
    /// - Parameters:
    ///   - name: 要检查的名称
    ///   - excludingId: 要排除的归属人ID
    /// - Returns: 如果名称唯一返回true，否则返回false
    func isNameUnique(_ name: String, excludingId: UUID) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !owners.contains(where: { $0.id != excludingId && $0.name == trimmedName })
    }
}
