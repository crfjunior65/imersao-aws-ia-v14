# Checkpoint de Sessão — Kiro-BIA

> Data: 02/08/2026 | Hora: ~03:08 UTC  
> Sessão: Imersão AWS & IA — Dia 2  
> Agente: Kiro-BIA

---

## Estado do Projeto no Momento do Checkpoint

### O que foi feito nesta sessão

1. **Análise completa do projeto** — estrutura de arquivos, containers rodando, git status
2. **Leitura e execução do runbook** `docs/runbook-cenario1-ecs.md`
3. **Criação dos recursos do Cenário 1** — cluster, task definition, service
4. **Correção da task definition** — problema de network mode awsvpc→bridge e porta
5. **Validação completa** do ambiente ECS + RDS
6. **Geração de documentação** `docs/verificacao-cenario1-ecs.md`

---

## Cenário 1 — CONCLUÍDO ✅

### Recursos AWS criados e operacionais

| Recurso | Nome | ID / ARN | Status |
|---|---|---|---|
| ECS Cluster | `cluster-bia` | `arn:aws:ecs:us-east-1:328113723783:cluster/cluster-bia` | ✅ ACTIVE |
| EC2 ECS | `ECS Instance - cluster-bia` | `i-0c7179d2eaf2e5063` | ✅ running |
| ECS Service | `service-bia` | `arn:aws:ecs:us-east-1:328113723783:service/cluster-bia/service-bia` | ✅ ACTIVE 1/1 |
| Task Definition | `task-bia:3` | `arn:aws:ecs:us-east-1:328113723783:task-definition/task-bia:3` | ✅ ACTIVE |
| IAM Role | `ecsTaskExecutionRole` | `arn:aws:iam::328113723783:role/ecsTaskExecutionRole` | ✅ criada |
| SG EC2 | `bia-web` | `sg-02644d8a3164e531b` | ✅ porta 80 liberada |
| SG RDS | `bia-db` | `sg-096a1e8518c3a982c` | ✅ 5432 de bia-web |

### Detalhes da Task Definition task-bia:3

```
family:        task-bia
revision:      3  ← versão em uso
network:       bridge
compatibility: EC2
execution role: arn:aws:iam::328113723783:role/ecsTaskExecutionRole
container:
  name:        bia
  image:       328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:latest
  cpu:         1024
  memory soft: 400 MB
  port:        8080 (container) → 80 (host)
  logs:        /ecs/task-bia (CloudWatch)
  env:
    DB_USER=postgres
    DB_PWD=l93Xp4KhciaomhgrdyEn
    DB_HOST=bia.co3qaww06tcz.us-east-1.rds.amazonaws.com
    DB_PORT=5432
    VERSAO_API=4.3.0
```

### Acesso à aplicação

- **URL:** `http://18.212.189.248`
- `/api/versao` → `Bia 4.3.0` ✅
- `/api/tarefas` → 3 tarefas do RDS ✅
- `/api/cache-config` → cache desabilitado ✅
- Frontend React → carregando ✅

---

## Infraestrutura Existente (pré-sessão)

| Recurso | Nome | ID |
|---|---|---|
| VPC | vpc padrão | `vpc-0d58780cd33b85a9c` |
| Subnet zona A | us-east-1a | `subnet-0f5924893a60e01b3` |
| SG | `bia-dev` | `sg-09c9c321387767850` |
| SG | `bia-db` | `sg-096a1e8518c3a982c` |
| SG | `bia-web` | `sg-02644d8a3164e531b` |
| IAM Profile | `role-acesso-ssm` | — |
| ECR | `bia` | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia` |
| RDS | PostgreSQL | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` |
| EC2 dev | `bia-dev` | `i-0acb3c5f6cffe094e` — IP `13.219.239.172` |

---

## Ambiente Local (bia-dev — EC2 13.219.239.172)

Containers rodando via `docker compose`:

| Container | Porta | Status |
|---|---|---|
| `bia` | 3001→8080 | Up — Dockerfile (VITE_API_URL=:3001) |
| `bia-3002` | 3002→8080 | Up — container órfão fora do compose |
| `database` | 5433→5432 | Up — PostgreSQL 17.1 |
| `redis` | 6379→6379 | Up — Valkey 8.1 (cache desabilitado na app) |

`compose.yml` aponta para RDS externo (`DB_HOST=bia.co3qaww06tcz.us-east-1.rds.amazonaws.com`)

---

## Pendências Identificadas

| # | Item | Prioridade |
|---|---|---|
| 1 | EC2 do cluster em `us-east-1b` (esperado `us-east-1a`) | Baixa — Cenário 1 sem ALB |
| 2 | `minimumHealthyPercent=0%` no service (esperado `50%`) | Baixa |
| 3 | `/api/ping` retorna HTML (bug pré-existente) | Baixa |
| 4 | Desregistrar task-bia:1, task-bia:2, task-def-bia:1 (revisões antigas) | Baixa |
| 5 | `bia-3002` container órfão rodando na bia-dev | Baixa |

---

## Próximo Passo — Cenário 2

**Objetivo:** Evoluir para ECS com ALB

Recursos a criar:
- Cluster: `cluster-bia-alb`
- Task Definition: `task-def-bia-alb` (bridge, EC2, porta 0→8080)
- Service: `service-bia-alb` (rolling update 50/100, AZ rebalancing off)
- ALB + Listener 80 → Target Group `tg-bia-alb` (tipo: instance, delay 30s)
- EC2 zona A + EC2 zona B (t3.micro)
- SG `bia-alb` — inbound 80 de `0.0.0.0/0`
- SG `bia-ec2` — inbound All TCP de `bia-alb`
- Atualizar `bia-db` — inbound 5432 de `bia-ec2`

Referência: `docs/infraestrutura.md` (regras) + `docs/runbook-cenario1-ecs.md` (padrão)

---

## Conta AWS

- **Account ID:** `328113723783`
- **Região:** `us-east-1`
- **Repositório git:** `crfjunior65/imersao-aws-ia-v14`
- **Branch:** `main`
- **Último commit:** `89f2ec3 Fix: Dockerfile-EC2`

---

## Arquivos Gerados nesta Sessão

| Arquivo | Descrição |
|---|---|
| `docs/verificacao-cenario1-ecs.md` | Verificação completa do Cenário 1 |
| `docs/checkpoint-sessao-02082026.md` | Este arquivo |

---

## Como Retomar

Se o agente cair, ao retomar diga:

> "leia docs/checkpoint-sessao-02082026.md e retome de onde paramos"

O agente deve:
1. Ler este arquivo
2. Confirmar estado dos recursos com `aws ecs describe-clusters --clusters cluster-bia`
3. Perguntar se continua para o **Cenário 2** ou trata alguma pendência
