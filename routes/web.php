<?php

use Illuminate\Support\Facades\Route;

// 健康檢查端點
Route::get('/up', function () {
    try {
        // 檢查基本 Laravel 功能
        if (app()->isDownForMaintenance()) {
            return response()->json(['status' => 'maintenance'], 503);
        }

        // 檢查數據庫連接（如果配置了數據庫）
        if (config('database.default') && config('database.connections.' . config('database.default'))) {
            try {
                \DB::connection()->getPdo();
            } catch (\Exception $e) {
                return response()->json(['status' => 'database_error', 'message' => $e->getMessage()], 500);
            }
        }

        return response()->json(['status' => 'ok', 'timestamp' => now()->toISOString()]);
    } catch (\Exception $e) {
        return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
    }
});

// 簡單的健康檢查端點
Route::get('/health', function () {
    return response()->json(['status' => 'healthy']);
});

// 根路徑
Route::get('/', function () {
    return response()->json(['message' => 'Paprika API is running']);
});
