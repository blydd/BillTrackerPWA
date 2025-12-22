import Foundation
import SQLite3

/// 基于 SQLite 的数据仓库实现
class SQLiteRepository: DataRepository {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init(dbName: String = "ExpenseTracker.sqlite") throws {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ 无法获取文档目录")
            throw SQLiteError.databasePathError
        }
        
        dbPath = documentsPath.appendingPathComponent(dbName).path
        print("📁 数据库路径: \(dbPath)")
        
        try openDatabase()
        print("✅ 数据库打开成功")
        
        try createTables()
        print("✅ 数据表创建成功")
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Setup
    
    // MARK: - Helper Methods
    
    private func getString(from statement: OpaquePointer?, at index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: cString)
    }
    
    private func getUUID(from statement: OpaquePointer?, at index: Int32) throws -> UUID {
        guard let string = getString(from: statement, at: index),
              let uuid = UUID(uuidString: string) else {
            throw SQLiteError.decodingFailed
        }
        return uuid
    }
    
    private func getDecimal(from statement: OpaquePointer?, at index: Int32) throws -> Decimal {
        guard let string = getString(from: statement, at: index),
              let decimal = Decimal(string: string) else {
            throw SQLiteError.decodingFailed
        }
        return decimal
    }
    
    private func getDate(from statement: OpaquePointer?, at index: Int32) throws -> Date {
        guard let string = getString(from: statement, at: index),
              let date = ISO8601DateFormatter().date(from: string) else {
            throw SQLiteError.decodingFailed
        }
        return date
    }
    
    private func openDatabase() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw SQLiteError.openDatabaseFailed
        }
        // 启用外键约束
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    private func createTables() throws {
        let tables = [
            """
            CREATE TABLE IF NOT EXISTS owners (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                transaction_type TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS payment_methods (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                transaction_type TEXT NOT NULL,
                account_type TEXT NOT NULL,
                owner_id TEXT NOT NULL,
                credit_limit TEXT,
                outstanding_balance TEXT,
                billing_date INTEGER,
                balance TEXT,
                FOREIGN KEY (owner_id) REFERENCES owners(id) ON DELETE CASCADE
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS bills (
                id TEXT PRIMARY KEY,
                amount TEXT NOT NULL,
                payment_method_id TEXT NOT NULL,
                owner_id TEXT NOT NULL,
                note TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE RESTRICT,
                FOREIGN KEY (owner_id) REFERENCES owners(id) ON DELETE RESTRICT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS bill_categories (
                bill_id TEXT NOT NULL,
                category_id TEXT NOT NULL,
                PRIMARY KEY (bill_id, category_id),
                FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE,
                FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_bills_created_at ON bills(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_bills_owner_id ON bills(owner_id)",
            "CREATE INDEX IF NOT EXISTS idx_bills_payment_method_id ON bills(payment_method_id)",
            "CREATE INDEX IF NOT EXISTS idx_payment_methods_owner_id ON payment_methods(owner_id)"
        ]
        
        for sql in tables {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ SQL 执行失败: \(errorMessage)")
                print("SQL: \(sql)")
                throw SQLiteError.createTableFailed
            }
        }
    }
    
    // MARK: - Clear All Data
    
    func clearAllTables() async throws {
        // 按照外键依赖顺序删除
        let tables = ["bill_categories", "bills", "payment_methods", "categories", "owners"]
        
        for table in tables {
            let deleteSQL = "DELETE FROM \(table);"
            if sqlite3_exec(db, deleteSQL, nil, nil, nil) != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ 清空表 \(table) 失败: \(errorMessage)")
                throw SQLiteError.executeFailed
            }
            print("✅ 清空表: \(table)")
        }
        
        // 执行 VACUUM 清理数据库
        if sqlite3_exec(db, "VACUUM;", nil, nil, nil) == SQLITE_OK {
            print("✅ 数据库清理完成")
        }
        
        // 验证表是否真的清空了
        let countSQL = "SELECT COUNT(*) FROM categories;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                print("📊 categories 表剩余记录数: \(count)")
            }
            sqlite3_finalize(statement)
        }
    }
    
    // MARK: - Bill Operations
    
    func saveBill(_ bill: Bill) async throws {
        let insertSQL = """
        INSERT INTO bills (id, amount, payment_method_id, owner_id, note, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        bill.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        "\(bill.amount)".withCString { amountPtr in
            sqlite3_bind_text(statement, 2, amountPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        bill.paymentMethodId.uuidString.withCString { pmPtr in
            sqlite3_bind_text(statement, 3, pmPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        bill.ownerId.uuidString.withCString { ownerPtr in
            sqlite3_bind_text(statement, 4, ownerPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        if let note = bill.note {
            note.withCString { notePtr in
                sqlite3_bind_text(statement, 5, notePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        } else {
            sqlite3_bind_null(statement, 5)
        }
        ISO8601DateFormatter().string(from: bill.createdAt).withCString { createdPtr in
            sqlite3_bind_text(statement, 6, createdPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        ISO8601DateFormatter().string(from: bill.updatedAt).withCString { updatedPtr in
            sqlite3_bind_text(statement, 7, updatedPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        print("💾 准备保存账单: ID=\(bill.id), 金额=\(bill.amount), 归属人=\(bill.ownerId)")
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ 保存账单失败: \(errorMessage)")
            print("账单信息: ID=\(bill.id), 金额=\(bill.amount)")
            throw SQLiteError.executeFailed
        }
        
        print("✅ 账单保存成功")
        
        // 保存账单类型关联
        try saveBillCategories(billId: bill.id, categoryIds: bill.categoryIds)
    }
    
    func fetchBills() async throws -> [Bill] {
        let querySQL = "SELECT id, amount, payment_method_id, owner_id, note, created_at, updated_at FROM bills ORDER BY created_at DESC;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        var bills: [Bill] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            do {
                let id = try getUUID(from: statement, at: 0)
                let amount = try getDecimal(from: statement, at: 1)
                let paymentMethodId = try getUUID(from: statement, at: 2)
                let ownerId = try getUUID(from: statement, at: 3)
                let note = getString(from: statement, at: 4)
                let createdAt = try getDate(from: statement, at: 5)
                let updatedAt = try getDate(from: statement, at: 6)
                
                let categoryIds = try fetchBillCategoryIds(billId: id)
                
                let bill = Bill(id: id, amount: amount, paymentMethodId: paymentMethodId, 
                              categoryIds: categoryIds, ownerId: ownerId, note: note, 
                              createdAt: createdAt, updatedAt: updatedAt)
                bills.append(bill)
            } catch {
                print("⚠️ 跳过无效的账单记录: \(error)")
                continue
            }
        }
        
        return bills
    }
    
    func updateBill(_ bill: Bill) async throws {
        let updateSQL = """
        UPDATE bills SET amount = ?, payment_method_id = ?, owner_id = ?, note = ?, created_at = ?, updated_at = ?
        WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        "\(bill.amount)".withCString { amountPtr in
            sqlite3_bind_text(statement, 1, amountPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        bill.paymentMethodId.uuidString.withCString { pmPtr in
            sqlite3_bind_text(statement, 2, pmPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        bill.ownerId.uuidString.withCString { ownerPtr in
            sqlite3_bind_text(statement, 3, ownerPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        if let note = bill.note {
            note.withCString { notePtr in
                sqlite3_bind_text(statement, 4, notePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        } else {
            sqlite3_bind_null(statement, 4)
        }
        ISO8601DateFormatter().string(from: bill.createdAt).withCString { createdPtr in
            sqlite3_bind_text(statement, 5, createdPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        ISO8601DateFormatter().string(from: bill.updatedAt).withCString { updatedPtr in
            sqlite3_bind_text(statement, 6, updatedPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        bill.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 7, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        print("📝 更新账单: ID=\(bill.id), 金额=\(bill.amount)")
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ 更新账单失败: \(errorMessage)")
            throw SQLiteError.executeFailed
        }
        
        print("✅ 账单更新成功")
        
        // 更新账单类型关联
        try deleteBillCategories(billId: bill.id)
        try saveBillCategories(billId: bill.id, categoryIds: bill.categoryIds)
    }
    
    func deleteBill(_ bill: Bill) async throws {
        print("🗄️ SQLite: 删除账单 ID=\(bill.id)")
        
        let deleteSQL = "DELETE FROM bills WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ SQLite: 准备删除语句失败: \(errorMessage)")
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        bill.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        let result = sqlite3_step(statement)
        if result != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ SQLite: 删除失败: \(errorMessage), 错误码: \(result)")
            throw SQLiteError.executeFailed
        }
        
        let changes = sqlite3_changes(db)
        print("✅ SQLite: 删除成功，影响行数: \(changes)")
        
        if changes == 0 {
            print("⚠️ SQLite: 警告 - 没有行被删除，账单可能不存在")
        }
    }
    
    func fetchBill(by id: UUID) async throws -> Bill? {
        let querySQL = "SELECT id, amount, payment_method_id, owner_id, note, created_at, updated_at FROM bills WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            do {
                let id = try getUUID(from: statement, at: 0)
                let amount = try getDecimal(from: statement, at: 1)
                let paymentMethodId = try getUUID(from: statement, at: 2)
                let ownerId = try getUUID(from: statement, at: 3)
                let note = getString(from: statement, at: 4)
                let createdAt = try getDate(from: statement, at: 5)
                let updatedAt = try getDate(from: statement, at: 6)
                
                let categoryIds = try fetchBillCategoryIds(billId: id)
                
                return Bill(id: id, amount: amount, paymentMethodId: paymentMethodId,
                           categoryIds: categoryIds, ownerId: ownerId, note: note,
                           createdAt: createdAt, updatedAt: updatedAt)
            } catch {
                print("⚠️ 解析账单失败: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    // MARK: - Bill Categories Helper
    
    private func saveBillCategories(billId: UUID, categoryIds: [UUID]) throws {
        let insertSQL = "INSERT INTO bill_categories (bill_id, category_id) VALUES (?, ?);"
        
        print("📝 保存账单类型关联: 账单ID=\(billId), 类型数量=\(categoryIds.count)")
        
        for categoryId in categoryIds {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                print("❌ 准备SQL失败")
                throw SQLiteError.prepareFailed
            }
            defer { sqlite3_finalize(statement) }
            
            billId.uuidString.withCString { billPtr in
                sqlite3_bind_text(statement, 1, billPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            categoryId.uuidString.withCString { catPtr in
                sqlite3_bind_text(statement, 2, catPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ 保存账单类型关联失败: \(errorMessage)")
                print("账单ID: \(billId), 类型ID: \(categoryId)")
                throw SQLiteError.executeFailed
            }
            print("  ✅ 关联类型: \(categoryId)")
        }
    }
    
    private func fetchBillCategoryIds(billId: UUID) throws -> [UUID] {
        let querySQL = "SELECT category_id FROM bill_categories WHERE bill_id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        billId.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        var categoryIds: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            do {
                let categoryId = try getUUID(from: statement, at: 0)
                categoryIds.append(categoryId)
            } catch {
                print("⚠️ 跳过无效的分类ID")
                continue
            }
        }
        
        print("📋 查询账单分类: 账单ID=\(billId), 找到 \(categoryIds.count) 个分类")
        return categoryIds
    }
    
    private func deleteBillCategories(billId: UUID) throws {
        let deleteSQL = "DELETE FROM bill_categories WHERE bill_id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        billId.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ 删除账单分类关联失败: \(errorMessage)")
            throw SQLiteError.executeFailed
        }
    }
    
    // MARK: - PaymentMethod Operations
    
    func savePaymentMethod(_ method: PaymentMethodWrapper) async throws {
        let insertSQL = """
        INSERT INTO payment_methods (id, name, transaction_type, account_type, owner_id, 
                                    credit_limit, outstanding_balance, billing_date, balance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        method.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        method.name.withCString { namePtr in
            sqlite3_bind_text(statement, 2, namePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        method.transactionType.rawValue.withCString { typePtr in
            sqlite3_bind_text(statement, 3, typePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        method.accountType.rawValue.withCString { accountPtr in
            sqlite3_bind_text(statement, 4, accountPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        method.ownerId.uuidString.withCString { ownerPtr in
            sqlite3_bind_text(statement, 5, ownerPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        switch method {
        case .credit(let credit):
            "\(credit.creditLimit)".withCString { limitPtr in
                sqlite3_bind_text(statement, 6, limitPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            "\(credit.outstandingBalance)".withCString { balancePtr in
                sqlite3_bind_text(statement, 7, balancePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            sqlite3_bind_int(statement, 8, Int32(credit.billingDate))
            sqlite3_bind_null(statement, 9)
        case .savings(let savings):
            sqlite3_bind_null(statement, 6)
            sqlite3_bind_null(statement, 7)
            sqlite3_bind_null(statement, 8)
            "\(savings.balance)".withCString { balancePtr in
                sqlite3_bind_text(statement, 9, balancePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ 保存支付方式失败: \(errorMessage)")
            print("支付方式: \(method.name), 归属人ID: \(method.ownerId)")
            throw SQLiteError.executeFailed
        }
    }
    
    func fetchPaymentMethods() async throws -> [PaymentMethodWrapper] {
        let querySQL = """
        SELECT id, name, transaction_type, account_type, owner_id, 
               credit_limit, outstanding_balance, billing_date, balance 
        FROM payment_methods;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        var methods: [PaymentMethodWrapper] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
            let name = String(cString: sqlite3_column_text(statement, 1))
            let transactionType = TransactionType(rawValue: String(cString: sqlite3_column_text(statement, 2)))!
            let accountType = AccountType(rawValue: String(cString: sqlite3_column_text(statement, 3)))!
            let ownerId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 4)))!
            
            if accountType == .credit {
                let creditLimit = Decimal(string: String(cString: sqlite3_column_text(statement, 5)))!
                let outstandingBalance = Decimal(string: String(cString: sqlite3_column_text(statement, 6)))!
                let billingDate = Int(sqlite3_column_int(statement, 7))
                
                let credit = CreditMethod(id: id, name: name, transactionType: transactionType,
                                        creditLimit: creditLimit, outstandingBalance: outstandingBalance,
                                        billingDate: billingDate, ownerId: ownerId)
                methods.append(.credit(credit))
            } else {
                let balance = Decimal(string: String(cString: sqlite3_column_text(statement, 8)))!
                
                let savings = SavingsMethod(id: id, name: name, transactionType: transactionType,
                                          balance: balance, ownerId: ownerId)
                methods.append(.savings(savings))
            }
        }
        
        return methods
    }
    
    func updatePaymentMethod(_ method: PaymentMethodWrapper) async throws {
        let updateSQL = """
        UPDATE payment_methods 
        SET name = ?, transaction_type = ?, credit_limit = ?, outstanding_balance = ?, 
            billing_date = ?, balance = ?
        WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        method.name.withCString { namePtr in
            sqlite3_bind_text(statement, 1, namePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        method.transactionType.rawValue.withCString { typePtr in
            sqlite3_bind_text(statement, 2, typePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        switch method {
        case .credit(let credit):
            "\(credit.creditLimit)".withCString { limitPtr in
                sqlite3_bind_text(statement, 3, limitPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            "\(credit.outstandingBalance)".withCString { balancePtr in
                sqlite3_bind_text(statement, 4, balancePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            sqlite3_bind_int(statement, 5, Int32(credit.billingDate))
            sqlite3_bind_null(statement, 6)
        case .savings(let savings):
            sqlite3_bind_null(statement, 3)
            sqlite3_bind_null(statement, 4)
            sqlite3_bind_null(statement, 5)
            "\(savings.balance)".withCString { balancePtr in
                sqlite3_bind_text(statement, 6, balancePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }
        
        method.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 7, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        print("💳 更新支付方式: \(method.name)")
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ 更新支付方式失败: \(errorMessage)")
            throw SQLiteError.executeFailed
        }
        
        print("✅ 支付方式更新成功")
    }
    
    func deletePaymentMethod(_ method: PaymentMethodWrapper) async throws {
        let deleteSQL = "DELETE FROM payment_methods WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        method.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executeFailed
        }
        
        // 检查是否真的删除了记录
        let changes = sqlite3_changes(db)
        if changes == 0 {
            throw SQLiteError.notFound
        }
        
        print("✅ 成功删除支付方式，ID: \(method.id), 影响行数: \(changes)")
    }
    
    func fetchPaymentMethod(by id: UUID) async throws -> PaymentMethodWrapper? {
        let querySQL = """
        SELECT id, name, transaction_type, account_type, owner_id, 
               credit_limit, outstanding_balance, billing_date, balance 
        FROM payment_methods WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            do {
                let id = try getUUID(from: statement, at: 0)
                guard let name = getString(from: statement, at: 1),
                      let typeString = getString(from: statement, at: 2),
                      let transactionType = TransactionType(rawValue: typeString),
                      let accountString = getString(from: statement, at: 3),
                      let accountType = AccountType(rawValue: accountString) else {
                    return nil
                }
                let ownerId = try getUUID(from: statement, at: 4)
                
                if accountType == .credit {
                    let creditLimit = try getDecimal(from: statement, at: 5)
                    let outstandingBalance = try getDecimal(from: statement, at: 6)
                    let billingDate = Int(sqlite3_column_int(statement, 7))
                    
                    let credit = CreditMethod(id: id, name: name, transactionType: transactionType,
                                            creditLimit: creditLimit, outstandingBalance: outstandingBalance,
                                            billingDate: billingDate, ownerId: ownerId)
                    return .credit(credit)
                } else {
                    let balance = try getDecimal(from: statement, at: 8)
                    
                    let savings = SavingsMethod(id: id, name: name, transactionType: transactionType,
                                              balance: balance, ownerId: ownerId)
                    return .savings(savings)
                }
            } catch {
                print("⚠️ 解析支付方式失败: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    // MARK: - Specific PaymentMethod Delete Operations
    
    func deleteCreditMethod(id: UUID) async throws {
        let deleteSQL = "DELETE FROM payment_methods WHERE id = ? AND account_type = 'credit';"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executeFailed
        }
        
        // 检查是否真的删除了记录
        let changes = sqlite3_changes(db)
        if changes == 0 {
            throw SQLiteError.notFound
        }
        
        print("✅ 成功删除信贷方式，ID: \(id)")
    }
    
    func deleteSavingsMethod(id: UUID) async throws {
        let deleteSQL = "DELETE FROM payment_methods WHERE id = ? AND account_type = 'savings';"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executeFailed
        }
        
        // 检查是否真的删除了记录
        let changes = sqlite3_changes(db)
        if changes == 0 {
            throw SQLiteError.notFound
        }
        
        print("✅ 成功删除储蓄方式，ID: \(id)")
    }
    
    // MARK: - Category Operations
    
    func saveCategory(_ category: BillCategory) async throws {
        let insertSQL = "INSERT INTO categories (id, name, transaction_type) VALUES (?, ?, ?);"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        category.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        category.name.withCString { namePtr in
            sqlite3_bind_text(statement, 2, namePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        category.transactionType.rawValue.withCString { typePtr in
            sqlite3_bind_text(statement, 3, typePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        print("  🔍 准备插入: ID=\(category.id.uuidString), name=\(category.name)")
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ 保存分类失败: \(errorMessage)")
            print("分类: \(category.name), ID: \(category.id)")
            
            // 查询当前表中的所有记录
            let querySQL = "SELECT id, name FROM categories;"
            var queryStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, querySQL, -1, &queryStmt, nil) == SQLITE_OK {
                print("📋 当前 categories 表中的记录:")
                while sqlite3_step(queryStmt) == SQLITE_ROW {
                    if let idStr = getString(from: queryStmt, at: 0),
                       let name = getString(from: queryStmt, at: 1) {
                        print("  - ID: \(idStr), name: \(name)")
                    }
                }
                sqlite3_finalize(queryStmt)
            }
            
            throw SQLiteError.executeFailed
        }
        print("  ✅ 插入成功")
    }
    
    func fetchCategories() async throws -> [BillCategory] {
        let querySQL = "SELECT id, name, transaction_type FROM categories;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        var categories: [BillCategory] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = try getUUID(from: statement, at: 0)
            guard let name = getString(from: statement, at: 1),
                  let typeString = getString(from: statement, at: 2),
                  let transactionType = TransactionType(rawValue: typeString) else {
                throw SQLiteError.decodingFailed
            }
            
            let category = BillCategory(id: id, name: name, transactionType: transactionType)
            categories.append(category)
        }
        
        return categories
    }
    
    func updateCategory(_ category: BillCategory) async throws {
        let updateSQL = "UPDATE categories SET name = ?, transaction_type = ? WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, category.name, -1, nil)
        sqlite3_bind_text(statement, 2, category.transactionType.rawValue, -1, nil)
        sqlite3_bind_text(statement, 3, category.id.uuidString, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executeFailed
        }
    }
    
    func deleteCategory(_ category: BillCategory) async throws {
        let deleteSQL = "DELETE FROM categories WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        category.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executeFailed
        }
        
        // 检查是否真的删除了记录
        let changes = sqlite3_changes(db)
        if changes == 0 {
            throw SQLiteError.notFound
        }
        
        print("✅ 成功删除分类，ID: \(category.id), 影响行数: \(changes)")
    }
    
    func fetchCategory(by id: UUID) async throws -> BillCategory? {
        let querySQL = "SELECT id, name, transaction_type FROM categories WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            do {
                let id = try getUUID(from: statement, at: 0)
                guard let name = getString(from: statement, at: 1),
                      let typeString = getString(from: statement, at: 2),
                      let transactionType = TransactionType(rawValue: typeString) else {
                    return nil
                }
                
                return BillCategory(id: id, name: name, transactionType: transactionType)
            } catch {
                print("⚠️ 解析分类失败: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    // MARK: - Owner Operations
    
    func saveOwner(_ owner: Owner) async throws {
        let insertSQL = "INSERT INTO owners (id, name) VALUES (?, ?);"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        owner.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        owner.name.withCString { namePtr in
            sqlite3_bind_text(statement, 2, namePtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ 保存归属人失败: \(errorMessage)")
            print("归属人: \(owner.name), ID: \(owner.id)")
            throw SQLiteError.executeFailed
        }
    }
    
    func fetchOwners() async throws -> [Owner] {
        let querySQL = "SELECT id, name FROM owners;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        var owners: [Owner] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            do {
                let id = try getUUID(from: statement, at: 0)
                guard let name = getString(from: statement, at: 1) else {
                    continue
                }
                
                let owner = Owner(id: id, name: name)
                owners.append(owner)
            } catch {
                print("⚠️ 跳过无效的归属人记录")
                continue
            }
        }
        
        return owners
    }
    
    func updateOwner(_ owner: Owner) async throws {
        let updateSQL = "UPDATE owners SET name = ? WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, owner.name, -1, nil)
        sqlite3_bind_text(statement, 2, owner.id.uuidString, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executeFailed
        }
    }
    
    func deleteOwner(_ owner: Owner) async throws {
        let deleteSQL = "DELETE FROM owners WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        owner.id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executeFailed
        }
        
        // 检查是否真的删除了记录
        let changes = sqlite3_changes(db)
        if changes == 0 {
            throw SQLiteError.notFound
        }
        
        print("✅ 成功删除归属人，ID: \(owner.id), 影响行数: \(changes)")
    }
    
    func fetchOwner(by id: UUID) async throws -> Owner? {
        let querySQL = "SELECT id, name FROM owners WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }
        
        id.uuidString.withCString { idPtr in
            sqlite3_bind_text(statement, 1, idPtr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            do {
                let id = try getUUID(from: statement, at: 0)
                guard let name = getString(from: statement, at: 1) else {
                    return nil
                }
                
                return Owner(id: id, name: name)
            } catch {
                print("⚠️ 解析归属人失败: \(error)")
                return nil
            }
        }
        
        return nil
    }
}

// MARK: - SQLite Errors

enum SQLiteError: Error, LocalizedError {
    case databasePathError
    case openDatabaseFailed
    case createTableFailed
    case prepareFailed
    case executeFailed
    case notFound
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .databasePathError:
            return "无法获取数据库路径"
        case .openDatabaseFailed:
            return "打开数据库失败"
        case .createTableFailed:
            return "创建数据表失败"
        case .prepareFailed:
            return "准备SQL语句失败"
        case .executeFailed:
            return "执行SQL语句失败"
        case .notFound:
            return "数据不存在"
        case .decodingFailed:
            return "数据解码失败"
        }
    }
}
