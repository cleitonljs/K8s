#!/bin/bash

echo "======================================"
echo "Criando NotificationsLambda..."
echo "======================================"

awslocal lambda create-function \
    --function-name NotificationsLambda \
    --runtime dotnet8 \
    --handler NotificationsLambda::NotificationsLambda.Function::FunctionHandler \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --environment 'Variables={
        API_Users__URL=http://users-api:8080,
        API_Users__Email=admin@email.com,
        API_Users__Senha=1234@Abc,
        URL_API_Catalog=http://catalog-api:8080
    }' \
    --zip-file fileb:///lambda/NotificationsLambda.zip

echo "======================================"
echo "Lambda criada!"
echo "======================================"

awslocal lambda list-functions