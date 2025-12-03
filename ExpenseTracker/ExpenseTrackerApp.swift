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
            ContentView(repository: repository)
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
    
    var body: some View {
        List {
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
}
