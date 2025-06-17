<?php

use App\Http\Controllers\Api\ArticleController;
use Illuminate\Support\Facades\Route;

// 所有路由都不需要認證
Route::get('/articles', [ArticleController::class, 'index']);
Route::get('/articles/{article}', [ArticleController::class, 'show']);
Route::post('/articles', [ArticleController::class, 'store']);
Route::put('/articles/{article}', [ArticleController::class, 'update']);
Route::delete('/articles/{article}', [ArticleController::class, 'destroy']);
Route::post('/articles/sync', [ArticleController::class, 'sync']);
