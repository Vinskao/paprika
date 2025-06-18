# 使用 PHP 8.2 作為基礎映像
FROM php:8.2-fpm

# 安裝系統依賴
RUN apt-get update && apt-get install -y \
    libpq-dev \
    && docker-php-ext-install pdo pdo_pgsql

# 安裝 Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 設置工作目錄
WORKDIR /var/www/html

# 複製專案文件
COPY . .

# 安裝依賴
RUN composer install --no-dev --optimize-autoloader

# 設置權限
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache \
    && mkdir -p /var/www/html/storage/logs \
    && touch /var/www/html/storage/logs/laravel.log \
    && chown -R www-data:www-data /var/www/html/storage/logs

# 修改 PHP-FPM 配置
RUN sed -i 's/listen = 127.0.0.1:9000/listen = 9000/g' /usr/local/etc/php-fpm.d/www.conf

# 暴露端口
EXPOSE 9000

# 啟動 PHP-FPM
CMD ["php-fpm"]
