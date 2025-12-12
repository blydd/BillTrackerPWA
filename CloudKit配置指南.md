# CloudKit 配置指南

## 问题：找不到 iCloud Capability

如果在 Xcode 的 "+ Capability" 中找不到 iCloud 选项，按照以下步骤操作。

## 解决方案

### 方案 1: 手动配置 Entitlements（推荐）

我已经帮你更新了 `ExpenseTracker.entitlements` 文件，添加了以下权限：

```xml
<!-- iCloud 容器标识符 -->
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>

<!-- iCloud 服务 (CloudKit) -->
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>

<!-- Ubiquity 容器标识符 -->
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
```

### 方案 2: 检查 Xcode 配置

#### 1. 确认 Apple ID 已登录

**步骤**：
1. 打开 Xcode
2. 菜单栏 → Xcode → Settings (或 Preferences)
3. 选择 "Accounts" 标签
4. 确认你的 Apple ID 已登录

**如果没有登录**：
1. 点击左下角的 "+" 按钮
2. 选择 "Apple ID"
3. 输入你的 Apple ID 和密码
4. 点击 "Continue"

#### 2. 选择正确的 Team

**步骤**：
1. 在项目导航器中选择项目（蓝色图标）
2. 选择 Target: ExpenseTracker
3. 进入 "Signing & Capabilities" 标签
4. 在 "Team" 下拉框中选择你的个人团队

**Team 格式**：
- 个人账户: `Your Name (Personal Team)`
- 付费账户: `Your Name` 或 `Company Name`

#### 3. 启用自动签名

**步骤**：
1. 在 "Signing & Capabilities" 标签中
2. 勾选 "Automatically manage signing"
3. Xcode 会自动处理证书和配置文件

### 方案 3: 通过 Xcode 界面添加（如果可用）

如果完成上述配置后，iCloud 选项出现了：

**步骤**：
1. 在 "Signing & Capabilities" 标签中
2. 点击 "+ Capability" 按钮
3. 搜索 "iCloud"
4. 双击添加
5. 勾选 "CloudKit"

## 验证配置

### 1. 检查 Entitlements 文件

在项目导航器中找到 `ExpenseTracker.entitlements`，确认包含：
- ✅ `com.apple.developer.icloud-container-identifiers`
- ✅ `com.apple.developer.icloud-services`
- ✅ `com.apple.developer.ubiquity-container-identifiers`

### 2. 检查 Bundle Identifier

**步骤**：
1. 选择 Target: ExpenseTracker
2. 进入 "General" 标签
3. 确认 "Bundle Identifier" 格式正确

**格式示例**：
```
com.yourname.ExpenseTracker
```

### 3. 检查 CloudKit Dashboard

**步骤**：
1. 访问 https://icloud.developer.apple.com/
2. 使用你的 Apple ID 登录
3. 查看是否有你的应用容器

**容器 ID 格式**：
```
iCloud.com.yourname.ExpenseTracker
```

## 启用云同步

### 1. 修改应用入口

在 `ExpenseTrackerApp.swift` 中：

```swift
var body: some Scene {
    WindowGroup {
        #if targetEnvironment(simulator)
        // 模拟器：不使用云同步（模拟器不支持 CloudKit）
        ContentView(repository: repository)
        #else
        // 真机：使用云同步
        ContentViewWithSync(repository: repository)
        #endif
    }
}
```

### 2. 在真机上测试

**注意**：
- ⚠️ CloudKit 不支持模拟器
- ✅ 必须在真机上测试
- ✅ 设备需要登录 iCloud

**测试步骤**：
1. 连接 iPhone/iPad
2. 确保设备已登录 iCloud
3. 在 Xcode 中选择真机设备
4. 运行应用
5. 进入"设置" → "云同步设置"
6. 点击"立即同步"

## 常见问题

### Q1: 提示 "CloudKit container not found"

**原因**：容器还未创建

**解决**：
1. 首次运行应用时，CloudKit 会自动创建容器
2. 等待几分钟
3. 重新运行应用

### Q2: 提示 "Not authenticated"

**原因**：设备未登录 iCloud

**解决**：
1. 打开设备的"设置"
2. 点击顶部的 Apple ID
3. 确认已登录 iCloud
4. 确保 iCloud Drive 已开启

### Q3: 同步失败

**可能原因**：
- 网络连接问题
- iCloud 服务器问题
- 权限配置错误

**解决**：
1. 检查网络连接
2. 查看 Xcode 控制台的错误信息
3. 确认 entitlements 配置正确
4. 重启应用

### Q4: 免费账户的限制

**免费账户可以使用 CloudKit**：
- ✅ 完整的 CloudKit 功能
- ✅ 每个用户 1GB 存储空间
- ✅ 每月 2GB 数据传输
- ⚠️ 真机签名每 7 天过期

**付费账户的优势**：
- ✅ 永久真机签名
- ✅ 可以发布到 App Store
- ✅ 更多的 CloudKit 配额

## 调试技巧

### 1. 查看 CloudKit 日志

在代码中添加日志：

```swift
print("📱 CloudKit 容器 ID: \(container.containerIdentifier ?? "未知")")
print("🔄 开始同步...")
```

### 2. 使用 CloudKit Dashboard

访问 https://icloud.developer.apple.com/ 查看：
- 容器状态
- 数据记录
- 同步日志

### 3. 检查网络请求

在 Xcode 中：
1. Product → Scheme → Edit Scheme
2. Run → Arguments
3. 添加环境变量：
   - `CK_LOGGING_LEVEL` = `1`

## 下一步

配置完成后：

1. ✅ 提交代码到 Git
2. ✅ 在真机上测试云同步
3. ✅ 测试多设备同步
4. ✅ 测试离线场景
5. ✅ 测试冲突解决

## 参考资料

- [CloudKit 官方文档](https://developer.apple.com/documentation/cloudkit)
- [iCloud 配置指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/)
- [CloudKit Dashboard](https://icloud.developer.apple.com/)

## 需要帮助？

如果遇到问题：
1. 查看 Xcode 控制台的错误信息
2. 检查 CloudKit Dashboard
3. 确认设备已登录 iCloud
4. 确认网络连接正常
