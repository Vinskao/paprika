<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Article extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'slug',
        'title',
        'content',
        'frontmatter',
        'file_hash',
        'file_path',
        'synced_at',
    ];

    protected $casts = [
        'frontmatter' => 'array',
        'synced_at' => 'datetime',
    ];
}
