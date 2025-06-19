# 使用 Bitnami Laravel image
FROM bitnami/laravel:latest

# 設置工作目錄
WORKDIR /app

# 創建必要的 Laravel 目錄結構
RUN mkdir -p storage/framework/{cache/data,views,sessions} \
    && mkdir -p storage/app/{public,private} \
    && mkdir -p storage/logs \
    && mkdir -p bootstrap/cache

# 複製專案文件
COPY . .

# 安裝依賴
RUN composer install --no-dev --optimize-autoloader

# 設置權限 - 確保所有 storage 和 cache 目錄有正確權限
RUN chmod -R 777 storage bootstrap/cache \
    && chown -R 1001:1001 storage bootstrap/cache

# 驗證 View 編譯器配置
RUN php -r 'try { require_once "/app/vendor/autoload.php"; $app = require_once "/app/bootstrap/app.php"; $compiledPath = config("view.compiled"); if (empty($compiledPath)) { throw new Exception("View compiled path is empty"); } if (!is_dir($compiledPath)) { throw new Exception("View compiled directory does not exist: " . $compiledPath); } if (!is_writable($compiledPath)) { throw new Exception("View compiled directory is not writable: " . $compiledPath); } echo "✅ View compiler cache path validated: " . $compiledPath . PHP_EOL; } catch (Exception $e) { echo "❌ View compiler validation failed: " . $e->getMessage() . PHP_EOL; exit(1); }'

# 設置環境變數
ENV LARAVEL_PORT=8000
ENV LARAVEL_APP_ENV=production
ENV VIEW_COMPILED_PATH=/app/storage/framework/views
ENV CACHE_DRIVER=file
ENV SESSION_DRIVER=file

# 暴露端口
EXPOSE 8000

# 健康檢查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/up || exit 1

# 使用 Bitnami 的啟動腳本
CMD ["/opt/bitnami/scripts/laravel/run.sh"]
