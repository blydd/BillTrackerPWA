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
    
    /// 从CSV文件导入账单数据
    /// - Parameter fileURL: CSV文件的URL
    /// - Returns: 导入结果统计
    func importFromCSV(fileURL: URL) async throws -> ImportResult {
        isImporting = true
        importProgress = 0.0
        errorMessage = nil
        
        defer {
            isImporting = false
            importProgress = 0.0
        }
        
        // 读取CSV文件内容
        let csvContent: String
        do {
            csvContent = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ImportError.fileReadFailed(error.localizedDescription)
        }
        
        // 解析CSV内容
        let lines = csvContent.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw ImportError.invalidFormat("文件为空或格式不正确")
        }
        
        // 检查CSV头部
        let header = lines[0]
        let expectedHeader = "日期,金额,账单类型,归属人,支付方式,备注"
        guard header.contains("日期") && header.contains("金额") else {
            throw ImportError.invalidFormat("CSV文件格式不正确，缺少必要的列")
        }
        
        // 获取现有数据用于去重和关联
        let existingBills = try await repository.fetchBills()
        let existingCategories = try await repository.fetchCategories()
        let existingOwners = try await repository.fetchOwners()
        let existingPaymentMethods = try await repository.fetchPaymentMethods()
        
        // 创建查找字典
        let categoryDict = Dictionary(uniqueKeysWithValues: existingCategories.map { ($0.name, $0) })
        let ownerDict = Dictionary(uniqueKeysWithValues: existingOwners.map { ($0.name, $0) })
        let paymentMethodDict = Dictionary(uniqueKeysWithValues: existingPaymentMethods.map { ($0.name, $0) })
        
        var importedBills: [Bill] = []
        var duplicateCount = 0
        var errorCount = 0
        var createdCategories: [BillCategory] = []
        var createdOwners: [Owner] = []
        var createdPaymentMethods: [PaymentMethodWrapper] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dataLines = Array(lines[1...]).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let totalLines = dataLines.count
        
        for (index, line) in dataLines.enumerated() {
            importProgress = Double(index) / Double(totalLines)
            
            do {
                let bill = try await parseBillFromCSVLine(
                    line: line,
                    dateFormatter: dateFormatter,
                    categoryDict: categoryDict,
                    ownerDict: ownerDict,
                    paymentMethodDict: paymentMethodDict,
                    createdCategories: &createdCategories,
                    createdOwners: &createdOwners,
                    createdPaymentMethods: &createdPaymentMethods
                )
                
                // 去重检查
                if isDuplicateBill(bill: bill, existingBills: existingBills + importedBills) {
                    duplicateCount += 1
                    continue
                }
                
                importedBills.append(bill)
                
            } catch {
                print("❌ 解析行数据失败: \(line), 错误: \(error)")
                errorCount += 1
            }
        }
        
        // 保存新创建的基础数据
        for category in createdCategories {
            try await repository.saveCategory(category)
        }
        for owner in createdOwners {
            try await repository.saveOwner(owner)
        }
        for paymentMethod in createdPaymentMethods {
            try await repository.savePaymentMethod(paymentMethod)
        }
        
        // 保存导入的账单
        for bill in importedBills {
            try await repository.saveBill(bill)
        }
        
        importProgress = 1.0
        
        return ImportResult(
            totalLines: totalLines,
            importedCount: importedBills.count,
            duplicateCount: duplicateCount,
            errorCount: errorCount,
            createdCategoriesCount: createdCategories.count,
            createdOwnersCount: createdOwners.count,
            createdPaymentMethodsCount: createdPaymentMethods.count
        )
    }
    
    /// 解析CSV行数据为账单对象
    private func parseBillFromCSVLine(
        line: String,
        dateFormatter: DateFormatter,
        categoryDict: [String: BillCategory],
        ownerDict: [String: Owner],
        paymentMethodDict: [String: PaymentMethodWrapper],
        createdCategories: inout [BillCategory],
        createdOwners: inout [Owner],
        createdPaymentMethods: inout [PaymentMethodWrapper]
    ) async throws -> Bill {
        let components = parseCSVLine(line)
        guard components.count >= 6 else {
            throw ImportError.invalidFormat("行数据列数不足: \(line)")
        }
        
        // 解析日期
        guard let date = dateFormatter.date(from: components[0]) else {
            throw ImportError.invalidFormat("日期格式错误: \(components[0])")
        }
        
        // 解析金额
        guard let amount = Decimal(string: components[1]) else {
            throw ImportError.invalidFormat("金额格式错误: \(components[1])")
        }
        
        // 处理账单类型
        let categoryNames = components[2].components(separatedBy: "; ").filter { !$0.isEmpty }
        var categoryIds: [UUID] = []
        
        for categoryName in categoryNames {
            if let existingCategory = categoryDict[categoryName] {
                categoryIds.append(existingCategory.id)
            } else if let createdCategory = createdCategories.first(where: { $0.name == categoryName }) {
                categoryIds.append(createdCategory.id)
            } else {
                // 创建新类别
                let newCategory = BillCategory(name: categoryName, createdAt: Date(), updatedAt: Date())
                createdCategories.append(newCategory)
                categoryIds.append(newCategory.id)
            }
        }
        
        // 处理归属人
        let ownerName = components[3]
        let ownerId: UUID
        if let existingOwner = ownerDict[ownerName] {
            ownerId = existingOwner.id
        } else if let createdOwner = createdOwners.first(where: { $0.name == ownerName }) {
            ownerId = createdOwner.id
        } else {
            // 创建新归属人
            let newOwner = Owner(name: ownerName, createdAt: Date(), updatedAt: Date())
            createdOwners.append(newOwner)
            ownerId = newOwner.id
        }
        
        // 处理支付方式
        let paymentMethodName = components[4]
        let paymentMethodId: UUID
        if let existingPaymentMethod = paymentMethodDict[paymentMethodName] {
            paymentMethodId = existingPaymentMethod.id
        } else if let createdPaymentMethod = createdPaymentMethods.first(where: { $0.name == paymentMethodName }) {
            paymentMethodId = createdPaymentMethod.id
        } else {
            // 创建新支付方式（默认为储蓄账户）
            let newPaymentMethod = PaymentMethodWrapper.savings(SavingsMethod(
                name: paymentMethodName,
                transactionType: .expense,
                balance: Decimal(1000), // 默认余额
                ownerId: ownerId
            ))
            createdPaymentMethods.append(newPaymentMethod)
            paymentMethodId = newPaymentMethod.id
        }
        
        // 备注
        let note = components.count > 5 ? components[5] : nil
        
        return Bill(
            amount: amount,
            paymentMethodId: paymentMethodId,
            categoryIds: categoryIds,
            ownerId: ownerId,
            note: note,
            createdAt: date,
            updatedAt: date
        )
    }
    
    /// 解析CSV行，处理逗号分隔和引号
    private func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                components.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
                currentComponent = ""
            } else {
                currentComponent.append(char)
            }
            
            i = line.index(after: i)
        }
        
        // 添加最后一个组件
        components.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return components
    }
    
    /// 检查是否为重复账单
    private func isDuplicateBill(bill: Bill, existingBills: [Bill]) -> Bool {
        return existingBills.contains { existingBill in
            // 检查关键字段是否完全相同
            abs(existingBill.amount - bill.amount) < 0.01 && // 金额相近
            existingBill.paymentMethodId == bill.paymentMethodId &&
            existingBill.ownerId == bill.ownerId &&
            abs(existingBill.createdAt.timeIntervalSince(bill.createdAt)) < 60 && // 时间相近（1分钟内）
            existingBill.note == bill.note
        }
    }
}

/// 导入结果统计
struct ImportResult {
    let totalLines: Int
    let importedCount: Int
    let duplicateCount: Int
    let errorCount: Int
    let createdCategoriesCount: Int
    let createdOwnersCount: Int
    let createdPaymentMethodsCount: Int
}

/// 导入错误类型
enum ImportError: Error, LocalizedError {
    case fileReadFailed(String)
    case invalidFormat(String)
    case dataProcessingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let message):
            return "文件读取失败: \(message)"
        case .invalidFormat(let message):
            return "文件格式错误: \(message)"
        case .dataProcessingFailed(let message):
            return "数据处理失败: \(message)"
        }
    }
}
