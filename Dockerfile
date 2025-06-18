# 使用 Bitnami Laravel image
FROM bitnami/laravel:latest

# 設置工作目錄
WORKDIR /app

# 複製專案文件
COPY . .

# 安裝依賴
RUN composer install --no-dev --optimize-autoloader

# 設置權限
RUN chmod -R 777 storage bootstrap/cache

# 設置環境變數
ENV LARAVEL_PORT=8000

# 暴露端口
EXPOSE 8000

# 使用 Bitnami 的啟動腳本
CMD ["/opt/bitnami/scripts/laravel/run.sh"]
