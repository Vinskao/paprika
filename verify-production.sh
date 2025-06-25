#!/bin/bash

# Production 環境驗證腳本
# 使用方法: ./verify-production.sh <POD_NAME>

POD_NAME=${1:-""}

if [ -z "$POD_NAME" ]; then
    echo "❌ 請提供 Pod 名稱"
    echo "使用方法: ./verify-production.sh <POD_NAME>"
    echo "例如: ./verify-production.sh paprika-7d8f9c6b4a-xyz12"
    exit 1
fi

echo "🔍 驗證 Production 環境配置..."
echo "Pod: $POD_NAME"

# 1. 檢查 bootstrap/app.php 配置
echo "📋 檢查 bootstrap/app.php 配置..."
kubectl exec $POD_NAME -- cat /app/bootstrap/app.php | grep -E "(apiPrefix|health)" || {
    echo "❌ 無法讀取或找到 bootstrap/app.php 配置"
    exit 1
}

# 2. 檢查路由列表
echo "🔍 檢查路由列表..."
kubectl exec $POD_NAME -- php artisan route:list --compact | grep -E "(paprika|up)" || {
    echo "⚠️  未找到 paprika 路由，可能配置有問題"
}

# 3. 檢查健康檢查端點
echo "🏥 測試健康檢查端點..."
kubectl exec $POD_NAME -- curl -s http://localhost:8000/paprika/up || {
    echo "❌ /paprika/up 端點無法訪問"
}

# 4. 檢查 API 端點
echo "📡 測試 API 端點..."
kubectl exec $POD_NAME -- curl -s http://localhost:8000/paprika/articles || {
    echo "❌ /paprika/articles 端點無法訪問"
}

# 5. 檢查 nginx 配置
echo "🌐 檢查 nginx 配置..."
kubectl exec $POD_NAME -- cat /etc/nginx/nginx.conf | grep -A 5 -B 5 "paprika" || {
    echo "⚠️  未找到 nginx paprika 配置"
}

echo "✅ Production 環境驗證完成！"
