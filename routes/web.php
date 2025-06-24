<?php

use Illuminate\Support\Facades\Route;

// 只保留健康檢查端點
Route::get('/up', function () {
    return response()->json(['status' => 'ok']);
});
