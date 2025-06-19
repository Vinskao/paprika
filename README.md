# Paprika Article Sync API

This API service handles synchronization of markdown articles between frontend and backend systems.

## Environment URLs

### Local Development
```
http://127.0.0.1:8000/api/articles
```

### Production
```
https://peoplesystem.tatdvsonorth.com/paprika/api/articles
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

## Troubleshooting

### Storage Permission Issues

If you encounter storage permission errors in Kubernetes, you can fix them manually:

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -l app=paprika -o jsonpath="{.items[0].metadata.name}")

# Create necessary directories and set permissions
kubectl exec -it $POD_NAME -- mkdir -p /app/storage/framework/views
kubectl exec -it $POD_NAME -- mkdir -p /app/storage/framework/cache/data
kubectl exec -it $POD_NAME -- chmod -R 777 /app/storage
kubectl exec -it $POD_NAME -- chmod -R 777 /app/bootstrap/cache

# Clear Laravel caches
kubectl exec -it $POD_NAME -- php artisan cache:clear
kubectl exec -it $POD_NAME -- php artisan config:clear
kubectl exec -it $POD_NAME -- php artisan view:clear
```

### Cache Configuration Issues

The application uses file-based caching by default. Ensure these directories exist with proper permissions:

- `/app/storage/framework/cache/data` - Laravel file cache storage
- `/app/storage/framework/views` - Blade template cache
- `/app/storage/framework/sessions` - Session files
- `/app/bootstrap/cache` - Application cache

### View Compiler Issues

The Blade compiler requires a specific cache path for compiled templates. If you encounter "Please provide a valid cache path" errors:

1. **Check View Compiler Path**: Ensure `VIEW_COMPILED_PATH` environment variable is set
2. **Verify Directory Permissions**: The `/app/storage/framework/views` directory must be writable
3. **Validation**: View compiler validation is automatically performed during Docker build and deployment

### Common Issues

1. **Storage directories not found**: The application requires specific Laravel storage directories to exist with proper permissions.
2. **Permission denied errors**: Ensure storage and bootstrap/cache directories have 777 permissions.
3. **Cache issues**: Clear Laravel caches after permission changes.
4. **Blade compiler cache path errors**: Ensure `/app/storage/framework/cache/data` directory exists and is writable.
5. **View compiler cache path errors**: Ensure `/app/storage/framework/views` directory exists and is writable, and `VIEW_COMPILED_PATH` is set correctly.

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
