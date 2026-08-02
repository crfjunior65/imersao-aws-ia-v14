# Análise Completa — cluster-bia / service-bia / task-bia

> Gerado em: 02/08/2026 04:39 UTC  
> Conta AWS: `328113723783`  
> Região: `us-east-1`  
> Status: ✅ OPERACIONAL

---

## Diagrama de Arquitetura

```
                         Internet
                            │
                            │ porta 80
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  EC2 — ECS Instance (i-0c4aa2ee22ad93aa1)                          │
│  Tipo: t3.micro | AZ: us-east-1b | IP: 52.87.247.22               │
│  SG: bia-web (sg-02644d8a3164e531b)                                │
│  IAM Instance Profile: ecsInstanceRole                             │
│  AMI: ami-0b416d150bdde5ea2 (ECS Optimized Amazon Linux 2023)      │
│  ASG: Infra-ECS-Cluster-cluster-bia-581e3f53 (min:1 max:1 des:1)  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  ECS Task (bridge mode)                                      │   │
│  │  Task Definition: task-bia:5                                 │   │
│  │  Container: bia                                              │   │
│  │  Imagem: 328113723783.dkr.ecr.us-east-1.amazonaws.com/      │   │
│  │          bia:a35d585                                         │   │
│  │  CPU: 1024 units (1 vCPU) | Mem: 400 MB (soft)              │   │
│  │  Port: 8080 (container) → 80 (host)                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                            │
                            │ porta 5432
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  RDS PostgreSQL (bia.co3qaww06tcz.us-east-1.rds.amazonaws.com)     │
│  Engine: postgres 18.3 | Classe: db.t4g.micro                      │
│  AZ: us-east-1a | Storage: 20 GB gp2 | Encryption: ✅             │
│  SG: bia-db (sg-096a1e8518c3a982c)                                 │
│  Multi-AZ: ❌ | Backup: desabilitado (0 dias)                      │
│  Acesso público: ❌                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 1. Cluster ECS

| Atributo | Valor |
|----------|-------|
| Nome | `cluster-bia` |
| ARN | `arn:aws:ecs:us-east-1:328113723783:cluster/cluster-bia` |
| Status | `ACTIVE` |
| Instâncias registradas | 1 |
| Tasks EC2 rodando | 1 |
| Services ativos | 1 |
| Container Insights | Desabilitado |
| Criado via | CloudFormation (`Infra-ECS-Cluster-cluster-bia-581e3f53`) |

### Capacity Providers

| Provider | Tipo | Peso |
|----------|------|------|
| `Infra-ECS-Cluster-cluster-bia-581e3f53-AsgCapacityProvider` | ASG (EC2) | 1 (default) |
| `FARGATE` | Fargate | — |
| `FARGATE_SPOT` | Fargate Spot | — |

> O cluster usa **ASG como capacity provider default**. Fargate e Fargate Spot estão disponíveis mas não são utilizados.

---

## 2. Service — service-bia

| Atributo | Valor |
|----------|-------|
| Nome | `service-bia` |
| ARN | `arn:aws:ecs:us-east-1:328113723783:service/cluster-bia/service-bia` |
| Status | `ACTIVE` |
| Launch Type | `EC2` |
| Task Definition | `task-bia:5` |
| Desired Count | 1 |
| Running Count | 1 |
| Pending Count | 0 |
| Scheduling Strategy | `REPLICA` |
| AZ Rebalancing | `DISABLED` |
| Execute Command | Desabilitado |
| Criado em | 2026-08-02 02:40:26 UTC |

### Deployment Configuration

| Parâmetro | Valor | Observação |
|-----------|-------|------------|
| Strategy | `ROLLING` | Deploy gradual |
| Maximum Percent | `100%` | ✅ conforme regra |
| Minimum Healthy Percent | `0%` | ⚠️ deveria ser 50% |
| Circuit Breaker | Desabilitado | — |
| Bake Time | 0 minutos | — |

### Placement Strategy

| Tipo | Campo |
|------|-------|
| `spread` | `attribute:ecs.availability-zone` |
| `spread` | `instanceId` |

### Deployment Atual

| Atributo | Valor |
|----------|-------|
| ID | `ecs-svc/7686180938609062511` |
| Status | `PRIMARY` |
| Rollout | `COMPLETED` |
| Task Definition | `task-bia:5` |
| Running | 1/1 |
| Failed Tasks | 0 |
| Criado em | 2026-08-02 04:21:25 UTC |

---

## 3. Task Definition — task-bia:5

| Atributo | Valor |
|----------|-------|
| Family | `task-bia` |
| Revision | 5 (ativa no service) |
| ARN | `arn:aws:ecs:us-east-1:328113723783:task-definition/task-bia:5` |
| Network Mode | `bridge` |
| Requires Compatibility | `EC2` |
| Execution Role | `arn:aws:iam::328113723783:role/ecsTaskExecutionRole` |
| Task Role | Nenhuma |
| Registrada em | 2026-08-02 04:21:24 UTC |
| Registrada por | `role-acesso-ssm/i-0acb3c5f6cffe094e` (bia-dev) |

### Container: bia

| Atributo | Valor |
|----------|-------|
| Nome | `bia` |
| Imagem | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:a35d585` |
| CPU | 1024 units (1 vCPU) |
| Memory Reservation (soft limit) | 400 MB |
| Memory (hard limit) | Não definido |
| Essential | `true` |
| Port Mapping | 8080 (container) → 80 (host) TCP |

### Variáveis de Ambiente

| Variável | Valor | Uso |
|----------|-------|-----|
| `DB_HOST` | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` | Endpoint RDS |
| `DB_PORT` | `5432` | Porta PostgreSQL |
| `DB_USER` | `postgres` | Usuário do banco |
| `DB_PWD` | `l93Xp4KhciaomhgrdyEn` | Senha do banco |
| `VERSAO_API` | `4.3.0` | Versão exibida em /api/versao |

### Log Configuration

| Atributo | Valor |
|----------|-------|
| Driver | `awslogs` |
| Log Group | `/ecs/task-bia` |
| Region | `us-east-1` |
| Stream Prefix | `ecs` |
| Auto Create Group | `true` |

### Histórico de Revisions

| Revision | Status | Imagem | Observação |
|----------|--------|--------|------------|
| task-bia:6 | ACTIVE | `bia:2e1b46e` | Mais recente (não em uso pelo service) |
| **task-bia:5** | **ACTIVE** | **`bia:a35d585`** | **← EM USO** |
| task-bia:4 | ACTIVE | — | — |
| task-bia:3 | ACTIVE | — | Primeira versão correta (porta 80 fixa) |
| task-bia:2 | ACTIVE | — | Bridge corrigida, porta dinâmica |
| task-bia:1 | ACTIVE | — | awsvpc + Fargate (incorreta) |

> Também existem revisions da família `task-def-bia` (task-def-bia:1, task-def-bia:2) — criadas em tentativas anteriores.

---

## 4. Task em Execução

| Atributo | Valor |
|----------|-------|
| Task ARN | `arn:aws:ecs:.../task/cluster-bia/b8b1dfb6636f4a738c6e9c1db47604c0` |
| Status | `RUNNING` |
| Connectivity | `CONNECTED` |
| AZ | `us-east-1b` |
| Started At | 2026-08-02 04:21:56 UTC |
| Image Digest | `sha256:070fefb3f21e62b29267fd4e2b2beaaf666a41a19d6ab58420378e69e8fee6d1` |
| Network Binding | `0.0.0.0:80 → 8080` |
| Pull Time | < 1s (imagem já cached) |

---

## 5. Container Instance (EC2)

| Atributo | Valor |
|----------|-------|
| Instance ID | `i-0c4aa2ee22ad93aa1` |
| Tipo | `t3.micro` |
| AZ | `us-east-1b` |
| Subnet | `subnet-05c133d510483bfa2` (172.31.80.0/20) |
| IP Público | `52.87.247.22` |
| IP Privado | `172.31.85.45` |
| DNS Público | `ec2-52-87-247-22.compute-1.amazonaws.com` |
| Security Group | `bia-web` (sg-02644d8a3164e531b) |
| IAM Profile | `ecsInstanceRole` |
| AMI | `ami-0b416d150bdde5ea2` (ECS Optimized Amazon Linux 2023) |
| ECS Agent | v1.106.0 |
| Docker | 25.0.16 |
| VPC | `vpc-0d58780cd33b85a9c` |
| Launch Time | 2026-08-02 03:20:45 UTC |
| Metadata (IMDSv2) | `required` (tokens obrigatórios) |

### Recursos da Container Instance

| Recurso | Total | Disponível | Em uso |
|---------|-------|------------|--------|
| CPU | 2048 units | 1024 units | 1024 units (task bia) |
| Memória | 916 MB | 516 MB | 400 MB (task bia) |
| Porta 80 | — | Reservada | Pela task bia |

---

## 6. Auto Scaling Group

| Atributo | Valor |
|----------|-------|
| Nome | `Infra-ECS-Cluster-cluster-bia-581e3f53-ECSAutoScalingGroup-VX1mts6Zyf02` |
| Min Size | 1 |
| Max Size | 1 |
| Desired Capacity | 1 |
| AZs configuradas | `us-east-1a`, `us-east-1b` |
| Instâncias | 1 (`i-0c4aa2ee22ad93aa1` em us-east-1b, Healthy, InService) |

> O ASG cobre duas AZs mas a instância foi provisionada em `us-east-1b`. Isso aconteceu porque o ASG escolhe a AZ com menor custo/carga no momento do launch.

---

## 7. Rede (VPC / Subnets)

### VPC

| Atributo | Valor |
|----------|-------|
| ID | `vpc-0d58780cd33b85a9c` |
| CIDR | `172.31.0.0/16` |
| Tipo | VPC padrão |

### Subnets Usadas pelo Cluster

| Subnet | AZ | CIDR | Auto-assign IP |
|--------|-----|------|----------------|
| `subnet-0f5924893a60e01b3` | `us-east-1a` | `172.31.0.0/20` | ✅ |
| `subnet-05c133d510483bfa2` | `us-east-1b` | `172.31.80.0/20` | ✅ |

---

## 8. Security Groups — Mapa de Conexões

### bia-web (sg-02644d8a3164e531b)

**Descrição:** Acesso Bia-Web  
**Associado a:** EC2 do cluster ECS (`i-0c4aa2ee22ad93aa1`)

| Direção | Protocolo | Porta | Origem/Destino | Descrição |
|---------|-----------|-------|----------------|-----------|
| **Inbound** | TCP | 80 | `0.0.0.0/0` | Acesso HTTP público |
| Outbound | All | All | `0.0.0.0/0` | — |

### bia-db (sg-096a1e8518c3a982c)

**Descrição:** Acesso bia-db  
**Associado a:** RDS PostgreSQL (`bia`)

| Direção | Protocolo | Porta | Origem/Destino | Descrição |
|---------|-----------|-------|----------------|-----------|
| **Inbound** | TCP | 5432 | `sg-09c9c321387767850` (bia-dev) | acesso vindo de bia-dev |
| **Inbound** | TCP | 5432 | `sg-02644d8a3164e531b` (bia-web) | Acessso vindo Bia-Web |
| Outbound | All | All | `0.0.0.0/0` | — |

### bia-dev (sg-09c9c321387767850)

**Descrição:** Acesso bia-dev  
**Associado a:** EC2 bia-dev (`i-0acb3c5f6cffe094e`)

| Direção | Protocolo | Porta | Origem/Destino | Descrição |
|---------|-----------|-------|----------------|-----------|
| **Inbound** | TCP | 3001 | `0.0.0.0/0` | App local (compose) |
| **Inbound** | TCP | 3002 | `0.0.0.0/0` | Container órfão |
| Outbound | All | All | `0.0.0.0/0` | — |

### Fluxo de Comunicação

```
Internet (0.0.0.0/0)
    │
    │ TCP 80 → bia-web
    ▼
EC2 ECS (52.87.247.22)
    │
    │ TCP 5432 → bia-db (origem: bia-web)
    ▼
RDS PostgreSQL (bia.co3qaww06tcz.us-east-1.rds.amazonaws.com)
    ▲
    │ TCP 5432 → bia-db (origem: bia-dev)
    │
EC2 bia-dev (13.219.239.172)
```

---

## 9. RDS PostgreSQL

| Atributo | Valor |
|----------|-------|
| Identifier | `bia` |
| Engine | PostgreSQL 18.3 |
| Classe | `db.t4g.micro` |
| Status | `available` |
| Endpoint | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` |
| Porta | 5432 |
| AZ | `us-east-1a` |
| Storage | 20 GB (gp2) |
| Encryption | ✅ habilitada |
| Multi-AZ | ❌ |
| Acesso público | ❌ |
| Backup | 0 dias (desabilitado) |
| Subnet Group | `default-vpc-0d58780cd33b85a9c` |
| Security Group | `bia-db` (sg-096a1e8518c3a982c) |

### Banco

| Atributo | Valor |
|----------|-------|
| Database | `bia` |
| Tabela principal | `Tarefas` |
| Schema | uuid (PK), titulo, dia_atividade, importante, createdAt, updatedAt |

---

## 10. ECR — Container Registry

| Atributo | Valor |
|----------|-------|
| URI | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia` |
| ARN | `arn:aws:ecr:us-east-1:328113723783:repository/bia` |
| Criado em | 2026-08-02 00:51:29 UTC |

### Imagens Disponíveis

| Tags | Push | Tamanho |
|------|------|---------|
| `latest`, `2e1b46e` | 2026-08-02 04:43:14 | 219.4 MB |
| `a35d585` | 2026-08-02 04:21:21 | 219.4 MB |
| `89f2ec3` | 2026-08-02 00:56:26 | 219.4 MB |

> **Em uso no ECS:** `bia:a35d585` (task-bia:5)  
> **Latest no ECR:** `bia:2e1b46e` (mais recente, ainda não deployada)

---

## 11. CloudWatch Logs

| Atributo | Valor |
|----------|-------|
| Log Group | `/ecs/task-bia` |
| Retenção | Sem expiração |
| Stored Bytes | 0 (recém criado) |
| Stream Prefix | `ecs` |

---

## 12. CloudFormation

| Atributo | Valor |
|----------|-------|
| Stack | `Infra-ECS-Cluster-cluster-bia-581e3f53` |
| Status | `CREATE_COMPLETE` |
| Criado em | 2026-08-02 02:05:51 UTC |
| Descrição | Template do console ECS para criar cluster |

### Parâmetros do Stack

| Parâmetro | Valor |
|-----------|-------|
| ECSClusterName | `cluster-bia` |
| VpcId | `vpc-0d58780cd33b85a9c` |
| SubnetIds | `subnet-0f5924893a60e01b3,subnet-05c133d510483bfa2` |
| SecurityGroupIds | `sg-02644d8a3164e531b` |
| Ec2InstanceProfileArn | `arn:aws:iam::328113723783:instance-profile/ecsInstanceRole` |
| LatestECSOptimizedAMI | `/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id` |

### Recursos Gerenciados pelo CloudFormation

- ECS Cluster (`cluster-bia`)
- Auto Scaling Group + Launch Template
- Capacity Provider (ASG)

---

## 13. IAM Roles

### ecsInstanceRole

**Associada a:** EC2 do cluster (via Instance Profile)  
**Permite:** A EC2 se registrar no cluster ECS, puxar imagens do ECR, enviar logs ao CloudWatch.

### ecsTaskExecutionRole

**Associada a:** Task Definition (execution role)  
**Permite:** Pull de imagens ECR, criação de log streams e envio de logs ao CloudWatch.

> ⚠️ Sem permissão de leitura IAM na `role-acesso-ssm` — policies exatas não puderam ser listadas, mas são as managed policies padrão da AWS (`AmazonEC2ContainerServiceforEC2Role` e `AmazonECSTaskExecutionRolePolicy`).

---

## 14. Fluxo de Deploy (CI/CD)

```
Git commit (bia-dev)
    │
    ▼
bia-deploy.sh (ou buildspec.yml via CodeBuild)
    │
    ├── docker build -t bia .
    ├── docker tag → ECR:latest + ECR:<commit-hash>
    ├── docker push → ECR
    │
    ▼
Registra nova Task Definition revision
    │
    ▼
aws ecs update-service → Rolling Update
    │
    ▼
ECS para task antiga → inicia nova task com nova imagem
    │
    ▼
Aplicação online com nova versão
```

---

## 15. Endpoints e Conectividade

| Serviço | Endpoint | Porta | Protocolo |
|---------|----------|-------|-----------|
| Aplicação (externa) | `http://52.87.247.22` | 80 | HTTP |
| API Versão | `http://52.87.247.22/api/versao` | 80 | HTTP |
| API Tarefas | `http://52.87.247.22/api/tarefas` | 80 | HTTP |
| RDS (interno) | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` | 5432 | TCP |
| ECR | `328113723783.dkr.ecr.us-east-1.amazonaws.com` | 443 | HTTPS |
| CloudWatch Logs | `logs.us-east-1.amazonaws.com` | 443 | HTTPS |

---

## 16. Observações e Desvios

| # | Item | Esperado | Atual | Impacto |
|---|------|----------|-------|---------|
| 1 | AZ da EC2 | `us-east-1a` | `us-east-1b` | Nenhum no Cenário 1 |
| 2 | Minimum Healthy % | 50% | 0% | Baixo (1 task) |
| 3 | Imagem em uso | `latest` | `a35d585` | OK — rastreável por commit |
| 4 | Task Def family | `task-def-bia` | `task-bia` | Sem prefixo `def` — diverge da convenção |
| 5 | Backup RDS | Habilitado | 0 dias | ⚠️ Sem backup |
| 6 | Container Insights | — | Desabilitado | Sem métricas de container |
| 7 | task-bia:6 mais recente | — | Não deployada | `latest` no ECR é `2e1b46e`, service usa `a35d585` |

---

## 17. Resumo de Recursos e IDs

| Recurso | Nome/ID |
|---------|---------|
| VPC | `vpc-0d58780cd33b85a9c` (172.31.0.0/16, default) |
| Subnet A | `subnet-0f5924893a60e01b3` (us-east-1a) |
| Subnet B | `subnet-05c133d510483bfa2` (us-east-1b) |
| SG bia-web | `sg-02644d8a3164e531b` |
| SG bia-db | `sg-096a1e8518c3a982c` |
| SG bia-dev | `sg-09c9c321387767850` |
| ECS Cluster | `cluster-bia` |
| ECS Service | `service-bia` |
| Task Definition | `task-bia:5` |
| EC2 ECS | `i-0c4aa2ee22ad93aa1` (52.87.247.22) |
| EC2 bia-dev | `i-0acb3c5f6cffe094e` (13.219.239.172) |
| RDS | `bia` (bia.co3qaww06tcz.us-east-1.rds.amazonaws.com) |
| ECR | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia` |
| ASG | `Infra-ECS-Cluster-cluster-bia-581e3f53-ECSAutoScalingGroup-VX1mts6Zyf02` |
| CloudFormation | `Infra-ECS-Cluster-cluster-bia-581e3f53` |
| Log Group | `/ecs/task-bia` |

---

*Documento gerado pelo agente Kiro-BIA em 02/08/2026.*
