Set these variables
    export TF_VAR_AWS_ACCESS_KEY_ID=********
    export TF_VAR_AWS_SECRET_ACCESS_KEY=********
    export TF_VAR_MYSQL_DB_PWD=**********
    export TF_VAR_MYSQL_DB_USER=**********

Deploy
    into serviceweb-infra
        terraform apply --auto-approve

    into serviceweb-infra/wordpress-k8s
        terraform apply --auto-approve