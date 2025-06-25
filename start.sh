#!/bin/sh

echo "🚀 Starting Laravel application..."

# 確保關鍵目錄存在（按照建議的順序）
echo "📁 Creating essential Laravel directories..."
mkdir -p /app/storage/framework/sessions
mkdir -p /app/storage/framework/views
mkdir -p /app/storage/framework/cache
mkdir -p /app/storage/framework/cache/data

# 設置權限
echo "🔧 Setting permissions..."
chmod -R 777 /app/storage /app/bootstrap/cache
chown -R www-data:www-data /app/storage /app/bootstrap/cache

# 生成 .env 文件（如果不存在）
if [ ! -f /app/.env ]; then
    echo "📝 Creating .env file..."
    # 生成 APP_KEY
    APP_KEY_VALUE="base64:$(openssl rand -base64 32)"
    cat > /app/.env << EOF
APP_NAME=Paprika
APP_ENV=${LARAVEL_APP_ENV:-production}
APP_KEY=${LARAVEL_APP_KEY:-$APP_KEY_VALUE}
APP_DEBUG=${LARAVEL_APP_DEBUG:-false}
APP_URL=${LARAVEL_APP_URL:-http://localhost:8000}

LOG_CHANNEL=stack
LOG_LEVEL=${LARAVEL_LOG_LEVEL:-debug}

DB_CONNECTION=${LARAVEL_DATABASE_CONNECTION:-pgsql}
DB_HOST=${LARAVEL_DATABASE_HOST:-localhost}
DB_PORT=${LARAVEL_DATABASE_PORT_NUMBER:-5432}
DB_DATABASE=${LARAVEL_DATABASE_NAME:-laravel}
DB_USERNAME=${LARAVEL_DATABASE_USER:-postgres}
DB_PASSWORD=${LARAVEL_DATABASE_PASSWORD:-}

CACHE_DRIVER=${LARAVEL_CACHE_DRIVER:-file}
QUEUE_CONNECTION=${LARAVEL_QUEUE_CONNECTION:-sync}
SESSION_DRIVER=${LARAVEL_SESSION_DRIVER:-file}
SESSION_LIFETIME=${LARAVEL_SESSION_LIFETIME:-120}

BROADCAST_DRIVER=${LARAVEL_BROADCAST_DRIVER:-log}
FILESYSTEM_DISK=${LARAVEL_FILESYSTEM_DISK:-local}

# 明確設置視圖緩存路徑
VIEW_COMPILED_PATH=/app/storage/framework/views
EOF
fi

# 檢查並生成 APP_KEY（如果不存在或無效）
if ! grep -q "^APP_KEY=base64:" /app/.env || grep -q "^APP_KEY=$" /app/.env; then
    echo "🔑 Generating application key..."
    php artisan key:generate --force
fi

# 清除緩存
echo "🧹 Clearing caches..."
php artisan config:clear
php artisan cache:clear || echo "⚠️  Cache clear failed, continuing..."
php artisan view:clear || echo "⚠️  View clear failed, continuing..."
php artisan route:clear

# 運行數據庫遷移（如果設置了數據庫）
if [ -n "$LARAVEL_DATABASE_HOST" ] && [ "$LARAVEL_DATABASE_HOST" != "localhost" ]; then
    echo "🗄️  Running database migrations..."
    php artisan migrate --force
fi

# 優化應用
echo "⚡ Optimizing application..."
php artisan config:cache

# 強制重新生成路由緩存，確保 bootstrap/app.php 的配置被應用
echo "🔄 Regenerating route cache..."
php artisan route:clear
php artisan route:cache

# 生成視圖緩存
echo "🎨 Generating view cache..."
php artisan view:cache || echo "⚠️  View cache generation failed, but continuing..."

# 驗證路由配置
echo "🔍 Verifying route configuration..."
php artisan route:list --compact

echo "✅ Laravel application is ready!"
echo "🌐 Application URL: ${LARAVEL_APP_URL:-http://localhost:8000}"

# 啟動服務
php-fpm -D
nginx -g "daemon off;"
