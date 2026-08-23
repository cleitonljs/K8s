# Tech-Challenge - Fase 3

segue abaixo passo a passo para levantar o Kubernetes utilizando o Kubernetes do Docker desktop.

1. limpar o Kubernetes no Docker-desktop

verificar se está habilitado o Kubernetes do Docker desktop:
kubectl config current-context

2. abrir power shell e posicionar na pasta C:\Tech-Challenge-Fase2\K8s\Kubernetes

#Criar namespace
kubectl apply -f _fcg-namespace.yaml

#Criar o segredo JWT compartilhado entre Users API, Catalog API e Kong:
kubectl apply -f jwt-secret.yaml

### 1. MySQL
kubectl apply -f mysql-configmap.yaml
kubectl apply -f mysql-secret.yaml
kubectl apply -f mysql-pvc.yaml
kubectl apply -f mysql-service.yaml
kubectl apply -f mysql-deployment.yaml

kubectl rollout status deployment/mysql -n fcg --timeout=300s

#2. RabbitMQ
kubectl apply -f rabbitmq-secret.yaml
kubectl apply -f rabbitmq-service.yaml
kubectl apply -f rabbitmq-deplyment.yaml

kubectl rollout status deployment/rabbitmq -n fcg --timeout=300s

#3. Users API
kubectl apply -f users-api-configmap.yaml
kubectl apply -f users-api-secret.yaml
kubectl apply -f users-api-service.yaml
kubectl apply -f users-api-deployment.yaml

#4. Catalog API
kubectl apply -f catalog-api-configmap.yaml
kubectl apply -f catalog-api-secret.yaml
kubectl apply -f catalog-api-service.yaml
kubectl apply -f catalog-api-deployment.yaml

#5. Payments API
kubectl apply -f payments-api-configmap.yaml
kubectl apply -f payments-api-secret.yaml
kubectl apply -f payments-api-service.yaml
kubectl apply -f payments-api-deployment.yaml
6. Notifications API
kubectl apply -f notifications-api-configmap.yaml
kubectl apply -f notifications-api-secret.yaml
kubectl apply -f notifications-api-service.yaml
kubectl apply -f notifications-api-deployment.yaml
Aguarde todas as APIs:
kubectl rollout status deployment/users-api-deployment -n fcg --timeout=300s
kubectl rollout status deployment/catalog-api-deployment -n fcg --timeout=300s
kubectl rollout status deployment/payments-api -n fcg --timeout=300s
kubectl rollout status deployment/notifications-api -n fcg --timeout=300s
Confira:
kubectl get pods -n fcg
7. PostgreSQL do Kong
kubectl apply -f kong-secret.yaml
kubectl apply -f kong-environment-configmap.yaml
kubectl apply -f kong-postgres-init-configmap.yaml
kubectl apply -f kong-postgres-pvc.yaml
kubectl apply -f kong-postgres-service.yaml
kubectl apply -f kong-postgres-deployment.yaml

kubectl rollout status deployment/kong-database -n fcg --timeout=300s

8. Migrations do Kong
kubectl apply -f kong-migrations-job.yaml

kubectl wait --for=condition=complete job/kong-migrations `
  -n fcg `
  --timeout=300s
Confira os logs:
kubectl logs job/kong-migrations -n fcg

9. Kong Gateway e Kong Manager
kubectl apply -f kong-deployment.yaml
kubectl apply -f kong-service.yaml

kubectl rollout status deployment/kong -n fcg --timeout=300s

10. Cadastrar as rotas
kubectl apply -f kong-routes-job.yaml

kubectl wait --for=condition=complete job/kong-routes `
  -n fcg `
  --timeout=300s
Confira:
kubectl logs job/kong-routes -n fcg

O job cria as rotas publicas de login e cadastro, cadastra a credencial HS256
e ativa a validacao JWT nas rotas gerais de Users API e Catalog API.

11. Preparar e subir o Konga
kubectl apply -f konga-prepare-job.yaml

kubectl wait --for=condition=complete job/konga-prepare `
  -n fcg `
  --timeout=300s

kubectl apply -f konga-deployment.yaml
kubectl apply -f konga-service.yaml

kubectl rollout status deployment/konga -n fcg --timeout=300s

12. Verificação final
kubectl get pods,services,jobs,pvc -n fcg
Os Deployments devem estar Running, os Jobs devem estar Completed e os PVCs devem estar Bound.

13. Acessar o Kong Manager
Abra um terminal e mantenha-o aberto:
kubectl port-forward service/kong-manager 8002:8002 -n fcg
Abra outro terminal:
kubectl port-forward service/kong-admin 8001:8001 -n fcg
Acesse:
http://localhost:8002

14. Acessar as APIs pelo gateway
Em outro terminal:
kubectl port-forward service/kong 8080:8000 -n fcg

Teste:
curl.exe -i http://localhost:8080/payments/api/health
curl.exe -i http://localhost:8080/notifications/api/health

Faça login para obter o token JWT (usuário admin padrão).
curl.exe -i http://localhost:8080/users/login -H "Content-Type: application/json" --% -d "{\"Email\":\"admin@email.com\",\"Senha\":\"1234@Abc\"}"

Copie o valor de "token" do retorno acima e use-o para testar a validação JWT do Kong nas rotas protegidas de Users API e Catalog API:
curl.exe -i http://localhost:8080/users/usuario/todos -H "Authorization: Bearer <TOKEN>"
curl.exe -i http://localhost:8080/catalog/game/todos -H "Authorization: Bearer <TOKEN>"

Sem o header Authorization (ou com um token inválido), o Kong deve responder 401 Unauthorized antes mesmo de a requisição chegar às APIs.

Endereços finais:
Kong Manager: http://localhost:8002
Admin API:    http://localhost:8001
Gateway:      http://localhost:8080

# Observabilidade (Prometheus + Grafana)

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
	

	
