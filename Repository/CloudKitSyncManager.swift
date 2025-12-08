import Foundation
import CloudKit
import Combine

/// CloudKit 同步管理器
@MainActor
class CloudKitSyncManager: ObservableObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    // Record Types
    private let ownerRecordType = "Owner"
    private let categoryRecordType = "Category"
    private let paymentMethodRecordType = "PaymentMethod"
    private let billRecordType = "Bill"
    
    init() {
        // 使用你的 iCloud Container ID
        container = CKContainer(identifier: "iCloud.com.bgt.TagBill20251201")
        privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - 检查 iCloud 状态
    
    func checkiCloudStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return true
            case .noAccount:
                syncError = "未登录 iCloud 账号"
                return false
            case .restricted:
                syncError = "iCloud 访问受限"
                return false
            case .couldNotDetermine:
                syncError = "无法确定 iCloud 状态"
                return false
            case .temporarilyUnavailable:
                syncError = "iCloud 暂时不可用"
                return false
            @unknown default:
                syncError = "未知的 iCloud 状态"
                return false
            }
        } catch {
            syncError = "检查 iCloud 状态失败: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - 上传数据到 CloudKit
    
    func uploadOwner(_ owner: Owner) async throws {
        let record = CKRecord(recordType: ownerRecordType, recordID: CKRecord.ID(recordName: owner.id.uuidString))
        record["name"] = owner.name as CKRecordValue
        record["createdAt"] = owner.createdAt as CKRecordValue
        record["updatedAt"] = owner.updatedAt as CKRecordValue
        
        try await privateDatabase.save(record)
    }
    
    func uploadCategory(_ category: BillCategory) async throws {
        let record = CKRecord(recordType: categoryRecordType, recordID: CKRecord.ID(recordName: category.id.uuidString))
        record["name"] = category.name as CKRecordValue
        record["transactionType"] = category.transactionType.rawValue as CKRecordValue
        record["createdAt"] = category.createdAt as CKRecordValue
        record["updatedAt"] = category.updatedAt as CKRecordValue
        
        try await privateDatabase.save(record)
    }
    
    func uploadPaymentMethod(_ method: PaymentMethodWrapper) async throws {
        let record = CKRecord(recordType: paymentMethodRecordType, recordID: CKRecord.ID(recordName: method.id.uuidString))
        record["name"] = method.name as CKRecordValue
        record["ownerId"] = method.ownerId.uuidString as CKRecordValue
        record["accountType"] = method.accountType.rawValue as CKRecordValue
        record["transactionType"] = method.transactionType.rawValue as CKRecordValue
        record["createdAt"] = method.createdAt as CKRecordValue
        record["updatedAt"] = method.updatedAt as CKRecordValue
        
        try await privateDatabase.save(record)
    }
    
    func uploadBill(_ bill: Bill) async throws {
        let record = CKRecord(recordType: billRecordType, recordID: CKRecord.ID(recordName: bill.id.uuidString))
        record["amount"] = (bill.amount as NSDecimalNumber).doubleValue as CKRecordValue
        record["ownerId"] = bill.ownerId.uuidString as CKRecordValue
        record["paymentMethodId"] = bill.paymentMethodId.uuidString as CKRecordValue
        record["categoryIds"] = bill.categoryIds.map { $0.uuidString } as CKRecordValue
        record["note"] = (bill.note ?? "") as CKRecordValue
        record["createdAt"] = bill.createdAt as CKRecordValue
        record["updatedAt"] = bill.updatedAt as CKRecordValue
        
        try await privateDatabase.save(record)
    }
    
    // MARK: - 从 CloudKit 下载数据
    
    func fetchOwners() async throws -> [Owner] {
        let query = CKQuery(recordType: ownerRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var owners: [Owner] = []
        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                if let owner = parseOwner(from: record) {
                    owners.append(owner)
                }
            }
        }
        return owners
    }
    
    func fetchCategories() async throws -> [BillCategory] {
        let query = CKQuery(recordType: categoryRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var categories: [BillCategory] = []
        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                if let category = parseCategory(from: record) {
                    categories.append(category)
                }
            }
        }
        return categories
    }
    
    func fetchPaymentMethods() async throws -> [PaymentMethodWrapper] {
        let query = CKQuery(recordType: paymentMethodRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var methods: [PaymentMethodWrapper] = []
        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                if let method = parsePaymentMethod(from: record) {
                    methods.append(method)
                }
            }
        }
        return methods
    }
    
    func fetchBills() async throws -> [Bill] {
        let query = CKQuery(recordType: billRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var bills: [Bill] = []
        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                if let bill = parseBill(from: record) {
                    bills.append(bill)
                }
            }
        }
        return bills
    }
    
    // MARK: - 解析 CloudKit Record
    
    private func parseOwner(from record: CKRecord) -> Owner? {
        guard let name = record["name"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        return Owner(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    private func parseCategory(from record: CKRecord) -> BillCategory? {
        guard let name = record["name"] as? String,
              let typeString = record["transactionType"] as? String,
              let transactionType = TransactionType(rawValue: typeString),
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        return BillCategory(id: id, name: name, transactionType: transactionType, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    private func parsePaymentMethod(from record: CKRecord) -> PaymentMethodWrapper? {
        guard let name = record["name"] as? String,
              let ownerIdString = record["ownerId"] as? String,
              let ownerId = UUID(uuidString: ownerIdString),
              let accountTypeString = record["accountType"] as? String,
              let accountType = AccountType(rawValue: accountTypeString),
              let transactionTypeString = record["transactionType"] as? String,
              let transactionType = TransactionType(rawValue: transactionTypeString),
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        return PaymentMethodWrapper(id: id, name: name, ownerId: ownerId, accountType: accountType, transactionType: transactionType, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    private func parseBill(from record: CKRecord) -> Bill? {
        guard let amountDouble = record["amount"] as? Double,
              let ownerIdString = record["ownerId"] as? String,
              let ownerId = UUID(uuidString: ownerIdString),
              let paymentMethodIdString = record["paymentMethodId"] as? String,
              let paymentMethodId = UUID(uuidString: paymentMethodIdString),
              let categoryIdStrings = record["categoryIds"] as? [String],
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let amount = Decimal(amountDouble)
        let categoryIds = categoryIdStrings.compactMap { UUID(uuidString: $0) }
        let note = record["note"] as? String
        
        return Bill(id: id, amount: amount, ownerId: ownerId, paymentMethodId: paymentMethodId, categoryIds: categoryIds, note: note, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    // MARK: - 完整同步
    
    func syncAll(localRepository: DataRepository) async throws {
        guard await checkiCloudStatus() else {
            throw CloudSyncError.iCloudNotAvailable
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // 1. 上传本地数据到 CloudKit
            let localOwners = try await localRepository.fetchOwners()
            for owner in localOwners {
                try await uploadOwner(owner)
            }
            
            let localCategories = try await localRepository.fetchCategories()
            for category in localCategories {
                try await uploadCategory(category)
            }
            
            let localMethods = try await localRepository.fetchPaymentMethods()
            for method in localMethods {
                try await uploadPaymentMethod(method)
            }
            
            let localBills = try await localRepository.fetchBills()
            for bill in localBills {
                try await uploadBill(bill)
            }
            
            // 2. 从 CloudKit 下载数据（这里简化处理，实际应该做冲突解决）
            // 可以根据 updatedAt 时间戳来决定保留哪个版本
            
            lastSyncDate = Date()
            isSyncing = false
        } catch {
            syncError = "同步失败: \(error.localizedDescription)"
            isSyncing = false
            throw error
        }
    }
}

// MARK: - 错误类型

enum CloudSyncError: LocalizedError {
    case iCloudNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud 不可用，请检查设置"
        }
    }
}
