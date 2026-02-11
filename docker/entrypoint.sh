#!/bin/sh

if [ ! -f "vendor/autoload.php" ]; then
    echo "Installing Composer"
    composer install --no-interaction --no-progress
fi

# Always generate .env from environment variables (clean slate)
rm -f .env
echo "APP_KEY=" > .env

# Write all relevant environment variables into .env with proper quoting
printenv | grep -E '^(APP_|DB_|SESSION_|CACHE_|THEME_|CRON|NTFY_|TELEGRAM_|DEFAULT_|ASSET_|EXCHANGE_|FRANKEN_|DISABLE_|RSS_|SPA|TOP_|BREADCRUMBS|CHROME_)' | while IFS='=' read -r key value; do
    echo "${key}=\"${value}\"" >> .env
done

# Generate APP_KEY if not set via environment
if [ -z "$APP_KEY" ]; then
    php artisan key:generate --force
fi

# Create database directory and file if they don't exist
mkdir -p /app/database/sqlite
if [ ! -f "/app/database/sqlite/database.sqlite" ]; then
    touch /app/database/sqlite/database.sqlite
    echo "Created empty SQLite database"
fi

# Create logs directory
mkdir -p /logs

php artisan storage:link 2>/dev/null || true

printenv > /etc/environment

php artisan migrate --force --seed

php artisan optimize:clear

php artisan filament:optimize-clear

php artisan octane:install --server=frankenphp

php artisan optimize

php artisan filament:optimize

php artisan discount:fill-supervisor-workers 2>/dev/null || true

php artisan discount:exchange-rate 2>/dev/null || true

Xvfb :99 -screen 0 2000x2000x24 & export DISPLAY=:99

supervisord -c /etc/supervisor/conf.d/supervisord.conf
