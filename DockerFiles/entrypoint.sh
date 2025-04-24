#!/bin/bash
set -e

# Create + migrate + seed with explicit credentials
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed


# Remove a potentially pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid

exec "$@"