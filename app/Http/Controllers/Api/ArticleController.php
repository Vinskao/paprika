<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Article;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class ArticleController extends Controller
{
    public function sync(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'articles' => 'required|array',
            'articles.*.slug' => 'required|string|max:255',
            'articles.*.title' => 'nullable|string|max:500',
            'articles.*.content' => 'required|string',
            'articles.*.frontmatter' => 'nullable|array',
            'articles.*.file_hash' => 'required|string|size:32',
            'articles.*.file_path' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $currentSlugs = collect($request->articles)->pluck('slug')->toArray();

            // Mark articles not in current batch as soft deleted
            Article::whereNotIn('slug', $currentSlugs)
                ->whereNull('deleted_at')
                ->update(['deleted_at' => now()]);

            $syncedCount = 0;
            $now = now();

            foreach ($request->articles as $articleData) {
                Article::updateOrCreate(
                    ['slug' => $articleData['slug']],
                    [
                        'title' => $articleData['title'] ?? null,
                        'content' => $articleData['content'],
                        'frontmatter' => $articleData['frontmatter'] ?? null,
                        'file_hash' => $articleData['file_hash'],
                        'file_path' => $articleData['file_path'],
                        'synced_at' => $now,
                    ]
                );
                $syncedCount++;
            }

            DB::commit();

            return response()->json([
                'message' => 'Articles synchronized successfully',
                'data' => [
                    'synced_count' => $syncedCount,
                    'synced_at' => $now,
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'message' => 'Failed to synchronize articles',
                'error' => $e->getMessage()
            ], 500);
        }
    }
}
