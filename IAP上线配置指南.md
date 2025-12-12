# IAP 上线配置指南

## 当前状态分析

### 🔍 目前的 IAP 实现

**当前是混合模式**：
- ✅ **代码是生产就绪的**（使用真实的 StoreKit 2 API）
- ⚠️ **测试使用 StoreKit Configuration 文件**
- ⚠️ **产品 ID 是真实的，但产品未在 App Store Connect 中创建**

### 📋 当前配置

#### 1. 产品 ID（已配置，上线时不需要修改）
```swift
enum IAPProduct: String, CaseIterable {
    case annualSubscription = "com.expensetracker.pro.annual"  // 年订阅 ¥12/年
    case lifetimePurchase = "com.expensetracker.pro.lifetime"   // 终身购买 ¥38
}
```

#### 2. StoreKit Configuration 文件（仅用于测试）
- 文件：`Products.storekit`
- 包含两个产品的测试配置
- 价格：年订阅 ¥12，终身购买 ¥38
- **上线时不会使用这个文件**

#### 3. IAP 管理器（生产就绪）
- 使用 StoreKit 2 API
- 支持购买、恢复、订阅管理
- 包含完整的错误处理
- **上线时无需修改代码**

## 🚀 上线时需要的步骤

### 阶段 1: 升级开发者账户

**必须先完成**：
1. 升级到付费 Apple 开发者账户（$99/年）
2. 等待账户激活（1-2 天）

### 阶段 2: App Store Connect 配置

#### 1. 创建应用记录
1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 点击 "我的 App" → "+" → "新建 App"
3. 填写应用信息：
   - **App 名称**: ExpenseTracker（或你想要的名称）
   - **Bundle ID**: `com.bgt.TagBill`（与 Xcode 中一致）
   - **SKU**: 唯一标识符（如：ExpenseTracker2024）
   - **用户访问权限**: 完全访问权限

#### 2. 配置 IAP 产品

**年订阅产品**：
1. 进入 App → 功能 → App 内购买项目
2. 点击 "+" → 自动续期订阅
3. 填写信息：
   - **产品 ID**: `com.expensetracker.pro.annual`
   - **引用名称**: Pro Annual Subscription
   - **订阅群组**: 创建新群组 "Pro Subscription"
   - **订阅时长**: 1 年
   - **价格**: ¥12（选择中国区价格等级）

**终身购买产品**：
1. 点击 "+" → 非消耗型项目
2. 填写信息：
   - **产品 ID**: `com.expensetracker.pro.lifetime`
   - **引用名称**: Pro Lifetime Purchase
   - **价格**: ¥38（选择中国区价格等级）

#### 3. 添加本地化信息

**对于每个产品**：
- **显示名称**: 
  - 年订阅: "ExpenseTracker Pro 年订阅"
  - 终身: "ExpenseTracker Pro 终身版"
- **描述**:
  - 年订阅: "自动续订，随时取消。解锁无限账单、云同步、数据导出等功能。"
  - 终身: "一次购买，永久使用所有 Pro 功能。包括无限账单、云同步、数据导出。"

#### 4. 审核信息
- 添加产品截图
- 填写审核备注
- 提交产品审核

### 阶段 3: 代码配置（最少修改）

#### 1. 移除 StoreKit Configuration（可选）

**在 Xcode 中**：
- Product → Scheme → Edit Scheme
- Run → Options
- StoreKit Configuration: 设置为 "None"

**注意**: 这一步是可选的，因为发布版本会自动使用真实的 App Store。

#### 2. 确认产品 ID（无需修改）

当前的产品 ID 已经是正确的：
```swift
// ✅ 这些 ID 上线时不需要修改
case annualSubscription = "com.expensetracker.pro.annual"
case lifetimePurchase = "com.expensetracker.pro.lifetime"
```

#### 3. 测试模式检测（已实现）

代码会自动检测环境：
```swift
// 开发/测试环境：使用 StoreKit Configuration
// 生产环境：使用真实的 App Store
```

### 阶段 4: 测试

#### 1. 沙盒测试

**创建沙盒测试账户**：
1. App Store Connect → 用户和访问 → 沙盒测试员
2. 创建测试账户（使用不同的邮箱）

**测试步骤**：
1. 在设备上登出 App Store
2. 运行应用（Release 配置）
3. 尝试购买
4. 使用沙盒账户登录
5. 完成测试购买

#### 2. TestFlight 测试

1. 上传应用到 App Store Connect
2. 通过 TestFlight 分发给测试用户
3. 测试真实的购买流程

### 阶段 5: 发布

#### 1. 提交审核

**应用审核**：
- 上传应用二进制文件
- 填写应用信息和截图
- 提交应用审核

**IAP 审核**：
- IAP 产品会与应用一起审核
- 确保产品信息完整准确

#### 2. 发布

- 应用和 IAP 产品审核通过后
- 选择发布方式（自动/手动）
- 应用上线，IAP 功能生效

## 📊 代码修改对比

### ❌ 不需要修改的部分

**产品 ID**：
```swift
// ✅ 保持不变
enum IAPProduct: String, CaseIterable {
    case annualSubscription = "com.expensetracker.pro.annual"
    case lifetimePurchase = "com.expensetracker.pro.lifetime"
}
```

**IAP 管理器**：
```swift
// ✅ 整个 IAPManager 类都不需要修改
// ✅ 使用的是标准 StoreKit 2 API
// ✅ 会自动适配生产环境
```

**购买流程**：
```swift
// ✅ 所有购买、恢复、验证逻辑都不需要修改
```

### ⚠️ 可选修改的部分

**Scheme 配置**：
```swift
// 可选：移除 StoreKit Configuration
// 但不移除也没关系，发布版本会忽略
```

**调试日志**：
```swift
// 可选：在生产版本中减少日志输出
#if DEBUG
print("IAP Debug: ...")
#endif
```

## 🔄 测试环境 vs 生产环境

### 当前测试环境

**使用 StoreKit Configuration**：
- ✅ 无需真实支付
- ✅ 可以测试所有购买流程
- ✅ 可以模拟各种场景
- ✅ 立即生效，无需等待

**测试方法**：
1. Xcode → Product → Scheme → Edit Scheme
2. Run → Options → StoreKit Configuration: `Products.storekit`
3. 运行应用，测试购买

### 生产环境

**使用真实 App Store**：
- ✅ 真实支付流程
- ✅ 真实的收入
- ✅ 完整的订阅管理
- ✅ Apple 的收据验证

**自动切换**：
- 代码会自动检测环境
- 无需手动修改代码
- StoreKit 2 会自动连接到正确的服务

## 💰 收入和分成

### Apple 分成比例

**标准分成**：
- Apple: 30%
- 开发者: 70%

**小企业计划**（年收入 < $100万）：
- Apple: 15%
- 开发者: 85%

### 实际收入计算

**年订阅 ¥12**：
- 标准: 开发者收入 ¥8.4
- 小企业: 开发者收入 ¥10.2

**终身购买 ¥38**：
- 标准: 开发者收入 ¥26.6
- 小企业: 开发者收入 ¥32.3

## 📅 上线时间线

### 准备阶段（1-2 周）
1. 升级开发者账户（1-2 天）
2. 在 App Store Connect 中配置产品（1-2 天）
3. 沙盒测试（3-5 天）
4. 准备应用截图和描述（2-3 天）

### 审核阶段（1-2 周）
1. 提交应用和 IAP 产品审核
2. 等待审核结果（通常 1-7 天）
3. 如有问题，修改后重新提交

### 发布阶段（1 天）
1. 审核通过后选择发布时间
2. 应用上线，IAP 功能生效

## ✅ 总结

### 当前状态
- ✅ **代码已经是生产就绪的**
- ✅ **产品 ID 已经配置正确**
- ✅ **购买流程完整实现**
- ⚠️ **仅使用测试环境（StoreKit Configuration）**

### 上线时需要做的
1. **升级开发者账户**（必须）
2. **在 App Store Connect 配置产品**（必须）
3. **提交审核**（必须）
4. **代码几乎不需要修改**（可选的小调整）

### 关键点
- 🎯 **代码不需要大改**，主要是配置工作
- 🎯 **产品 ID 保持不变**
- 🎯 **StoreKit 2 会自动适配生产环境**
- 🎯 **最大的工作是 App Store Connect 配置和审核**

你的 IAP 实现已经很完善了，上线主要是配置和审核的工作！