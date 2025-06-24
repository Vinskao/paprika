#!/bin/sh

echo "🚀 Starting Laravel application..."

# 設置權限
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
EOF
fi

# 檢查並生成 APP_KEY（如果不存在或無效）
if ! grep -q "^APP_KEY=base64:" /app/.env || grep -q "^APP_KEY=$" /app/.env; then
    echo "🔑 Generating application key..."
    php artisan key:generate --force
fi

# 確保權限正確設置
echo "🔧 Setting permissions..."
chmod -R 777 /app/storage /app/bootstrap/cache
chown -R www-data:www-data /app/storage /app/bootstrap/cache

# 清除緩存
echo "🧹 Clearing caches..."
php artisan config:clear
php artisan cache:clear || echo "⚠️  Cache clear failed, continuing..."
php artisan view:clear
php artisan route:clear

# 運行數據庫遷移（如果設置了數據庫）
if [ -n "$LARAVEL_DATABASE_HOST" ] && [ "$LARAVEL_DATABASE_HOST" != "localhost" ]; then
    echo "🗄️  Running database migrations..."
    php artisan migrate --force
fi

# 優化應用
echo "⚡ Optimizing application..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "✅ Laravel application is ready!"
echo "🌐 Application URL: ${LARAVEL_APP_URL:-http://localhost:8000}"

# 啟動服務
php-fpm -D
nginx -g "daemon off;"
