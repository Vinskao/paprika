#!/bin/bash

echo "=== Laravel Cache Configuration Verification Script ==="
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
echo "=== Verifying Cache Configuration ==="
kubectl exec $POD_NAME -c paprika -- /bin/sh -c '
    echo "Checking Laravel cache configuration..."
    echo ""

    # 檢查環境變數
    echo "Environment Variables:"
    echo "CACHE_DRIVER: ${CACHE_DRIVER:-not set}"
    echo "SESSION_DRIVER: ${SESSION_DRIVER:-not set}"
    echo ""

    # 檢查目錄結構
    echo "Directory Structure Check:"
    for dir in "/app/storage/framework/cache/data" "/app/storage/framework/views" "/app/storage/framework/sessions" "/app/bootstrap/cache"; do
        if [ -d "$dir" ]; then
            echo "✅ $dir exists"
            if [ -w "$dir" ]; then
                echo "   ✅ $dir is writable"
            else
                echo "   ❌ $dir is not writable"
            fi
        else
            echo "❌ $dir does not exist"
        fi
    done
    echo ""

    # 檢查權限
    echo "Permission Check:"
    ls -la /app/storage/framework/cache/
    echo ""
    ls -la /app/storage/framework/views/
    echo ""
    ls -la /app/bootstrap/cache/
    echo ""

    # 測試 Laravel 快取功能
    echo "Testing Laravel Cache:"
    if php artisan cache:clear >/dev/null 2>&1; then
        echo "✅ Cache clear command works"
    else
        echo "❌ Cache clear command failed"
    fi

    if php artisan config:clear >/dev/null 2>&1; then
        echo "✅ Config clear command works"
    else
        echo "❌ Config clear command failed"
    fi

    if php artisan view:clear >/dev/null 2>&1; then
        echo "✅ View clear command works"
    else
        echo "❌ View clear command failed"
    fi
    echo ""

    # 檢查 Laravel 配置
    echo "Laravel Configuration Check:"
    php artisan config:show cache.default 2>/dev/null || echo "❌ Cannot read cache.default config"
    php artisan config:show session.driver 2>/dev/null || echo "❌ Cannot read session.driver config"
    echo ""

    echo "✅ Cache configuration verification completed"
'

echo ""
echo "=== Verification Complete ==="
