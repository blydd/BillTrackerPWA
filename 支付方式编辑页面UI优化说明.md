# 支付方式编辑页面UI优化说明

## 优化内容

### 问题描述
原来的支付方式编辑页面使用 TextField 作为输入框，当字段有值时，用户看不出这个值代表什么含义（如信用额度、当前欠费等）。

### 解决方案
将表单布局改造为左侧标题、右侧值的 HStack 布局，提高用户体验和可读性。

## 具体修改

### 1. 信贷方式表单布局

#### 修改前
```swift
TextField("信用额度", text: $creditLimit)
    .keyboardType(.decimalPad)
TextField("当前欠费", text: $outstandingBalance)
    .keyboardType(.decimalPad)
TextField("账单日", text: $billingDate)
    .keyboardType(.numberPad)
```

#### 修改后
```swift
HStack {
    Text("信用额度")
        .foregroundColor(.primary)
    Spacer()
    TextField("0", text: $creditLimit)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
}

HStack {
    Text("当前欠费")
        .foregroundColor(.primary)
    Spacer()
    TextField("0", text: $outstandingBalance)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
}

HStack {
    Text("账单日")
        .foregroundColor(.primary)
    Spacer()
    TextField("1", text: $billingDate)
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
}
```

### 2. 储蓄方式表单布局

#### 修改前
```swift
TextField("当前余额", text: $savingsBalance)
    .keyboardType(.decimalPad)
```

#### 修改后
```swift
HStack {
    Text("当前余额")
        .foregroundColor(.primary)
    Spacer()
    TextField("0", text: $savingsBalance)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
}
```

### 3. 名称字段统一优化

#### 修改前
```swift
TextField("名称", text: $creditName)
```

#### 修改后
```swift
HStack {
    Text("名称")
        .foregroundColor(.primary)
    Spacer()
    TextField("请输入名称", text: $creditName)
        .multilineTextAlignment(.trailing)
}
```

## 优化特点

### 1. 清晰的标签显示
- **左侧标题**: 明确显示字段含义（如"信用额度"、"当前欠费"）
- **右侧输入**: 用户可以清楚看到当前值和输入新值

### 2. 一致的视觉体验
- **统一布局**: 所有字段都采用相同的左右布局
- **对齐方式**: 输入框内容右对齐，符合数字输入习惯
- **颜色搭配**: 标题使用主色调，保持视觉层次

### 3. 改进的用户体验
- **可读性**: 用户能立即识别每个字段的含义
- **输入提示**: 提供合理的占位符文本（如"0"、"请输入名称"）
- **保持功能**: 键盘类型和输入验证保持不变

## 涉及的表单

1. **添加信贷方式** (`addCreditMethodSheet`)
2. **编辑信贷方式** (`editCreditMethodSheet`)
3. **添加储蓄方式** (`addSavingsMethodSheet`)
4. **编辑储蓄方式** (`editSavingsMethodSheet`)

## 技术实现

### HStack 布局结构
```swift
HStack {
    Text("标题")                    // 左侧标签
        .foregroundColor(.primary)
    Spacer()                       // 弹性空间
    TextField("占位符", text: $value) // 右侧输入框
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
}
```

### 关键属性
- `Spacer()`: 在标题和输入框之间创建弹性空间
- `multilineTextAlignment(.trailing)`: 输入内容右对齐
- `foregroundColor(.primary)`: 标题使用系统主色调
- 保持原有的 `keyboardType` 设置

## 用户体验提升

1. **信息清晰**: 用户能立即看出"58000"是信用额度而不是其他数值
2. **输入便捷**: 右对齐的数字输入更符合用户习惯
3. **视觉统一**: 所有表单字段保持一致的视觉风格
4. **减少困惑**: 消除了"这个数字代表什么"的疑问

这次优化显著提升了支付方式管理页面的用户体验，使表单更加直观和易用。