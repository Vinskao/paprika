<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Article;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

class ArticleController extends Controller
{
    public function index()
    {
        $articles = Article::select(['id', 'file_path', 'content', 'file_date', 'created_at', 'updated_at'])
            ->orderBy('file_date', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $articles
        ]);
    }

    public function show(Article $article)
    {
        try {
            return response()->json([
                'success' => true,
                'data' => $article
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to fetch article: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch article',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function store(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'file_path' => 'required|string|max:500|unique:articles',
                'content' => 'required|string',
                'file_date' => 'required|date',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            $article = Article::create($request->all());

            return response()->json([
                'success' => true,
                'message' => 'Article created successfully',
                'data' => $article
            ], 201);
        } catch (\Exception $e) {
            Log::error('Failed to create article: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to create article',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function update(Request $request, Article $article)
    {
        try {
            $validator = Validator::make($request->all(), [
                'content' => 'required|string',
                'file_date' => 'required|date',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            $article->update($request->all());

            return response()->json([
                'success' => true,
                'message' => 'Article updated successfully',
                'data' => $article
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to update article: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to update article',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function destroy(Article $article)
    {
        try {
            $article->delete();

            return response()->json([
                'success' => true,
                'message' => 'Article deleted successfully'
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to delete article: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to delete article',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function sync(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'articles' => 'required|array',
                'articles.*.file_path' => 'required|string|max:500',
                'articles.*.content' => 'required|string',
                'articles.*.file_date' => 'required|date',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            $stats = [
                'total_received' => count($request->articles),
                'created' => 0,
                'updated' => 0,
                'skipped' => 0
            ];

            DB::beginTransaction();

            foreach ($request->articles as $articleData) {
                $article = Article::where('file_path', $articleData['file_path'])->first();
                $fileDate = new \DateTime($articleData['file_date']);

                if (!$article) {
                    Article::create([
                        'file_path' => $articleData['file_path'],
                        'content' => $articleData['content'],
                        'file_date' => $fileDate
                    ]);
                    $stats['created']++;
                } else {
                    if ($fileDate > $article->file_date) {
                        $article->update([
                            'content' => $articleData['content'],
                            'file_date' => $fileDate
                        ]);
                        $stats['updated']++;
                    } else {
                        $stats['skipped']++;
                    }
                }
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Articles synced successfully',
                'data' => $stats,
                'timestamp' => now()->toIso8601String()
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Article sync failed: ' . $e->getMessage());

            return response()->json([
                'success' => false,
                'message' => 'An error occurred while syncing articles',
                'error' => $e->getMessage()
            ], 500);
        }
    }
}
