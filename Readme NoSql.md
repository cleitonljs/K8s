# Manual de teste — Item 4, Fase 3 (Persistência poliglota + Cache)

Guia para qualquer integrante do grupo testar, do zero, o que foi implementado no
item 4 da Fase 3: **MongoDB** para dado de schema flexível/alto volume e **Redis**
como cache distribuído, agora nos três serviços (`UsersAPI`, `CatalogAPI`,
`PaymentsAPI`), além da orquestração (`K8s`).

## 1. Pré-requisitos

- Docker Desktop instalado e rodando.
- .NET 8 SDK instalado, com a ferramenta `dotnet-ef`:

		dotnet tool install --global dotnet-ef

## 2. Buscar e trocar de branch (nos 4 repositórios)

Em `UsersAPI`, `PaymentsAPI`, `CatalogAPI` e `K8s`:

	git fetch origin
	git checkout implementacao-persistencia-poliglota-e-cache

## 3. Subir o ambiente completo

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

## 4. Seed básico

Login do Admin já existe (`admin@email.com` / `1234@Abc`):

	curl.exe -i http://localhost:8010/login -H "Content-Type: application/json" --% -d "{\"email\":\"admin@email.com\",\"senha\":\"1234@Abc\"}"

Copie o `token` (`<ADMIN_TOKEN>`) e crie um jogo:

	curl.exe -i http://localhost:8030/game/criar -H "Content-Type: application/json" -H "Authorization: Bearer <ADMIN_TOKEN>" --% -d "{\"nome\":\"The Witcher 3\",\"price\":49.90}"

Crie um usuário comum e pegue o token dele também (`<USER_TOKEN>`):

	curl.exe -i http://localhost:8010/usuario/criar -H "Content-Type: application/json" --% -d "{\"nome\":\"Usuario Teste\",\"email\":\"usuarioteste@email.com\",\"senha\":\"Senha123!\"}"
	curl.exe -i http://localhost:8010/login -H "Content-Type: application/json" --% -d "{\"email\":\"usuarioteste@email.com\",\"senha\":\"Senha123!\"}"

Anote o `id` do jogo criado (normalmente `1`, `<GAME_ID>` daqui pra frente) e o `id`
do usuário comum (normalmente `2`).

## 5. Roteiro de teste por funcionalidade

### 5.1 Perfil estendido de usuário (UsersAPI) — MongoDB + cache

Criar/atualizar o próprio perfil (usuário comum, id 2):

	curl.exe -i -X PUT http://localhost:8010/usuario/2/perfil -H "Content-Type: application/json" -H "Authorization: Bearer <USER_TOKEN>" --% -d "{\"bio\":\"Jogador casual\",\"avatarUrl\":\"\",\"preferencias\":{}}"

**Esperado:** `200 OK`, retorna o perfil salvo.

Tentar ver o perfil do Admin (id 1) logado como o usuário comum:

	curl.exe -i http://localhost:8010/usuario/1/perfil -H "Authorization: Bearer <USER_TOKEN>"

**Esperado:** `403 Forbidden` — só o próprio usuário ou um Administrador pode
ver/editar um perfil.

Confirmar persistência no MongoDB:

	docker exec mongo mongosh -u root -p root123 --authenticationDatabase admin --quiet --eval "db.getSiblingDB('fcg_users').user_profiles.find().toArray()"

(Opcional) Confirmar o cache: chame `GET usuario/2/perfil` duas vezes — a 2ª deve
ser bem mais rápida (TTL de 10 min), e aparece uma chave `users-api:users:perfil:2`
em `docker exec redis redis-cli KEYS "*"`.

### 5.2 Auditoria de pagamento (PaymentsAPI) — MongoDB

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

### 5.3 Idempotência (PaymentsAPI) — Redis

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

### 5.4 Avaliação de jogos (CatalogAPI) — MongoDB + cache (parte já pronta antes)

Criar e listar uma avaliação:

	curl.exe -i -X POST http://localhost:8030/game/<GAME_ID>/avaliacoes -H "Content-Type: application/json" -H "Authorization: Bearer <USER_TOKEN>" --% -d "{\"nota\":5,\"comentario\":\"Obra-prima, recomendo muito!\"}"
	curl.exe -i http://localhost:8030/game/<GAME_ID>/avaliacoes -H "Authorization: Bearer <USER_TOKEN>"

**Esperado:** `201` na criação, e a avaliação aparece na listagem.

Confirmar persistência no MongoDB:

	docker exec mongo mongosh -u root -p root123 --authenticationDatabase admin --quiet --eval "db.getSiblingDB('fcg_catalog').game_reviews.find().toArray()"

(Opcional) Cache: `GET game/todos` duas vezes seguidas — a 2ª deve vir bem mais
rápida (TTL 60s).

## 6. Pontos de atenção conhecidos

- **Redis e Mongo sem senha/com senha fixa**: tudo certo pra ambiente local, mas
  não é configuração pra produção — `redis:7-alpine` está sem autenticação, e o
  Mongo usa usuário/senha fixos (`root`/`root123`) tanto no compose quanto nos
  manifestos K8s.
- **Endpoint de auditoria do PaymentsAPI sem autenticação**: `GET
  payments/auditoria/{gameId}` está aberto porque a PaymentsAPI ainda não tem
  nenhuma infraestrutura de JWT — já está comentado no código pra adicionar
  `[Authorize]` quando isso mudar.
- **Sem testes automatizados novos**: as classes de cache/repositório Mongo não
  têm testes unitários (nenhum serviço tinha testes na camada de infra antes
  disso também, então mantém o padrão que já existia).
- **Possível conflito ao mesclar com a branch do serverless**: se a branch
  `feature/serverless-notifications` do `K8s` for mesclada depois, o
  `docker-compose.yml` provavelmente vai dar conflito, porque essa branch ainda
  não tem `mongo`/`redis`.
- **Bug de concorrência na idempotência já foi encontrado e corrigido durante o
  teste** — ver a mensagem do grupo pra mais detalhes.

## 7. Encerrar o ambiente

	docker-compose down -v
