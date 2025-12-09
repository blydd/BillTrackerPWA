# IAP 功能快速开始指南

## 🚀 5 分钟快速集成

### 步骤 1: 添加文件到 Xcode（2 分钟）

在 Xcode 中，将以下新文件添加到项目：

```
Models/
  └── SubscriptionTier.swift

Services/
  ├── IAPManager.swift
  └── SubscriptionManager.swift

Views/
  ├── PurchaseView.swift
  ├── UpgradePromptView.swift
  └── DatabaseExportView.swift

Products.storekit
```

**操作方法**：
1. 右键点击对应的文件夹
2. 选择 "Add Files to ExpenseTracker..."
3. 选择对应的文件
4. 确保 "Copy items if needed" 已勾选
5. Target 选择 "ExpenseTracker"

### 步骤 2: 修改现有文件（3 分钟）

打开 `IAP_INTEGRATION_PATCHES.md`，按照说明修改 7 个文件：

1. ✏️ `Views/BillFormView.swift` - 3 处修改
2. ✏️ `Views/BillListView.swift` - 5 处修改
3. ✏️ `ExpenseTracker/ExpenseTrackerApp.swift` - 3 处修改
4. ✏️ `Views/CloudSyncSettingsView.swift` - 2 处修改
5. ✏️ `Models/AppError.swift` - 2 处修改
6. ✏️ `ViewModels/ExportViewModel.swift` - 1 处修改
7. ✏️ `Views/StatisticsView.swift` - 3 处修改（可选）

**提示**：每个文件的修改都有明确的位置说明和完整代码。

### 步骤 3: 配置 StoreKit 测试（30 秒）

1. 在 Xcode 中：Product → Scheme → Edit Scheme
2. 选择 Run → Options
3. StoreKit Configuration 选择 `Products.storekit`
4. 点击 Close

### 步骤 4: 编译和测试（1 分钟）

1. ⌘ + B 编译项目
2. ⌘ + R 运行应用
3. 测试功能：
   - 查看设置页面的订阅状态
   - 点击升级按钮查看购买界面
   - 尝试创建 500+ 条账单（会被阻止）
   - 尝试导出数据（会提示升级）

## ✅ 验证清单

- [ ] 项目编译成功，无错误
- [ ] 设置页面显示"免费版"状态
- [ ] 点击"升级"按钮显示购买界面
- [ ] 购买界面显示两个产品（年订阅和终身买断）
- [ ] 创建账单时有数量限制检查
- [ ] 导出功能有权限检查
- [ ] 云同步有权限检查

## 🎯 核心概念

### 订阅层级
```swift
SubscriptionTier.free   // 免费版（500 条账单限制）
SubscriptionTier.pro    // Pro 版（无限制）
```

### 购买类型
```swift
PurchaseType.annual     // 年订阅 ¥12/年
PurchaseType.lifetime   // 终身买断 ¥38
```

### 功能检查
```swift
// 检查是否可以创建账单
subscriptionManager.canCreateBill(currentBillCount: count)

// 检查是否可以导出数据
subscriptionManager.canExportData

// 检查是否可以使用云同步
subscriptionManager.canUseCloudSync

// 获取账单限制警告
subscriptionManager.getBillLimitWarning(currentBillCount: count)
```

## 📱 产品 ID

```swift
// 年订阅
"com.expensetracker.pro.annual"

// 终身买断
"com.expensetracker.pro.lifetime"
```

**重要**：上线前需要在 App Store Connect 中创建这两个产品！

## 🧪 测试场景

### 场景 1: 免费版限制
1. 创建 450 条账单 → 应该显示警告
2. 创建 500 条账单 → 应该被阻止
3. 点击导出 → 应该提示升级
4. 点击云同步 → 应该提示升级

### 场景 2: 购买流程
1. 点击任意"升级"按钮
2. 查看功能对比
3. 选择购买选项（年订阅或终身买断）
4. 完成购买（测试环境自动成功）
5. 验证 Pro 功能已解锁

### 场景 3: Pro 功能
1. 购买后创建超过 500 条账单 → 应该成功
2. 导出数据 → 应该成功
3. 使用云同步 → 应该可用
4. 查看设置 → 应该显示 Pro 状态

## 🐛 常见问题

### Q: 编译错误 "Cannot find type 'SubscriptionManager'"
**A**: 确保已将 `Services/SubscriptionManager.swift` 添加到项目中

### Q: 购买按钮点击无反应
**A**: 检查 StoreKit Configuration 是否已配置

### Q: 产品列表为空
**A**: 检查 `Products.storekit` 文件是否已添加到项目

### Q: 购买后状态未更新
**A**: 检查 `ContentView` 中是否添加了 `.task { await subscriptionManager.refreshSubscriptionStatus() }`

## 📚 详细文档

- **完整集成指南**: `INTEGRATION_GUIDE.md`
- **代码修改补丁**: `IAP_INTEGRATION_PATCHES.md`
- **实现总结**: `IAP_IMPLEMENTATION_SUMMARY.md`

## 🎉 下一步

1. ✅ 完成本地测试
2. 📱 在真机上测试（使用沙盒账号）
3. 🏪 在 App Store Connect 中配置产品
4. 🚀 提交审核

## 💡 提示

- 开发阶段使用 `Products.storekit` 即可，无需真实购买
- 测试时可以随意"购买"，不会产生费用
- 真机测试需要沙盒测试账号
- 上线前务必在 App Store Connect 中配置产品

---

**需要帮助？** 查看详细文档或检查代码注释。所有功能都有完整的实现和说明！
