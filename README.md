# Paprika Article Sync API

This API service handles synchronization of markdown articles between frontend and backend systems.

## Environment URLs

### Local Development
```
http://127.0.0.1:8000/api/articles
```

### Production
```
http://peoplesystem.tatdvsonorth.com/paprika/api/articles
```

## Setup Instructions

1. Configure the database connection in `.env`:
```
DB_CONNECTION=pgsql
DB_HOST=your-database-host
DB_PORT=your-database-port
DB_DATABASE=your-database-name
DB_USERNAME=your-username
DB_PASSWORD=your-password
```

2. Run database migrations:
```bash
php artisan migrate:fresh
```

3. Start the Laravel development server:
```bash
php artisan serve
```

## Database Setup

1. Create the articles table and indexes:

```sql
-- Create articles table
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    file_path VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    file_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE UNIQUE INDEX idx_articles_file_path ON articles(file_path);
CREATE INDEX idx_articles_file_date ON articles(file_date);
```

2. Create the trigger function:

```sql
-- Create trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

3. Create the trigger:

```sql
-- Create trigger
CREATE TRIGGER update_articles_updated_at 
    BEFORE UPDATE ON articles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
```

## Useful Commands

### List all routes
```bash
php artisan route:list
```

### Database commands
```bash
# Run migrations
php artisan migrate

# Rollback migrations
php artisan migrate:rollback

# Refresh migrations (rollback all and migrate again)
php artisan migrate:refresh

# Reset database and run all migrations
php artisan migrate:fresh
```

### Clear application cache
```bash
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
```

## Docker Build

```bash
# Build with latest tag
docker build -t papakao/paprika:latest .

# Build with specific tag
docker build -t papakao/paprika:v1.0.0 .

# Push to Docker Hub
docker login
docker push papakao/paprika:latest
```

## API Endpoints

### 1. 取得所有文章列表
- **端點**: `GET /api/articles`
- **說明**: 取得所有文章的列表
- **回應格式**:
```json
{
    "success": true,
    "data": [
        {
            "id": 1,
            "file_path": "src/content/work/article-1.md",
            "content": "# Article Title\n\nArticle content here...",
            "file_date": "2024-12-01T10:30:00Z",
            "created_at": "2024-03-21T12:00:00Z",
            "updated_at": "2024-03-21T12:00:00Z"
        }
    ]
}
```

### POST /api/paprika/sync

Synchronizes articles between systems.

#### Request Format

```json
{
    "articles": [
        {
            "file_path": "src/content/work/article-1.md",
            "content": "# Article Title\n\nArticle content here...",
            "file_date": "2024-12-01T10:30:00Z"
        }
    ]
}
```

#### Response Format

Success (200):
```json
{
    "success": true,
    "message": "Articles synced successfully",
    "data": {
        "total_received": 5,
        "created": 2,
        "updated": 3,
        "skipped": 0
    },
    "timestamp": "2024-12-01T12:00:00Z"
}
```

Error (422):
```json
{
    "success": false,
    "message": "Validation failed",
    "errors": {
        "articles.0.file_path": ["The file path field is required"],
        "articles.1.content": ["The content field is required"]
    }
}
```

## Business Logic

- Accepts batch of articles in single request
- For each article, compares file_date with existing record
- Only updates if incoming file_date is newer than stored file_date
- Creates new record if file_path doesn't exist
- Skips update if incoming file_date is older or equal
- Returns detailed sync statistics

## Validation Rules

- articles: required|array
- articles.*.file_path: required|string|max:500
- articles.*.content: required|string
- articles.*.file_date: required|date

## Error Handling

- Implements try-catch for database operations
- Returns appropriate HTTP status codes
- Logs sync operations for debugging

## API 端點說明

### 2. 新增單篇文章
- **端點**: `POST /api/articles`
- **說明**: 新增一篇文章
- **請求格式**:
```json
{
    "file_path": "src/content/work/article-1.md",
    "content": "# Article Title\n\nArticle content here...",
    "file_date": "2024-12-01T10:30:00Z"
}
```

### 3. 同步多篇文章
- **端點**: `POST /api/articles/sync`
- **說明**: 批次同步多篇文章，會根據 file_date 決定是否更新
- **請求格式**:
```json
{
    "articles": [
        {
            "file_path": "src/content/work/article-1.md",
            "content": "# Article Title\n\nArticle content here...",
            "file_date": "2024-12-01T10:30:00Z"
        }
    ]
}
```
- **回應格式**:
```json
{
    "success": true,
    "message": "Articles synced successfully",
    "data": {
        "total_received": 5,
        "created": 2,
        "updated": 3,
        "skipped": 0
    },
    "timestamp": "2024-12-01T12:00:00Z"
}
```

### 4. 取得單篇文章
- **端點**: `GET /api/articles/{article}`
- **說明**: 根據 ID 取得特定文章的詳細資訊
- **回應格式**:
```json
{
    "success": true,
    "data": {
        "id": 1,
        "file_path": "src/content/work/article-1.md",
        "content": "# Article Title\n\nArticle content here...",
        "file_date": "2024-12-01T10:30:00Z",
        "created_at": "2024-03-21T12:00:00Z",
        "updated_at": "2024-03-21T12:00:00Z"
    }
}
```

### 5. 更新單篇文章
- **端點**: `PUT /api/articles/{article}`
- **說明**: 更新特定文章的內容
- **請求格式**:
```json
{
    "file_path": "src/content/work/article-1.md",
    "content": "# Updated Title\n\nUpdated content here...",
    "file_date": "2024-12-01T10:30:00Z"
}
```

### 6. 刪除單篇文章
- **端點**: `DELETE /api/articles/{article}`
- **說明**: 刪除特定文章
- **回應格式**:
```json
{
    "success": true,
    "message": "Article deleted successfully"
}
```

## Postman 集合

你可以使用以下 Postman 集合來測試 API：

```json
{
    "info": {
        "name": "Paprika Article API",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    },
    "item": [
        {
            "name": "Get All Articles",
            "request": {
                "method": "GET",
                "url": "http://localhost:8001/api/articles"
            }
        },
        {
            "name": "Create Article",
            "request": {
                "method": "POST",
                "url": "http://localhost:8001/api/articles",
                "header": [
                    {
                        "key": "Content-Type",
                        "value": "application/json"
                    }
                ],
                "body": {
                    "mode": "raw",
                    "raw": "{\n    \"file_path\": \"src/content/work/article-1.md\",\n    \"content\": \"# Article Title\\n\\nArticle content here...\",\n    \"file_date\": \"2024-12-01T10:30:00Z\"\n}"
                }
            }
        },
        {
            "name": "Sync Articles",
            "request": {
                "method": "POST",
                "url": "http://localhost:8001/api/articles/sync",
                "header": [
                    {
                        "key": "Content-Type",
                        "value": "application/json"
                    }
                ],
                "body": {
                    "mode": "raw",
                    "raw": "{\n    \"articles\": [\n        {\n            \"file_path\": \"src/content/work/article-1.md\",\n            \"content\": \"# Article Title\\n\\nArticle content here...\",\n            \"file_date\": \"2024-12-01T10:30:00Z\"\n        }\n    ]\n}"
                }
            }
        },
        {
            "name": "Get Article",
            "request": {
                "method": "GET",
                "url": "http://localhost:8001/api/articles/1"
            }
        },
        {
            "name": "Update Article",
            "request": {
                "method": "PUT",
                "url": "http://localhost:8001/api/articles/1",
                "header": [
                    {
                        "key": "Content-Type",
                        "value": "application/json"
                    }
                ],
                "body": {
                    "mode": "raw",
                    "raw": "{\n    \"file_path\": \"src/content/work/article-1.md\",\n    \"content\": \"# Updated Title\\n\\nUpdated content here...\",\n    \"file_date\": \"2024-12-01T10:30:00Z\"\n}"
                }
            }
        },
        {
            "name": "Delete Article",
            "request": {
                "method": "DELETE",
                "url": "http://localhost:8001/api/articles/1"
            }
        }
    ]
}
```
