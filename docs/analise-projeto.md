# Análise do Projeto BIA

> Análise gerada em 01/08/2026 — Dia 1 da Imersão AWS & IA

---

## O que é

Projeto educacional criado por **Henrylle Maia** para a **Imersão AWS & IA** (01-02/08/2026). É uma aplicação de gerenciamento de tarefas usada como base para ensinar boas práticas AWS de forma progressiva — do simples ao complexo.

- Repositório: https://github.com/henrylle/bia
- Versão atual: `4.3.0`

---

## Stack Técnica

### Backend (Node.js/Express)

- Entry point: `server.js` → carrega `config/express.js` e sobe na porta configurada
- `index.js` é um arquivo legado (Express com boot automático de controllers, sessão, etc.) — não é o entry point principal
- ORM: Sequelize 6 com PostgreSQL
- Cache: ioredis (Redis/Valkey) — **opcional**, ativado só se `CACHE_ENDPOINT` estiver setado
- AWS SDK v3: Secrets Manager e STS para gerenciar credenciais remotamente

### Frontend (React)

- React 17 com Vite em `client/`
- Build gerado dentro do Dockerfile e servido como estático pelo Express via `client/build`

### Banco de Dados

- PostgreSQL 17.1 (no Docker), migração única: tabela `tarefas`
- Campos: `uuid` (PK), `titulo`, `dia_atividade`, `importante`

---

## Estrutura de Diretórios

```
/bia
├── api/
│   ├── controllers/       # Lógica de negócio (tarefas, versao, cache-config)
│   ├── models/            # Modelos Sequelize
│   ├── routes/            # Definição de rotas Express
│   └── data/              # Dados estáticos (tarefas.json)
├── client/                # Aplicação React (Vite)
│   └── src/
│       ├── components/    # Componentes React
│       └── contexts/      # React Contexts
├── config/                # Configurações Express e banco de dados
├── database/
│   └── migrations/        # Migrations Sequelize
├── docs/                  # Documentação
├── lib/
│   ├── boot.js            # Bootstrap de controllers legados
│   └── cache.js           # Abstração do cliente Redis
├── scripts/               # Scripts auxiliares e de infraestrutura
├── tests/
│   └── unit/              # Testes unitários com Jest
├── .kiro/
│   ├── rules/             # Regras de infraestrutura e pipeline para o Kiro
│   └── agents/            # Agentes configurados
├── buildspec.yml          # Definição do build para AWS CodeBuild
├── compose.yml            # Docker Compose para ambiente local
└── Dockerfile             # Imagem da aplicação
```

---

## Rotas da API

| Método   | Rota                                  | Descrição                          |
|----------|---------------------------------------|------------------------------------|
| GET      | `/api/versao`                         | Versão do app — sem banco          |
| GET      | `/api/ping`                           | Health check                       |
| GET      | `/api/cache-config`                   | Configuração atual do cache        |
| GET      | `/api/tarefas`                        | Lista tarefas (com suporte a cache)|
| POST     | `/api/tarefas`                        | Cria nova tarefa                   |
| DELETE   | `/api/tarefas`                        | Deleta todas as tarefas            |
| GET      | `/api/tarefas/:uuid`                  | Busca tarefa por UUID              |
| DELETE   | `/api/tarefas/:uuid`                  | Deleta tarefa específica           |
| PUT      | `/api/tarefas/update_priority/:uuid`  | Atualiza prioridade da tarefa      |

---

## Infraestrutura e CI/CD

### Docker Compose (ambiente local)

- 3 serviços: `server` (porta 3001→8080), `database` (postgres:17.1, porta 5433), `redis` (valkey:8.1)
- Variáveis de ambiente para AWS (Secrets Manager, etc.) comentadas — não necessárias na imersão
- Healthcheck do servidor está comentado — habilitá-lo é recomendável

### Dockerfile

- Base: `node:24.18.0-slim` (ECR público)
- Build em etapas: instala deps do backend + frontend, executa build Vite, faz prune das devDeps
- Expõe porta `8080`

### Pipeline CI/CD (CodeBuild + CodePipeline)

- ECR registry: `380278406175.dkr.ecr.us-east-1.amazonaws.com/bia`
- Tags geradas: `latest` + hash curto do commit
- Artefato `imagedefinitions.json` gerado para deploy automático no ECS
- Fluxo: GitHub → CodePipeline → CodeBuild → ECR → ECS (rolling update)

### Arquitetura ECS — 3 Cenários Progressivos

| Cenário | Descrição                     | Instância EC2 | Network Mode |
|---------|-------------------------------|---------------|--------------|
| 1       | Sem ALB                       | t3.micro      | bridge       |
| 2       | Com ALB                       | t3.micro      | bridge       |
| 3       | Com ALB + Cache (Redis/ECS)   | t3.small      | awsvpc       |

- Região: `us-east-1`
- AZs utilizadas (com ALB): zona A (`us-east-1a`) e zona B (`us-east-1b`)
- No Cenário 3, o Redis roda como serviço ECS descoberto via **AWS Cloud Map** (DNS interno)

---

## Comportamento do Cache

O cache é implementado de forma não-obstrutiva:

1. Se `CACHE_ENDPOINT` não estiver definido → cache ignorado, busca direto no banco
2. Se Redis estiver disponível → serve do cache com TTL configurável (`CACHE_TTL`, padrão 60s)
3. Se Redis falhar → fallback gracioso para o banco, sem retornar erro ao cliente

A resposta do `GET /api/tarefas` inclui metadados: `fromCache`, `cacheTTL`, `dbTime`, `cacheError`.

---

## Integração com AWS Secrets Manager

A configuração de banco (`config/database.js`) suporta dois modos:

- **Local:** usa variáveis de ambiente `DB_USER` e `DB_PWD`
- **Remoto:** se `DB_SECRET_NAME` estiver definida, busca credenciais no Secrets Manager e aplica SSL automaticamente

Variável `DEBUG_SECRET=true` habilita logs de diagnóstico das credenciais via STS.

---

## Observações Técnicas

### Código Legado

- `index.js` contém um sistema de boot automático que carrega controllers de `app/controllers/` (diretório que não existe mais). Esse arquivo aparentemente não é mais utilizado — o entry point real é `server.js` via `config/express.js`.
- Manter esse arquivo pode causar confusão. Vale avaliar remoção ou documentar que é legado.

### Cache Desabilitado Localmente

- O `compose.yml` sobe o Redis (Valkey), mas a variável `CACHE_ENDPOINT` está comentada. Isso significa que o Redis roda mas a aplicação não o utiliza no ambiente local por padrão.
- Para testar o cache localmente, basta descomentar as variáveis `CACHE_ENDPOINT`, `CACHE_PORT`, `CACHE_TTL` e `CACHE_TLS` no `compose.yml`.

### Healthcheck Comentado

- O Docker Compose tem um healthcheck configurado mas comentado. Sem ele, o `depends_on` não garante que o banco esteja pronto antes da app iniciar — pode causar falhas de conexão no primeiro start.

### Session Secret Hardcoded

- Em `index.js` o secret da sessão está como `"some secret here"`. Como esse arquivo parece ser legado e não usado, o impacto é baixo — mas vale confirmar.

### Porta Inconsistente

- `index.js` sobe na porta `3000`; `server.js` usa a porta definida em `config/express.js` (provavelmente `8080` via variável de ambiente). O Dockerfile expõe `8080` e o compose mapeia `3001:8080` — o fluxo atual está correto via `server.js`.

---

## Possíveis Implementações e Evoluções

### Curto Prazo (melhorias imediatas)

- **Habilitar healthcheck no compose:** descomentar o bloco `healthcheck` para garantir ordem de inicialização correta
- **Ativar cache localmente:** descomentar variáveis `CACHE_*` no `compose.yml` para testar o comportamento completo
- **Remover ou documentar `index.js`:** evitar confusão sobre o entry point da aplicação
- **Adicionar rota de health check no ECS:** a rota `/api/ping` existe, mas precisa estar configurada no Target Group do ALB

### Médio Prazo (arquitetura)

- **Cenário 2 — Incluir ALB:** adicionar Application Load Balancer com Target Group `tg-bia-alb` (tipo instance), SGs `bia-alb` e `bia-ec2`, e evolução do cluster ECS para `cluster-bia-alb`
- **Cenário 3 — Cache como serviço ECS:** mover Redis para container ECS com Cloud Map para service discovery, habilitar `CACHE_ENDPOINT` via variável de ambiente injetada pelo ECS, e migrar para `awsvpc` com instâncias t3.small
- **Migrations automáticas no startup:** rodar `npx sequelize db:migrate` automaticamente ao subir o container (via script de entrypoint)

### Longo Prazo (produção)

- **Amazon ElastiCache:** substituir Redis em container pelo ElastiCache gerenciado (Redis OSS ou Valkey), com suporte a TLS — variável `CACHE_TLS=true` já existe no código
- **AWS Secrets Manager (produção):** a integração já está implementada em `config/database.js` — basta provisionar o secret no AWS e configurar `DB_SECRET_NAME` e `DB_REGION`
- **Multi-AZ no RDS:** evoluir de instância única para Multi-AZ para maior disponibilidade
- **Auto Scaling no ECS Service:** configurar scaling baseado em CPU/memória no ECS Service
- **HTTPS no ALB:** adicionar certificado via ACM e listener na porta 443
- **Variáveis de ambiente via SSM Parameter Store:** centralizar configurações não-secretas
- **Testes de integração:** a estrutura Jest existe para unit tests — adicionar testes de integração para as rotas da API
- **Observabilidade:** integrar CloudWatch Container Insights para métricas de ECS, e adicionar tracing com AWS X-Ray

---

## Estado Atual (01/08/2026)

O projeto está funcional e pronto para uso como base da imersão. O ambiente local sobe via `docker compose up`. O pipeline CodeBuild/ECS está estruturado no `buildspec.yml`. A EC2 de desenvolvimento (`bia-dev`) tem scripts de setup prontos em `scripts/user_data_ec2_zona_a.sh`.

O foco do evento é conduzir os alunos pelos 3 cenários de arquitetura ECS de forma progressiva, partindo do mais simples (sem ALB) até o mais completo (ALB + Cache via Cloud Map).
