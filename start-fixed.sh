#!/bin/sh

echo "🚀 Starting Laravel application (Fixed Version)..."

# 設置明確的環境變數
export VIEW_COMPILED_PATH=/app/storage/framework/views
export CACHE_DRIVER=file
export SESSION_DRIVER=file

# 建立必要目錄並設置權限
echo "📁 Creating directories with explicit paths..."
mkdir -p /app/storage/framework/cache/data
mkdir -p /app/storage/framework/views
mkdir -p /app/storage/framework/sessions
mkdir -p /app/storage/app/public
mkdir -p /app/storage/app/private
mkdir -p /app/storage/logs
mkdir -p /app/bootstrap/cache

# 設置權限
echo "🔧 Setting permissions..."
chmod -R 777 /app/storage /app/bootstrap/cache
chown -R www-data:www-data /app/storage /app/bootstrap/cache

# 驗證目錄存在
echo "✅ Verifying directories..."
ls -la /app/storage/framework/views
ls -la /app/storage/framework/cache/data

# 生成 .env 文件（如果不存在）
if [ ! -f /app/.env ]; then
    echo "📝 Creating .env file..."
    APP_KEY_VALUE="base64:$(openssl rand -base64 32)"
    cat > /app/.env << EOF
APP_NAME=Paprika
APP_ENV=production
APP_KEY=${APP_KEY_VALUE}
APP_DEBUG=false
APP_URL=http://localhost:8000

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=pgsql
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=postgres
DB_PASSWORD=

CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

BROADCAST_DRIVER=log
FILESYSTEM_DISK=local

# 明確設置視圖緩存路徑
VIEW_COMPILED_PATH=/app/storage/framework/views
EOF
fi

# 檢查並生成 APP_KEY
if ! grep -q "^APP_KEY=base64:" /app/.env; then
    echo "🔑 Generating application key..."
    php artisan key:generate --force
fi

# 清除緩存（使用明確路徑）
echo "🧹 Clearing caches..."
php artisan config:clear
php artisan cache:clear || echo "⚠️  Cache clear failed, continuing..."
php artisan view:clear || echo "⚠️  View clear failed, continuing..."
php artisan route:clear

# 優化應用
echo "⚡ Optimizing application..."
php artisan config:cache

# 生成路由緩存
echo "🔄 Generating route cache..."
php artisan route:cache

# 生成視圖緩存（使用明確路徑）
echo "🎨 Generating view cache..."
cd /app
php artisan view:cache || {
    echo "⚠️  View cache generation failed, but continuing..."
    echo "📋 Checking views directory:"
    ls -la /app/storage/framework/views
}

# 驗證路由配置
echo "🔍 Verifying route configuration..."
php artisan route:list --compact

echo "✅ Laravel application is ready!"
echo "🌐 Application URL: http://localhost:8000"

# 啟動服務
php-fpm -D
nginx -g "daemon off;"
