# IAP 功能集成检查清单

## 📋 集成步骤

### 阶段 1: 文件添加（预计 5 分钟）

#### 新增文件
- [ ] `Models/SubscriptionTier.swift` 添加到项目
- [ ] `Services/IAPManager.swift` 添加到项目
- [ ] `Services/SubscriptionManager.swift` 添加到项目
- [ ] `Views/PurchaseView.swift` 添加到项目
- [ ] `Views/UpgradePromptView.swift` 添加到项目
- [ ] `Views/DatabaseExportView.swift` 添加到项目
- [ ] `Products.storekit` 添加到项目

**验证方法**: 在 Xcode 项目导航器中能看到所有文件

---

### 阶段 2: 代码修改（预计 10 分钟）

#### 文件 1: Views/BillFormView.swift
- [ ] 添加 `@StateObject private var subscriptionManager`
- [ ] 添加 `@State private var showingUpgradePrompt`
- [ ] 在 `saveBill()` 中添加账单限制检查
- [ ] 在 `body` 末尾添加 `.upgradePrompt()` 修饰符

**验证方法**: 创建第 501 条账单时应该被阻止

#### 文件 2: Views/BillListView.swift
- [ ] 添加 `@StateObject private var subscriptionManager`
- [ ] 添加 `@State private var showingUpgradePrompt`
- [ ] 添加 `@State private var upgradePromptFeature`
- [ ] 在 `VStack` 顶部添加账单限制警告条
- [ ] 修改 `exportBills()` 方法添加权限检查
- [ ] 添加 `upgradePromptTitle` 和 `upgradePromptMessage` 属性
- [ ] 在 `body` 末尾添加 `.upgradePrompt()` 修饰符

**验证方法**: 
- 接近 500 条时显示警告
- 点击导出时检查权限

#### 文件 3: ExpenseTracker/ExpenseTrackerApp.swift
- [ ] 在 `ContentView` 添加 `@StateObject private var subscriptionManager`
- [ ] 在 `TabView` 后添加 `.environmentObject(subscriptionManager)`
- [ ] 在 `TabView` 后添加 `.task { await subscriptionManager.refreshSubscriptionStatus() }`
- [ ] 在 `SettingsView` 添加 `@StateObject private var subscriptionManager`
- [ ] 在 `SettingsView` 添加 `@State private var showingPurchase`
- [ ] 在 `List` 顶部添加订阅状态 Section
- [ ] 在 `SettingsView` 添加 `.sheet(isPresented: $showingPurchase)`

**验证方法**: 设置页面显示订阅状态

#### 文件 4: Views/CloudSyncSettingsView.swift
- [ ] 添加 `@StateObject private var subscriptionManager`
- [ ] 添加 `@State private var showingPurchase`
- [ ] 在 `List` 开始处添加 Pro 功能检查
- [ ] 添加升级提示界面
- [ ] 添加 `.sheet(isPresented: $showingPurchase)`

**验证方法**: 免费版用户看到升级提示

#### 文件 5: Models/AppError.swift
- [ ] 添加 `case billLimitReached`
- [ ] 添加 `case featureNotAvailable`
- [ ] 在 `errorDescription` 中添加对应的错误描述

**验证方法**: 编译通过

#### 文件 6: ViewModels/ExportViewModel.swift
- [ ] 在 `exportToCSV` 方法开始处添加权限检查

**验证方法**: 免费版导出时抛出错误

#### 文件 7: Views/StatisticsView.swift（可选）
- [ ] 添加 `@StateObject private var subscriptionManager`
- [ ] 添加 `@State private var showingUpgradePrompt`
- [ ] 在数据库导出功能中添加权限检查
- [ ] 添加 `.upgradePrompt()` 修饰符

**验证方法**: 数据库导出有权限检查

---

### 阶段 3: Xcode 配置（预计 2 分钟）

#### StoreKit 配置
- [ ] 打开 Edit Scheme
- [ ] 选择 Run → Options
- [ ] StoreKit Configuration 选择 `Products.storekit`
- [ ] 点击 Close

**验证方法**: Scheme 配置中能看到 StoreKit Configuration

#### 数据库导出入口（可选）
- [ ] 在 `SettingsView` 的"数据管理" Section 中添加：
  ```swift
  NavigationLink("数据库导出") {
      DatabaseExportView()
  }
  ```

**验证方法**: 设置页面能看到"数据库导出"选项

---

### 阶段 4: 编译测试（预计 2 分钟）

#### 编译检查
- [ ] ⌘ + B 编译项目
- [ ] 无编译错误
- [ ] 无警告（或只有预期的警告）

**如果有错误**:
- 检查所有文件是否已添加
- 检查 import 语句
- 清理构建文件夹（Shift + ⌘ + K）

---

### 阶段 5: 功能测试（预计 10 分钟）

#### 免费版测试
- [ ] 启动应用
- [ ] 设置页面显示"免费版"状态
- [ ] 创建账单到 450 条，显示警告
- [ ] 创建账单到 500 条，被阻止并提示升级
- [ ] 点击导出按钮，提示升级
- [ ] 点击云同步，提示升级

#### 购买界面测试
- [ ] 点击任意"升级"按钮
- [ ] 购买界面正确显示
- [ ] 功能对比表格显示正确
- [ ] 显示两个购买选项（年订阅和终身买断）
- [ ] 显示当前订阅状态

#### 购买流程测试
- [ ] 点击"终身买断"
- [ ] 显示系统支付界面（测试环境）
- [ ] 确认购买
- [ ] 购买成功，界面关闭
- [ ] 设置页面显示"终身会员"
- [ ] 所有 Pro 功能已解锁

#### Pro 功能测试
- [ ] 可以创建超过 500 条账单
- [ ] 可以导出 CSV
- [ ] 可以导出数据库
- [ ] 可以使用云同步
- [ ] 不再显示限制警告

#### 恢复购买测试
- [ ] 删除应用
- [ ] 重新安装
- [ ] 打开购买界面
- [ ] 点击"恢复购买"
- [ ] Pro 状态恢复成功

---

### 阶段 6: App Store Connect 配置（上线前）

#### 产品配置
- [ ] 登录 App Store Connect
- [ ] 进入应用页面
- [ ] 点击"功能" → "App 内购买项目"

#### 年订阅产品
- [ ] 点击"创建"
- [ ] 类型：自动续期订阅
- [ ] 产品 ID: `com.expensetracker.pro.annual`
- [ ] 订阅群组：创建新群组 "Pro Subscription"
- [ ] 价格：¥12/年
- [ ] 本地化信息：
  - 显示名称：ExpenseTracker Pro 年订阅
  - 描述：自动续订，随时取消
- [ ] 保存

#### 终身买断产品
- [ ] 点击"创建"
- [ ] 类型：非消耗型项目
- [ ] 产品 ID: `com.expensetracker.pro.lifetime`
- [ ] 价格：¥38
- [ ] 本地化信息：
  - 显示名称：ExpenseTracker Pro 终身版
  - 描述：一次购买，永久使用所有 Pro 功能
- [ ] 保存

#### 验证配置
- [ ] 两个产品状态为"准备提交"
- [ ] 产品 ID 与代码中一致
- [ ] 价格正确
- [ ] 本地化信息完整

---

### 阶段 7: 沙盒测试（上线前）

#### 准备工作
- [ ] 在 App Store Connect 创建沙盒测试账号
- [ ] 在设备上登出真实 Apple ID
- [ ] 在设备上登录沙盒账号

#### 真机测试
- [ ] 在真机上运行应用
- [ ] 测试购买年订阅
- [ ] 测试购买终身买断
- [ ] 测试恢复购买
- [ ] 测试订阅续订（如果可能）
- [ ] 测试跨设备恢复

---

### 阶段 8: 提交审核（上线）

#### 准备材料
- [ ] 应用截图（包含 Pro 功能）
- [ ] 应用描述（说明 IAP 功能）
- [ ] 审核说明（如何测试 IAP）
- [ ] 测试账号（如果需要）

#### 提交检查
- [ ] 所有功能测试通过
- [ ] 产品配置完成
- [ ] 隐私政策已更新（如需要）
- [ ] 用户协议已更新（如需要）
- [ ] 提交审核

---

## ✅ 最终验证

### 代码质量
- [ ] 无编译错误
- [ ] 无编译警告
- [ ] 代码格式规范
- [ ] 注释清晰

### 功能完整性
- [ ] 免费版限制正常
- [ ] Pro 功能正常
- [ ] 购买流程正常
- [ ] 恢复购买正常
- [ ] 状态同步正常

### 用户体验
- [ ] 升级提示友好
- [ ] 购买界面清晰
- [ ] 功能对比明确
- [ ] 错误提示清楚

### 安全性
- [ ] 收据验证正常
- [ ] 状态缓存安全
- [ ] 功能门控严格

---

## 📊 进度追踪

- [ ] 阶段 1: 文件添加 (0/7)
- [ ] 阶段 2: 代码修改 (0/7)
- [ ] 阶段 3: Xcode 配置 (0/2)
- [ ] 阶段 4: 编译测试 (0/3)
- [ ] 阶段 5: 功能测试 (0/20)
- [ ] 阶段 6: App Store Connect 配置 (0/10)
- [ ] 阶段 7: 沙盒测试 (0/6)
- [ ] 阶段 8: 提交审核 (0/5)

**总进度**: 0/60 项

---

## 🎯 完成标准

当所有复选框都被勾选时，IAP 功能集成完成！

**预计总时间**: 30-60 分钟（不含审核等待时间）

---

**提示**: 建议按顺序完成各阶段，每完成一个阶段就进行验证，确保没有问题再继续下一阶段。
