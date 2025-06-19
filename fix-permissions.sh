#!/bin/bash

echo "=== Laravel Storage Permissions Fix Script ==="
echo "Date: $(date)"
echo ""

# 獲取 Pod 名稱
POD_NAME=$(kubectl get pods -l app=paprika -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "❌ No paprika pod found!"
    exit 1
fi

echo "Pod Name: $POD_NAME"
echo ""

# 檢查 Pod 狀態
echo "=== Pod Status ==="
kubectl get pods -l app=paprika

echo ""
echo "=== Fixing Storage Permissions ==="
kubectl exec $POD_NAME -c paprika -- /bin/sh -c '
    echo "Creating necessary directories..."
    mkdir -p /app/storage/framework/views
    mkdir -p /app/storage/framework/cache
    mkdir -p /app/storage/framework/sessions
    mkdir -p /app/storage/app/public
    mkdir -p /app/storage/app/private
    mkdir -p /app/storage/logs
    mkdir -p /app/bootstrap/cache

    echo "Setting permissions..."
    chmod -R 777 /app/storage
    chmod -R 777 /app/bootstrap/cache

    echo "Clearing Laravel caches..."
    php artisan cache:clear
    php artisan config:clear
    php artisan view:clear
    php artisan route:clear

    echo "Verifying permissions..."
    ls -la /app/storage/
    echo ""
    ls -la /app/storage/framework/
    echo ""
    ls -la /app/bootstrap/cache/

    echo "✅ Permissions fixed successfully!"
'

echo ""
echo "=== Permission Fix Complete ==="
