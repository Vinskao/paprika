# Paprika Article Sync API

This API service handles synchronization of markdown articles between frontend and backend systems.

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

The API will be available at `http://localhost:8000/api/paprika/sync`

## Testing the API

You can test the API using curl:

```bash
curl -X POST http://localhost:8000/api/paprika/sync \
  -H "Content-Type: application/json" \
  -d '{
    "articles": [
      {
        "file_path": "src/content/work/article-1.md",
        "content": "# Article Title\n\nArticle content here...",
        "file_date": "2024-12-01T10:30:00Z"
      }
    ]
  }'
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

## API Endpoints

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
