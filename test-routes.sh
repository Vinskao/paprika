#!/bin/bash

echo "🧪 Testing Laravel Route Configuration..."

# 檢查 bootstrap/app.php 配置
echo "📋 Checking bootstrap/app.php configuration..."
if grep -q "apiPrefix: 'paprika'" bootstrap/app.php; then
    echo "✅ apiPrefix: 'paprika' found in bootstrap/app.php"
else
    echo "❌ apiPrefix: 'paprika' NOT found in bootstrap/app.php"
    exit 1
fi

if grep -q "health: '/up'" bootstrap/app.php; then
    echo "✅ health: '/up' found in bootstrap/app.php"
else
    echo "❌ health: '/up' NOT found in bootstrap/app.php"
    exit 1
fi

# 檢查路由列表
echo "🔍 Checking route list..."
if command -v php &> /dev/null; then
    echo "📋 Current routes:"
    php artisan route:list --compact | grep -E "(paprika|up)" || echo "No paprika routes found"
else
    echo "⚠️  PHP not available, skipping route list check"
fi

# 檢查 nginx 配置
echo "🌐 Checking nginx configuration..."
if [ -f "nginx.conf" ]; then
    if grep -q "location ~ \^/paprika/" nginx.conf; then
        echo "✅ nginx paprika route configuration found"
    else
        echo "❌ nginx paprika route configuration NOT found"
    fi
else
    echo "⚠️  nginx.conf not found"
fi

echo "✅ Route configuration test completed!"