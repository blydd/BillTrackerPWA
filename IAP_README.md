# ExpenseTracker IAP 功能实现

## 📦 项目概述

为 ExpenseTracker 应用实现完整的应用内购买（IAP）功能，将应用分为免费版和 Pro 版。

### 定价方案
- **年订阅**: ¥12/年（自动续订）
- **终身买断**: ¥38（一次性购买）

### 功能对比

| 功能 | 免费版 | Pro 版 |
|------|--------|--------|
| 账单记录 | 最多 500 条 | ✅ 无限制 |
| 基础统计 | ✅ | ✅ |
| 管理功能 | ✅ | ✅ |
| 云同步 | ❌ | ✅ |
| 导出 CSV | ❌ | ✅ |
| 导出数据库 | ❌ | ✅ |

## 📁 文件结构

```
ExpenseTracker/
├── Models/
│   └── SubscriptionTier.swift          ✨ 新增 - 订阅模型
├── Services/
│   ├── IAPManager.swift                ✨ 新增 - IAP 管理器
│   └── SubscriptionManager.swift       ✨ 新增 - 订阅管理器
├── Views/
│   ├── PurchaseView.swift              ✨ 新增 - 购买界面
│   ├── UpgradePromptView.swift         ✨ 新增 - 升级提示
│   ├── DatabaseExportView.swift        ✨ 新增 - 数据库导出
│   ├── BillFormView.swift              📝 需修改
│   ├── BillListView.swift              📝 需修改
│   ├── CloudSyncSettingsView.swift     📝 需修改
│   └── StatisticsView.swift            📝 需修改
├── ViewModels/
│   └── ExportViewModel.swift           📝 需修改
├── ExpenseTracker/
│   ├── ExpenseTrackerApp.swift         📝 需修改
│   └── ExpenseTracker.entitlements     ✅ 已更新
├── Products.storekit                   ✨ 新增 - 测试配置
└── 文档/
    ├── QUICK_START.md                  📖 快速开始
    ├── IAP_INTEGRATION_PATCHES.md      📖 代码补丁
    ├── INTEGRATION_GUIDE.md            📖 完整指南
    ├── IAP_ARCHITECTURE.md             📖 架构设计
    └── IAP_IMPLEMENTATION_SUMMARY.md   📖 实现总结
```

## 🚀 快速开始

### 1️⃣ 添加新文件（2 分钟）

将以下文件添加到 Xcode 项目：
- `Models/SubscriptionTier.swift`
- `Services/IAPManager.swift`
- `Services/SubscriptionManager.swift`
- `Views/PurchaseView.swift`
- `Views/UpgradePromptView.swift`
- `Views/DatabaseExportView.swift`
- `Products.storekit`

### 2️⃣ 修改现有文件（3 分钟）

按照 `IAP_INTEGRATION_PATCHES.md` 修改 7 个文件：
1. `Views/BillFormView.swift`
2. `Views/BillListView.swift`
3. `ExpenseTracker/ExpenseTrackerApp.swift`
4. `Views/CloudSyncSettingsView.swift`
5. `Models/AppError.swift`
6. `ViewModels/ExportViewModel.swift`
7. `Views/StatisticsView.swift`

### 3️⃣ 配置 StoreKit（30 秒）

1. Edit Scheme → Run → Options
2. StoreKit Configuration: `Products.storekit`

### 4️⃣ 测试（1 分钟）

运行应用，测试：
- ✅ 查看订阅状态
- ✅ 打开购买界面
- ✅ 测试账单限制
- ✅ 测试功能门控

## 📚 文档导航

### 新手入门
👉 **[QUICK_START.md](QUICK_START.md)** - 5 分钟快速集成指南

### 代码集成
👉 **[IAP_INTEGRATION_PATCHES.md](IAP_INTEGRATION_PATCHES.md)** - 详细的代码修改说明

### 完整指南
👉 **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** - 完整的集成和配置指南

### 架构设计
👉 **[IAP_ARCHITECTURE.md](IAP_ARCHITECTURE.md)** - 系统架构和设计文档

### 实现总结
👉 **[IAP_IMPLEMENTATION_SUMMARY.md](IAP_IMPLEMENTATION_SUMMARY.md)** - 功能清单和部署指南

## 🎯 核心功能

### 1. 订阅管理
```swift
// 获取订阅管理器
let subscriptionManager = SubscriptionManager.shared

// 检查是否是 Pro 用户
if subscriptionManager.isProUser {
    // Pro 功能
}

// 检查账单限制
if subscriptionManager.canCreateBill(currentBillCount: count) {
    // 允许创建
}
```

### 2. 购买流程
```swift
// 显示购买界面
.sheet(isPresented: $showingPurchase) {
    PurchaseView()
}

// 显示升级提示
.upgradePrompt(
    isPresented: $showingUpgrade,
    title: "升级到 Pro",
    message: "解锁所有高级功能",
    feature: "feature_name"
)
```

### 3. 功能门控
```swift
// 导出数据检查
if !subscriptionManager.canExportData {
    showUpgradePrompt = true
    return
}

// 云同步检查
if !subscriptionManager.canUseCloudSync {
    showUpgradePrompt = true
    return
}
```

## 🧪 测试清单

### 本地测试（使用 StoreKit Configuration）
- [ ] 免费版显示正确状态
- [ ] 账单限制在 500 条生效
- [ ] 升级提示正确显示
- [ ] 购买界面功能正常
- [ ] 购买流程可以完成
- [ ] Pro 功能正确解锁
- [ ] 恢复购买功能正常

### 真机测试（使用沙盒账号）
- [ ] 真实购买流程
- [ ] 收据验证
- [ ] 订阅续订
- [ ] 跨设备恢复
- [ ] 网络异常处理

## 🏪 App Store Connect 配置

### 产品 1: 年订阅
```
产品 ID: com.expensetracker.pro.annual
类型: 自动续期订阅
价格: ¥12/年
订阅群组: Pro Subscription
```

### 产品 2: 终身买断
```
产品 ID: com.expensetracker.pro.lifetime
类型: 非消耗型项目
价格: ¥38
```

## 🔧 技术栈

- **StoreKit 2**: 原生 IAP 框架
- **SwiftUI**: 用户界面
- **Combine**: 响应式编程
- **UserDefaults**: 本地状态缓存

## 📊 实现进度

### ✅ 已完成
- [x] 订阅模型设计
- [x] IAP 管理器实现
- [x] 订阅状态管理
- [x] 购买界面
- [x] 升级提示组件
- [x] 功能门控逻辑
- [x] 账单限制检查
- [x] 导出权限检查
- [x] 云同步权限检查
- [x] 数据库导出功能
- [x] StoreKit 测试配置
- [x] 完整文档

### 📝 待完成（需手动操作）
- [ ] 将新文件添加到 Xcode 项目
- [ ] 修改现有文件（按补丁文档）
- [ ] 配置 StoreKit 测试环境
- [ ] 本地测试
- [ ] 在 App Store Connect 中配置产品
- [ ] 沙盒测试
- [ ] 提交审核

## 💡 最佳实践

### 开发阶段
- 使用 `Products.storekit` 进行本地测试
- 频繁测试购买流程
- 验证所有功能门控

### 测试阶段
- 创建沙盒测试账号
- 在真机上完整测试
- 测试所有边界情况

### 上线阶段
- 确保产品 ID 一致
- 配置完整的本地化信息
- 准备审核说明
- 监控购买数据

## 🐛 故障排除

### 编译错误
- 确保所有新文件已添加到项目
- 检查 import 语句
- 清理构建文件夹（Shift + Cmd + K）

### 购买失败
- 检查 StoreKit Configuration
- 验证产品 ID
- 查看控制台日志

### 状态不更新
- 检查 SubscriptionManager 初始化
- 验证 @Published 属性
- 确认 environmentObject 传递

## 📞 支持

遇到问题？查看：
1. **[QUICK_START.md](QUICK_START.md)** - 常见问题解答
2. **[IAP_INTEGRATION_PATCHES.md](IAP_INTEGRATION_PATCHES.md)** - 详细代码说明
3. **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** - 完整配置指南

## 🎉 总结

所有核心功能已完整实现！只需：
1. ✅ 添加新文件到项目
2. ✅ 按补丁修改现有文件
3. ✅ 配置测试环境
4. ✅ 测试功能
5. ✅ 配置 App Store Connect
6. ✅ 提交审核

**预计集成时间**: 10-15 分钟
**预计测试时间**: 30-60 分钟

---

**版本**: 1.0.0  
**最后更新**: 2024-12-09  
**作者**: Kiro AI Assistant

祝你的应用成功上线！🚀
