# IAP 集成代码补丁

## 文件 1: Views/BillFormView.swift

在文件顶部的属性声明区域添加：

```swift
@StateObject private var subscriptionManager = SubscriptionManager.shared
@State private var showingUpgradePrompt = false
```

在 `saveBill()` 方法的开始处添加（在创建账单之前）：

```swift
// 检查账单数量限制（仅在创建新账单时检查）
if editingBill == nil {
    let currentCount = billViewModel.bills.count
    if !subscriptionManager.canCreateBill(currentBillCount: currentCount) {
        showingUpgradePrompt = true
        return
    }
}
```

在 `body` 的最后，`.task` 之前添加：

```swift
.upgradePrompt(
    isPresented: $showingUpgradePrompt,
    title: "已达到账单上限",
    message: "免费版最多支持 500 条账单记录\n升级到 Pro 版解锁无限账单",
    feature: "unlimited_bills"
)
```

---

## 文件 2: Views/BillListView.swift

在文件顶部的属性声明区域添加：

```swift
@StateObject private var subscriptionManager = SubscriptionManager.shared
@State private var showingUpgradePrompt = false
@State private var upgradePromptFeature = ""
```

在 `body` 的 `VStack(spacing: 0) {` 之后立即添加：

```swift
// 账单限制警告
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
```

替换 `exportBills()` 方法为：

```swift
private func exportBills() {
    // 检查导出权限
    if !subscriptionManager.canExportData {
        upgradePromptFeature = "export"
        showingUpgradePrompt = true
        return
    }
    
    Task {
        do {
            let fileURL = try await exportViewModel.exportToCSV(
                bills: billViewModel.bills,
                categories: categoryViewModel.categories,
                owners: ownerViewModel.owners,
                paymentMethods: paymentViewModel.paymentMethods
            )
            exportedFileURL = fileURL
            showingExportSheet = true
        } catch {
            showingError = true
        }
    }
}
```

在文件末尾添加这些辅助属性：

```swift
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
```

在 `body` 的最后，`.task` 之前添加：

```swift
.upgradePrompt(
    isPresented: $showingUpgradePrompt,
    title: upgradePromptTitle,
    message: upgradePromptMessage,
    feature: upgradePromptFeature
)
```

---

## 文件 3: ExpenseTracker/ExpenseTrackerApp.swift

在 `SettingsView` 的 `body` 中，在第一个 `Section` 之前添加：

```swift
@StateObject private var subscriptionManager = SubscriptionManager.shared
@State private var showingPurchase = false
```

在 `List {` 之后立即添加新的 Section：

```swift
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
```

在 `SettingsView` 的 `.navigationTitle("设置")` 之后添加：

```swift
.sheet(isPresented: $showingPurchase) {
    PurchaseView()
}
```

在 `ContentView` 的 `body` 中，在 `TabView {` 之前添加：

```swift
@StateObject private var subscriptionManager = SubscriptionManager.shared
```

在 `TabView` 的闭合括号 `}` 之后添加：

```swift
.environmentObject(subscriptionManager)
.task {
    await subscriptionManager.refreshSubscriptionStatus()
}
```

---

## 文件 4: Views/CloudSyncSettingsView.swift

在文件顶部的属性声明区域添加：

```swift
@StateObject private var subscriptionManager = SubscriptionManager.shared
@State private var showingPurchase = false
```

在 `List {` 之后立即添加：

```swift
// Pro 功能检查
if !subscriptionManager.canUseCloudSync {
    Section {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("云同步是 Pro 功能")
                .font(.headline)
            
            Text("升级到 Pro 版解锁 iCloud 云同步，在多设备间同步您的账单数据")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingPurchase = true
            } label: {
                Text("升级到 Pro")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // 如果不是 Pro 用户，直接返回，不显示其他内容
    .sheet(isPresented: $showingPurchase) {
        PurchaseView()
    }
} else {
    // 原有的云同步设置内容保持不变
```

确保在文件末尾有对应的闭合括号 `}`

---

## 文件 5: Models/AppError.swift

在 `AppError` 枚举中添加新的错误类型：

```swift
case billLimitReached
case featureNotAvailable
```

在 `errorDescription` 的 `switch` 语句中添加：

```swift
case .billLimitReached:
    return "已达到免费版账单上限（500条）"
case .featureNotAvailable:
    return "此功能仅限 Pro 用户使用"
```

---

## 文件 6: ViewModels/ExportViewModel.swift

在 `exportToCSV` 方法的开始处（在 `isExporting = true` 之前）添加：

```swift
// 检查导出权限
guard SubscriptionManager.shared.canExportData else {
    throw AppError.featureNotAvailable
}
```

---

## 文件 7: Views/StatisticsView.swift

如果统计视图中有导出数据库的功能，也需要添加类似的检查。

在文件顶部添加：

```swift
@StateObject private var subscriptionManager = SubscriptionManager.shared
@State private var showingUpgradePrompt = false
```

在导出数据库的按钮 action 中添加：

```swift
// 检查导出权限
if !subscriptionManager.canExportData {
    showingUpgradePrompt = true
    return
}
```

在 `body` 的最后添加：

```swift
.upgradePrompt(
    isPresented: $showingUpgradePrompt,
    title: "Pro 功能",
    message: "数据库导出功能仅限 Pro 用户使用\n升级解锁完整数据备份",
    feature: "database_export"
)
```

---

## 完成后的测试步骤

1. **编译项目**：确保没有编译错误
2. **测试免费版限制**：
   - 创建账单到 450 条，查看警告
   - 创建到 500 条，应该被阻止
   - 尝试导出，应该提示升级
   - 尝试云同步，应该提示升级

3. **测试购买流程**：
   - 点击升级按钮
   - 查看购买界面
   - 测试购买（使用 StoreKit 测试环境）

4. **测试 Pro 功能**：
   - 购买后创建超过 500 条账单
   - 测试导出功能
   - 测试云同步功能

5. **测试恢复购买**：
   - 删除应用重新安装
   - 点击恢复购买
   - 验证 Pro 状态恢复

## 注意事项

- 所有代码都已经创建在对应的文件中
- 只需要按照上述补丁修改现有文件
- 确保在 Xcode 中配置好 StoreKit Configuration
- 测试时使用沙盒账号
- 产品 ID 必须与 App Store Connect 中配置的一致
