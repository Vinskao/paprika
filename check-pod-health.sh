#!/bin/bash

echo "=== Pod Health Check Script ==="
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
echo "=== Pod Details ==="
kubectl describe pod $POD_NAME

echo ""
echo "=== Pod Restart Count ==="
RESTART_COUNT=$(kubectl get pods -l app=paprika -o jsonpath="{.items[0].status.containerStatuses[0].restartCount}")
echo "Restart Count: $RESTART_COUNT"

if [ "$RESTART_COUNT" -gt 10 ]; then
    echo "⚠️  Warning: High restart count detected!"
fi

echo ""
echo "=== Pod Events ==="
kubectl get events --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp'

echo ""
echo "=== Container Logs (Last 20 lines) ==="
kubectl logs $POD_NAME -c paprika --tail=20

echo ""
echo "=== Checking Laravel Application Health ==="

# 等待 Pod Ready
echo "Waiting for pod to be ready..."
if kubectl wait --for=condition=Ready pod/$POD_NAME --timeout=180s; then
    echo "✅ Pod is ready!"
else
    echo "❌ Pod failed to become ready within 180s"
    exit 1
fi

# 檢查 Laravel 應用
echo "Checking Laravel application..."
for i in {1..30}; do
    echo "Attempt $i/30: Checking Laravel application..."

    if kubectl exec $POD_NAME -c paprika -- curl -f http://localhost:8000/up >/dev/null 2>&1; then
        echo "✅ Laravel application is ready!"
        break
    fi

    if [ $i -eq 30 ]; then
        echo "❌ Laravel application failed to become ready after 30 attempts"
        echo "=== Final Laravel logs ==="
        kubectl logs $POD_NAME -c paprika --tail=50
        exit 1
    fi

    echo "Application not ready yet, waiting 2 seconds..."
    sleep 2
done

echo ""
echo "=== Environment Variables Check ==="
kubectl exec $POD_NAME -c paprika -- env | grep LARAVEL_ | sort

echo ""
echo "=== Storage Directory Permissions Check ==="
kubectl exec $POD_NAME -c paprika -- sh -c '
    echo "Checking storage directory permissions..."
    ls -la /app/storage/
    echo ""
    echo "Checking storage/framework directory permissions..."
    ls -la /app/storage/framework/
    echo ""
    echo "Checking bootstrap/cache directory permissions..."
    ls -la /app/bootstrap/cache/
    echo ""
    echo "Checking if storage directories are writable..."
    if [ -w /app/storage ] && [ -w /app/bootstrap/cache ]; then
        echo "✅ Storage directories are writable"
    else
        echo "❌ Storage directories are not writable"
        exit 1
    fi
'

echo ""
echo "=== Health Check Complete ==="
