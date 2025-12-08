import Foundation
import CloudKit
import Combine
import UIKit

/// 自动云同步管理器
@MainActor
class AutoSyncManager: ObservableObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let localRepository: DataRepository
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isAutoSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoSyncEnabled, forKey: "isAutoSyncEnabled")
            if isAutoSyncEnabled {
                startAutoSync()
            } else {
                stopAutoSync()
            }
        }
    }
    
    @Published var syncInterval: SyncInterval {
        didSet {
            UserDefaults.standard.set(syncInterval.rawValue, forKey: "syncInterval")
            if isAutoSyncEnabled {
                stopAutoSync()
                startAutoSync()
            }
        }
    }
    
    // 同步状态
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Record Types
    private let ownerRecordType = "Owner"
    private let categoryRecordType = "Category"
    private let paymentMethodRecordType = "PaymentMethod"
    private let billRecordType = "Bill"
    
    // 同步间隔选项
    enum SyncInterval: TimeInterval, CaseIterable, Identifiable {
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600
        
        var id: TimeInterval { rawValue }
        
        var displayName: String {
            switch self {
            case .oneMinute: return "1分钟"
            case .fiveMinutes: return "5分钟"
            case .fifteenMinutes: return "15分钟"
            case .thirtyMinutes: return "30分钟"
            case .oneHour: return "1小时"
            }
        }
    }
    
    init(repository: DataRepository) {
        self.localRepository = repository
        container = CKContainer(identifier: "iCloud.com.bgt.TagBill20251201")
        privateDatabase = container.privateCloudDatabase
        
        // 从 UserDefaults 恢复设置
        self.isAutoSyncEnabled = UserDefaults.standard.object(forKey: "isAutoSyncEnabled") as? Bool ?? true
        
        let savedInterval = UserDefaults.standard.double(forKey: "syncInterval")
        self.syncInterval = SyncInterval(rawValue: savedInterval) ?? .fiveMinutes
        
        if let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            self.lastSyncDate = lastSync
        }
        
        // 启动自动同步
        if isAutoSyncEnabled {
            startAutoSync()
        }
        
        // 监听应用进入前台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // 监听应用进入后台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        syncTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 自动同步控制
    
    func startAutoSync() {
        guard isAutoSyncEnabled else { return }
        
        // 立即执行一次同步
        Task {
            await syncIfNeeded()
        }
        
        // 设置定时器
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval.rawValue, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncIfNeeded()
            }
        }
    }
    
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    @objc private func appDidBecomeActive() {
        Task {
            await syncIfNeeded()
        }
    }
    
    @objc private func appWillResignActive() {
        Task {
            await syncIfNeeded()
        }
    }
    
    // MARK: - 手动同步
    
    func manualSync() async {
        await performSync()
    }
    
    // MARK: - 智能同步
    
    private func syncIfNeeded() async {
        // 如果正在同步，跳过
        guard !isSyncing else { return }
        
        // 检查 iCloud 状态
        guard await checkiCloudStatus() else { return }
        
        // 检查是否需要同步（距离上次同步超过1分钟）
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 60 {
            return
        }
        
        await performSync()
    }
    
    // MARK: - 执行同步
    
    func performSync() async {
        isSyncing = true
        syncError = nil
        
        do {
            // 1. 上传本地新增/修改的数据
            try await uploadLocalChanges()
            
            // 2. 下载云端新增/修改的数据
            try await downloadCloudChanges()
            
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            
            isSyncing = false
        } catch {
            syncError = "同步失败: \(error.localizedDescription)"
            isSyncing = false
            
            // 静默失败，不打扰用户
            print("Auto sync failed: \(error)")
        }
    }
    
    // MARK: - 上传本地变更
    
    private func uploadLocalChanges() async throws {
        // 获取本地数据
        let owners = try await localRepository.fetchOwners()
        let categories = try await localRepository.fetchCategories()
        let methods = try await localRepository.fetchPaymentMethods()
        let bills = try await localRepository.fetchBills()
        
        // 批量上传（CloudKit 支持批量操作，性能更好）
        var recordsToSave: [CKRecord] = []
        
        // 转换为 CloudKit Records
        for owner in owners {
            recordsToSave.append(createOwnerRecord(owner))
        }
        
        for category in categories {
            recordsToSave.append(createCategoryRecord(category))
        }
        
        for method in methods {
            recordsToSave.append(createPaymentMethodRecord(method))
        }
        
        for bill in bills {
            recordsToSave.append(createBillRecord(bill))
        }
        
        // 批量保存（每次最多500条）
        let batchSize = 400
        for i in stride(from: 0, to: recordsToSave.count, by: batchSize) {
            let end = min(i + batchSize, recordsToSave.count)
            let batch = Array(recordsToSave[i..<end])
            
            try await privateDatabase.modifyRecords(saving: batch, deleting: [])
        }
    }
    
    // MARK: - 下载云端变更
    
    private func downloadCloudChanges() async throws {
        // 使用 CKQueryOperation 获取最近更新的记录
        let lastSync = lastSyncDate ?? Date.distantPast
        
        // 下载 Owners
        let ownerPredicate = NSPredicate(format: "modificationDate > %@", lastSync as NSDate)
        let ownerQuery = CKQuery(recordType: ownerRecordType, predicate: ownerPredicate)
        let (ownerResults, _) = try await privateDatabase.records(matching: ownerQuery)
        
        for (_, result) in ownerResults {
            if let record = try? result.get(),
               let owner = parseOwner(from: record) {
                // 保存到本地数据库（需要添加 upsert 方法）
                try await upsertOwner(owner)
            }
        }
        
        // 类似地下载其他类型的数据...
        // 为了简化，这里省略了 categories, methods, bills 的下载
    }
    
    // MARK: - 创建 CloudKit Records
    
    private func createOwnerRecord(_ owner: Owner) -> CKRecord {
        let record = CKRecord(recordType: ownerRecordType, recordID: CKRecord.ID(recordName: owner.id.uuidString))
        record["name"] = owner.name as CKRecordValue
        record["createdAt"] = owner.createdAt as CKRecordValue
        record["updatedAt"] = owner.updatedAt as CKRecordValue
        return record
    }
    
    private func createCategoryRecord(_ category: BillCategory) -> CKRecord {
        let record = CKRecord(recordType: categoryRecordType, recordID: CKRecord.ID(recordName: category.id.uuidString))
        record["name"] = category.name as CKRecordValue
        record["transactionType"] = category.transactionType.rawValue as CKRecordValue
        record["createdAt"] = category.createdAt as CKRecordValue
        record["updatedAt"] = category.updatedAt as CKRecordValue
        return record
    }
    
    private func createPaymentMethodRecord(_ method: PaymentMethodWrapper) -> CKRecord {
        let record = CKRecord(recordType: paymentMethodRecordType, recordID: CKRecord.ID(recordName: method.id.uuidString))
        record["name"] = method.name as CKRecordValue
        record["ownerId"] = method.ownerId.uuidString as CKRecordValue
        record["accountType"] = method.accountType.rawValue as CKRecordValue
        record["transactionType"] = method.transactionType.rawValue as CKRecordValue
        record["createdAt"] = method.createdAt as CKRecordValue
        record["updatedAt"] = method.updatedAt as CKRecordValue
        return record
    }
    
    private func createBillRecord(_ bill: Bill) -> CKRecord {
        let record = CKRecord(recordType: billRecordType, recordID: CKRecord.ID(recordName: bill.id.uuidString))
        record["amount"] = (bill.amount as NSDecimalNumber).doubleValue as CKRecordValue
        record["ownerId"] = bill.ownerId.uuidString as CKRecordValue
        record["paymentMethodId"] = bill.paymentMethodId.uuidString as CKRecordValue
        record["categoryIds"] = bill.categoryIds.map { $0.uuidString } as CKRecordValue
        record["note"] = (bill.note ?? "") as CKRecordValue
        record["createdAt"] = bill.createdAt as CKRecordValue
        record["updatedAt"] = bill.updatedAt as CKRecordValue
        return record
    }
    
    // MARK: - 解析 CloudKit Records
    
    private func parseOwner(from record: CKRecord) -> Owner? {
        guard let name = record["name"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        return Owner(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    // MARK: - 本地数据库操作
    
    private func upsertOwner(_ owner: Owner) async throws {
        // 检查是否已存在
        let existing = try await localRepository.fetchOwners()
        if existing.contains(where: { $0.id == owner.id }) {
            // 更新
            try await localRepository.updateOwner(owner)
        } else {
            // 插入
            try await localRepository.saveOwner(owner)
        }
    }
    
    // MARK: - 检查 iCloud 状态
    
    private func checkiCloudStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
}
