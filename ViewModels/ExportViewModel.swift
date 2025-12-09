import Foundation
import Combine

/// Excel导出/导入ViewModel
/// 负责将账单数据导出为CSV文件，以及从CSV文件导入恢复数据
@MainActor
class ExportViewModel: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var importProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    /// 导出账单为CSV格式
    /// - Parameters:
    ///   - bills: 要导出的账单列表
    ///   - categories: 账单类型列表
    ///   - owners: 归属人列表
    ///   - paymentMethods: 支付方式列表
    /// - Returns: CSV文件的URL
    /// - Requirements: 12.1, 12.2, 12.3, 12.4
    func exportToCSV(
        bills: [Bill],
        categories: [BillCategory],
        owners: [Owner],
        paymentMethods: [PaymentMethodWrapper]
    ) async throws -> URL {
        // 检查导出权限
        guard SubscriptionManager.shared.canExportData else {
            throw AppError.featureNotAvailable
        }
        
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        // 检查是否有数据 (Requirement 12.6)
        guard !bills.isEmpty else {
            throw AppError.dataNotFound
        }
        
        // 创建字典以便快速查找
        let categoryDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let ownerDict = Dictionary(uniqueKeysWithValues: owners.map { ($0.id, $0.name) })
        let paymentMethodDict = Dictionary(uniqueKeysWithValues: paymentMethods.map { ($0.id, $0.name) })
        
        // 创建CSV内容
        var csvContent = "日期,金额,账单类型,归属人,支付方式,备注\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let totalBills = bills.count
        for (index, bill) in bills.enumerated() {
            // 更新进度
            exportProgress = Double(index) / Double(totalBills)
            
            // 格式化日期
            let dateString = dateFormatter.string(from: bill.createdAt)
            
            // 获取账单类型名称
            let categoryNames = bill.categoryIds.compactMap { categoryDict[$0] }.joined(separator: "; ")
            
            // 获取归属人名称
            let ownerName = ownerDict[bill.ownerId] ?? "未知"
            
            // 获取支付方式名称
            let paymentMethodName = paymentMethodDict[bill.paymentMethodId] ?? "未知"
            
            // 获取备注
            let note = bill.note ?? ""
            
            // 添加行数据 (Requirement 12.2)
            let row = "\(dateString),\(bill.amount),\(categoryNames),\(ownerName),\(paymentMethodName),\(note)\n"
            csvContent += row
        }
        
        exportProgress = 1.0
        
        // 保存到临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "bills_export_\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw AppError.persistenceError(underlying: error)
        }
    }
}
