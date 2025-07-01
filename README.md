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

## Local Docker Testing

### Quick Start

```bash
# Build the Docker image
docker build -t paprika:prod .

### Testing with Database (Production-like)

```bash
# Run with actual database configuration
docker run -d \
  --name paprika-with-db \
  -p 8000:8000 \
  -e LARAVEL_APP_ENV=production \
  -e LARAVEL_APP_DEBUG=true \
  -e LARAVEL_APP_URL=http://localhost:8000 \
  -e LARAVEL_DATABASE_CONNECTION=pgsql \
  -e LARAVEL_DATABASE_HOST=? \
  -e LARAVEL_DATABASE_PORT_NUMBER=? \
  -e LARAVEL_DATABASE_NAME=? \
  -e LARAVEL_DATABASE_USER=? \
  -e LARAVEL_DATABASE_PASSWORD=? \
  -e LARAVEL_CACHE_DRIVER=file \
  -e LARAVEL_SESSION_DRIVER=file \
  -e LARAVEL_SESSION_LIFETIME=120 \
  -e LARAVEL_FILESYSTEM_DISK=local \
  paprika:prod
```

### Testing the Application

```bash
# Check if the container is running
docker ps

# View container logs
docker logs paprika-dev

# Test the health endpoint
curl http://localhost:8000/up

# Test the API endpoint
curl http://localhost:8000/api/articles

# Access the container shell
docker exec -it paprika-dev /bin/sh
```

### Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `LARAVEL_APP_ENV` | Application environment | `production` | `local` |
| `LARAVEL_APP_DEBUG` | Enable debug mode | `false` | `true` |
| `LARAVEL_APP_URL` | Application URL | `http://localhost:8000` | `http://localhost:8000` |
| `LARAVEL_DATABASE_CONNECTION` | Database connection type | `pgsql` | `pgsql` |
| `LARAVEL_DATABASE_HOST` | Database host | `localhost` | `peoplesystem.tatdvsonorth.com` |
| `LARAVEL_DATABASE_PORT_NUMBER` | Database port | `5432` | `30000` |
| `LARAVEL_DATABASE_NAME` | Database name | `laravel` | `peoplesystem` |
| `LARAVEL_DATABASE_USER` | Database username | `postgres` | `wavo` |
| `LARAVEL_DATABASE_PASSWORD` | Database password | (empty) | `Wawi247525=` |
| `LARAVEL_CACHE_DRIVER` | Cache driver | `file` | `file` |
| `LARAVEL_SESSION_DRIVER` | Session driver | `file` | `file` |
| `LARAVEL_SESSION_LIFETIME` | Session lifetime | `120` | `120` |
| `LARAVEL_FILESYSTEM_DISK` | Filesystem disk | `local` | `local` |

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

1. Create the articles table:

```sql
-- Create articles table
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    file_path VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    file_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    embedding vector(1536)
);
```

2. Run database migrations:
```bash
php artisan migrate:fresh
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

# Paprika Laravel Application

A Laravel application deployed with Docker and Kubernetes using Bitnami Laravel image.

## 🚀 Quick Start

### Prerequisites
- Docker
- Kubernetes cluster
- Jenkins (for CI/CD)

### Local Development
```bash
# Clone the repository
git clone <repository-url>
cd paprika

# Install dependencies
composer install

# Copy environment file
cp .env.template .env

# Generate application key
php artisan key:generate

# Run migrations
php artisan migrate

# Start development server
php artisan serve
```

## 🔧 Configuration

### Environment Variables
The application uses the following key environment variables:

- `LARAVEL_APP_ENV`: Application environment (production/development)
- `LARAVEL_APP_DEBUG`: Debug mode (true/false)
- `LARAVEL_DATABASE_HOST`: Database host
- `LARAVEL_DATABASE_PORT_NUMBER`: Database port
- `LARAVEL_DATABASE_NAME`: Database name
- `LARAVEL_DATABASE_USER`: Database username
- `LARAVEL_DATABASE_PASSWORD`: Database password
- `VIEW_COMPILED_PATH`: Blade view compiler cache path

### Storage Configuration
Laravel storage directories are automatically created by the entrypoint script:

- `/app/storage/framework/views` - Blade compiled views
- `/app/storage/framework/cache/data` - Application cache
- `/app/storage/framework/sessions` - Session files
- `/app/storage/app/public` - Public storage
- `/app/storage/app/private` - Private storage
- `/app/storage/logs` - Application logs
- `/app/bootstrap/cache` - Bootstrap cache


## Debug in Laravel
```bash
tail -n 50 /app/storage/logs/laravel.log
```
