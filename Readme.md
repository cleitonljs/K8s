# Tech-Challenge - Fase 3

# 1. Implementação de um API Gateway

## Segue abaixo passo a passo para instalar a aplicação FCG no Kubernetes utilizando o Kubernetes do Docker desktop.

1. verificar se está habilitado o Kubernetes do Docker desktop:
kubectl config current-context

2. Limpar o namespace do fcg no Kubernetes no Docker-desktop:
kubectl delete namespace fcg

3. Abrir power shell e posicionar na pasta C:\Tech-Challenge-Fase2\K8s\Kubernetes

### 1. Criar namespace
kubectl apply -f _fcg-namespace.yaml

### 2. Criar o segredo JWT compartilhado entre Users API, Catalog API e Kong:
kubectl apply -f jwt-secret.yaml

### 3. MySQL
kubectl apply -f mysql-configmap.yaml
kubectl apply -f mysql-secret.yaml
kubectl apply -f mysql-pvc.yaml
kubectl apply -f mysql-service.yaml
kubectl apply -f mysql-deployment.yaml

kubectl rollout status deployment/mysql -n fcg --timeout=300s

### 4. RabbitMQ
kubectl apply -f rabbitmq-secret.yaml
kubectl apply -f rabbitmq-service.yaml
kubectl apply -f rabbitmq-deplyment.yaml

kubectl rollout status deployment/rabbitmq -n fcg --timeout=300s

### 5. Users API
kubectl apply -f users-api-configmap.yaml
kubectl apply -f users-api-secret.yaml
kubectl apply -f users-api-service.yaml
kubectl apply -f users-api-deployment.yaml

### 6. Catalog API
kubectl apply -f catalog-api-configmap.yaml
kubectl apply -f catalog-api-secret.yaml
kubectl apply -f catalog-api-service.yaml
kubectl apply -f catalog-api-deployment.yaml

### 7. Payments API
kubectl apply -f payments-api-configmap.yaml
kubectl apply -f payments-api-secret.yaml
kubectl apply -f payments-api-service.yaml
kubectl apply -f payments-api-deployment.yaml

### 8. Notifications API
kubectl apply -f notifications-api-configmap.yaml
kubectl apply -f notifications-api-secret.yaml
kubectl apply -f notifications-api-service.yaml
kubectl apply -f notifications-api-deployment.yaml

### 9. Aguarde todas as APIs:
kubectl rollout status deployment/users-api-deployment -n fcg --timeout=300s
kubectl rollout status deployment/catalog-api-deployment -n fcg --timeout=300s
kubectl rollout status deployment/payments-api -n fcg --timeout=300s
kubectl rollout status deployment/notifications-api -n fcg --timeout=300s

### 10. PostgreSQL do Kong
kubectl apply -f kong-secret.yaml
kubectl apply -f kong-environment-configmap.yaml
kubectl apply -f kong-postgres-init-configmap.yaml
kubectl apply -f kong-postgres-pvc.yaml
kubectl apply -f kong-postgres-service.yaml
kubectl apply -f kong-postgres-deployment.yaml

kubectl rollout status deployment/kong-database -n fcg --timeout=300s

### 11. Migrations do Kong
kubectl apply -f kong-migrations-job.yaml
kubectl wait --for=condition=complete job/kong-migrations -n fcg --timeout=300s

### 12. Kong Gateway e Kong Manager
kubectl apply -f kong-deployment.yaml
kubectl apply -f kong-service.yaml

kubectl rollout status deployment/kong -n fcg --timeout=300s

#Excluir o job das rotas:
#kubectl delete job kong-routes -n fcg

### Fim criação Kubernetes

## Executar migrations:
kubectl port-forward service/mysql 3306:3306 -n fcg
cd C:\Tech-Challenge-Fase2\CatalogAPI
dotnet ef migrations add InitialCatalog --project .\Infrastructure\Infrastructure.csproj --startup-project .\CatalogAPI\CatalogAPI.csproj
dotnet ef database update --project .\Infrastructure\Infrastructure.csproj --startup-project .\CatalogAPI\CatalogAPI.csproj

## Cadastrar as rotas no Api Gateway
#kubectl apply -f kong-routes-job.yaml

## Acessar o Kong Manager
kubectl port-forward service/kong-admin 8001:8001 -n fcg
kubectl port-forward service/kong-manager 8002:8002 -n fcg
Acesse: http://localhost:8002

## Expor o Kong API Gateway
kubectl port-forward service/kong 8080:8000 -n fcg

## Testes:
http://localhost:8080/payments/api/health
http://localhost:8080/notifications/api/health

## Faça login para obter o token JWT (usuário admin padrão).
curl.exe -i http://localhost:8080/users/login -H "Content-Type: application/json" --% -d "{\"Email\":\"admin@email.com\",\"Senha\":\"1234@Abc\"}"

## Copie o valor de "token" do retorno acima e use-o para testar a validação JWT do Kong nas rotas protegidas de Users API e Catalog API:
curl.exe -i http://localhost:8080/users/usuario/todos -H "Authorization: Bearer <TOKEN>"
curl.exe -i http://localhost:8080/catalog/game/todos -H "Authorization: Bearer <TOKEN>"

Sem o header Authorization (ou com um token inválido), o Kong deve responder 401 Unauthorized antes mesmo de a requisição chegar às APIs.

Endereços finais:
Kong Manager: http://localhost:8002
Admin API:    http://localhost:8001
Gateway:      http://localhost:8080

# 2. Arquitetura Serverless

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

# 3. Observabilidade (Prometheus + Grafana)

CatalogAPI e UsersAPI (.NET 8) são instrumentadas com OpenTelemetry e expõem métricas Prometheus no
próprio processo, em `/metrics`. Não é necessário nenhum agente ou sidecar adicional.



## Rodar via Docker Compose

	cd K8s\Docker-Compose
	docker compose up --build

Prometheus: http://localhost:9090 (targets em Status > Targets)
Grafana:    http://localhost:3001  (login: admin / admin123)

## Rodar via Kubernetes

Após subir Users API e Catalog API normalmente (passos 3 e 4 no topo deste arquivo):

	kubectl apply -f prometheus-configmap.yaml
	kubectl apply -f prometheus-pvc.yaml
	kubectl apply -f prometheus-service.yaml
	kubectl apply -f prometheus-deployment.yaml

	kubectl apply -f grafana-datasource-configmap.yaml
	kubectl apply -f grafana-dashboards-configmap.yaml
	kubectl apply -f grafana-secret.yaml
	kubectl apply -f grafana-service.yaml
	kubectl apply -f grafana-deployment.yaml

	kubectl rollout status deployment/prometheus-deployment -n fcg --timeout=300s
	kubectl rollout status deployment/grafana-deployment -n fcg --timeout=300s

Verificar os targets do Prometheus:
	kubectl port-forward service/prometheus 9090:9090 -n fcg
	Acesse http://localhost:9090/targets — catalog-api e users-api devem estar "UP".

Acessar o Grafana (exposto via NodePort, mesmo padrão do Konga):
	minikube service grafana -n fcg
	(ou, em cluster local do Docker Desktop: http://localhost:30030)
	se Kubernetes executar port-forward:
	kubectl port-forward service/grafana 3099:3000 -n fcg
	login: admin / admin123 (definida em grafana-secret.yaml)

Prometheus não é exposto via NodePort/Ingress — só é alcançável dentro do cluster (o Grafana já
concentra a visualização) ou via `port-forward` pontual para depuração.

# 4. Persistência Poliglota e Alta Performance

Guia para o que foi implementado no
item 4 da Fase 3: **MongoDB** para dado de schema flexível/alto volume e **Redis**
como cache distribuído, agora nos três serviços (`UsersAPI`, `CatalogAPI`,
`PaymentsAPI`), além da orquestração (`K8s`).

## 1. Pré-requisitos

- Docker Desktop instalado e rodando.
- .NET 8 SDK instalado, com a ferramenta `dotnet-ef`:

		dotnet tool install --global dotnet-ef

## 2. Subir o ambiente completo

A partir da pasta `K8s/Docker-Compose`:

	cd K8s/Docker-Compose
	docker-compose up --build -d

Espere cerca de 1 minuto e confira que os 8 containers estão `Up` (`mysql`,
`rabbitmq`, `mongo`, `redis`, `users-api`, `notifications-api`, `catalog-api`,
`payments-api`):

	docker-compose ps

> **Normal reiniciar 1-2 vezes no começo:** `users-api`/`catalog-api` podem
> reiniciar sozinhos logo no início num volume de MySQL novo (corrida na criação da
> tabela de migrations). O `restart: always` resolve isso sozinho — se depois de
> ~1 minuto todos estiverem `Up`, seguiu certo.

### Criar as tabelas do MySQL

O time optou por não versionar as migrations do EF Core no repositório, então é
preciso gerar/aplicar uma vez por ambiente (rode a partir da raiz de cada repo):

	# UsersAPI
	$env:ConnectionStrings__DefaultConnection = "server=localhost;port=3306;database=fcgdb;user=root;password=root123"
	dotnet ef migrations add CriacaoBanco --project Infrastructure/Infrastructure.csproj --startup-project UsersAPI/UsersAPI.csproj
	dotnet ef database update --project Infrastructure/Infrastructure.csproj --startup-project UsersAPI/UsersAPI.csproj

	# CatalogAPI (connection string padrão já aponta pra localhost, não precisa sobrescrever)
	dotnet ef migrations add cria-tabelas-catalogAPI --project Infrastructure/Infrastructure.csproj --startup-project CatalogAPI/CatalogAPI.csproj
	dotnet ef database update --project Infrastructure/Infrastructure.csproj --startup-project CatalogAPI/CatalogAPI.csproj

Confirme:

	docker exec mysql mysql -uroot -proot123 -e "USE fcgdb; SHOW TABLES;"

Deve listar `Users`, `Games`, `Library` e `__EFMigrationsHistory`. **Não dê `git add`
na pasta `Migrations/` que isso gera** — ela fica só local, fora do repositório.

## 3. Login e criação de usuário

Login do Admin já existe (`admin@email.com` / `1234@Abc`):

	curl.exe -i http://localhost:8010/login -H "Content-Type: application/json" --% -d "{\"email\":\"admin@email.com\",\"senha\":\"1234@Abc\"}"

Copie o `token` (`<ADMIN_TOKEN>`) e crie um jogo:

	curl.exe -i http://localhost:8030/game/criar -H "Content-Type: application/json" -H "Authorization: Bearer <ADMIN_TOKEN>" --% -d "{\"nome\":\"The Witcher 3\",\"price\":49.90}"

Crie um usuário comum e pegue o token dele também (`<USER_TOKEN>`):

	curl.exe -i http://localhost:8010/usuario/criar -H "Content-Type: application/json" --% -d "{\"nome\":\"Usuario Teste\",\"email\":\"usuarioteste@email.com\",\"senha\":\"Senha123!\"}"
	curl.exe -i http://localhost:8010/login -H "Content-Type: application/json" --% -d "{\"email\":\"usuarioteste@email.com\",\"senha\":\"Senha123!\"}"

Anote o `id` do jogo criado (normalmente `1`, `<GAME_ID>` daqui pra frente) e o `id`
do usuário comum (normalmente `2`).

## 4. Roteiro de teste por funcionalidade

### 4.1 Perfil estendido de usuário (UsersAPI) — MongoDB + cache

Criar/atualizar o próprio perfil (usuário comum, id 2):

	curl.exe -i -X PUT http://localhost:8010/usuario/2/perfil -H "Content-Type: application/json" -H "Authorization: Bearer <USER_TOKEN>" --% -d "{\"bio\":\"Jogador casual\",\"avatarUrl\":\"\",\"preferencias\":{}}"

**Esperado:** `200 OK`, retorna o perfil salvo.

Tentar ver o perfil do Admin (id 1) logado como o usuário comum:

	curl.exe -i http://localhost:8010/usuario/1/perfil -H "Authorization: Bearer <USER_TOKEN>"

**Esperado:** `403 Forbidden` — só o próprio usuário ou um Administrador pode
ver/editar um perfil.

Confirmar persistência no MongoDB:

	docker exec mongo mongosh -u root -p root123 --authenticationDatabase admin --quiet --eval "db.getSiblingDB('fcg_users').user_profiles.find().toArray()"

	Limpar documentos:
		docker exec mongo mongosh -u root -p root123 --authenticationDatabase admin --quiet --eval "db.getSiblingDB('fcg_users').user_profiles.deleteMany({})"

Confirmar persistência no redis:

	docker exec -it redis redis-cli
	keys *
	flushall

Confirmar o cache: chame `GET usuario/2/perfil` duas vezes — a 2ª deve
ser bem mais rápida (TTL de 10 min), e aparece uma chave `users-api:users:perfil:2`
em `docker exec redis redis-cli KEYS "*"`.

### 4.2 Auditoria de pagamento (PaymentsAPI) — MongoDB

Fluxo de compra ponta a ponta (CatalogAPI → RabbitMQ → PaymentsAPI → volta pro
Catalog):

	curl.exe -i -X POST http://localhost:8030/criar -H "Content-Type: application/json" -H "Authorization: Bearer <USER_TOKEN>" --% -d "{\"iDUsuario\":2,\"iDGame\":<GAME_ID>}"

**Esperado:** `201 Created`. Aguarde ~3 segundos (processamento é assíncrono).

Consultar a auditoria:

	curl.exe -i http://localhost:8040/payments/auditoria/<GAME_ID>

**Esperado:** `200 OK`, retorna o pagamento processado (status `Approved`).

Confirmar persistência no MongoDB e a liberação do jogo na biblioteca (MySQL):

	docker exec mongo mongosh -u root -p root123 --authenticationDatabase admin --quiet --eval "db.getSiblingDB('fcg_payments').payment_audit_logs.find().toArray()"
	docker exec mysql mysql -uroot -proot123 -e "USE fcgdb; SELECT * FROM Library;"

### 4.3 Idempotência (PaymentsAPI) — Redis

Prova de que a mesma mensagem do RabbitMQ, entregue mais de uma vez (redelivery),
não é processada duas vezes. Precisa de Python (só biblioteca padrão) instalado.

1. Pare o consumidor: `docker-compose stop payments-api`
2. Faça uma nova compra (fica parada na fila, sem ninguém pra consumir):

		curl.exe -i -X POST http://localhost:8030/criar -H "Content-Type: application/json" -H "Authorization: Bearer <USER_TOKEN>" --% -d "{\"iDUsuario\":2,\"iDGame\":<GAME_ID>}"

3. Capture essa mensagem na fila `FGC-queue-payment` (sem removê-la) e publique
   mais 1-2 cópias idênticas, com o mesmo `message_id` (via RabbitMQ Management
   API, usuário/senha `guest`/`guest`, porta 15672):

		python -c "
		import json, urllib.request, base64
		req = urllib.request.Request('http://localhost:15672/api/queues/%2f/FGC-queue-payment/get', data=json.dumps({'count':1,'ackmode':'ack_requeue_true','encoding':'auto','truncate':50000}).encode(), method='POST', headers={'Content-Type':'application/json'})
		req.add_header('Authorization', 'Basic ' + base64.b64encode(b'guest:guest').decode())
		peek = json.load(urllib.request.urlopen(req))[0]
		def dup():
		    body = {'properties': peek['properties'], 'routing_key': '', 'payload': peek['payload'], 'payload_encoding': 'string'}
		    r = urllib.request.Request('http://localhost:15672/api/exchanges/%2f/FGC-queue-payment/publish', data=json.dumps(body).encode(), method='POST', headers={'Content-Type':'application/json'})
		    r.add_header('Authorization', 'Basic ' + base64.b64encode(b'guest:guest').decode())
		    print(urllib.request.urlopen(r).read().decode())
		dup(); dup()
		print('message_id duplicado:', peek['properties']['message_id'])
		"

4. Religue o consumidor: `docker-compose start payments-api`
5. Aguarde uns 5 segundos e confira:

		docker exec mongo mongosh -u root -p root123 --authenticationDatabase admin --quiet --eval "db.getSiblingDB('fcg_payments').payment_audit_logs.countDocuments()"
		docker exec mysql mysql -uroot -proot123 -e "USE fcgdb; SELECT * FROM Library;"

**Esperado:** mesmo com 3 entregas da mesma mensagem, só **1** registro novo de
auditoria e **1** linha nova na `Library` — nada duplicado.

### 4.4 Avaliação de jogos (CatalogAPI) — MongoDB + cache

Criar e listar uma avaliação:

	curl.exe -i -X POST http://localhost:8030/game/<GAME_ID>/avaliacoes -H "Content-Type: application/json" -H "Authorization: Bearer <USER_TOKEN>" --% -d "{\"nota\":5,\"comentario\":\"Obra-prima, recomendo muito!\"}"
	curl.exe -i http://localhost:8030/game/<GAME_ID>/avaliacoes -H "Authorization: Bearer <USER_TOKEN>"

**Esperado:** `201` na criação, e a avaliação aparece na listagem.

Confirmar persistência no MongoDB:

	docker exec mongo mongosh -u root -p root123 --authenticationDatabase admin --quiet --eval "db.getSiblingDB('fcg_catalog').game_reviews.find().toArray()"

(Opcional) Cache: `GET game/todos` duas vezes seguidas — a 2ª deve vir bem mais
rápida (TTL 60s).

## 5. Encerrar o ambiente

	docker-compose down -v


# Tech-Challenge - Fase 2

# Instruções de uso para rodar via Docker Compose

- Crie uma pasta para salvar os projetos baixados
- Baixe e descompacte o projeto ou clone os repositórios (UsersAPI, CatalogAPI, NotificationsAPI, PaymentsAPI e K8s) na pasta que você criou.
- Abra o terminal na pasta do projeto baixado ou clonado e digite:

cd K8s\Docker-Compose

docker compose up --build

cd..

cd..

dotnet ef migrations add UsersCreate --startup-project .\UserAPI-master\UsersAPI\UsersAPI.csproj --project .\UserAPI-master\Infrastructure\Infrastructure.csproj
dotnet ef database update --startup-project .\UserAPI-master\UsersAPI\UsersAPI.csproj --project .\UserAPI-master\Infrastructure\Infrastructure.csproj

dotnet ef migrations add JogosCreate --startup-project .\CatalogAPI-master\CatalogAPI\CatalogAPI.csproj --project .\CatalogAPI-master\Infrastructure\Infrastructure.csproj
dotnet ef database update --startup-project .\CatalogAPI-master\CatalogAPI\CatalogAPI.csproj --project .\CatalogAPI-master\Infrastructure\Infrastructure.csproj


APIs:
 UsersAPI
 http://localhost:8010/swagger/index.html

 NotificationsAPI
 http://localhost:8020/swagger/index.html
 
 CatalogAPI
 http://localhost:8030/swagger/index.html
 
 PaymentsAPI
 http://localhost:8040/swagger/index.html
 
# Instruções de uso para rodar via Kubernetes

Preparação do ambiente para rodar o minikube via docker para simular um ambiente Kubernetes local na máquina

Iniciar minikube:
	minikube delete
	minikube status
	minikube start --driver=docker

Para limpar os artefatos do minikube:
	kubectl delete all --all -A
	kubectl delete configmaps --all -A
	kubectl delete secrets --all -A
	kubectl delete pvc --all -A
	kubectl delete ingress --all -A

Ver todo conteúdo do fcg:
	kubectl get all -n fcg
	
Ver pods:
	kubectl get pods -n fcg

Copie as imagens para o minikube. Esse comando pega a imagem local e copia para dentro do Minikube:
	minikube image load users-api:latest
	minikube image load notifications-api:latest
	minikube image load catalog-api:latest
	minikube image load payments-api:latest

Ver as imagens do minikube:
	minikube ssh
	crictl images

kubectl apply -f _fcg-namespace.yaml

kubectl apply -f mysql-service.yaml
kubectl apply -f mysql-configmap.yaml
kubectl apply -f mysql-pvc.yaml
kubectl apply -f mysql-secret.yaml
kubectl apply -f mysql-deployment.yaml

kubectl apply -f rabbitmq-secret.yaml
kubectl apply -f rabbitmq-service.yaml
kubectl apply -f rabbitmq-deplyment.yaml
	
kubectl apply -f users-api-configmap.yaml
kubectl apply -f users-api-secret.yaml
kubectl apply -f users-api-service.yaml
kubectl apply -f users-api-deployment.yaml

kubectl apply -f catalog-api-configmap.yaml
kubectl apply -f catalog-api-secret.yaml
kubectl apply -f catalog-api-service.yaml
kubectl apply -f catalog-api-deployment.yaml

kubectl apply -f notifications-api-secret.yaml
kubectl apply -f notifications-api-configmap.yaml
kubectl apply -f notifications-api-service.yaml
kubectl apply -f notifications-api-deployment.yaml

kubectl apply -f payments-api-configmap.yaml
kubectl apply -f payments-api-secret.yaml
kubectl apply -f payments-api-service.yaml
kubectl apply -f payments-api-deployment.yaml

Para descobrir o motivo do Pending:
	kubectl describe pod/mysql-56c6dbcd55-mfkjt -n fcg

Acessar o banco do minikube a partir da máquina local:	
	kubectl port-forward service/mysql 3306:3306 -n fcg
Depois disso, na sua máquina local você acessa:
	Host: localhost
	Port: 3306
	User: root
	Password: root123

Acessar o rabbitmq do minikube a partir da máquina local:	
	kubectl port-forward service/rabbitmq 15672:15672 -n fcg
	
Acessar as apis local na máquina é necessário criar um túnel entre o minikube e a máquina local, execute:
	minikube service users-api -n fcg
	minikube service notifications-api -n fcg
	minikube service catalog-api -n fcg
	minikube service payments-api -n fcg
Será aberta a aplicação automaticamente, porém é necessário completar a url com /swagger/index.html
	
Para ver os logs do deployment da notifications-api:
	kubectl logs deployment/notifications-api -n fcg
	kubectl logs deployment/catalog-api-deployment -n fcg
	kubectl logs deployment/payments-api -n fcg
	kubectl logs pod/mysql-56c6dbcd55-59crx -n fcg
	

	
