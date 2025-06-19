# 使用 Bitnami Laravel image
FROM bitnami/laravel:latest

# 設置工作目錄
WORKDIR /app

# 複製專案文件
COPY . .

# 安裝依賴
RUN composer install --no-dev --optimize-autoloader

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
