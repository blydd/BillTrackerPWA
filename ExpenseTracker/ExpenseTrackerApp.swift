import SwiftUI

@main
struct ExpenseTrackerApp: App {
    private let repository: DataRepository
    
    init() {
        // 初始化 SQLite 数据仓库
        self.repository = Self.setupRepository()
    }
    
    var body: some Scene {
        WindowGroup {
            // 临时禁用云同步以测试 IAP 功能
            ContentView(repository: repository)
            
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
            
            // 临时禁用云同步 Section 以测试 IAP 功能
            // 如果需要云同步，取消下面的注释
            /*
            #if !targetEnvironment(simulator)
            // 云同步状态（仅在真机上显示）
            CloudSyncSection()
            #endif
            */
            
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
