# Verificação — Cenário 1: BIA no ECS sem ALB

> Gerado em 02/08/2026 | Região: us-east-1 | Conta: 328113723783  
> Executado pelo agente Kiro-BIA  
> Status geral: ✅ **OPERACIONAL**

---

## Visão Geral

Este documento registra a verificação completa do ambiente BIA rodando no **Cenário 1** — ECS com EC2, sem Load Balancer. Todos os recursos foram criados e validados em 02/08/2026 durante a Imersão AWS & IA.

```
Internet
    │
    ▼ porta 80
EC2 t3.micro — IP 18.212.189.248 (us-east-1b)
  Security Group: bia-web
  ECS Cluster: cluster-bia
    │
    ▼ container port 8080 → host port 80
  ECS Task (bridge mode)
    Container: bia
    Task Definition: task-bia:3
    Service: service-bia
    │
    ▼ porta 5432
  RDS PostgreSQL
    bia.co3qaww06tcz.us-east-1.rds.amazonaws.com
    Security Group: bia-db
```

---

## 1. Cluster ECS

| Atributo | Valor | Status |
|---|---|---|
| Nome | `cluster-bia` | ✅ |
| Status | `ACTIVE` | ✅ |
| Instâncias registradas | `1` | ✅ |
| Tasks rodando | `1` | ✅ |
| Tasks pendentes | `0` | ✅ |
| Serviços ativos | `1` | ✅ |
| Capacity Providers | `Infra-ECS-Cluster-cluster-bia` (ASG) + FARGATE + FARGATE_SPOT | ✅ |

---

## 2. EC2 no Cluster

| Atributo | Valor | Status |
|---|---|---|
| Nome | `ECS Instance - cluster-bia` | ✅ |
| Instance ID | `i-0c7179d2eaf2e5063` | ✅ |
| Tipo | `t3.micro` | ✅ |
| Estado | `running` | ✅ |
| IP Público | `18.212.189.248` | ✅ |
| Availability Zone | `us-east-1b` | ⚠️ |
| Security Group | `bia-web` | ✅ |

> ⚠️ **Observação de AZ:** O runbook define subnet da `us-east-1a`. A instância foi registrada na `us-east-1b`. Não impacta o funcionamento do Cenário 1 (sem ALB), mas no **Cenário 2** (com ALB) a instância deverá estar na zona A conforme as regras de infraestrutura.

---

## 3. ECS Service

| Atributo | Valor | Status |
|---|---|---|
| Nome | `service-bia` | ✅ |
| Cluster | `cluster-bia` | ✅ |
| Status | `ACTIVE` | ✅ |
| Desired Count | `1` | ✅ |
| Running Count | `1` | ✅ |
| Pending Count | `0` | ✅ |
| Failed Tasks | `0` | ✅ |
| Task Definition | `task-bia:3` | ✅ |
| Launch Type | `EC2` | ✅ |
| Deployment Strategy | `Rolling Update` | ✅ |
| Minimum Healthy % | `0%` | ⚠️ |
| Maximum % | `100%` | ✅ |
| AZ Rebalancing | `DISABLED` | ✅ |

> ⚠️ **Observação de Minimum Healthy %:** O runbook define `50%`. O service foi criado pelo console com `0%`. Para ambiente educacional com 1 task não causa impacto prático, mas pode ser ajustado via `aws ecs update-service --deployment-configuration minimumHealthyPercent=50,maximumPercent=100`.

---

## 4. Task Definition — task-bia:3

| Atributo | Valor | Status |
|---|---|---|
| Family | `task-bia` | ✅ |
| Revisão ativa | `3` | ✅ |
| Network Mode | `bridge` | ✅ |
| Requires Compatibility | `EC2` | ✅ |
| Execution Role | `ecsTaskExecutionRole` | ✅ |
| **Container: bia** | | |
| Imagem | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:latest` | ✅ |
| CPU | `1024` units (1 vCPU) | ✅ |
| Memory Reservation (soft) | `400` MB | ✅ |
| Container Port | `8080` | ✅ |
| Host Port | `80` | ✅ |
| Log Driver | `awslogs` → `/ecs/task-bia` | ✅ |

### Variáveis de Ambiente

| Variável | Valor |
|---|---|
| `DB_USER` | `postgres` |
| `DB_PWD` | `l93Xp4KhciaomhgrdyEn` |
| `DB_HOST` | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` |
| `DB_PORT` | `5432` |
| `VERSAO_API` | `4.3.0` |

> **Nota sobre revisões:** Foram criadas 3 revisões durante o processo:
> - `task-bia:1` — criada pelo console com `awsvpc` + FARGATE + porta 80→80 + 3072MB ❌ (incorreta)
> - `task-bia:2` — corrigida via CLI com `bridge` + EC2 + porta 0→8080 ✅ (mas host port dinâmico)
> - `task-bia:3` — versão final com host port fixo `80` ✅ (em uso)

---

## 5. IAM — Execution Role

| Atributo | Valor | Status |
|---|---|---|
| Nome | `ecsTaskExecutionRole` | ✅ |
| ARN | `arn:aws:iam::328113723783:role/ecsTaskExecutionRole` | ✅ |
| Trust Policy | `ecs-tasks.amazonaws.com` | ✅ |
| Policy anexada | `AmazonECSTaskExecutionRolePolicy` | ✅ |

### Permissões concedidas pela AmazonECSTaskExecutionRolePolicy

| Permissão | Finalidade |
|---|---|
| `ecr:GetAuthorizationToken` | Autenticar no ECR para pull da imagem |
| `ecr:BatchCheckLayerAvailability` | Verificar camadas da imagem |
| `ecr:GetDownloadUrlForLayer` | Baixar camadas da imagem |
| `ecr:BatchGetImage` | Puxar imagem completa |
| `logs:CreateLogStream` | Criar stream no CloudWatch Logs |
| `logs:PutLogEvents` | Enviar logs da task para CloudWatch |

---

## 6. Security Groups

### bia-web (sg-02644d8a3164e531b)
Associado à EC2 do cluster. Controla acesso externo à aplicação.

| Direção | Protocolo | Porta | Origem | Status |
|---|---|---|---|---|
| Inbound | TCP | 80 | `0.0.0.0/0` | ✅ |
| Outbound | All | All | `0.0.0.0/0` | ✅ |

### bia-db (sg-096a1e8518c3a982c)
Protege o RDS PostgreSQL.

| Direção | Protocolo | Porta | Origem | Descrição | Status |
|---|---|---|---|---|---|
| Inbound | TCP | 5432 | `bia-dev` (sg-09c9c321387767850) | acesso vindo de bia-dev | ✅ |
| Inbound | TCP | 5432 | `bia-web` (sg-02644d8a3164e531b) | acesso vindo de bia-web | ✅ |

---

## 7. Testes de Rotas da API

Base URL: `http://18.212.189.248`

| Rota | Método | HTTP | Tempo | Resultado | Status |
|---|---|---|---|---|---|
| `/api/versao` | GET | 200 | ~3ms | `Bia 4.3.0` | ✅ |
| `/api/cache-config` | GET | 200 | ~3ms | `{"enabled":false,...}` | ✅ |
| `/api/tarefas` | GET | 200 | ~58ms | 3 tarefas do RDS | ✅ |
| `/` (Frontend React) | GET | 200 | ~3ms | HTML carregado | ✅ |
| `/api/ping` | GET | 200 | — | Retorna HTML do React | ⚠️ |

> ⚠️ **Bug pré-existente:** A rota `/api/ping` retorna o HTML do React em vez de `"Rota funcionando. Pong!"`. O arquivo `api/routes/ping.js` existe mas não está carregado em `config/express.js`. Não foi introduzido neste cenário.

---

## 8. Logs CloudWatch

Grupo: `/ecs/task-bia` | Stream prefix: `ecs`

```
> bia@4.3.0 start
> node server
Servidor rodando na porta 8080
Executing (default): SELECT "uuid", "titulo", "dia_atividade", "importante", "createdAt", "updatedAt" FROM "Tarefas" AS "Tarefas";
[DB] tarefas - 97ms
```

✅ Aplicação iniciou corretamente e conectou ao RDS.

---

## 9. Conectividade RDS

| Atributo | Valor | Status |
|---|---|---|
| Endpoint | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` | ✅ |
| Porta | `5432` | ✅ |
| Banco | `bia` | ✅ |
| Latência | ~97ms (primeira query) | ✅ |
| Tarefas retornadas | 3 | ✅ |
| Acesso via SG | `bia-db` com origem `bia-web` | ✅ |

---

## 10. ECR

| Atributo | Valor | Status |
|---|---|---|
| Registry | `328113723783.dkr.ecr.us-east-1.amazonaws.com` | ✅ |
| Repositório | `bia` | ✅ |
| Tag em uso | `latest` | ✅ |
| Último commit | `89f2ec3` | ✅ |

---

## Resumo Executivo

| Componente | Status |
|---|---|
| Cluster ECS `cluster-bia` | ✅ OPERACIONAL |
| EC2 `ECS Instance - cluster-bia` | ✅ RUNNING |
| Service `service-bia` | ✅ ACTIVE — 1/1 tasks |
| Task Definition `task-bia:3` | ✅ CORRETA |
| IAM `ecsTaskExecutionRole` | ✅ CRIADA |
| SG `bia-web` porta 80 | ✅ LIBERADA |
| SG `bia-db` origem bia-web | ✅ LIBERADA |
| RDS PostgreSQL | ✅ CONECTADO |
| Frontend React | ✅ SERVINDO |
| API `/api/versao` | ✅ 200 OK |
| API `/api/tarefas` | ✅ 200 OK |
| Logs CloudWatch | ✅ RECEBENDO |

**URL de acesso:** `http://18.212.189.248`

---

## Pendências e Observações

| # | Item | Impacto | Ação Recomendada |
|---|---|---|---|
| 1 | EC2 em `us-east-1b` (esperado `us-east-1a`) | Baixo — Cenário 1 sem ALB | Corrigir no Cenário 2 |
| 2 | `minimumHealthyPercent` em `0%` (esperado `50%`) | Baixo — 1 task apenas | `update-service` com `minimumHealthyPercent=50` |
| 3 | `/api/ping` retorna HTML do React | Baixo — bug pré-existente | Adicionar `require('../api/routes/ping')(app)` em `config/express.js` |
| 4 | `task-bia:1` e `task-bia:2` (revisões antigas) | Nenhum | Desregistrar para manter ambiente limpo |
| 5 | `task-def-bia:1` (criada anteriormente) | Nenhum | Desregistrar para manter ambiente limpo |

---

## Próximo Passo

**Cenário 2 — ECS com ALB**  
Referência: `docs/runbook-cenario2-ecs-alb.md` *(a criar)*

Recursos a adicionar:
- ALB + Listener porta 80 → Target Group `tg-bia-alb`
- Segunda EC2 em zona B
- Cluster `cluster-bia-alb` | Service `service-bia-alb` | Task `task-def-bia-alb`
- SG `bia-alb` e `bia-ec2`

---

*Documento gerado pelo agente Kiro-BIA em 02/08/2026.*
