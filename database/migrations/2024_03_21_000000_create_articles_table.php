<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 檢查表是否存在
        if (!Schema::hasTable('articles')) {
            Schema::create('articles', function (Blueprint $table) {
                $table->id();
                $table->string('file_path', 500)->unique();
                $table->text('content');
                $table->timestamp('file_date');
                $table->timestamps();

                $table->index('file_date');
            });
        }
    }

    public function down(): void
    {
        // 不刪除表，因為可能影響到其他應用
        // Schema::dropIfExists('articles');
    }
};
