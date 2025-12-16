# Decimal 格式化兼容性修复说明

## 问题描述
编译时出现错误：
```
Instance method 'appendInterpolation(_:specifier:)' requires that 'Decimal' conform to '_FormatSpecifiable'
```

## 问题原因
在 iOS 15 中，`Decimal` 类型不支持直接使用 `specifier` 参数进行字符串插值格式化。

## 解决方案
将 `Decimal` 转换为 `Double` 类型后再格式化：

### 修改前（不兼容 iOS 15）
```swift
Text("¥\(todayExpense, specifier: "%.2f")")
Text("¥\(monthExpense, specifier: "%.2f")")
Text("¥\(expense.amount, specifier: "%.2f")")
```

### 修改后（兼容 iOS 15+）
```swift
Text("¥\(NSDecimalNumber(decimal: todayExpense).doubleValue, specifier: "%.2f")")
Text("¥\(NSDecimalNumber(decimal: monthExpense).doubleValue, specifier: "%.2f")")
Text("¥\(NSDecimalNumber(decimal: expense.amount).doubleValue, specifier: "%.2f")")
```

## 修复位置
- `ExpenseTracker/ExpenseTrackerApp.swift` 中的 3 处 Decimal 格式化

## 技术说明
- 使用 `NSDecimalNumber(decimal:).doubleValue` 进行类型转换
- 保持了原有的格式化精度（保留两位小数）
- 兼容 iOS 15.0+ 版本要求

## 修复结果
✅ 编译错误解决
✅ iOS 15 兼容性保持
✅ 格式化显示正常