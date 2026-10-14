#!/bin/sh
set -e
cd /app

# 0. Set APP_URL otomatis dari URL platform (Render menyediakannya)
if [ -z "$APP_URL" ] && [ -n "$RENDER_EXTERNAL_URL" ]; then
  export APP_URL="$RENDER_EXTERNAL_URL"
fi

# 1. App key (kalau belum diset lewat env)
if [ -z "$APP_KEY" ]; then
  php artisan key:generate --force
fi

# 1b. Fallback: kalau DB_URL (Postgres) belum diisi, pakai SQLite sementara
#     supaya deploy pertama tetap berhasil.
if [ -z "$DB_URL" ]; then
  echo "DB_URL kosong -> memakai SQLite sementara."
  export DB_CONNECTION=sqlite
  export DB_DATABASE=/app/database/database.sqlite
  touch "$DB_DATABASE"
fi

# 2. Optimasi konfigurasi
php artisan config:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan storage:link || true

# 3. Migrasi database
php artisan migrate --force

# 4. Seed SEKALI saja (hanya kalau tabel users masih kosong,
#    supaya data yang sudah diinput tidak pernah kehapus)
php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
if (\App\Models\User::count() === 0) {
    Illuminate\Support\Facades\Artisan::call("db:seed", ["--force" => true]);
    echo "Seeding database (pertama kali)...\n";
} else {
    echo "Database sudah terisi, seed dilewati.\n";
}
'

# 5. Jalankan web server di port dari platform ($PORT)
exec php artisan serve --host=0.0.0.0 --port=${PORT:-8080}
