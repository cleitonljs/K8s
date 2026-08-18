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

5. Criar arquivo .env na pasta C:\Tech-Challenge-Fase2\K8s\Docker-Compose. Esse arquivo não possui nome, é só a extensão mesmo. No seu conteúdo colar:
	LOCALSTACK_AUTH_TOKEN="Seu token"

6. Rodar o comando abaixo:
	PS C:\git\TecChanleng(Grupo)\K8s\Docker-Compose> Docker compose up -d

7. Em seguida, seguir o fluxo de criar usuário ou adquirir jogo no catálogo.

8. Container criado para o serverless (somente para a requisição; depois ele morre).

9. No ambiente local, o Amazon MQ Event Source Mapping não existe como 
serviço AWS real. Por isso, utilizamos o projeto `RabbitMqLambdaBridge`
para simular esse comportamento.

https://app.localstack.cloud/getting-started