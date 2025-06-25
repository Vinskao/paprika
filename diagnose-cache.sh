#!/bin/bash

echo "🔍 Laravel Cache Path Diagnosis"

# 檢查當前目錄
echo "📁 Current directory: $(pwd)"

# 檢查 storage 目錄結構
echo "📋 Storage directory structure:"
ls -la storage/ 2>/dev/null || echo "❌ storage/ directory not found"

echo "📋 Storage/framework directory structure:"
ls -la storage/framework/ 2>/dev/null || echo "❌ storage/framework/ directory not found"

echo "📋 Storage/framework/views directory:"
ls -la storage/framework/views/ 2>/dev/null || echo "❌ storage/framework/views/ directory not found"

# 檢查權限
echo "🔐 Directory permissions:"
if [ -d "storage" ]; then
    echo "storage/ permissions: $(ls -ld storage/)"
fi

if [ -d "storage/framework" ]; then
    echo "storage/framework/ permissions: $(ls -ld storage/framework/)"
fi

if [ -d "storage/framework/views" ]; then
    echo "storage/framework/views/ permissions: $(ls -ld storage/framework/views/)"
fi

# 檢查 PHP 和 Laravel 配置
echo "🐘 PHP version:"
php --version 2>/dev/null || echo "❌ PHP not available"

# 檢查 .env 文件
echo "📝 .env file check:"
if [ -f ".env" ]; then
    echo "✅ .env file exists"
    grep -E "(CACHE_DRIVER|VIEW_COMPILED_PATH)" .env 2>/dev/null || echo "⚠️  Cache configuration not found in .env"
else
    echo "❌ .env file not found"
fi

# 檢查 bootstrap/cache 目錄
echo "📋 Bootstrap/cache directory:"
ls -la bootstrap/cache/ 2>/dev/null || echo "❌ bootstrap/cache/ directory not found"

# 嘗試執行 Laravel 命令
echo "🎯 Testing Laravel commands:"
if command -v php &> /dev/null && [ -f "artisan" ]; then
    echo "Testing config:clear..."
    php artisan config:clear 2>&1 || echo "❌ config:clear failed"

    echo "Testing view:clear..."
    php artisan view:clear 2>&1 || echo "❌ view:clear failed"

    echo "Testing view:cache..."
    php artisan view:cache 2>&1 || echo "❌ view:cache failed"
else
    echo "⚠️  PHP or artisan not available"
fi

echo "✅ Diagnosis completed!"
