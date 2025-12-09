# IAP 功能架构设计

## 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         用户界面层                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ BillListView │  │SettingsView  │  │CloudSyncView │      │
│  │              │  │              │  │              │      │
│  │ • 账单列表   │  │ • 订阅状态   │  │ • 云同步设置 │      │
│  │ • 限制警告   │  │ • 升级按钮   │  │ • Pro 门控   │      │
│  │ • 导出按钮   │  │              │  │              │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │              │
│         └─────────────────┼─────────────────┘              │
│                           │                                │
│                  ┌────────▼────────┐                       │
│                  │  PurchaseView   │                       │
│                  │                 │                       │
│                  │ • 功能对比      │                       │
│                  │ • 购买选项      │                       │
│                  │ • 恢复购买      │                       │
│                  └────────┬────────┘                       │
│                           │                                │
└───────────────────────────┼────────────────────────────────┘
                            │
┌───────────────────────────┼────────────────────────────────┐
│                      业务逻辑层                              │
├───────────────────────────┼────────────────────────────────┤
│                           │                                │
│         ┌─────────────────▼──────────────────┐            │
│         │    SubscriptionManager              │            │
│         │                                     │            │
│         │ • 订阅状态管理                      │            │
│         │ • 功能权限检查                      │            │
│         │ • 本地状态缓存                      │            │
│         │ • 账单限制逻辑                      │            │
│         │                                     │            │
│         │  canCreateBill()                    │            │
│         │  canExportData                      │            │
│         │  canUseCloudSync                    │            │
│         │  getBillLimitWarning()              │            │
│         └─────────────────┬──────────────────┘            │
│                           │                                │
│                           │ 监听购买状态                   │
│                           │                                │
│         ┌─────────────────▼──────────────────┐            │
│         │         IAPManager                  │            │
│         │                                     │            │
│         │ • 产品加载                          │            │
│         │ • 购买处理                          │            │
│         │ • 收据验证                          │            │
│         │ • 交易监听                          │            │
│         │ • 恢复购买                          │            │
│         │                                     │            │
│         │  loadProducts()                     │            │
│         │  purchase()                         │            │
│         │  restorePurchases()                 │            │
│         └─────────────────┬──────────────────┘            │
│                           │                                │
└───────────────────────────┼────────────────────────────────┘
                            │
┌───────────────────────────┼────────────────────────────────┐
│                       系统服务层                             │
├───────────────────────────┼────────────────────────────────┤
│                           │                                │
│         ┌─────────────────▼──────────────────┐            │
│         │         StoreKit 2                  │            │
│         │                                     │            │
│         │ • Product.products()                │            │
│         │ • Product.purchase()                │            │
│         │ • Transaction.updates               │            │
│         │ • Transaction.currentEntitlements   │            │
│         │ • AppStore.sync()                   │            │
│         └─────────────────┬──────────────────┘            │
│                           │                                │
│                           ▼                                │
│                  ┌─────────────────┐                       │
│                  │  App Store      │                       │
│                  │  服务器          │                       │
│                  └─────────────────┘                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 数据流图

### 1. 购买流程

```
用户点击购买
    │
    ▼
PurchaseView.purchase()
    │
    ▼
IAPManager.purchase(product)
    │
    ├─► StoreKit 2 处理购买
    │       │
    │       ▼
    │   显示系统支付界面
    │       │
    │       ▼
    │   用户确认支付
    │       │
    │       ▼
    │   Apple 服务器验证
    │       │
    │       ▼
    │   返回购买结果
    │
    ▼
IAPManager.updatePurchasedProducts()
    │
    ▼
SubscriptionManager 监听到变化
    │
    ▼
更新订阅状态
    │
    ▼
保存到本地缓存
    │
    ▼
UI 自动更新（通过 @Published）
```

### 2. 功能门控流程

```
用户尝试使用功能
    │
    ▼
检查权限
    │
    ├─► SubscriptionManager.canCreateBill()
    │   ├─► isProUser? → 允许
    │   └─► 检查账单数量
    │       ├─► < 500 → 允许
    │       └─► >= 500 → 拒绝 + 显示升级提示
    │
    ├─► SubscriptionManager.canExportData
    │   ├─► isProUser? → 允许
    │   └─► 拒绝 + 显示升级提示
    │
    └─► SubscriptionManager.canUseCloudSync
        ├─► isProUser? → 允许
        └─► 拒绝 + 显示升级提示
```

### 3. 状态同步流程

```
应用启动
    │
    ▼
ContentView.task
    │
    ▼
SubscriptionManager.refreshSubscriptionStatus()
    │
    ▼
IAPManager.updatePurchasedProducts()
    │
    ▼
遍历 Transaction.currentEntitlements
    │
    ├─► 验证每个交易
    │   ├─► 检查签名
    │   ├─► 检查过期时间
    │   └─► 提取产品 ID
    │
    ▼
更新 purchasedProductIDs
    │
    ▼
SubscriptionManager 监听到变化
    │
    ▼
更新订阅状态
    │
    ├─► 终身买断? → tier = .pro, type = .lifetime
    ├─► 年订阅? → tier = .pro, type = .annual
    └─► 无购买? → tier = .free, type = .none
    │
    ▼
保存到 UserDefaults
    │
    ▼
UI 更新
```

## 核心类设计

### SubscriptionManager

```swift
class SubscriptionManager: ObservableObject {
    // 状态
    @Published var subscriptionStatus: SubscriptionStatus
    @Published var isProUser: Bool
    
    // 功能门控
    func canCreateBill(currentBillCount: Int) -> Bool
    func getBillLimitWarning(currentBillCount: Int) -> String?
    var canUseCloudSync: Bool
    var canExportData: Bool
    
    // 状态管理
    func updateSubscriptionStatus(purchasedIDs: Set<String>)
    func refreshSubscriptionStatus()
    
    // 持久化
    private func saveSubscriptionStatus()
}
```

### IAPManager

```swift
class IAPManager: ObservableObject {
    // 状态
    @Published var products: [Product]
    @Published var purchasedProductIDs: Set<String>
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    
    // 产品管理
    func loadProducts() async
    func product(for productID: IAPProduct) -> Product?
    func isPurchased(_ productID: IAPProduct) -> Bool
    
    // 购买流程
    func purchase(_ product: Product) async -> Bool
    func restorePurchases() async -> Bool
    
    // 内部方法
    func updatePurchasedProducts() async
    private func listenForTransactions() -> Task<Void, Error>
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T
}
```

### SubscriptionStatus

```swift
struct SubscriptionStatus: Codable {
    var tier: SubscriptionTier          // free / pro
    var purchaseType: PurchaseType      // none / annual / lifetime
    var expirationDate: Date?           // 订阅过期时间
    var purchaseDate: Date?             // 购买时间
    
    var isActive: Bool                  // 是否激活
    var displayStatus: String           // 显示文本
}
```

## 功能权限矩阵

| 功能 | 免费版 | Pro 年订阅 | Pro 终身 |
|------|--------|-----------|----------|
| 创建账单 | ≤ 500 条 | ✅ 无限 | ✅ 无限 |
| 查看统计 | ✅ | ✅ | ✅ |
| 管理分类 | ✅ | ✅ | ✅ |
| 管理归属人 | ✅ | ✅ | ✅ |
| 管理支付方式 | ✅ | ✅ | ✅ |
| 云同步 | ❌ | ✅ | ✅ |
| 导出 CSV | ❌ | ✅ | ✅ |
| 导出数据库 | ❌ | ✅ | ✅ |

## 状态转换图

```
┌─────────┐
│  Free   │ ◄─── 初始状态
└────┬────┘
     │
     │ 购买年订阅
     ▼
┌─────────┐
│Pro年订阅│
└────┬────┘
     │
     ├─► 订阅过期 ──► 回到 Free
     │
     └─► 购买终身 ──► Pro 终身
     
     
┌─────────┐
│  Free   │
└────┬────┘
     │
     │ 购买终身
     ▼
┌─────────┐
│Pro终身  │ ◄─── 永久状态
└─────────┘
```

## 错误处理

```
购买流程错误
├─► 用户取消 → 返回购买界面
├─► 网络错误 → 显示错误提示 + 重试
├─► 验证失败 → 显示错误提示
└─► 未知错误 → 显示错误提示 + 联系支持

功能门控错误
├─► 账单限制 → 显示升级提示
├─► 导出限制 → 显示升级提示
└─► 云同步限制 → 显示升级提示

状态同步错误
├─► 网络不可用 → 使用缓存状态 + 下次重试
├─► 收据无效 → 回退到免费版
└─► 解析错误 → 使用缓存状态
```

## 性能优化

### 1. 状态缓存
- 订阅状态保存在 UserDefaults
- 避免每次启动都验证收据
- 后台异步验证

### 2. 懒加载
- 产品列表按需加载
- 购买界面打开时才加载产品

### 3. 响应式更新
- 使用 Combine 框架
- @Published 属性自动触发 UI 更新
- 避免手动刷新

## 安全性设计

### 1. 收据验证
- 使用 StoreKit 2 原生验证
- 检查交易签名
- 验证产品 ID 和过期时间

### 2. 本地验证
- 每次功能调用都检查权限
- 不信任客户端状态
- 服务端验证（如果有后端）

### 3. 防止盗版
- 收据验证失败回退到免费版
- 定期刷新订阅状态
- 监听交易更新

## 测试策略

### 1. 单元测试
- SubscriptionManager 逻辑测试
- 功能门控测试
- 状态转换测试

### 2. 集成测试
- 购买流程测试
- 恢复购买测试
- 状态同步测试

### 3. UI 测试
- 升级提示显示测试
- 购买界面交互测试
- 功能解锁测试

## 部署架构

```
开发环境
├─► StoreKit Configuration 文件
├─► 本地测试
└─► 无需真实购买

测试环境
├─► 沙盒账号
├─► 真机测试
└─► App Store Connect 沙盒

生产环境
├─► 真实产品
├─► App Store Connect 配置
└─► 真实用户购买
```

## 监控和分析

### 关键指标
- 免费版用户数
- Pro 版转化率
- 年订阅 vs 终身买断比例
- 恢复购买成功率
- 购买失败率

### 日志记录
- 购买流程日志
- 验证失败日志
- 状态转换日志
- 错误日志

---

这个架构设计确保了：
- ✅ 清晰的职责分离
- ✅ 可维护性和可扩展性
- ✅ 良好的用户体验
- ✅ 安全的购买流程
- ✅ 可靠的状态管理
