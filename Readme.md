# Instruções de uso para rodar via Docker Compose

- Crie uma pasta para salvar os projetos baixados
- Baixe e descompacte o projeto ou clone os repositórios (UsersAPI, CatalogAPI, NotificationsAPI, PaymentsAPI e K8s) na pasta que você criou.
- Abra o terminal na pasta do projeto baixado ou clonado e digite:

cd K8s\Docker

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

Preparação do ambiente

1) Instalar o Docker.
2) Instalar o minikube para simular um ambiente Kubernetes local na máquina.
	2.1) Inicie o Minikube usando Docker, executando o seguinte comando: minikube start --driver=docker
	2.2) Verique o status: minikube status
	
Copie as imagens para o minikube. Execute:
minikube image load users-api:latest
Esse comando pega a imagem local e copia para dentro do Minikube

Crie os objetos Kubernetes, executando os seguinte comandos:
	
kubectl apply -f namespace.yaml

kubectl apply -f mysql-service.yaml
kubectl apply -f mysql-configmap.yaml
kubectl apply -f mysql-pvc.yaml
kubectl apply -f mysql-secret.yaml
kubectl apply -f mysql-deployment.yaml

kubectl apply -f users-api-configmap.yaml
kubectl apply -f users-api-secret.yaml
kubectl apply -f users-api-service.yaml
kubectl apply -f users-api-deployment.yaml

Para abrir a users-api local na máquina é necessário criar um túnel, execute:
minikube service users-api -n fcg
será aberta a aplicação automaticamente, porém é necessário completar a url com swagger/index.html.