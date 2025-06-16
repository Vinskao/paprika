<?php

use App\Http\Controllers\Api\ArticleController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'throttle:60,1'])->group(function () {
    Route::post('/articles/sync', [ArticleController::class, 'sync'])
        ->middleware('ability:article:sync');
});
