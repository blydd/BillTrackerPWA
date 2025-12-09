#!/bin/bash

echo "🔍 验证 IAP 功能文件..."
echo ""

# 检查必需的文件
files=(
    "Models/SubscriptionTier.swift"
    "Services/IAPManager.swift"
    "Services/SubscriptionManager.swift"
    "Views/PurchaseView.swift"
    "Views/UpgradePromptView.swift"
    "Views/DatabaseExportView.swift"
    "Products.storekit"
)

all_exist=true

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - 文件不存在"
        all_exist=false
    fi
done

echo ""

if [ "$all_exist" = true ]; then
    echo "✅ 所有文件都存在"
    echo ""
    echo "📝 检查 import 语句..."
    echo ""
    
    # 检查 SubscriptionManager 的 import
    if grep -q "import StoreKit" Services/SubscriptionManager.swift; then
        echo "✅ SubscriptionManager.swift 有 import StoreKit"
    else
        echo "❌ SubscriptionManager.swift 缺少 import StoreKit"
    fi
    
    # 检查 IAPManager 的 import
    if grep -q "import StoreKit" Services/IAPManager.swift; then
        echo "✅ IAPManager.swift 有 import StoreKit"
    else
        echo "❌ IAPManager.swift 缺少 import StoreKit"
    fi
    
    echo ""
    echo "🎉 文件验证完成！"
    echo ""
    echo "📋 下一步："
    echo "1. 在 Xcode 中按 Shift + ⌘ + K 清理构建"
    echo "2. 按 ⌘ + B 重新编译"
    echo "3. 如果还有错误，完全退出 Xcode 并重新打开"
else
    echo ""
    echo "❌ 有文件缺失，请先添加缺失的文件"
fi
