# 使用 PHP 8.2 FPM Alpine 鏡像
FROM php:8.2-fpm-alpine

# 安裝系統依賴
RUN apk add --no-cache \
    nginx \
    curl \
    libzip-dev \
    postgresql-dev \
    git \
    unzip \
    && docker-php-ext-install \
    zip \
    pdo \
    pdo_pgsql \
    && docker-php-ext-enable \
    pdo \
    pdo_pgsql

# 設置工作目錄
WORKDIR /app

# 安裝 Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 複製 composer.json 和 composer.lock 文件
COPY composer.json composer.lock ./

# 安裝依賴（使用 --no-scripts 避免執行 Laravel 腳本）
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# 複製整個專案文件
COPY . .

# 重新生成 autoload 文件並執行 Laravel 腳本
RUN composer dump-autoload --optimize && \
    composer run-script post-autoload-dump --no-interaction

# 建立必要目錄並設置權限
RUN mkdir -p \
    storage/framework/sessions \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/cache/data \
    storage/app/public \
    storage/app/private \
    storage/logs \
    bootstrap/cache \
 && chmod -R 777 storage bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache

# 複製 Nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf

# 複製啟動腳本並設置權限
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 暴露端口
EXPOSE 8000

# 設置環境變數
ENV LARAVEL_PORT=8000
ENV LARAVEL_APP_ENV=production
ENV VIEW_COMPILED_PATH=/app/storage/framework/views
ENV CACHE_DRIVER=file
ENV SESSION_DRIVER=file

# 健康檢查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/up || exit 1

# 啟動腳本
CMD ["/start.sh"]
