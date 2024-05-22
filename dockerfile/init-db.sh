# init-db.sh
#!/bin/bash

# Extraire le hostname et le port
DB_HOST=$(echo $WORDPRESS_DB_HOST | cut -d':' -f1)
port=$(echo $db_RDS | cut -d':' -f2)

DB_USER=${WORDPRESS_DB_USER}
DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
DB_NAME=${WORDPRESS_DB_NAME}

echo "Checking if database $DB_NAME exists..."
echo "mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e \"CREATE DATABASE IF NOT EXISTS $DB_NAME\""
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME"