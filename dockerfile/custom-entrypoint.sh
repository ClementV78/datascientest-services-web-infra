#!/bin/bash
set -e

# Execute the database initialization script
/usr/local/bin/init-db.sh
echo "test script"
# Execute the original entrypoint script provided by WordPress
/usr/local/bin/docker-entrypoint.sh "$@"