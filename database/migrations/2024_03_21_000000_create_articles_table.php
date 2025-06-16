<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 只創建 articles 表，如果它不存在
        if (!Schema::hasTable('articles')) {
            Schema::create('articles', function (Blueprint $table) {
                $table->id();
                $table->string('slug', 255)->unique();
                $table->string('title', 500)->nullable();
                $table->text('content');
                $table->jsonb('frontmatter')->nullable();
                $table->string('file_hash', 32);
                $table->string('file_path', 500);
                $table->timestamp('synced_at')->nullable();
                $table->softDeletes();
                $table->timestamps();

                $table->index('slug');
                $table->index('deleted_at');
            });
        }
    }

    public function down(): void
    {
        // 不刪除表，因為可能影響到其他應用
        // Schema::dropIfExists('articles');
    }
};
