<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Laravel\Sanctum\PersonalAccessToken;

class GenerateApiToken extends Command
{
    protected $signature = 'api:generate-token {name} {--abilities=*}';
    protected $description = 'Generate a new API token for external services';

    public function handle()
    {
        $name = $this->argument('name');
        $abilities = $this->option('abilities') ?: ['article:sync'];

        $token = PersonalAccessToken::create([
            'name' => $name,
            'token' => hash('sha256', $plainTextToken = \Str::random(40)),
            'abilities' => $abilities,
        ]);

        $this->info('API Token generated successfully!');
        $this->info('Token: ' . $plainTextToken);
        $this->info('Please store this token securely. It will not be shown again.');
    }
}
