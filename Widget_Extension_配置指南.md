# Widget Extension 配置指南

## 📋 第一步：在 Xcode 中添加 Widget Extension Target

### 1. 添加新 Target
1. **打开项目**：在 Xcode 中打开 `ExpenseTracker.xcodeproj`
2. **选择项目**：点击左侧导航栏中的项目文件
3. **添加 Target**：点击左下角的 "+" 按钮
4. **选择模板**：选择 "Widget Extension"，点击 "Next"

### 2. 配置 Target 信息
```
Product Name: ExpenseTrackerWidgetExtension
Bundle Identifier: com.bgt.TagBill.ExpenseTrackerWidgetExtension
Language: Swift
Use Core Data: ❌ (不勾选)
Include Configuration Intent: ❌ (不勾选)
```

### 3. 点击 "Finish" 完成创建

## 📁 第二步：替换自动生成的文件

Xcode 会自动生成一些模板文件，我们需要替换它们：

### 1. 删除自动生成的文件
- 删除 `ExpenseTrackerWidgetExtension.swift`（如果存在）
- 保留 `Info.plist`

### 2. 添加我准备的文件
将以下文件复制到 `ExpenseTrackerWidgetExtension` 文件夹：

#### 📄 主文件：`ExpenseTrackerWidgetExtension.swift`
```swift
// 内容已在上面的文件中提供
```

#### 📄 权限文件：`ExpenseTrackerWidgetExtension.entitlements`
```xml
// 内容已在上面的文件中提供
```

## ⚙️ 第三步：配置 Target 设置

### 1. 选择 Widget Extension Target
在项目设置中选择 `ExpenseTrackerWidgetExtension` target

### 2. 基本设置
```
Deployment Target: iOS 15.0
Bundle Identifier: com.bgt.TagBill.ExpenseTrackerWidgetExtension
Display Name: 标签记账
```

### 3. 签名和权限
- **Code Signing**: 使用与主应用相同的开发者账号
- **Entitlements**: 指向 `ExpenseTrackerWidgetExtension.entitlements`

### 4. App Groups 配置
1. 在 **Signing & Capabilities** 中点击 "+ Capability"
2. 添加 **App Groups**
3. 勾选或添加：`group.com.bgt.TagBill.shared`

## 🔗 第四步：确保主应用也配置了 App Groups

### 1. 选择主应用 Target (`ExpenseTracker`)
### 2. 在 Signing & Capabilities 中确保有 App Groups
### 3. 确保使用相同的组标识符：`group.com.bgt.TagBill.shared`

## 🏗️ 第五步：构建和测试

### 1. 清理项目
```
Product → Clean Build Folder (Cmd+Shift+K)
```

### 2. 构建项目
```
Product → Build (Cmd+B)
```

### 3. 运行到设备
```
Product → Run (Cmd+R)
```

### 4. 测试小组件
1. 长按主屏幕空白处
2. 点击左上角 "+" 号
3. 搜索 "标签记账"
4. 添加小组件

## 🔧 常见问题解决

### Q1: 编译错误 "No such module 'WidgetKit'"
**解决方案**：确保 Deployment Target 设置为 iOS 14.0 或更高

### Q2: 找不到小组件
**解决方案**：
1. 确保 Widget Extension Target 被正确添加
2. 检查 Bundle Identifier 配置
3. 重新安装应用到设备
4. 重启设备

### Q3: App Groups 权限错误
**解决方案**：
1. 确保主应用和小组件都配置了相同的 App Groups
2. 检查开发者账号权限
3. 重新生成 Provisioning Profile

### Q4: 小组件显示空白
**解决方案**：
1. 检查 `containerBackground` 是否正确设置
2. 确保 iOS 版本兼容性
3. 查看 Xcode 控制台错误信息

## ✅ 验证清单

完成配置后，请检查以下项目：

- [ ] Widget Extension Target 已创建
- [ ] Bundle Identifier 正确设置
- [ ] App Groups 在主应用和小组件中都已配置
- [ ] Entitlements 文件正确配置
- [ ] 项目可以成功编译
- [ ] 应用可以正常安装到设备
- [ ] 小组件可以在小组件库中找到
- [ ] 点击小组件按钮可以打开应用并执行快速记账

## 🎯 预期结果

配置完成后，用户将能够：

1. **安装应用**：只安装一个"标签记账"应用
2. **添加小组件**：在小组件库中找到"标签记账"小组件
3. **使用小组件**：
   - 小尺寸：显示一个主要的快速记账按钮
   - 中等尺寸：显示 4 个快速记账按钮
4. **快速记账**：点击小组件按钮直接记账并打开应用

如果遇到任何问题，请检查上述配置步骤或查看 Xcode 控制台的错误信息。