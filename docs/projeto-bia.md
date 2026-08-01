# Documento de Projeto — BIA

> Versão do documento: 1.0.0 | Gerado em: 01/08/2026

---

## 1. Visão Geral

**Nome:** BIA — Gerenciador de Tarefas  
**Versão atual:** 4.3.0  
**Autor:** Henrylle Maia ([@henryllemaia](https://github.com/henrylle))  
**Repositório:** https://github.com/henrylle/bia  
**Contexto:** Projeto educacional base para a **Imersão AWS & IA** (01-02/08/2026) e para o treinamento **Formação AWS**.

O BIA é uma aplicação full-stack de gerenciamento de tarefas criada intencionalmente como plataforma de ensino. Seu design progressivo permite que alunos partam de uma aplicação rodando localmente via Docker e evoluam até uma arquitetura completa na AWS com ECS, ALB, RDS e ElastiCache. O projeto existe desde 2021 e reflete boas práticas que evoluem junto com a plataforma AWS.

---

## 2. Objetivos do Projeto

- Servir como base prática para o ensino de AWS na Formação AWS
- Demonstrar evolução arquitetural progressiva (do simples ao complexo)
- Ilustrar integração de serviços AWS no mundo real: ECS, RDS, ElastiCache, Secrets Manager, CodePipeline, CodeBuild
- Ser simples o suficiente para iniciantes sem perder relevância para profissionais

---

## 3. Stack Tecnológica

### 3.1 Backend

| Componente        | Tecnologia                        | Versão   |
|-------------------|-----------------------------------|----------|
| Runtime           | Node.js                           | 24.x     |
| Framework         | Express                           | 4.17.1   |
| ORM               | Sequelize                         | 6.6.5    |
| Driver PostgreSQL  | pg + pg-hstore                    | ^8.7.1   |
| Cache             | ioredis                           | ^5.4.1   |
| Session           | express-session                   | ^1.17.2  |
| Logger            | morgan                            | ^1.10.0  |
| CORS              | cors                              | ^2.8.5   |
| Body Parser       | body-parser (via express)         | —        |
| AWS SDK           | @aws-sdk/client-secrets-manager   | ^3.583.0 |
| AWS SDK           | @aws-sdk/client-sts               | ^3.583.0 |
| AWS SDK           | @aws-sdk/credential-providers     | ^3.583.0 |
| Config            | config                            | ^4.1.1   |
| Template Engines  | ejs, hbs                          | legado   |

### 3.2 Frontend

| Componente        | Tecnologia                        | Versão   |
|-------------------|-----------------------------------|----------|
| Framework UI      | React                             | ^18.3.1  |
| Roteamento        | react-router-dom                  | ^6.28.0  |
| Ícones            | react-icons                       | ^5.3.0   |
| Build Tool        | Vite                              | ^5.4.19  |
| Plugin React      | @vitejs/plugin-react              | ^4.5.2   |
| Vitals            | web-vitals                        | ^4.2.4   |

### 3.3 Banco de Dados

| Componente | Tecnologia    | Versão |
|------------|---------------|--------|
| SGBD       | PostgreSQL    | 17.1   |
| ORM        | Sequelize CLI | ^6.2.0 |

### 3.4 Cache

| Componente | Tecnologia       | Versão      |
|------------|------------------|-------------|
| Servidor   | Valkey (Redis)   | 8.1-alpine  |
| Cliente    | ioredis          | ^5.4.1      |

### 3.5 Infraestrutura e DevOps

| Componente      | Tecnologia                  |
|-----------------|-----------------------------|
| Container       | Docker                      |
| Orquestração    | Docker Compose (local)      |
| CI/CD           | AWS CodePipeline + CodeBuild|
| Registry        | AWS ECR                     |
| Orquestração    | AWS ECS (EC2 launch type)   |
| Banco Gerenciado| AWS RDS (PostgreSQL)        |
| Cache Gerenciado| AWS ElastiCache (avançado)  |
| Segredos        | AWS Secrets Manager         |
| Service Discovery| AWS Cloud Map (Cenário 3)  |
| Load Balancer   | AWS ALB (Cenário 2 e 3)     |
| Testes          | Jest 27.5.1                 |

---

## 4. Estrutura de Diretórios

```
/bia
├── api/
│   ├── controllers/
│   │   ├── tarefas.js         # CRUD completo + integração cache
│   │   ├── versao.js          # Retorna versão da app via env VERSAO_API
│   │   └── cache-config.js    # Expõe configuração atual do cache
│   ├── models/
│   │   ├── index.js           # Inicializador dinâmico dos modelos Sequelize
│   │   └── tarefas.js         # Model Tarefas (UUID, titulo, dia_atividade, importante)
│   ├── routes/
│   │   ├── tarefas.js         # Define todas as rotas de /api/tarefas
│   │   ├── versao.js          # Define rota /api/versao
│   │   ├── ping.js            # Define rota /api/ping (health check)
│   │   └── cache-config.js    # Define rota /api/cache-config
│   └── data/
│       └── tarefas.json       # Dados estáticos para json-server (dev)
│
├── client/
│   ├── src/
│   │   ├── App.jsx            # Componente raiz com toda lógica de estado
│   │   ├── main.jsx           # Entry point React (createRoot)
│   │   ├── index.css          # Estilos globais (~16KB)
│   │   ├── reportWebVitals.js # Métricas de performance
│   │   ├── components/
│   │   │   ├── Tasks.jsx      # Lista de tarefas com indicador de cache
│   │   │   ├── Task.jsx       # Item individual de tarefa
│   │   │   ├── AddTask.jsx    # Formulário de criação de tarefa
│   │   │   ├── Header.jsx     # Cabeçalho da aplicação
│   │   │   ├── Footer.jsx     # Rodapé da aplicação
│   │   │   ├── Modal.jsx      # Modal de confirmação genérico
│   │   │   ├── About.jsx      # Página sobre
│   │   │   ├── About.js       # Versão JS legada do About
│   │   │   ├── Button.jsx     # Botão reutilizável
│   │   │   ├── DebugLogs.jsx  # Painel de logs em tempo real
│   │   │   ├── VersionInfo.jsx# Informações de versão/conectividade
│   │   │   └── DadosHenrylle.jsx # Dados do instrutor
│   │   └── contexts/
│   │       ├── ThemeContext.jsx # Context de tema (dark/light + localStorage)
│   │       └── LogContext.jsx   # Context de logs em tempo real (até 50 entradas)
│   ├── public/
│   │   ├── favicon.ico
│   │   ├── favicon-simple.svg
│   │   ├── logo192.png
│   │   ├── logo512.png
│   │   └── manifest.json
│   ├── db.json                # Base para json-server (mock API)
│   ├── .env                   # VITE_DEBUG_MODE=false
│   ├── vite.config.js         # Dev port 3001, build outDir=build, sourcemap=true
│   └── package.json
│
├── config/
│   ├── express.js             # Factory da app Express (porta, rotas, static, CORS)
│   ├── database.js            # Config dinâmica de banco (local/remoto/Secrets Manager)
│   └── default.json           # Porta padrão: 8080
│
├── database/
│   └── migrations/
│       └── 20210924000838-criar-tarefas.js  # Migration inicial da tabela Tarefas
│
├── lib/
│   ├── boot.js                # Bootstrap legado de controllers em app/controllers/
│   └── cache.js               # Abstração ioredis (get/set/del/ttl com fallback)
│
├── tests/
│   └── unit/
│       └── controllers/
│           ├── tarefas.test.js  # 15 testes do controller de tarefas
│           └── versao.test.js   # 3 testes do controller de versão
│
├── scripts/
│   ├── user_data_ec2_zona_a.sh  # User data para EC2 bia-dev
│   ├── lancar_ec2_zona_a.sh     # Script para criar EC2 via CLI
│   ├── validar_recursos_zona_a.sh # Valida recursos AWS existentes
│   ├── insert-tarefas-massa.sh  # Insere tarefas em massa via API
│   ├── delete-all-tarefas.sh    # Deleta todas as tarefas via API
│   ├── ligar_bia_local.sh       # Sobe ambiente local
│   ├── parar_bia_local.sh       # Para ambiente local
│   ├── tunnel-elasticache.sh    # Tunnel SSM para ElastiCache
│   ├── start-session-bash.sh    # SSM Session Manager
│   ├── criar_role_ssm.sh        # Cria role IAM para SSM
│   ├── generate-sts-token.sh    # Gera token STS temporário
│   ├── setup_bia_dev_ubuntu_ui.sh
│   ├── setup_cloudshell_ssm.sh
│   ├── setup_ui_ubuntu.sh
│   ├── setup_vscode+chrome.sh
│   ├── ec2_principal.json
│   └── ecs/
│       ├── unix/
│       │   ├── build.sh           # Build e push para ECR
│       │   ├── deploy.sh          # Force new deployment no ECS
│       │   ├── check-disponibilidade.sh
│       │   └── testar-latencia.sh
│       └── windows/               # Equivalentes para Windows
│
├── docs/
│   ├── README.md
│   ├── analise-projeto.md         # Análise gerada pelo Kiro
│   ├── projeto-bia.md             # Este arquivo
│   └── architecture/
│       └── aws-ecs-diagram.html   # Diagrama de arquitetura AWS
│
├── n8n/
│   ├── n8n-ha-single-mode.md
│   ├── n8n-queue-mode.md
│   └── .env
│
├── .kiro/
│   ├── agents/
│   │   └── bia.json               # Definição do agente BIA
│   ├── rules/
│   │   ├── infraestrutura.md      # Regras de infraestrutura AWS
│   │   ├── pipeline.md            # Regras de CI/CD
│   │   └── dockerfile.md          # Regras para Dockerfiles
│   ├── settings/
│   │   └── aws-mcp.json
│   ├── mcp-aws.json
│   ├── mcp-db.json
│   ├── mcp-ecs.json
│   └── bia-com-mcp-db-aws.json
│
├── server.js                      # Entry point real da aplicação
├── index.js                       # Entry point legado (não utilizado em produção)
├── Dockerfile                     # Imagem de produção
├── Dockerfile_checkdisponibilidade# Imagem para verificação de disponibilidade
├── compose.yml                    # Ambiente local completo
├── buildspec.yml                  # Spec para AWS CodeBuild
├── package.json                   # Dependências e scripts do backend
├── .sequelizerc                   # Configuração de caminhos do Sequelize CLI
├── .gitignore
├── .dockerignore
└── README.md
```

---

## 5. Fluxo da Aplicação

### 5.1 Inicialização (server.js → config/express.js)

```
server.js
  └── require('./config/express')()
        ├── app.set('port', process.env.PORT || config.get('server.port'))  → 8080
        ├── express.static('client/build')    → serve o React compilado
        ├── express.urlencoded + bodyParser.json
        ├── cors()
        ├── require('../api/routes/tarefas')(app)
        ├── require('../api/routes/versao')(app)
        ├── require('../api/routes/cache-config')(app)
        └── app.get('*') → fallback para React Router (serve index.html)
  └── app.listen(port)
```

A porta default é **8080** (definida em `config/default.json`). Pode ser sobrescrita via variável de ambiente `PORT`.

### 5.2 Fluxo de uma Requisição GET /api/tarefas

```
Cliente HTTP / React
  │
  ▼
Express Router (api/routes/tarefas.js)
  │
  ▼
tarefasController.findAll()
  │
  ├── CACHE_ENDPOINT definido?
  │     ├── SIM → cache.get('tarefas:all')
  │     │           ├── HIT  → retorna { fromCache: true, cacheTTL, cacheTime, data }
  │     │           ├── MISS → busca no banco → cache.set() → retorna { fromCache: false, ... }
  │     │           └── ERRO → fallback: busca no banco sem setar cache
  │     └── NÃO → busca no banco → retorna { dbTime, data }
  │
  ▼
initializeModels()  →  new Sequelize(await getConfig())
  │
  ├── getConfig()
  │     ├── DB_SECRET_NAME vazio? → usa DB_USER/DB_PWD das envs
  │     └── DB_SECRET_NAME definido? → SecretsManagerClient.GetSecretValueCommand()
  │           └── retorna { username, password } do secret JSON
  │
  └── Tarefas.findAll() → SELECT * FROM "Tarefas"
```

### 5.3 Fluxo do Build Frontend

```
Dockerfile
  └── COPY client/package*.json → npm install --legacy-peer-deps
  └── COPY . .
  └── cd client && VITE_API_URL=http://localhost:3001 npm run build
        └── vite build → outDir: 'build'  (client/build/)
  └── npm prune --production (client)
  └── CMD ["npm", "start"] → node server.js
```

No frontend, a URL da API é resolvida por:
```js
const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:8080";
```
Em produção ECS, `VITE_API_URL` é injetada em tempo de **build** do Docker.

---

## 6. Rotas da API

### 6.1 Tabela Completa

| Método   | Rota                                  | Controller           | Banco | Cache |
|----------|---------------------------------------|----------------------|-------|-------|
| GET      | `/api/ping`                           | inline (routes)      | ❌    | ❌    |
| GET      | `/api/versao`                         | versao.get           | ❌    | ❌    |
| GET      | `/api/cache-config`                   | cache-config.get     | ❌    | ❌    |
| GET      | `/api/tarefas`                        | tarefas.findAll      | ✅    | ✅    |
| POST     | `/api/tarefas`                        | tarefas.create       | ✅    | ♻️    |
| DELETE   | `/api/tarefas`                        | tarefas.deleteAll    | ✅    | 🗑️    |
| GET      | `/api/tarefas/:uuid`                  | tarefas.find         | ✅    | ❌    |
| DELETE   | `/api/tarefas/:uuid`                  | tarefas.delete       | ✅    | ♻️    |
| PUT      | `/api/tarefas/update_priority/:uuid`  | tarefas.update_priority | ✅ | ♻️    |

Legenda: ✅ usa | ❌ não usa | ♻️ invalida/atualiza cache | 🗑️ deleta chave do cache

### 6.2 Detalhes por Rota

**GET /api/ping**
```json
"Rota funcionando. Pong!"
```

**GET /api/versao**
```
Bia 4.3.0
```
Controlado pela env `VERSAO_API`. Se não definida, usa `4.3.0` como fallback.

**GET /api/cache-config**
```json
{
  "enabled": false,
  "endpoint": null,
  "port": "6379",
  "ttl": "60"
}
```

**GET /api/tarefas** (sem cache)
```json
{
  "dbTime": 12,
  "data": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "titulo": "Estudar AWS ECS",
      "dia_atividade": "2026-08-01",
      "importante": true,
      "createdAt": "2026-08-01T10:00:00.000Z",
      "updatedAt": "2026-08-01T10:00:00.000Z"
    }
  ]
}
```

**GET /api/tarefas** (com cache — HIT)
```json
{
  "fromCache": true,
  "cacheTTL": 45,
  "cacheTime": 2,
  "data": [...]
}
```

**GET /api/tarefas** (com cache — MISS)
```json
{
  "fromCache": false,
  "cacheTTL": 60,
  "cacheError": false,
  "dbTime": 15,
  "data": [...]
}
```

**POST /api/tarefas**
- Body: `{ "titulo": "string", "dia_atividade": "string", "importante": boolean }`
- Resposta: objeto da tarefa criada (201 implícito, retorna com `res.send`)

**DELETE /api/tarefas**
```json
{ "message": "Todas as tarefas foram deletadas." }
```

**DELETE /api/tarefas/:uuid**
```json
{ "message": "Tarefa deletada com sucesso." }
```
- 404 se uuid não encontrado

**PUT /api/tarefas/update_priority/:uuid**
- Body: `{ "importante": boolean }`
- Resposta: objeto tarefa atualizado
- 404 se uuid não encontrado

---

## 7. Banco de Dados

### 7.1 Schema da Tabela Tarefas

```sql
CREATE TABLE "Tarefas" (
  uuid         UUID         PRIMARY KEY DEFAULT uuid_generate_v1(),
  titulo       VARCHAR(255) NOT NULL,
  dia_atividade VARCHAR(255),
  importante   BOOLEAN      DEFAULT false,
  "createdAt"  TIMESTAMP    NOT NULL,
  "updatedAt"  TIMESTAMP    NOT NULL
);
```

### 7.2 Model Sequelize

```js
Tarefas = sequelize.define("Tarefas", {
  uuid:          { type: UUID,    defaultValue: UUIDV1, primaryKey: true },
  titulo:        DataTypes.STRING,
  dia_atividade: DataTypes.STRING,
  importante:    DataTypes.BOOLEAN,
});
```

O nome da tabela segue o padrão Sequelize: `"Tarefas"` (com aspas, case-sensitive no PostgreSQL).

### 7.3 Configuração de Banco (config/database.js)

A conexão é resolvida dinamicamente em runtime:

| Situação                              | Comportamento                                             |
|---------------------------------------|-----------------------------------------------------------|
| `DB_HOST` ausente / `localhost`       | Conexão local sem SSL                                     |
| `DB_HOST` remoto (ex: RDS endpoint)   | SSL habilitado (`rejectUnauthorized: false`)              |
| `DB_SECRET_NAME` definido             | Credenciais buscadas no AWS Secrets Manager               |
| `DB_SECRET_NAME` + `IS_LOCAL=true`    | Usa credenciais de variável de ambiente para Secrets Manager |
| `DEBUG_SECRET=true`                   | Loga identidade STS e conteúdo do secret no console       |

### 7.4 Variáveis de Ambiente — Banco

| Variável         | Padrão       | Descrição                                      |
|------------------|--------------|------------------------------------------------|
| `DB_USER`        | `postgres`   | Usuário do banco                               |
| `DB_PWD`         | `postgres`   | Senha do banco                                 |
| `DB_HOST`        | `127.0.0.1`  | Host do banco                                  |
| `DB_PORT`        | `5433`       | Porta do banco                                 |
| `DB_SECRET_NAME` | —            | Nome do secret no Secrets Manager              |
| `DB_REGION`      | —            | Região AWS do Secrets Manager                  |
| `IS_LOCAL`       | —            | `true` = usa credenciais de env para SDK AWS   |
| `DEBUG_SECRET`   | —            | `true` = loga diagnóstico de credenciais       |

### 7.5 Execução de Migrations

```bash
# No container local
docker compose exec server bash -c 'npx sequelize db:migrate'

# Direto (fora do container, apontando para o banco correto)
npx sequelize db:migrate
```

O `.sequelizerc` aponta migrations para `database/migrations/` e config para `config/database.js`.

---

## 8. Frontend (React)

### 8.1 Arquitetura de Componentes

```
App.jsx (estado global: tasks, fromCache, cacheTTL, cacheError)
├── ThemeProvider (context: isDarkMode, toggleTheme → localStorage)
├── LogProvider   (context: logs[], addLog, logApiRequest, logApiResponse)
│
└── AppContent
    ├── Router (BrowserRouter)
    │   ├── Header.jsx
    │   ├── Routes
    │   │   ├── "/" → HomePage
    │   │   │   ├── AddTask.jsx      (formulário: titulo, dia_atividade, importante)
    │   │   │   ├── Tasks.jsx        (lista + indicador de cache)
    │   │   │   │   └── Task.jsx     (item individual + toggle importante + delete)
    │   │   │   └── Modal.jsx        (confirmação de deleteAll)
    │   │   └── "/about" → About.jsx
    │   └── Footer.jsx
    └── DebugLogs.jsx  (painel flutuante de logs — ativo se VITE_DEBUG_MODE=true)
```

### 8.2 Gerenciamento de Estado

Todo o estado da aplicação vive em `App.jsx`:

| Estado            | Tipo      | Descrição                                    |
|-------------------|-----------|----------------------------------------------|
| `tasks`           | array     | Lista de tarefas carregadas                  |
| `fromCache`       | boolean   | Indica se a última resposta veio do cache    |
| `cacheTTL`        | number    | TTL restante do cache em segundos            |
| `cacheError`      | boolean   | Indica se houve erro de conexão com o cache  |
| `showConfirmModal`| boolean   | Controla visibilidade do modal de confirmação|

### 8.3 Contexts

**ThemeContext**
- Persiste preferência de tema no `localStorage`
- Detecta preferência do sistema via `prefers-color-scheme`
- Aplica o atributo `data-theme` no `document.documentElement`

**LogContext**
- Mantém fila circular de até 50 logs mais recentes
- Tipos: `INFO`, `SUCCESS`, `WARNING`, `ERROR`
- Intercepta todas as chamadas à API: `logApiRequest`, `logApiResponse`, `logApiError`
- Ativado via `VITE_DEBUG_MODE=true` no `.env`

### 8.4 Variáveis de Ambiente — Frontend

| Variável          | Padrão  | Descrição                                         |
|-------------------|---------|---------------------------------------------------|
| `VITE_API_URL`    | `http://localhost:8080` | URL base da API backend            |
| `VITE_DEBUG_MODE` | `false` | Habilita painel de logs em tempo real             |

> **Atenção:** `VITE_API_URL` é injetada em **tempo de build** do Vite — não pode ser alterada em runtime sem rebuild da imagem Docker.

### 8.5 Build e Desenvolvimento Local

```bash
# Desenvolvimento (HMR, porta 3001)
cd client && npm run dev

# Build de produção
cd client && npm run build   # gera client/build/

# Mock API local (json-server)
cd client && npm run server  # porta 5000, usa client/db.json
```

---

## 9. Testes

### 9.1 Estrutura

```
tests/unit/controllers/
├── tarefas.test.js   # 15 casos de teste
└── versao.test.js    # 3 casos de teste
```

### 9.2 Executar Testes

```bash
npm test
# ou
npm test -- --verbose
```

### 9.3 Cobertura por Controller

**versao.test.js (3 testes)**
- `get` retorna `"Bia 4.3.0"` quando `VERSAO_API` não está definido
- `get` retorna `"Bia 4.3.0"` quando `VERSAO_API` é deletado do processo
- `get` retorna `"Bia 1.0.0"` quando `VERSAO_API=1.0.0`

**tarefas.test.js (15 testes)**

| Método           | Cenário testado                          |
|------------------|------------------------------------------|
| `create`         | Sucesso → cria e retorna tarefa          |
| `create`         | Falha DB → retorna 500                   |
| `find`           | Sucesso → retorna tarefa por UUID        |
| `find`           | UUID não existe → retorna 404            |
| `find`           | Falha DB → retorna 500                   |
| `findAll`        | Sucesso → retorna lista de tarefas       |
| `findAll`        | Falha DB → retorna 500                   |
| `delete`         | Sucesso → retorna mensagem de confirmação|
| `delete`         | UUID não existe → retorna 404            |
| `delete`         | Falha DB → retorna 500                   |
| `update_priority`| Sucesso → retorna tarefa atualizada      |
| `update_priority`| UUID não existe → retorna 404            |
| `update_priority`| Falha DB → retorna 500                   |

### 9.4 Estratégia de Mock

Os testes usam `jest.mock('../../../api/models')` para isolar completamente o banco de dados. O mock do Sequelize simula `create`, `findByPk`, `findAll`, `destroy` e `update` com `jest.fn()`. Os mocks são resetados via `jest.clearAllMocks()` no `beforeEach`.

> **Gap identificado:** Não há testes para o comportamento do cache no `findAll`. Quando `CACHE_ENDPOINT` está definido, o `lib/cache.js` não é mockado nos testes atuais.

---

## 10. Ambiente Local (Docker Compose)

### 10.1 Serviços

```yaml
services:
  server:    porta 3001 → 8080  (app Node.js + React)
  database:  porta 5433 → 5432  (PostgreSQL 17.1)
  redis:     porta 6379 → 6379  (Valkey 8.1-alpine)
```

### 10.2 Comandos Essenciais

```bash
# Subir ambiente completo
docker compose up -d

# Parar tudo
docker compose down

# Executar migrations
docker compose exec server bash -c 'npx sequelize db:migrate'

# Ver logs da aplicação
docker compose logs -f server

# Rebuild forçado
docker compose up -d --build

# Inserir tarefas em massa (usa a API)
./scripts/insert-tarefas-massa.sh

# Deletar todas as tarefas
./scripts/delete-all-tarefas.sh
```

### 10.3 Variáveis de Ambiente Padrão (compose.yml)

| Variável           | Valor padrão  |
|--------------------|---------------|
| `DB_USER`          | `postgres`    |
| `DB_PWD`           | `postgres`    |
| `DB_HOST`          | `database`    |
| `DB_PORT`          | `5432`        |

As variáveis AWS (`DB_SECRET_NAME`, `DB_REGION`, `AWS_ACCESS_KEY_ID`, etc.) estão comentadas — não são necessárias para a imersão básica.

### 10.4 Ativar Cache Localmente

Para testar o comportamento completo com Redis, descomentar no `compose.yml`:

```yaml
environment:
  CACHE_ENDPOINT: redis
  CACHE_PORT: 6379
  CACHE_TTL: 15
  CACHE_TLS: false
```

### 10.5 Dockerfile

```
Base: public.ecr.aws/docker/library/node:24.18.0-slim
  ↓
npm install -g npm@11
  ↓
apt-get install curl   (para health checks)
  ↓
WORKDIR /usr/src/app
  ↓
COPY package*.json → npm install
  ↓
COPY client/package*.json → cd client && npm install --legacy-peer-deps
  ↓
COPY . .
  ↓
cd client && VITE_API_URL=http://localhost:3001 npm run build
  ↓
cd client && npm prune --production && rm -rf node_modules/.cache
  ↓
EXPOSE 8080
CMD ["npm", "start"]
```

**Regras obrigatórias do Dockerfile (definidas em `.kiro/rules/dockerfile.md`):**
- Sempre usar ECR público como base (`public.ecr.aws/...`)
- Single stage — nunca multi-stage build
- WORKDIR sempre `/usr/src/app`
- Incluir curl para health checks
- Flags: `--loglevel=error`, `--legacy-peer-deps` quando necessário
- Nunca sobrescrever Dockerfile existente sem confirmação

---

## 11. CI/CD — Pipeline AWS

### 11.1 Visão Geral

```
GitHub (push na branch principal)
  ↓
AWS CodePipeline
  ↓
AWS CodeBuild (buildspec.yml)
  ├── pre_build: login ECR, define tags
  ├── build: docker build + docker tag
  └── post_build: docker push + gera imagedefinitions.json
  ↓
AWS ECS (rolling update)
  └── Usa imagedefinitions.json para atualizar a task definition
```

### 11.2 buildspec.yml — Detalhado

```yaml
env:
  variables:
    ECR_REGISTRY: 380278406175.dkr.ecr.us-east-1.amazonaws.com
    ECR_REPO: bia

phases:
  pre_build:
    - Login no ECR via get-login-password
    - REPOSITORY_URI = $ECR_REGISTRY/$ECR_REPO
    - COMMIT_HASH = primeiros 7 chars do CODEBUILD_RESOLVED_SOURCE_VERSION
    - IMAGE_TAG = $COMMIT_HASH (fallback: latest)

  build:
    - docker build -t $REPOSITORY_URI:latest .
    - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG

  post_build:
    - docker push $REPOSITORY_URI:latest
    - docker push $REPOSITORY_URI:$IMAGE_TAG
    - gera imagedefinitions.json:
      [{"name":"bia","imageUri":"<registry>/<repo>:<commit-hash>"}]

artifacts:
  files: imagedefinitions.json
```

### 11.3 ECR

- **Registry:** `380278406175.dkr.ecr.us-east-1.amazonaws.com`
- **Repositório:** `bia`
- **Tags mantidas:** `latest` + tag por hash de commit (ex: `a1b2c3d`)

### 11.4 Deploy Manual via Scripts

```bash
# Unix — build e push para ECR
./scripts/ecs/unix/build.sh

# Unix — force new deployment no ECS
./scripts/ecs/unix/deploy.sh
# Executa: aws ecs update-service --cluster [CLUSTER] --service [SERVICE] --force-new-deployment
```

---

## 12. Arquitetura AWS — 3 Cenários Progressivos

### 12.1 Cenário 1 — ECS sem ALB (ponto de partida)

```
Internet
  │
  ▼
EC2 (ECS Cluster) — t3.micro — zona A
  │  Security Group: bia-web
  │  Inbound: porta da task (aleatória)
  │
  ▼
ECS Task (bridge mode)
  │  Container: bia (porta 8080)
  │  Task Definition: task-def-bia
  │  Service: service-bia
  │
  ▼
RDS PostgreSQL — t3.micro
  Security Group: bia-db
  Inbound: 5432 de bia-web e bia-dev
```

**Recursos:**
- Cluster: `cluster-bia`
- Task Definition: `task-def-bia`
- Service: `service-bia`
- Container: 400MB soft limit, 1 vCPU
- Network mode: `bridge`

### 12.2 Cenário 2 — ECS com ALB

```
Internet
  │ porta 80
  ▼
ALB — Security Group: bia-alb
  │  Inbound: 0.0.0.0/0 porta 80
  │  Subnets: zona A + zona B
  │
  ▼ (porta 8080, aleatória via dynamic port mapping)
Target Group: tg-bia-alb (tipo: instance)
  │  Deregistration delay: 30s
  │
  ▼
EC2 zona A + EC2 zona B — t3.micro
  Security Group: bia-ec2
  Inbound: All TCP de bia-alb
  │
  ▼
ECS Tasks (bridge mode)
  Task Definition: task-def-bia-alb
  Service: service-bia-alb
  │
  ▼
RDS PostgreSQL — t3.micro
  Security Group: bia-db
  Inbound: 5432 de bia-ec2 e bia-dev
```

**Deploy:**
- Rolling Update: min 50% / max 100%
- AZ Rebalancing: desativado

### 12.3 Cenário 3 — ECS com ALB + Cache (awsvpc + Cloud Map)

```
Internet
  │ porta 80
  ▼
ALB — Security Group: bia-alb
  │
  ▼
Target Group: tg-bia-app (tipo: ip)   ← necessário para awsvpc
  │
  ▼
EC2 zona A + EC2 zona B — t3.small    ← t3.small por limite de ENIs do awsvpc
  Security Group: bia-cluster
  Inbound: VAZIO (controle nas tasks)
  │
  ├── ECS Task: bia-app (awsvpc mode)
  │     Security Group: bia-app
  │     Inbound: porta 8080 de bia-alb
  │     Envs: CACHE_ENDPOINT via DNS do Cloud Map
  │
  └── ECS Task: bia-cache (awsvpc mode)
        Security Group: bia-cache
        Inbound: porta 6379 de bia-app
        Imagem: valkey/valkey ou redis

AWS Cloud Map
  └── service-bia-cache registrado
        DNS interno resolvido por service-bia-app

RDS PostgreSQL
  Security Group: bia-db
  Inbound: 5432 de bia-app e bia-dev
```

**Cluster:** `cluster-bia-app`  
**Serviços:** `service-bia-app` + `service-bia-cache`

### 12.4 Tabela Comparativa dos Cenários

| Aspecto                  | Cenário 1       | Cenário 2          | Cenário 3                |
|--------------------------|-----------------|--------------------|--------------------------|
| Load Balancer            | ❌              | ALB                | ALB                      |
| Network Mode             | bridge          | bridge             | awsvpc                   |
| Cache                    | ❌              | ❌                 | Redis/Valkey via ECS     |
| Service Discovery        | ❌              | ❌                 | AWS Cloud Map            |
| EC2 type                 | t3.micro        | t3.micro           | t3.small                 |
| Target Group type        | —               | instance           | ip                       |
| AZs                      | 1 (zona A)      | A + B              | A + B                    |
| SGs de EC2               | bia-web         | bia-ec2            | bia-cluster (vazio)      |
| Cluster                  | cluster-bia     | cluster-bia-alb    | cluster-bia-app          |

### 12.5 EC2 de Desenvolvimento (bia-dev)

| Atributo          | Valor                           |
|-------------------|---------------------------------|
| Nome (Tag)        | `bia-dev`                       |
| Tipo              | t3.micro                        |
| AMI               | Amazon Linux 2023 (via SSM)     |
| Key Pair          | `bia-dev`                       |
| Security Group    | `bia-dev`                       |
| IAM Profile       | `role-acesso-ssm`               |
| Região            | `us-east-1`                     |
| Subnet            | zona A (`us-east-1a`)           |
| IP Público        | habilitado                      |

**Acesso:** via SSM Session Manager (sem SSH exposto)
```bash
aws ssm start-session --target <instance-id> --region us-east-1
```

**User Data instala:**
- Docker + Docker Compose v2.23.3
- Git, jq, AWS CLI v2
- Node.js 24.x + npm
- Python 3.11 + uv (para MCP servers)
- Swap de 4GB

### 12.6 Regras de Security Groups

| Security Group | Recurso           | Inbound                                        |
|----------------|-------------------|------------------------------------------------|
| `bia-dev`      | EC2 dev           | configurado conforme necessidade               |
| `bia-db`       | RDS               | 5432 de bia-dev, bia-web/bia-ec2/bia-app       |
| `bia-web`      | EC2 (cenário 1)   | porta da task de internet direta               |
| `bia-alb`      | ALB               | 0.0.0.0/0 porta 80/443                         |
| `bia-ec2`      | EC2 (cenário 2)   | All TCP de bia-alb                             |
| `bia-cluster`  | EC2 (cenário 3)   | VAZIO — controle nas tasks via awsvpc          |
| `bia-app`      | Task app          | 8080 de bia-alb                                |
| `bia-cache`    | Task cache        | 6379 de bia-app                                |

**Formato obrigatório da descrição das inbound rules:**
> "acesso vindo de [nome-do-security-group]"

---

## 13. Segurança

### 13.1 Situação Atual

| Aspecto                        | Status         | Observação                                          |
|--------------------------------|----------------|-----------------------------------------------------|
| Credenciais no compose.yml     | ⚠️ hardcoded   | Apenas dev local — aceitável                        |
| Session secret no index.js     | ⚠️ hardcoded   | Arquivo legado, não usado em produção               |
| SSL no banco remoto            | ✅ implementado | `rejectUnauthorized: false` (aceitável para alunos) |
| Secrets Manager                | ✅ implementado | Ativado via `DB_SECRET_NAME`                        |
| STS / debug de credenciais     | ✅ implementado | Ativado via `DEBUG_SECRET=true`                     |
| Acesso EC2 via SSM             | ✅ boas práticas| Sem SSH exposto, via `role-acesso-ssm`              |
| CORS                           | ⚠️ aberto       | `cors()` sem restrição de origem                    |

### 13.2 Boas Práticas Aplicadas

- IAM Instance Profile obrigatório (`role-acesso-ssm`) para acesso via SSM
- Credenciais do banco em produção via Secrets Manager (sem hardcode)
- Security Groups seguem princípio de menor privilégio — SGs referenciam outros SGs
- Sem SSH habilitado na infraestrutura (acesso apenas via SSM)
- HTTPS suportado no ALB (requer certificado ACM)

### 13.3 Melhorias Recomendadas (Produção)

- Restringir CORS para domínios específicos
- Ativar `rejectUnauthorized: true` com certificado RDS válido
- Usar Parameter Store para variáveis não-secretas
- Remover `index.js` legado para evitar confusão
- Habilitar CloudTrail para auditoria de chamadas à API AWS

---

## 14. Sistema de Cache

### 14.1 Arquitetura do Cache (lib/cache.js)

O módulo `lib/cache.js` é uma abstração sobre ioredis com as seguintes características:

- **Singleton:** Um único cliente Redis por processo, criado na primeira chamada
- **Lazy connection:** Conexão só é estabelecida se `CACHE_ENDPOINT` estiver definido
- **Fallback gracioso:** Erros de conexão não propagam exceção — retornam `{ data: null, error: true }`
- **TLS:** Ativado via `CACHE_TLS=true` (necessário para ElastiCache em produção)
- **Timeout:** `connectTimeout: 3000ms`, `maxRetriesPerRequest: 1`
- **Auto-reconexão desabilitada:** `retryStrategy: () => null` — sem loop infinito

### 14.2 Chave de Cache

| Chave           | Operação        | TTL                          |
|-----------------|-----------------|------------------------------|
| `tarefas:all`   | SET após findAll| `CACHE_TTL` env (padrão 60s) |
| `tarefas:all`   | REFRESH após create, delete, update_priority |
| `tarefas:all`   | DELETE em deleteAll |

### 14.3 Variáveis de Ambiente — Cache

| Variável          | Padrão  | Descrição                                       |
|-------------------|---------|-------------------------------------------------|
| `CACHE_ENDPOINT`  | —       | Host do Redis. Se ausente, cache é desabilitado |
| `CACHE_PORT`      | `6379`  | Porta do Redis                                  |
| `CACHE_TTL`       | `60`    | TTL em segundos para as chaves                  |
| `CACHE_TLS`       | `false` | Habilita TLS (necessário para ElastiCache)      |

### 14.4 Evolução do Cache

| Estágio  | Solução               | Como configurar                                    |
|----------|-----------------------|----------------------------------------------------|
| Local    | Valkey via Docker     | `CACHE_ENDPOINT=redis` no compose.yml              |
| Cenário 3| Valkey via ECS task   | `CACHE_ENDPOINT` via Cloud Map DNS                 |
| Avançado | AWS ElastiCache       | `CACHE_ENDPOINT=<endpoint>`, `CACHE_TLS=true`      |

---

## 15. Observações Técnicas e Débitos

### 15.1 index.js — Arquivo Legado

O arquivo `index.js` contém uma implementação Express diferente de `server.js`:
- Usa `lib/boot.js` para carregar controllers de `app/controllers/` (diretório inexistente)
- Configura sessions, method-override e template engines (não usados na app atual)
- **Não é referenciado** por `package.json` (`"main": "index.js"` aponta para ele, mas `"start": "node server"` usa server.js)
- Risco: confusão para novos desenvolvedores

**Recomendação:** Renomear para `index.legacy.js` ou remover, atualizando `"main"` no package.json.

### 15.2 Modelos Inicializados por Chamada

`api/models/index.js` cria uma nova instância `Sequelize` a cada chamada de `initializeModels()`. Isso significa que cada requisição pode abrir uma nova conexão. Para produção de alta escala, seria ideal implementar connection pooling com uma instância Sequelize singleton.

### 15.3 VITE_API_URL Hardcoded no Build

O Dockerfile executa:
```
VITE_API_URL=http://localhost:3001 npm run build
```
Isso embute a URL no bundle do frontend em tempo de build. Para ambientes diferentes (dev/staging/prod) é necessário rebuildar a imagem ou adotar uma estratégia de runtime config (ex: endpoint dinâmico via `window.__config`).

### 15.4 Rota de Conflito Potencial

Em `api/routes/tarefas.js`, há duas definições para `DELETE /api/tarefas/:uuid`:
```js
app.route("/api/tarefas/:uuid").get(...)   // linha 1
app.route("/api/tarefas/:uuid").delete(...)  // linha 2 (separada)
```
O Express aceita isso, mas o padrão mais limpo seria encadear os métodos na mesma chamada `.route()`.

### 15.5 Cache não Testado nos Testes Unitários

O `lib/cache.js` e o comportamento de cache/hit/miss/fallback em `tarefas.findAll` não possuem cobertura de testes. Quando `CACHE_ENDPOINT` está definido, o caminho de cache é executado mas não verificado.

### 15.6 Healthcheck Desabilitado no Compose

```yaml
# healthcheck:
#   test: ["CMD", "curl", "-f", "http://localhost:8080/api/versao"]
```
Sem healthcheck, o `depends_on` não garante que o banco esteja pronto antes da app inicializar — pode causar falha de conexão no primeiro start.

---

## 16. Roadmap de Melhorias

### Imediatas (sem mudança de arquitetura)

- [ ] Habilitar healthcheck no `compose.yml`
- [ ] Ativar cache localmente (descomentar vars no compose.yml)
- [ ] Adicionar testes de cache em `tarefas.test.js`
- [ ] Documentar `index.js` como legado ou removê-lo
- [ ] Adicionar rota de health check no ALB Target Group (`/api/ping`)

### Curto Prazo (mudanças pontuais)

- [ ] Implementar singleton de conexão Sequelize (connection pool)
- [ ] Restringir CORS para origens permitidas
- [ ] Migrations automáticas no startup via script de entrypoint
- [ ] Versionamento de API (`/api/v1/tarefas`)
- [ ] Paginação em `GET /api/tarefas`

### Médio Prazo (evolução de arquitetura)

- [ ] Cenário 2: Implementar ALB com Target Group e 2 AZs
- [ ] Cenário 3: Cache como serviço ECS com Cloud Map
- [ ] HTTPS no ALB via ACM
- [ ] Variáveis de configuração via SSM Parameter Store
- [ ] Separar `VITE_API_URL` em runtime (window config)

### Longo Prazo (produção)

- [ ] AWS ElastiCache (Redis gerenciado) com TLS habilitado
- [ ] AWS Secrets Manager para credenciais de produção
- [ ] Multi-AZ no RDS
- [ ] Auto Scaling no ECS Service (CPU/memória)
- [ ] CloudWatch Container Insights
- [ ] AWS X-Ray para distributed tracing
- [ ] WAF no ALB para proteção contra ataques
- [ ] Testes de integração para as rotas da API

---

## 17. Glossário

| Termo              | Significado                                                          |
|--------------------|----------------------------------------------------------------------|
| ALB                | Application Load Balancer — distribui requisições entre tasks ECS   |
| awsvpc             | Network mode do ECS onde cada task recebe sua própria ENI           |
| bridge             | Network mode padrão do Docker — tasks compartilham a interface da EC2|
| Cloud Map          | Serviço AWS de service discovery via DNS interno                     |
| ECR                | Elastic Container Registry — registro de imagens Docker na AWS      |
| ECS                | Elastic Container Service — orquestrador de containers da AWS       |
| ENI                | Elastic Network Interface — interface de rede virtual na AWS        |
| ElastiCache        | Serviço gerenciado de cache (Redis/Memcached) da AWS                |
| imagedefinitions   | Artefato JSON que instrui o ECS a usar uma nova versão da imagem    |
| RDS                | Relational Database Service — banco gerenciado da AWS               |
| Rolling Update     | Estratégia de deploy que substitui tasks gradualmente               |
| Secrets Manager    | Serviço AWS para armazenar e rotacionar segredos                    |
| SSM                | Systems Manager — permite acesso seguro a EC2 sem SSH               |
| STS                | Security Token Service — emite credenciais temporárias AWS          |
| Target Group       | Grupo de destinos do ALB (instâncias EC2 ou IPs de tasks ECS)       |
| Task Definition    | Especificação de container no ECS (imagem, memória, CPU, envs)      |
| UUIDV1             | UUID baseado em timestamp — usado como PK da tabela Tarefas         |
| Valkey             | Fork open-source do Redis mantido pela Linux Foundation             |
| Vite               | Build tool moderno para projetos frontend (substitui webpack/CRA)   |

---

## 18. Referências

- [Repositório GitHub](https://github.com/henrylle/bia)
- [Documentação AWS ECS](https://docs.aws.amazon.com/ecs/)
- [Documentação Sequelize](https://sequelize.org/docs/v6/)
- [Documentação ioredis](https://github.com/redis/ioredis)
- [Documentação Vite](https://vitejs.dev/)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [AWS Cloud Map](https://docs.aws.amazon.com/cloud-map/)
- Diagrama de arquitetura: `docs/architecture/aws-ecs-diagram.html`
