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
