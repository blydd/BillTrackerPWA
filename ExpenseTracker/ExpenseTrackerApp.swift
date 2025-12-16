import SwiftUI
import UserNotifications
import Foundation
import WidgetKit

// MARK: - 通知名称定义
extension Notification.Name {
    static let billDataChanged = Notification.Name("billDataChanged")
}

@main
struct ExpenseTrackerApp: App {
    private let repository: DataRepository
    
    init() {
        // 初始化 SQLite 数据仓库
        self.repository = Self.setupRepository()
    }
    
    var body: some Scene {
        WindowGroup {
            // 临时禁用云同步以简化 IAP 功能
            ContentView(repository: repository)
                .onOpenURL { url in
                    handleQuickExpense(url: url)
                }
            
            // 如果需要云同步，取消下面的注释并注释掉上面的代码
            /*
            #if targetEnvironment(simulator)
            // 模拟器：不使用云同步
            ContentView(repository: repository)
            #else
            // 真机：使用云同步
            ContentViewWithSync(repository: repository)
            #endif
            */
        }
    }
    
    /// 设置数据仓库
    private static func setupRepository() -> DataRepository {
        do {
            let sqliteRepo = try SQLiteRepository()
            print("✅ SQLite 数据库初始化成功")
            return sqliteRepo
        } catch {
            print("❌ SQLite 初始化失败: \(error)")
            print("⚠️ 回退到 UserDefaults")
            // 回退到 UserDefaults 而不是崩溃
            return UserDefaultsRepository()
        }
    }
    
    /// 处理来自小组件的快速记账 URL
    private func handleQuickExpense(url: URL) {
        guard url.scheme == "expensetracker",
              url.host == "quick",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let itemName = components.queryItems?.first(where: { $0.name == "item" })?.value else {
            print("❌ 无效的快速记账 URL: \(url)")
            return
        }
        
        print("🎯 收到快速记账请求: \(itemName)")
        
        // 使用主队列确保 UI 更新和数据操作的稳定性
        DispatchQueue.main.async {
            Task {
                await self.performQuickExpenseWithRetry(itemName: itemName)
            }
        }
    }
    
    /// 执行快速记账（带重试机制）
    private func performQuickExpenseWithRetry(itemName: String) async {
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry < maxRetries {
            let success = await performQuickExpense(itemName: itemName)
            if success {
                return
            }
            
            currentRetry += 1
            if currentRetry < maxRetries {
                print("⚠️ 快速记账失败，第 \(currentRetry) 次重试...")
                // 等待一小段时间后重试
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
        }
        
        print("❌ 快速记账最终失败，已重试 \(maxRetries) 次")
    }
    
    /// 执行快速记账
    private func performQuickExpense(itemName: String) async -> Bool {
        // 预设的快速记账项目
        let quickItems = [
            "早餐": (amount: Decimal(15), category: "食"),
            "午餐": (amount: Decimal(25), category: "食"),
            "晚餐": (amount: Decimal(35), category: "食"),
            "咖啡": (amount: Decimal(20), category: "娱乐"),
            "交通": (amount: Decimal(10), category: "行"),
            "购物": (amount: Decimal(100), category: "购物")
        ]
        
        guard let item = quickItems[itemName] else {
            print("❌ 未找到快速记账项目: \(itemName)")
            return false
        }
        
        do {
            // 添加延迟确保应用完全启动
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            
            print("🔍 开始获取数据库数据...")
            
            // 获取默认数据
            let owners = try await repository.fetchOwners()
            let paymentMethods = try await repository.fetchPaymentMethods()
            let categories = try await repository.fetchCategories()
            
            print("📊 数据库状态：归属人 \(owners.count) 个，支付方式 \(paymentMethods.count) 个，类别 \(categories.count) 个")
            
            // 如果数据库为空，尝试自动初始化
            if owners.isEmpty || paymentMethods.isEmpty || categories.isEmpty {
                print("⚠️ 数据库数据不完整，尝试自动初始化...")
                let initSuccess = await autoInitializeData()
                if !initSuccess {
                    print("❌ 自动初始化失败")
                    await sendErrorNotification(message: "数据库未初始化，请到设置→系统→初始化")
                    return false
                }
                
                // 重新获取数据
                let newOwners = try await repository.fetchOwners()
                let newPaymentMethods = try await repository.fetchPaymentMethods()
                let newCategories = try await repository.fetchCategories()
                
                print("🔄 重新获取数据：归属人 \(newOwners.count) 个，支付方式 \(newPaymentMethods.count) 个，类别 \(newCategories.count) 个")
                
                guard let defaultOwner = newOwners.first else {
                    print("❌ 初始化后仍然没有找到归属人")
                    await sendErrorNotification(message: "自动初始化失败，请手动初始化")
                    return false
                }
                
                // 使用新数据继续处理
                return await processQuickExpense(
                    itemName: itemName, 
                    item: item, 
                    owner: defaultOwner, 
                    paymentMethods: newPaymentMethods, 
                    categories: newCategories
                )
            }
            
            guard let defaultOwner = owners.first else {
                print("❌ 没有找到归属人")
                await sendErrorNotification(message: "请先初始化应用数据")
                return false
            }
            
            // 使用现有数据处理
            return await processQuickExpense(
                itemName: itemName, 
                item: item, 
                owner: defaultOwner, 
                paymentMethods: paymentMethods, 
                categories: categories
            )
            
        } catch {
            print("❌ 快速记账失败：\(error)")
            await sendErrorNotification(message: "记账失败：\(error.localizedDescription)")
            return false
        }
    }
    
    /// 自动初始化数据库数据
    private func autoInitializeData() async -> Bool {
        do {
            print("🔧 开始自动初始化数据库...")
            
            // 创建默认归属人
            let defaultOwner = Owner(name: "我", createdAt: Date(), updatedAt: Date())
            try await repository.saveOwner(defaultOwner)
            print("✅ 创建默认归属人：\(defaultOwner.name)")
            
            // 创建默认支付方式
            let defaultPaymentMethods: [PaymentMethodWrapper] = [
                .savings(SavingsMethod(
                    name: "微信支付",
                    transactionType: .expense,
                    balance: Decimal(1000),
                    ownerId: defaultOwner.id
                )),
                .savings(SavingsMethod(
                    name: "支付宝",
                    transactionType: .expense,
                    balance: Decimal(800),
                    ownerId: defaultOwner.id
                )),
                .savings(SavingsMethod(
                    name: "现金",
                    transactionType: .expense,
                    balance: Decimal(200),
                    ownerId: defaultOwner.id
                ))
            ]
            
            for paymentMethod in defaultPaymentMethods {
                try await repository.savePaymentMethod(paymentMethod)
                print("✅ 创建支付方式：\(paymentMethod.name)")
            }
            
            // 创建默认类别
            let defaultCategories = [
                BillCategory(name: "食", createdAt: Date(), updatedAt: Date()),
                BillCategory(name: "行", createdAt: Date(), updatedAt: Date()),
                BillCategory(name: "娱乐", createdAt: Date(), updatedAt: Date()),
                BillCategory(name: "购物", createdAt: Date(), updatedAt: Date()),
                BillCategory(name: "医疗", createdAt: Date(), updatedAt: Date()),
                BillCategory(name: "其他", createdAt: Date(), updatedAt: Date())
            ]
            
            for category in defaultCategories {
                try await repository.saveCategory(category)
                print("✅ 创建类别：\(category.name)")
            }
            
            print("🎉 自动初始化完成！")
            return true
            
        } catch {
            print("❌ 自动初始化失败：\(error)")
            return false
        }
    }
    
    /// 处理快速记账的核心逻辑
    private func processQuickExpense(
        itemName: String,
        item: (amount: Decimal, category: String),
        owner: Owner,
        paymentMethods: [PaymentMethodWrapper],
        categories: [BillCategory]
    ) async -> Bool {
        do {
            // 智能选择支付方式
            let ownerPaymentMethods = paymentMethods.filter { $0.ownerId == owner.id }
            guard let defaultPaymentMethod = selectBestPaymentMethod(
                paymentMethods: ownerPaymentMethods, 
                amount: item.amount, 
                category: item.category
            ) else {
                print("❌ 没有找到支付方式")
                await sendErrorNotification(message: "请先添加支付方式")
                return false
            }
            
            print("💳 选择支付方式：\(defaultPaymentMethod.name)")
            
            // 确保有类别数据
            guard !categories.isEmpty else {
                print("❌ 没有找到账单类别")
                await sendErrorNotification(message: "请先添加账单类别")
                return false
            }
            
            // 查找匹配的类别
            let matchedCategory = categories.first { category in
                category.name.contains(item.category) || item.category.contains(category.name)
            }
            
            let categoryId = matchedCategory?.id ?? categories.first?.id ?? UUID()
            let categoryName = matchedCategory?.name ?? categories.first?.name ?? "未知"
            
            print("📂 选择类别：\(categoryName)")
            
            // 创建账单
            let bill = Bill(
                amount: -abs(item.amount), // 支出为负数
                paymentMethodId: defaultPaymentMethod.id,
                categoryIds: [categoryId],
                ownerId: owner.id,
                note: "🚀 小组件快速记账：\(itemName)",
                createdAt: Date(),
                updatedAt: Date()
            )
            
            print("💾 准备保存账单：\(itemName) ¥\(item.amount)")
            
            // 保存账单
            try await repository.saveBill(bill)
            
            // 更新支付方式余额
            print("💳 更新支付方式余额：\(defaultPaymentMethod.name)")
            var updatedPaymentMethod = defaultPaymentMethod
            
            switch updatedPaymentMethod {
            case .savings(var savingsMethod):
                // 储蓄账户：直接更新余额
                let oldBalance = savingsMethod.balance
                savingsMethod.balance += bill.amount // amount 为负数时会减少余额
                updatedPaymentMethod = .savings(savingsMethod)
                print("💰 \(defaultPaymentMethod.name) 余额更新：¥\(oldBalance) → ¥\(savingsMethod.balance)")
                
            case .credit(var creditMethod):
                // 信用卡：更新欠费金额
                let oldBalance = creditMethod.outstandingBalance
                creditMethod.outstandingBalance -= bill.amount // amount 为负数时会增加欠费
                updatedPaymentMethod = .credit(creditMethod)
                
                let availableCredit = creditMethod.creditLimit - creditMethod.outstandingBalance
                print("💳 \(defaultPaymentMethod.name) 欠费更新：¥\(oldBalance) → ¥\(creditMethod.outstandingBalance)")
                print("💳 可用额度：¥\(availableCredit)")
            }
            
            // 更新支付方式
            try await repository.updatePaymentMethod(updatedPaymentMethod)
            print("✅ 支付方式余额更新完成")
            
            print("✅ 快速记账成功：\(itemName) \(item.amount) 元")
            
            // 发送成功通知
            await sendQuickExpenseNotification(itemName: itemName, amount: item.amount)
            
            // 通知 UI 刷新（发送通知给主界面）
            await MainActor.run {
                NotificationCenter.default.post(name: .billDataChanged, object: nil)
            }
            
            return true
            
        } catch {
            print("❌ 处理快速记账失败：\(error)")
            await sendErrorNotification(message: "记账失败：\(error.localizedDescription)")
            return false
        }
    }
    
    /// 智能选择最佳支付方式
    private func selectBestPaymentMethod(paymentMethods: [PaymentMethodWrapper], amount: Decimal, category: String) -> PaymentMethodWrapper? {
        guard !paymentMethods.isEmpty else { return nil }
        
        // 如果只有一个支付方式，直接返回
        if paymentMethods.count == 1 {
            return paymentMethods.first
        }
        
        // 根据金额选择支付方式
        let amountValue = NSDecimalNumber(decimal: amount).doubleValue
        
        // 小额支出（<50元）优先选择现金类
        if amountValue < 50 {
            if let cashMethod = paymentMethods.first(where: { method in
                method.name.contains("现金") || method.name.contains("零钱") || 
                method.name.contains("微信") || method.name.contains("支付宝")
            }) {
                return cashMethod
            }
        }
        
        // 大额支出（>=50元）优先选择信用卡
        if amountValue >= 50 {
            if let creditMethod = paymentMethods.first(where: { method in
                method.name.contains("信用卡") || method.name.contains("花呗") || method.name.contains("白条")
            }) {
                return creditMethod
            }
        }
        
        // 根据类别选择支付方式
        switch category {
        case "食":
            if let foodMethod = paymentMethods.first(where: { method in
                method.name.contains("微信") || method.name.contains("支付宝") || method.name.contains("美团")
            }) {
                return foodMethod
            }
        case "行":
            if let transportMethod = paymentMethods.first(where: { method in
                method.name.contains("交通") || method.name.contains("地铁") || 
                method.name.contains("滴滴") || method.name.contains("微信") || method.name.contains("支付宝")
            }) {
                return transportMethod
            }
        case "购物":
            if let shoppingMethod = paymentMethods.first(where: { method in
                method.name.contains("信用卡") || method.name.contains("花呗") || method.name.contains("白条")
            }) {
                return shoppingMethod
            }
        default:
            break
        }
        
        // 默认选择第一个可用的支付方式
        return paymentMethods.first
    }
    

    /// 发送错误通知
    private func sendErrorNotification(message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "快速记账失败"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "quick_expense_error_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ 发送错误通知失败: \(error)")
        }
    }
    
    /// 发送快速记账成功通知
    private func sendQuickExpenseNotification(itemName: String, amount: Decimal) async {
        let content = UNMutableNotificationContent()
        content.title = "✅ 记账成功"
        content.body = "已记录 \(itemName) ¥\(amount)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "quick_expense_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ 发送通知失败: \(error)")
        }
    }
    

}

struct ContentView: View {
    let repository: DataRepository
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        TabView {
            NavigationView {
                BillListView(repository: repository)
            }
            .tabItem {
                Label("账单", systemImage: "doc.text")
            }
            
            NavigationView {
                StatisticsView(repository: repository)
            }
            .tabItem {
                Label("统计", systemImage: "chart.bar")
            }
            
            NavigationView {
                SettingsView(repository: repository)
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .environmentObject(subscriptionManager)
        .task {
            await subscriptionManager.refreshSubscriptionStatus()
        }
    }
}

struct SettingsView: View {
    let repository: DataRepository
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPurchase = false
    
    var body: some View {
        List {
            // 订阅状态
            Section("订阅状态") {
                HStack {
                    Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "star")
                        .foregroundColor(subscriptionManager.isProUser ? .yellow : .gray)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionManager.subscriptionStatus.displayStatus)
                            .font(.headline)
                        
                        if !subscriptionManager.isProUser {
                            Text("升级解锁更多功能")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !subscriptionManager.isProUser {
                        Button("升级") {
                            showingPurchase = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            // 临时禁用云同步 Section 以简化 IAP 功能
            // 如果需要云同步，取消下面的注释
            /*
            #if !targetEnvironment(simulator)
            // 云同步状态（仅在真机上显示）
            CloudSyncSection()
            #endif
            */
            
            Section("快速功能") {
                NavigationLink("小组件配置") {
                    SimpleWidgetConfigView()
                }
            }
            
            Section("数据管理") {
                NavigationLink("账单类型管理") {
                    CategoryManagementView(repository: repository)
                }
                
                NavigationLink("归属人管理") {
                    OwnerManagementView(repository: repository)
                }
                
                NavigationLink("支付方式管理") {
                    PaymentMethodListView(repository: repository)
                }
                
                NavigationLink("导入账单") {
                    BillImportView(repository: repository)
                }
                
                NavigationLink("数据库导出") {
                    DatabaseExportView()
                }
            }
            
            Section("系统") {
                NavigationLink {
                    InitializationView(repository: repository)
                } label: {
                    HStack {
                        Text("初始化")
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                    }
                }
                
                NavigationLink {
                    DatabaseInfoView()
                } label: {
                    HStack {
                        Text("数据库信息")
                        Spacer()
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                NavigationLink {
                    DebugView(repository: repository)
                } label: {
                    HStack {
                        Text("调试信息")
                        Spacer()
                        Image(systemName: "ladybug")
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showingPurchase) {
            PurchaseView()
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }
}

// MARK: - Cloud Sync Section (真机专用)

struct CloudSyncSection: View {
    @EnvironmentObject var autoSyncManager: AutoSyncManager
    
    var body: some View {
        Section {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(autoSyncManager.isSyncing ? .blue : .gray)
                Text("iCloud 同步")
                Spacer()
                if autoSyncManager.isSyncing {
                    ProgressView()
                } else if let lastSync = autoSyncManager.lastSyncDate {
                    Text(timeAgo(lastSync))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("未同步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = autoSyncManager.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        Section("云服务") {
            NavigationLink {
                CloudSyncSettingsView()
            } label: {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.blue)
                    Text("云同步设置")
                    Spacer()
                    if autoSyncManager.isSyncing {
                        ProgressView()
                    }
                }
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }
}

// MARK: - Content View with Sync (真机版本)

struct ContentViewWithSync: View {
    let repository: DataRepository
    @StateObject private var autoSyncManager: AutoSyncManager
    
    init(repository: DataRepository) {
        self.repository = repository
        _autoSyncManager = StateObject(wrappedValue: AutoSyncManager(repository: repository))
    }
    
    var body: some View {
        ContentView(repository: repository)
            .environmentObject(autoSyncManager)
    }
}

// MARK: - 数据模型

/// 最近记账项目（用于应用内显示）
struct RecentExpenseItem: Identifiable {
    let id: UUID
    let title: String
    let amount: Decimal
    let date: Date
    let icon: String
    let color: String
}

// MARK: - 简化的小组件配置视图

struct SimpleWidgetConfigView: View {
    @State private var quickExpenseItems = [
        ("早餐", "15", "cup.and.saucer.fill", "orange"),
        ("午餐", "25", "fork.knife", "green"),
        ("晚餐", "35", "takeoutbag.and.cup.and.straw.fill", "red"),
        ("咖啡", "20", "cup.and.saucer.fill", "brown"),
        ("交通", "10", "car.fill", "blue"),
        ("购物", "100", "bag.fill", "purple")
    ]
    @State private var showingResultAlert = false
    @State private var resultMessage = ""

    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var processingItem: String?
    
    private let repository: DataRepository
    
    init() {
        do {
            self.repository = try SQLiteRepository()
        } catch {
            self.repository = UserDefaultsRepository()
        }
    }
    
    var body: some View {
        List {
            
            // 快速记账项目管理
            Section {
                ForEach(quickExpenseItems.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: quickExpenseItems[index].2)
                            .font(.title2)
                            .foregroundColor(colorFromName(quickExpenseItems[index].3))
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("项目名称", text: Binding(
                                get: { quickExpenseItems[index].0 },
                                set: { quickExpenseItems[index].0 = $0 }
                            ))
                            .font(.headline)
                            
                            HStack {
                                Text("¥")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("金额", text: Binding(
                                    get: { quickExpenseItems[index].1 },
                                    set: { quickExpenseItems[index].1 = $0 }
                                ))
                                .font(.caption)
                                .keyboardType(.decimalPad)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            performQuickExpense(itemName: quickExpenseItems[index].0)
                        } label: {
                            if processingItem == quickExpenseItems[index].0 {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                        }
                        .disabled(processingItem != nil)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("快速记账项目")
            } footer: {
                Text("可以编辑项目名称和金额，点击播放按钮进行快速记账")
                    .font(.caption)
            }

            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("如何添加小组件：")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1.")
                                .fontWeight(.medium)
                            Text("长按主屏幕空白处")
                        }
                        
                        HStack {
                            Text("2.")
                                .fontWeight(.medium)
                            Text("点击左上角的 + 号")
                        }
                        
                        HStack {
                            Text("3.")
                                .fontWeight(.medium)
                            Text("搜索\"标签记账\"")
                        }
                        
                        HStack {
                            Text("4.")
                                .fontWeight(.medium)
                            Text("选择小组件尺寸并添加")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("使用说明")
            }
        }
        .navigationTitle("快速记账")
        .navigationBarTitleDisplayMode(.inline)
        .alert("记账结果", isPresented: $showingResultAlert) {
            Button("确定") { }
        } message: {
            Text(resultMessage)
        }
        .overlay(
            // 成功提示 Toast
            VStack {
                if showingSuccessToast {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(successMessage)
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 50)
            .animation(.easeInOut(duration: 0.3), value: showingSuccessToast)
        )

    }
    
    /// 根据颜色名称获取颜色
    private func colorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "brown": return .brown
        case "blue": return .blue
        case "purple": return .purple
        default: return .primary
        }
    }
    

    

    
    /// 时间格式化
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }
    
    /// 快速记账功能
    private func performQuickExpense(itemName: String) {
        // 防止重复点击
        guard processingItem == nil else { return }
        
        processingItem = itemName
        
        // 直接调用快速记账函数，避免 URL Scheme 问题
        Task {
            let result = await performQuickExpenseAction(itemName: itemName)
            
            await MainActor.run {
                processingItem = nil
                
                if result.success {
                    // 显示成功提示
                    successMessage = "✅ \(itemName) 记账成功！"
                    showingSuccessToast = true
                    
                    // 3秒后隐藏提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingSuccessToast = false
                    }
                    

                } else {
                    // 显示错误详情
                    resultMessage = result.message
                    showingResultAlert = true
                }
            }
        }
    }
    
    /// 智能选择最佳支付方式
    private func selectBestPaymentMethod(paymentMethods: [PaymentMethodWrapper], ownerId: UUID, amount: Decimal, category: String) -> PaymentMethodWrapper? {
        let ownerPaymentMethods = paymentMethods.filter { $0.ownerId == ownerId }
        
        guard !ownerPaymentMethods.isEmpty else { return nil }
        
        // 如果只有一个支付方式，直接返回
        if ownerPaymentMethods.count == 1 {
            return ownerPaymentMethods.first
        }
        
        // 根据金额选择支付方式
        let amountValue = NSDecimalNumber(decimal: amount).doubleValue
        
        // 小额支出（<50元）优先选择现金类
        if amountValue < 50 {
            if let cashMethod = ownerPaymentMethods.first(where: { method in
                method.name.contains("现金") || method.name.contains("零钱") || method.name.contains("微信") || method.name.contains("支付宝")
            }) {
                return cashMethod
            }
        }
        
        // 大额支出（>=50元）优先选择信用卡
        if amountValue >= 50 {
            if let creditMethod = ownerPaymentMethods.first(where: { method in
                method.name.contains("信用卡") || method.name.contains("花呗") || method.name.contains("白条")
            }) {
                return creditMethod
            }
        }
        
        // 根据类别选择支付方式
        switch category {
        case "食":
            // 餐饮类优先选择日常支付方式
            if let foodMethod = ownerPaymentMethods.first(where: { method in
                method.name.contains("微信") || method.name.contains("支付宝") || method.name.contains("美团")
            }) {
                return foodMethod
            }
        case "行":
            // 交通类优先选择交通卡或移动支付
            if let transportMethod = ownerPaymentMethods.first(where: { method in
                method.name.contains("交通") || method.name.contains("地铁") || method.name.contains("滴滴") || method.name.contains("微信") || method.name.contains("支付宝")
            }) {
                return transportMethod
            }
        case "购物":
            // 购物类优先选择信用卡或花呗
            if let shoppingMethod = ownerPaymentMethods.first(where: { method in
                method.name.contains("信用卡") || method.name.contains("花呗") || method.name.contains("白条")
            }) {
                return shoppingMethod
            }
        default:
            break
        }
        
        // 默认选择第一个可用的支付方式
        return ownerPaymentMethods.first
    }
    
    /// 获取项目对应的类别关键词
    private func getCategoryKeyword(for itemName: String) -> String {
        let categoryMappings: [String: String] = [
            "早餐": "食",
            "午餐": "食", 
            "晚餐": "食",
            "夜宵": "食",
            "零食": "食",
            "咖啡": "娱乐",
            "奶茶": "娱乐",
            "饮料": "娱乐",
            "交通": "行",
            "打车": "行",
            "地铁": "行",
            "公交": "行",
            "购物": "购物",
            "超市": "购物",
            "日用品": "购物",
            "衣服": "购物",
            "电影": "娱乐",
            "游戏": "娱乐",
            "运动": "娱乐",
            "医疗": "医疗",
            "药品": "医疗",
            "看病": "医疗"
        ]
        
        // 精确匹配
        if let category = categoryMappings[itemName] {
            return category
        }
        
        // 模糊匹配
        for (keyword, category) in categoryMappings {
            if itemName.contains(keyword) || keyword.contains(itemName) {
                return category
            }
        }
        
        // 默认类别
        return "食"
    }
    
    /// 执行快速记账
    private func performQuickExpenseAction(itemName: String) async -> (success: Bool, message: String) {
        // 从当前编辑的快速记账项目中查找
        guard let itemTuple = quickExpenseItems.first(where: { $0.0 == itemName }) else {
            print("❌ 未找到快速记账项目: \(itemName)")
            return (false, "❌ 未找到快速记账项目：\(itemName)")
        }
        
        // 解析金额和类别
        guard let amount = Decimal(string: itemTuple.1) else {
            return (false, "❌ 金额格式错误：\(itemTuple.1)")
        }
        
        // 智能匹配类别
        let categoryKeyword = getCategoryKeyword(for: itemName)
        let item = (amount: amount, category: categoryKeyword)
        
        do {
            // 创建临时的 repository 实例
            let repository = try SQLiteRepository()
            
            // 获取默认数据
            let owners = try await repository.fetchOwners()
            let paymentMethods = try await repository.fetchPaymentMethods()
            let categories = try await repository.fetchCategories()
            
            // 检查是否有归属人
            guard let defaultOwner = owners.first else {
                print("❌ 没有找到归属人")
                return (false, """
                ❌ 快速记账失败：数据库未初始化
                
                请先完成以下操作之一：
                
                1️⃣ 应用初始化：
                   设置 → 系统 → 初始化
                
                2️⃣ 手动创建数据：
                   设置 → 归属人管理 → 添加归属人
                   设置 → 支付方式管理 → 添加支付方式
                
                完成后再试试快速记账功能！
                """)
            }
            
            // 智能选择支付方式
            guard let defaultPaymentMethod = selectBestPaymentMethod(
                paymentMethods: paymentMethods, 
                ownerId: defaultOwner.id, 
                amount: item.amount, 
                category: item.category
            ) else {
                print("❌ 没有找到支付方式")
                return (false, """
                ❌ 快速记账失败：缺少支付方式
                
                请先添加支付方式：
                设置 → 支付方式管理 → 添加支付方式
                
                或者重新初始化应用：
                设置 → 系统 → 初始化
                """)
            }
            
            // 检查是否有类别
            if categories.isEmpty {
                print("❌ 没有找到账单类别")
                return (false, """
                ❌ 快速记账失败：缺少账单类别
                
                请先添加账单类别：
                设置 → 账单类型管理 → 添加类别
                
                或者重新初始化应用：
                设置 → 系统 → 初始化
                """)
            }
            
            // 查找匹配的类别
            let matchedCategory = categories.first { category in
                category.name.contains(item.category) || item.category.contains(category.name)
            }
            
            let categoryId = matchedCategory?.id ?? categories.first?.id ?? UUID()
            
            // 创建账单
            let bill = Bill(
                amount: -abs(item.amount), // 支出为负数
                paymentMethodId: defaultPaymentMethod.id,
                categoryIds: [categoryId],
                ownerId: defaultOwner.id,
                note: "🚀 快速记账：\(itemName)",
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // 保存账单
            try await repository.saveBill(bill)
            
            // 更新支付方式余额
            print("💳 更新支付方式余额：\(defaultPaymentMethod.name)")
            var updatedPaymentMethod = defaultPaymentMethod
            
            switch updatedPaymentMethod {
            case .savings(var savingsMethod):
                let oldBalance = savingsMethod.balance
                savingsMethod.balance += bill.amount
                updatedPaymentMethod = .savings(savingsMethod)
                print("💰 \(defaultPaymentMethod.name) 余额更新：¥\(oldBalance) → ¥\(savingsMethod.balance)")
                
            case .credit(var creditMethod):
                let oldBalance = creditMethod.outstandingBalance
                creditMethod.outstandingBalance -= bill.amount
                updatedPaymentMethod = .credit(creditMethod)
                
                let availableCredit = creditMethod.creditLimit - creditMethod.outstandingBalance
                print("💳 \(defaultPaymentMethod.name) 欠费更新：¥\(oldBalance) → ¥\(creditMethod.outstandingBalance)")
            }
            
            try await repository.updatePaymentMethod(updatedPaymentMethod)
            print("✅ 支付方式余额更新完成")
            
            print("✅ 快速记账成功：\(itemName) \(item.amount) 元")
            
            return (true, """
            ✅ 快速记账成功！
            
            📝 记录详情：
            • 项目：\(itemName)
            • 金额：¥\(item.amount)
            • 类别：\(item.category)
            • 支付方式：\(defaultPaymentMethod.name)
            • 归属人：\(defaultOwner.name)
            
            请查看账单列表确认记录已添加。
            """)
            
        } catch {
            print("❌ 快速记账失败：\(error)")
            return (false, """
            ❌ 快速记账失败：系统错误
            
            错误信息：\(error.localizedDescription)
            
            建议解决方案：
            1️⃣ 重新初始化应用：设置 → 系统 → 初始化
            2️⃣ 重启应用后再试
            3️⃣ 检查数据库权限
            """)
        }
    }
}

// MARK: - 小组件定义

/// 快速记账小组件
struct QuickExpenseWidget: Widget {
    let kind: String = "QuickExpenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickExpenseProvider()) { entry in
            QuickExpenseWidgetView(entry: entry)
        }
        .configurationDisplayName("标签记账")
        .description("快速记录日常支出")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 小组件数据提供器
struct QuickExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickExpenseEntry {
        QuickExpenseEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickExpenseEntry) -> ()) {
        let entry = QuickExpenseEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = QuickExpenseEntry(date: currentDate)
        
        // 每小时更新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

/// 小组件时间线条目
struct QuickExpenseEntry: TimelineEntry {
    let date: Date
}

/// 小组件视图
struct QuickExpenseWidgetView: View {
    var entry: QuickExpenseProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallQuickExpenseView()
        case .systemMedium:
            MediumQuickExpenseView()
        default:
            SmallQuickExpenseView()
        }
    }
}

/// 小尺寸小组件视图
struct SmallQuickExpenseView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("快速记账")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            Link(destination: URL(string: "expensetracker://quick?item=早餐")!) {
                VStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("早餐")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("¥15")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
    }
}

/// 中等尺寸小组件视图
struct MediumQuickExpenseView: View {
    let quickItems = [
        ("早餐", "15", "cup.and.saucer.fill", Color.orange),
        ("午餐", "25", "fork.knife", Color.green),
        ("交通", "10", "car.fill", Color.blue),
        ("咖啡", "20", "cup.and.saucer.fill", Color.brown)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
                Text("快速记账")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(quickItems.enumerated()), id: \.offset) { index, item in
                    Link(destination: URL(string: "expensetracker://quick?item=\(item.0)")!) {
                        VStack(spacing: 4) {
                            Image(systemName: item.2)
                                .font(.title2)
                                .foregroundColor(item.3)
                            
                            Text(item.0)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Text("¥\(item.1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.systemBackground))
    }
}

// MARK: - 调试视图

struct DebugView: View {
    let repository: DataRepository
    @State private var debugInfo = "点击按钮开始调试...\n"
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(debugInfo)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                Button("检查数据库状态") {
                    checkDatabaseStatus()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Button("快速记账演示") {
                    performQuickExpenseDemo()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button("清空调试信息") {
                    debugInfo = "调试信息已清空\n"
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            
            if isLoading {
                ProgressView("处理中...")
                    .padding()
            }
        }
        .padding()
        .navigationTitle("调试信息")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addDebugInfo(_ info: String) {
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "HH:mm:ss"
        }.string(from: Date())
        
        debugInfo += "[\(timestamp)] \(info)\n"
    }
    
    private func checkDatabaseStatus() {
        isLoading = true
        addDebugInfo("🔍 开始检查数据库状态...")
        
        Task {
            do {
                let owners = try await repository.fetchOwners()
                let paymentMethods = try await repository.fetchPaymentMethods()
                let categories = try await repository.fetchCategories()
                let bills = try await repository.fetchBills()
                
                await MainActor.run {
                    addDebugInfo("📊 归属人: \(owners.count) 个")
                    for owner in owners {
                        addDebugInfo("  - \(owner.name) (ID: \(owner.id))")
                    }
                    
                    addDebugInfo("💳 支付方式: \(paymentMethods.count) 个")
                    for pm in paymentMethods {
                        addDebugInfo("  - \(pm.name): ¥\(pm.balance)")
                    }
                    
                    addDebugInfo("📂 类别: \(categories.count) 个")
                    for category in categories {
                        addDebugInfo("  - \(category.name)")
                    }
                    
                    addDebugInfo("📝 账单: \(bills.count) 条")
                    if bills.count > 0 {
                        addDebugInfo("最近的账单:")
                        for bill in bills.prefix(3) {
                            addDebugInfo("  - ¥\(bill.amount) (\(bill.note ?? "无备注"))")
                        }
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    addDebugInfo("❌ 检查失败: \(error)")
                    isLoading = false
                }
            }
        }
    }
    
    private func performQuickExpenseDemo() {
        isLoading = true
        addDebugInfo("🚀 开始快速记账演示...")
        addDebugInfo("📱 模拟URL: expensetracker://quick?item=早餐")
        addDebugInfo("ℹ️ 请查看Xcode控制台输出获取详细信息")
        addDebugInfo("ℹ️ 或者直接点击小组件进行快速记账")
        
        Task {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}