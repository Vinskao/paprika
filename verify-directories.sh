#!/bin/bash

echo "🔍 Verifying Laravel Framework Directories..."

# 檢查關鍵目錄
directories=(
    "storage/framework/sessions"
    "storage/framework/views"
    "storage/framework/cache"
    "storage/framework/cache/data"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir exists"
        ls -ld "$dir"
    else
        echo "❌ $dir missing"
    fi
done

echo "📋 Full storage/framework structure:"
ls -la storage/framework/ 2>/dev/null || echo "storage/framework/ not found"

echo "✅ Directory verification completed!"
