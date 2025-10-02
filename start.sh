#!/bin/sh

echo "🚀 Starting Laravel application..."

# 🔍 Volume 掛載後檢查：加入診斷輸出
echo "📦 Contents of /app/storage after mount:"
ls -alR /app/storage || echo "❌ /app/storage is missing or not mounted!"

# 🔧 修復 Composer 依賴問題
echo "🔧 Checking and fixing Composer dependencies..."
if [ ! -d "/app/vendor" ] || [ ! -f "/app/vendor/autoload.php" ]; then
    echo "❌ Vendor directory missing or incomplete, reinstalling dependencies..."
    composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
    composer dump-autoload --optimize
    composer run-script post-autoload-dump --no-interaction
fi

# 驗證 Laravel 核心類是否可用
echo "🔍 Validating Laravel core classes..."
if ! php -r "require_once '/app/vendor/autoload.php'; class_exists('Illuminate\\Foundation\\Application') ? exit(0) : exit(1);" 2>/dev/null; then
    echo "❌ Laravel core classes not found, attempting to fix..."
    composer dump-autoload --optimize
    composer run-script post-autoload-dump --no-interaction
fi

# 確保關鍵目錄存在（按照建議的順序）
echo "📁 Creating essential Laravel directories..."

# 🔁 防止 Volume 蓋掉後目錄消失 - 檢查並重建所有必要目錄
if [ ! -d /app/storage/framework/sessions ]; then
    echo "📁 Recreating missing /app/storage/framework/sessions..."
    mkdir -p /app/storage/framework/sessions
fi

if [ ! -d /app/storage/framework/views ]; then
    echo "📁 Recreating missing /app/storage/framework/views..."
    mkdir -p /app/storage/framework/views
fi

if [ ! -d /app/storage/framework/cache ]; then
    echo "📁 Recreating missing /app/storage/framework/cache..."
    mkdir -p /app/storage/framework/cache
fi

if [ ! -d /app/storage/framework/cache/data ]; then
    echo "📁 Recreating missing /app/storage/framework/cache/data..."
    mkdir -p /app/storage/framework/cache/data
fi

# 額外檢查其他可能需要的目錄
if [ ! -d /app/storage/logs ]; then
    echo "📁 Recreating missing /app/storage/logs..."
    mkdir -p /app/storage/logs
fi

if [ ! -d /app/bootstrap/cache ]; then
    echo "📁 Recreating missing /app/bootstrap/cache..."
    mkdir -p /app/bootstrap/cache
fi

# 設置權限
echo "🔧 Setting permissions..."
chmod -R 777 /app/storage /app/bootstrap/cache
chown -R www-data:www-data /app/storage /app/bootstrap/cache

# 再次檢查目錄狀態
echo "🔍 Final directory check after creation:"
ls -al /app/storage/framework/ || echo "❌ /app/storage/framework/ still missing!"
ls -al /app/bootstrap/cache/ || echo "❌ /app/bootstrap/cache/ still missing!"

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
APP_URL=${APP_URL:-http://localhost:8000}

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

# 明確設置視圖緩存路徑 - 這是關鍵設置！
VIEW_COMPILED_PATH=/app/storage/framework/views
EOF
else
    # 如果 .env 已存在，確保 VIEW_COMPILED_PATH 設置正確
    echo "🔧 Ensuring VIEW_COMPILED_PATH is set in existing .env..."
    if ! grep -q "^VIEW_COMPILED_PATH=" /app/.env; then
        echo "VIEW_COMPILED_PATH=/app/storage/framework/views" >> /app/.env
        echo "✅ Added VIEW_COMPILED_PATH to existing .env"
    else
        # 更新現有的 VIEW_COMPILED_PATH
        sed -i 's|^VIEW_COMPILED_PATH=.*|VIEW_COMPILED_PATH=/app/storage/framework/views|' /app/.env
        echo "✅ Updated VIEW_COMPILED_PATH in existing .env"
    fi
fi

# 驗證 .env 設置
echo "🔍 Verifying .env configuration..."
if grep -q "^VIEW_COMPILED_PATH=/app/storage/framework/views" /app/.env; then
    echo "✅ VIEW_COMPILED_PATH correctly set in .env"
else
    echo "❌ VIEW_COMPILED_PATH not found or incorrect in .env"
    echo "Current .env VIEW_COMPILED_PATH setting:"
    grep "VIEW_COMPILED_PATH" /app/.env || echo "Not found"
fi

# 檢查並生成 APP_KEY（如果不存在或無效）
if ! grep -q "^APP_KEY=base64:" /app/.env || grep -q "^APP_KEY=$" /app/.env; then
    echo "🔑 Generating application key..."
    php artisan key:generate --force
fi

# 測試 VIEW_COMPILED_PATH 設置
echo "🔍 Testing VIEW_COMPILED_PATH configuration..."
if php -r "
require_once '/app/vendor/autoload.php';
require_once '/app/bootstrap/app.php';
\$app = require_once '/app/bootstrap/app.php';
echo 'view.compiled: ' . \$app['config']['view.compiled'] . PHP_EOL;
" 2>/dev/null; then
    echo "✅ VIEW_COMPILED_PATH test passed"
else
    echo "❌ VIEW_COMPILED_PATH test failed, attempting to fix..."
    # 強制設置環境變數
    export VIEW_COMPILED_PATH=/app/storage/framework/views
    export LARAVEL_VIEW_COMPILED_PATH=/app/storage/framework/views
    echo "VIEW_COMPILED_PATH=/app/storage/framework/views" >> /app/.env
    echo "LARAVEL_VIEW_COMPILED_PATH=/app/storage/framework/views" >> /app/.env
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
echo "🌐 Application URL: ${APP_URL:-http://localhost:8000}"

# 啟動服務
php-fpm -D
nginx -g "daemon off;"
