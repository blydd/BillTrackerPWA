#!/bin/bash

echo "🔍 检查所有 Services 文件的 import 语句..."
echo ""

for file in Services/*.swift; do
    echo "📄 $file"
    echo "   Imports:"
    grep "^import" "$file" | sed 's/^/     /'
    echo ""
done

echo "✅ 检查完成"
