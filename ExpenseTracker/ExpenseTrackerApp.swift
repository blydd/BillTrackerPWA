import SwiftUI

@main
struct ExpenseTrackerApp: App {
    private let repository: DataRepository
    @StateObject private var autoSyncManager: AutoSyncManager
    
    init() {
        // 初始化 SQLite 数据仓库
        let repo = Self.setupRepository()
        self.repository = repo
        
        // 初始化自动同步管理器
        _autoSyncManager = StateObject(wrappedValue: AutoSyncManager(repository: repo))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(repository: repository)
                .environmentObject(autoSyncManager)
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
    }
}

struct SettingsView: View {
    let repository: DataRepository
    @EnvironmentObject var autoSyncManager: AutoSyncManager
    
    var body: some View {
        List {
            // 云同步状态
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
