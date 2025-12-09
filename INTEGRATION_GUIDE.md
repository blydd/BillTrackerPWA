# IAP 功能集成指南

## 已创建的文件

1. ✅ `Models/SubscriptionTier.swift` - 订阅层级模型
2. ✅ `Services/IAPManager.swift` - IAP 核心管理器
3. ✅ `Services/SubscriptionManager.swift` - 订阅状态管理
4. ✅ `Views/PurchaseView.swift` - 购买界面
5. ✅ `Views/UpgradePromptView.swift` - 升级提示视图

## 需要手动修改的文件

### 1. ExpenseTracker/ExpenseTrackerApp.swift

在 `ContentView` 结构体中添加订阅管理器：

```swift
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
```

在 `SettingsView` 中添加订阅状态显示：

```swift
struct SettingsView: View {
    let repository: DataRepository
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPurchase = false
    
    var body: some View {
        List {
            // 订阅状态 Section
            Section("订阅状态") {
                HStack {
                    Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "star")
                        .foregroundColor(subscriptionManager.isProUser ? .yellow : .gray)
                    
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
            
            // ... 其他 sections
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showingPurchase) {
            PurchaseView()
        }
    }
}
```

### 2. Views/BillFormView.swift

在创建账单前添加限制检查：

```swift
struct BillFormView: View {
    // ... 现有属性
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingUpgradePrompt = false
    
    // 在保存按钮的 action 中添加：
    private func saveBill() {
        // 检查账单数量限制
        if !subscriptionManager.canCreateBill(currentBillCount: billViewModel.bills.count) {
            showingUpgradePrompt = true
            return
        }
        
        // ... 原有的保存逻辑
    }
    
    var body: some View {
        // ... 现有视图
        .upgradePrompt(
            isPresented: $showingUpgradePrompt,
            title: "已达到账单上限",
            message: "免费版最多支持 500 条账单记录\n升级到 Pro 版解锁无限账单",
            feature: "unlimited_bills"
        )
    }
}
```

### 3. Views/BillListView.swift

在工具栏中添加账单数量提示和导出限制：

```swift
struct BillListView: View {
    // ... 现有属性
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingUpgradePrompt = false
    @State private var upgradePromptFeature = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 在顶部添加账单限制警告
            if let warning = subscriptionManager.getBillLimitWarning(currentBillCount: billViewModel.bills.count) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("升级") {
                        upgradePromptFeature = "unlimited_bills"
                        showingUpgradePrompt = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
            
            // ... 现有视图
        }
        .upgradePrompt(
            isPresented: $showingUpgradePrompt,
            title: upgradePromptTitle,
            message: upgradePromptMessage,
            feature: upgradePromptFeature
        )
    }
    
    private func exportBills() {
        // 检查导出权限
        if !subscriptionManager.canExportData {
            upgradePromptFeature = "export"
            showingUpgradePrompt = true
            return
        }
        
        // ... 原有的导出逻辑
    }
    
    private var upgradePromptTitle: String {
        switch upgradePromptFeature {
        case "unlimited_bills":
            return "已达到账单上限"
        case "export":
            return "Pro 功能"
        default:
            return "升级到 Pro"
        }
    }
    
    private var upgradePromptMessage: String {
        switch upgradePromptFeature {
        case "unlimited_bills":
            return "免费版最多支持 500 条账单记录\n升级到 Pro 版解锁无限账单"
        case "export":
            return "数据导出功能仅限 Pro 用户使用\n升级解锁 CSV 和数据库导出"
        default:
            return "升级到 Pro 版解锁所有高级功能"
        }
    }
}
```

### 4. Views/CloudSyncSettingsView.swift

添加云同步权限检查：

```swift
struct CloudSyncSettingsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingUpgradePrompt = false
    
    var body: some View {
        List {
            if !subscriptionManager.canUseCloudSync {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        
                        Text("云同步是 Pro 功能")
                            .font(.headline)
                        
                        Text("升级到 Pro 版解锁 iCloud 云同步")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("升级到 Pro") {
                            showingUpgradePrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                // ... 原有的云同步设置
            }
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            PurchaseView()
        }
    }
}
```

### 5. ViewModels/ExportViewModel.swift

在导出方法开始处添加权限检查：

```swift
func exportToCSV(...) async throws -> URL {
    // 检查导出权限
    guard SubscriptionManager.shared.canExportData else {
        throw AppError.featureNotAvailable
    }
    
    // ... 原有逻辑
}
```

### 6. Models/AppError.swift

添加新的错误类型：

```swift
enum AppError: Error, LocalizedError {
    // ... 现有错误
    case billLimitReached
    case featureNotAvailable
    
    var errorDescription: String? {
        switch self {
        // ... 现有错误描述
        case .billLimitReached:
            return "已达到免费版账单上限（500条）"
        case .featureNotAvailable:
            return "此功能仅限 Pro 用户使用"
        }
    }
}
```

## 配置 StoreKit

### 1. 更新 Entitlements

在 `ExpenseTracker/ExpenseTracker.entitlements` 中添加：

```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.yourcompany.expensetracker</string>
</array>
```

### 2. 在 App Store Connect 中配置产品

1. 登录 App Store Connect
2. 进入你的应用
3. 点击"功能" → "App 内购买项目"
4. 创建两个产品：

**产品 1：年订阅**
- 产品 ID: `com.expensetracker.pro.annual`
- 类型：自动续期订阅
- 价格：¥12/年
- 订阅群组：Pro Subscription

**产品 2：终身买断**
- 产品 ID: `com.expensetracker.pro.lifetime`
- 类型：非消耗型项目
- 价格：¥38

### 3. 创建 StoreKit Configuration 文件（用于测试）

1. 在 Xcode 中：File → New → File
2. 选择 "StoreKit Configuration File"
3. 命名为 `Products.storekit`
4. 添加两个产品（与 App Store Connect 中的配置一致）

### 4. 在 Xcode 中配置测试

1. 选择 Scheme → Edit Scheme
2. 在 Run → Options 中
3. StoreKit Configuration 选择 `Products.storekit`

## 测试流程

### 1. 免费版测试
- 创建账单直到 450 条，应该看到警告
- 创建到 500 条，应该被阻止并提示升级
- 尝试导出数据，应该提示升级
- 尝试使用云同步，应该提示升级

### 2. 购买测试
- 点击升级按钮，应该显示购买界面
- 查看功能对比
- 测试购买流程（使用沙盒账号）
- 测试恢复购买

### 3. Pro 版测试
- 购买后应该立即解锁所有功能
- 可以创建无限账单
- 可以导出数据
- 可以使用云同步
- 重启应用后状态应该保持

## 注意事项

1. **产品 ID 必须与代码中的一致**
2. **测试时使用沙盒账号**
3. **真机测试前需要在 App Store Connect 中配置产品**
4. **订阅需要配置订阅群组**
5. **终身买断使用非消耗型项目类型**

## 部署清单

- [ ] 在 App Store Connect 中创建产品
- [ ] 配置订阅群组（年订阅）
- [ ] 更新 Entitlements
- [ ] 创建 StoreKit Configuration 文件
- [ ] 测试免费版限制
- [ ] 测试购买流程
- [ ] 测试恢复购买
- [ ] 测试 Pro 功能解锁
- [ ] 提交审核前测试所有场景
