# Article Manager API

一個基於 Laravel 的 API 服務，用於管理來自 Astro 前端專案的 Markdown 文章。

## 系統需求

- PHP 8.2+
- PostgreSQL 12+
- Composer
- Node.js & NPM（用於前端開發）

## 安裝步驟

1. 克隆專案：
```bash
git clone <repository-url>
cd article-manager
```

2. 安裝依賴：
```bash
composer install
```

3. 配置環境：
```bash
cp .env.example .env
php artisan key:generate
```

4. 更新 `.env` 中的資料庫配置：
```
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=article_manager
DB_USERNAME=your_username
DB_PASSWORD=your_password
```

5. 執行資料庫遷移：
```bash
php artisan migrate
```

6. 生成前端 API 令牌：
```bash
php artisan api:generate-token astro-frontend
```

## API 文檔

### 認證

所有 API 請求都需要使用 Laravel Sanctum 令牌進行認證。在請求中加入以下標頭：

```
Authorization: Bearer your-token-here
```

### API 端點

#### 同步文章
```
POST /api/articles/sync
```

請求內容：
```json
{
  "articles": [
    {
      "slug": "article-slug",
      "title": "文章標題",
      "content": "文章內容...",
      "frontmatter": {
        "author": "作者名稱",
        "date": "2024-03-21"
      },
      "file_hash": "32位元雜湊值",
      "file_path": "src/content/work/article-slug.md"
    }
  ]
}
```

回應：
```json
{
  "message": "文章同步成功",
  "data": {
    "synced_count": 1,
    "synced_at": "2024-03-21T12:00:00Z"
  }
}
```

## 開發指南

1. 啟動開發伺服器：
```bash
php artisan serve
```

2. API 將在 `http://localhost:8000` 上運行

## 速率限制

API 端點限制為每分鐘每 IP 60 個請求。

## 錯誤處理

API 會返回適當的 HTTP 狀態碼和 JSON 格式的錯誤訊息：

- 422: 驗證錯誤
- 401: 認證錯誤
- 403: 授權錯誤
- 429: 超過速率限制
- 500: 伺服器錯誤

## 授權

MIT
