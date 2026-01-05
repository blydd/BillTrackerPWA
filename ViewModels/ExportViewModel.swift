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
        let categoryDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let ownerDict = Dictionary(uniqueKeysWithValues: owners.map { ($0.id, $0.name) })
        let paymentMethodDict = Dictionary(uniqueKeysWithValues: paymentMethods.map { ($0.id, $0.name) })
        
        // 创建CSV内容（添加交易类型列）
        var csvContent = "日期,金额,交易类型,账单类型,归属人,支付方式,备注\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let totalBills = bills.count
        for (index, bill) in bills.enumerated() {
            // 更新进度
            exportProgress = Double(index) / Double(totalBills)
            
            // 格式化日期
            let dateString = dateFormatter.string(from: bill.createdAt)
            
            // 获取账单类型名称和判断交易类型
            let billCategories = bill.categoryIds.compactMap { categoryDict[$0] }
            let categoryNames = billCategories.map { $0.name }.joined(separator: "; ")
            
            // 判断交易类型
            let transactionType: String
            let isExcluded = !billCategories.isEmpty && billCategories.allSatisfy { $0.transactionType == .excluded }
            if isExcluded {
                transactionType = "不计入"
            } else if bill.amount > 0 {
                transactionType = "收入"
            } else {
                transactionType = "支出"
            }
            
            // 获取归属人名称
            let ownerName = ownerDict[bill.ownerId] ?? "未知"
            
            // 获取支付方式名称
            let paymentMethodName = paymentMethodDict[bill.paymentMethodId] ?? "未知"
            
            // 获取备注
            let note = bill.note ?? ""
            
            // 添加行数据（包含交易类型）
            let row = "\(dateString),\(bill.amount),\(transactionType),\(categoryNames),\(ownerName),\(paymentMethodName),\(note)\n"
            csvContent += row
        }
        
        exportProgress = 1.0
        
        // 保存到临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let fileNameFormatter = DateFormatter()
        fileNameFormatter.dateFormat = "yyyyMMddHHmmss"
        let fileName = "bills_export_\(fileNameFormatter.string(from: Date())).csv"
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
        
        // 检查文件扩展名
        let fileExtension = fileURL.pathExtension.lowercased()
        if fileExtension == "xlsx" || fileExtension == "xls" {
            throw ImportError.invalidFormat("暂不支持 Excel 文件格式，请将文件另存为 CSV 格式后再导入")
        }
        
        // 读取CSV文件内容
        let csvContent: String
        do {
            // 尝试多种编码读取
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                csvContent = content
            } else if let data = try? Data(contentsOf: fileURL),
                      let content = String(data: data, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))) {
                // 尝试 GBK/GB18030 编码（中文 Windows 默认编码）
                csvContent = content
            } else if let data = try? Data(contentsOf: fileURL),
                      let content = String(data: data, encoding: .utf16) {
                csvContent = content
            } else if let data = try? Data(contentsOf: fileURL),
                      let content = String(data: data, encoding: .ascii) {
                csvContent = content
            } else {
                throw ImportError.fileReadFailed("无法读取文件，请尝试将文件另存为 UTF-8 编码的 CSV 格式")
            }
        }
        
        // 检查是否为空文件
        let trimmedContent = csvContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty {
            throw ImportError.invalidFormat("文件内容为空")
        }
        
        // 解析CSV内容
        let lines = csvContent.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw ImportError.invalidFormat("文件只有标题行，没有数据")
        }
        
        // 检查CSV头部（支持新旧两种格式）
        let header = lines[0]
        let hasTransactionType = header.contains("交易类型")
        
        // 检查是否包含必要的列
        if !header.contains("日期") || !header.contains("金额") {
            // 可能是 Excel 导出的格式，检查是否有乱码
            if header.contains("\u{FEFF}") || header.first?.isASCII == false {
                throw ImportError.invalidFormat("文件编码格式不正确，请使用 UTF-8 编码保存 CSV 文件")
            }
            throw ImportError.invalidFormat("CSV 文件缺少必要的列（日期、金额），请检查文件格式是否正确\n\n当前标题行：\(header.prefix(100))")
        }
        
        // 获取现有数据用于去重和关联
        let existingBills = try await repository.fetchBills()
        let existingCategories = try await repository.fetchCategories()
        let existingOwners = try await repository.fetchOwners()
        let existingPaymentMethods = try await repository.fetchPaymentMethods()
        
        // 创建查找字典（处理可能存在的重复名称，保留第一个）
        var categoryDict: [String: BillCategory] = [:]
        for category in existingCategories {
            if categoryDict[category.name] == nil {
                categoryDict[category.name] = category
            }
        }
        
        var ownerDict: [String: Owner] = [:]
        for owner in existingOwners {
            if ownerDict[owner.name] == nil {
                ownerDict[owner.name] = owner
            }
        }
        
        var paymentMethodDict: [String: PaymentMethodWrapper] = [:]
        for method in existingPaymentMethods {
            if paymentMethodDict[method.name] == nil {
                paymentMethodDict[method.name] = method
            }
        }
        
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
                    hasTransactionType: hasTransactionType,
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
        hasTransactionType: Bool,
        categoryDict: [String: BillCategory],
        ownerDict: [String: Owner],
        paymentMethodDict: [String: PaymentMethodWrapper],
        createdCategories: inout [BillCategory],
        createdOwners: inout [Owner],
        createdPaymentMethods: inout [PaymentMethodWrapper]
    ) async throws -> Bill {
        let components = parseCSVLine(line)
        
        // 根据是否有交易类型列，确定最小列数
        let minColumns = hasTransactionType ? 7 : 6
        guard components.count >= minColumns else {
            throw ImportError.invalidFormat("行数据列数不足: \(line)")
        }
        
        // 根据格式解析不同位置的数据
        let dateIndex = 0
        let amountIndex = 1
        let transactionTypeIndex = hasTransactionType ? 2 : -1
        let categoryIndex = hasTransactionType ? 3 : 2
        let ownerIndex = hasTransactionType ? 4 : 3
        let paymentMethodIndex = hasTransactionType ? 5 : 4
        let noteIndex = hasTransactionType ? 6 : 5
        
        // 解析日期（支持多种格式）
        var date: Date?
        let dateString = components[dateIndex]
        
        // 尝试多种日期格式
        let dateFormats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/M/d HH:mm",
            "yyyy/M/d H:mm",
            "yyyy-M-d HH:mm:ss",
            "yyyy-M-d HH:mm",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm"
        ]
        
        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "zh_CN")
            if let parsedDate = formatter.date(from: dateString) {
                date = parsedDate
                break
            }
        }
        
        guard let parsedDate = date else {
            throw ImportError.invalidFormat("日期格式错误: \(dateString)，支持的格式如：2024-01-15 12:30:00 或 2024/1/15 12:30")
        }
        
        // 解析金额
        guard var amount = Decimal(string: components[amountIndex]) else {
            throw ImportError.invalidFormat("金额格式错误: \(components[amountIndex])")
        }
        
        // 解析交易类型（如果有）
        var transactionType: TransactionType = .expense
        if hasTransactionType && transactionTypeIndex >= 0 {
            let typeStr = components[transactionTypeIndex]
            switch typeStr {
            case "收入":
                transactionType = .income
            case "不计入":
                transactionType = .excluded
            default:
                transactionType = .expense
            }
        } else {
            // 旧格式：根据金额正负判断
            transactionType = amount > 0 ? .income : .expense
        }
        
        // 处理账单类型
        let categoryNames = components[categoryIndex].components(separatedBy: "; ").filter { !$0.isEmpty }
        var categoryIds: [UUID] = []
        
        for categoryName in categoryNames {
            if let existingCategory = categoryDict[categoryName] {
                categoryIds.append(existingCategory.id)
            } else if let createdCategory = createdCategories.first(where: { $0.name == categoryName }) {
                categoryIds.append(createdCategory.id)
            } else {
                // 创建新类别，使用解析出的交易类型
                let newCategory = BillCategory(name: categoryName, transactionType: transactionType, createdAt: Date(), updatedAt: Date())
                createdCategories.append(newCategory)
                categoryIds.append(newCategory.id)
            }
        }
        
        // 处理归属人
        let ownerName = components[ownerIndex]
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
        let paymentMethodName = components[paymentMethodIndex]
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
        let note = components.count > noteIndex ? components[noteIndex] : nil
        
        return Bill(
            amount: amount,
            paymentMethodId: paymentMethodId,
            categoryIds: categoryIds,
            ownerId: ownerId,
            note: note,
            createdAt: parsedDate,
            updatedAt: parsedDate
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
