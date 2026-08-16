# Testes Lambda

1. Baixar todos os projetos dos repositórios e colocar na mesma pasta.
	https://github.com/cleitonljs/K8s/
	https://github.com/cleitonljs/NotificationsAPI
	https://github.com/cleitonljs/PaymentsAPI
	https://github.com/cleitonljs/CatalogAPI
	https://github.com/cleitonljs/UsersAPI

2. Verificar se está com o LocalStack instalado, executando o comando:
	localstack --version

3. Caso não esteja, executar: 
	npm install -g @localstack/lstk

4. Deixar o Docker Desktop rodando.

5. Rodar o comando abaixo:
	PS C:\git\TecChanleng(Grupo)\K8s\Docker-Compose> Docker compose up -d

6. Em seguida, seguir o fluxo de criar usuário ou adquirir jogo no catálogo.

7. Container criado para o serverless (somente para a requisição; depois ele morre).

8. No ambiente local, o Amazon MQ Event Source Mapping não existe como 
serviço AWS real. Por isso, utilizamos o projeto `RabbitMqLambdaBridge`
para simular esse comportamento.

https://app.localstack.cloud/getting-started