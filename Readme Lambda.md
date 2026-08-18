# Testes Lambda

1. Clonar todos os seguintes repositórios:
	https://github.com/cleitonljs/K8s/
	https://github.com/cleitonljs/NotificationsAPI
	https://github.com/cleitonljs/PaymentsAPI
	https://github.com/cleitonljs/CatalogAPI
	https://github.com/cleitonljs/UsersAPI
	
	Serverless:

	Foi feito o seguinte: Foi convertido o projeto NotificationsAPI para uma Lambda function.

	O repositório abaixo contém o código fonte da função Lambda (serverless):
	https://github.com/lSpenserl/NotificationsLambda
	
	O repositório abaixo contém o RabbitMqLambdaBridge (necessário para fazer a ponte entre o RabbitMq e a Lambda function).
	https://github.com/lSpenserl/RabbitMqLambdaBridge

	Detalhamento sobre o RabbitMqLambdaBridge: A NotificationsLambda serve só para criar o .zip,
	e a RabbitMqLambdaBridge é o "gatilho" para acionar o serverless, uma vez que no local não temos Amazon MQ Event Source Mapping.
	
1.1 - Gerar zip:
	
	Rodar o comando abaixo, via powerShell:
		dotnet lambda package --project-location .\NotificationsLambda --output-package .\NotificationsLambda.zip

	O comando acima, criará um arquivo .zip contendo a função Lambda.
	
1.2 - Colar zip.

	O .zip deve estar nesse local: C:\Tech-Challenge-Fase2\K8s\Docker-Compose\localstack\lambdas\NotificationsLambda.zip

2. Verificar se está com o LocalStack instalado, executando o comando:
	localstack --version

3. Caso não esteja, executar: 
	npm install -g @localstack/lstk

4. Deixar o Docker Desktop rodando.

5. Token:

5.1 Acessar https://app.localstack.cloud/getting-started

5.2. Copiar o token da página acima.

5.3 Colar em no arquivo .env

5.4 Criar arquivo .env na pasta C:\Tech-Challenge-Fase2\K8s\Docker-Compose. Esse arquivo não possui nome, é só a extensão mesmo. No seu conteúdo colar:
	LOCALSTACK_AUTH_TOKEN="<token gerado no LocalStack>"

6. Abra o arquivo C:\Tech-Challenge-Fase2\K8s\Docker-Compose\localstack\init\ready.d\01-create-lambda.sh no VS e salve ele no formato LF.

7. Rodar o comando abaixo:
	PS C:\git\TecChanleng(Grupo)\K8s\Docker-Compose> Docker compose up -d

8. Em seguida, seguir o fluxo de criar usuário ou adquirir jogo no catálogo.

8.1. Acessar o FGC API via http://localhost:8010/swagger/index.html
8.2 executar /login:
		{
		  "email": "admin@email.com",
		  "senha": "1234@Abc"
		}
9.3. copiar o token e se autenticar no swagger.

10. Funcionamento:

10.1 Container criado para o serverless (somente para a requisição; depois ele morre).

