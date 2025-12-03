import Foundation

/// 数据库管理工具
class DatabaseManager {
    private let sqliteRepo: SQLiteRepository
    
    init(sqliteRepo: SQLiteRepository) {
        self.sqliteRepo = sqliteRepo
    }
    
    /// 获取数据库文件路径
    static func getDatabasePath() -> String? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent("ExpenseTracker.sqlite").path
    }
    
    /// 导出数据库文件
    static func exportDatabase() -> URL? {
        guard let dbPath = getDatabasePath(),
              FileManager.default.fileExists(atPath: dbPath) else {
            return nil
        }
        return URL(fileURLWithPath: dbPath)
    }
    
    /// 获取数据库大小
    static func getDatabaseSize() -> String {
        guard let dbPath = getDatabasePath(),
              let attributes = try? FileManager.default.attributesOfItem(atPath: dbPath),
              let fileSize = attributes[.size] as? Int64 else {
            return "未知"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// 清空所有数据（危险操作）
    func clearAllData() async throws {
        let bills = try await sqliteRepo.fetchBills()
        for bill in bills {
            try await sqliteRepo.deleteBill(bill)
        }
        
        let methods = try await sqliteRepo.fetchPaymentMethods()
        for method in methods {
            try await sqliteRepo.deletePaymentMethod(method)
        }
        
        let categories = try await sqliteRepo.fetchCategories()
        for category in categories {
            try await sqliteRepo.deleteCategory(category)
        }
        
        let owners = try await sqliteRepo.fetchOwners()
        for owner in owners {
            try await sqliteRepo.deleteOwner(owner)
        }
    }
}
