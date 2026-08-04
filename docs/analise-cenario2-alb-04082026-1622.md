# Análise do Ambiente AWS — Cenário 2 (ECS com ALB)

> **Data da análise:** 04/08/2026 16:10 (BRT)  
> **Conta AWS:** 328113723783  
> **Região:** us-east-1  
> **Objetivo:** ECS com Application Load Balancer em alta disponibilidade (zona A + zona B)

---

## 1. Visão Geral do Cenário 2

O Cenário 2 evolui o deploy da BIA para incluir um **Application Load Balancer (ALB)** distribuindo tráfego entre instâncias EC2 em **duas Availability Zones** (us-east-1a e us-east-1b), garantindo alta disponibilidade.

### Arquitetura Esperada

```
Internet
    │
    ▼
┌──────────────┐
│  bia-alb     │  ← SG: bia-alb (80/443 de 0.0.0.0/0)
│  (ALB)       │
│  zona A + B  │
└──────┬───────┘
       │
┌──────▼───────┐
│  tg-bia-alb  │  ← Target Group tipo instance, porta dinâmica
└──────┬───────┘
       │
  ┌────┴────┐
  ▼         ▼
┌─────┐  ┌─────┐
│EC2-A│  │EC2-B│  ← SG: bia-ec2 (All TCP de bia-alb)
│zona │  │zona │
│ A   │  │  B  │
└──┬──┘  └──┬──┘
   │        │
   ▼        ▼
┌──────────────┐
│  RDS (bia)   │  ← SG: bia-db (5432 de bia-ec2)
│  PostgreSQL  │
└──────────────┘
```

---

## 2. Recursos Criados (Estado Atual)

### 2.1 Application Load Balancer ✅

| Atributo | Valor |
|----------|-------|
| Nome | `bia-alb` |
| DNS | `bia-alb-1140832221.us-east-1.elb.amazonaws.com` |
| Tipo | Application (internet-facing) |
| VPC | `vpc-0d58780cd33b85a9c` |
| Zonas | `us-east-1a` (subnet-0f5924893a60e01b3) + `us-east-1b` (subnet-05c133d510483bfa2) |
| Security Group | `bia-alb` (sg-0b71ec6df73add1d0) |
| Estado | ✅ ACTIVE |
| Criado em | 04/08/2026 18:17 UTC |

**Veredicto:** ✅ Criado corretamente nas duas zonas.

---

### 2.2 Listener ✅

| Atributo | Valor |
|----------|-------|
| Porta | 80 (HTTP) |
| Ação | Forward para `tg-alb` |
| Protocolo | HTTP |

**Veredicto:** ✅ OK — Listener na porta 80 encaminhando para o Target Group.

---

### 2.3 Target Group ⚠️

| Atributo | Valor | Esperado | Status |
|----------|-------|----------|--------|
| Nome | `tg-alb` | `tg-bia-alb` | ⚠️ Fora do padrão |
| Tipo | instance | instance | ✅ |
| Protocolo | HTTP | HTTP | ✅ |
| Porta | 80 | 80 | ✅ |
| Health Check Path | `/` | `/api/versao` | ⚠️ Recomendado alterar |
| Deregistration Delay | 30s | 30s | ✅ |
| Targets registrados | 0 | 2 | 🔴 Sem targets |

**Problemas encontrados:**
1. **Nome fora do padrão** — deveria ser `tg-bia-alb` (não é bloqueante, apenas nomenclatura)
2. **Health check na raiz** — o frontend pode responder 200 mas não garante que o backend está funcional. Recomendado usar `/api/versao` que é leve e não acessa banco
3. **Sem targets** — não há instâncias EC2 registradas

---

### 2.4 Security Groups

#### SG `bia-alb` (sg-0b71ec6df73add1d0) ✅

| Direção | Porta | Protocolo | Source | Descrição |
|---------|-------|-----------|--------|-----------|
| Inbound | 80 | TCP | 0.0.0.0/0 | HTTP All Access |
| Inbound | 443 | TCP | 0.0.0.0/0 | HTTPS All Access |
| Outbound | All | All | 0.0.0.0/0 | — |

**Veredicto:** ✅ Correto conforme regras do projeto.

---

#### SG `bia-ec2` (sg-02a4f839749673f09) 🔴 PROBLEMAS CRÍTICOS

| Direção | Porta | Source | Descrição |
|---------|-------|--------|-----------|
| Inbound | — | — | **VAZIO** 🔴 |
| Outbound | All | `bia-alb` (sg-0b71ec6df73add1d0) | Allow bia-alb |

**Problemas encontrados:**

1. 🔴 **Inbound VAZIO** — O ALB não consegue enviar tráfego para as EC2.
   - **Esperado:** All TCP de `bia-alb` (o ECS usa portas dinâmicas no modo bridge com hostPort=0)

2. 🔴 **Outbound restritivo** — Permite tráfego APENAS para o SG `bia-alb`. Isso impede:
   - Download de imagens do ECR
   - Comunicação com o ECS Agent (endpoint ECS)
   - Conexão com o RDS (porta 5432)
   - Qualquer saída para internet (atualizações, logs)
   - **Esperado:** `0.0.0.0/0` (All traffic)

---

#### SG `bia-db` (sg-096a1e8518c3a982c) ✅

| Direção | Porta | Source | Descrição |
|---------|-------|--------|-----------|
| Inbound | 5432 | `bia-dev` (sg-09c9c321387767850) | acesso vindo de bia-dev |
| Inbound | 5432 | `bia-web` (sg-02644d8a3164e531b) | Acessso vindo Bia-Web |
| Inbound | 5432 | `bia-ec2` (sg-02a4f839749673f09) | Acesso Vindo Cluster bia-ec2 |
| Outbound | All | 0.0.0.0/0 | — |

**Veredicto:** ✅ Correto — já permite acesso do `bia-ec2` na porta 5432.

---

### 2.5 ECS Cluster

| Atributo | Valor |
|----------|-------|
| Nome | `cluster-bia` |
| Status | ACTIVE |
| Container Instances | **0** 🔴 |
| Running Tasks | 0 |
| Active Services | 2 (service-bia + service-bia-alb) |
| Capacity Provider | ASG-based (`Infra-ECS-Cluster-cluster-bia-...`) |

**Observação:** O projeto previa um cluster separado `cluster-bia-alb` para o Cenário 2, mas o service foi criado dentro do `cluster-bia` existente. Isso não é bloqueante — pode funcionar, desde que haja EC2 no cluster.

---

### 2.6 Auto Scaling Group 🔴 PROBLEMA CRÍTICO

| Atributo | Valor | Esperado |
|----------|-------|----------|
| Nome | `Infra-ECS-Cluster-cluster-bia-...-ECSAutoScalingGroup-...` | — |
| Min Size | **0** | 2 |
| Max Size | **0** | 2 |
| Desired | **0** | 2 |
| AZs | us-east-1a, us-east-1b | ✅ |
| Subnets | subnet zona A + subnet zona B | ✅ |
| Instâncias ativas | 0 | 2 |

**Problema:** O ASG está com capacidade **zerada**. Nenhuma EC2 está sendo lançada para o cluster. Este é o principal motivo do service `service-bia-alb` não conseguir colocar tasks.

---

### 2.7 Launch Template ⚠️

| Atributo | Valor | Esperado |
|----------|-------|----------|
| ID | `lt-0e9074274a3baea81` | — |
| Tipo instância | `t3.micro` | ✅ |
| AMI | `ami-0b416d150bdde5ea2` (ECS-optimized) | ✅ |
| IAM Profile | `ecsInstanceRole` | ✅ |
| Security Group | **`bia-web`** (sg-02644d8a3164e531b) | 🔴 Deveria ser `bia-ec2` |
| User Data | `ECS_CLUSTER=cluster-bia` | ✅ |

**Problema:** O Launch Template está usando o SG **`bia-web`** (do Cenário 1) em vez do **`bia-ec2`** (criado para o Cenário 2). Se o ASG subir EC2 com esse template, as instâncias ficarão no SG errado.

---

### 2.8 Task Definition `task-bia-alb:1` ✅

| Atributo | Valor |
|----------|-------|
| Family | `task-bia-alb` |
| Revision | 1 |
| Network Mode | bridge ✅ |
| Compatibilidade | EC2 ✅ |
| Execution Role | `ecsTaskExecutionRole` ✅ |
| Container Name | `bia` |
| Imagem | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:2e1b46e` |
| CPU | 1024 |
| Memory (soft) | 400 MB |
| Port Mapping | **0 → 8080** (host dinâmico) ✅ |
| Logs | `/ecs/task-bia-alb` (CloudWatch) ✅ |
| Environment | DB_USER, DB_PWD, DB_HOST, DB_PORT, VERSAO_API ✅ |

**Veredicto:** ✅ Task definition correta para o cenário com ALB (porta dinâmica 0→8080).

---

### 2.9 ECS Service `service-bia-alb` ⚠️

| Atributo | Valor | Esperado | Status |
|----------|-------|----------|--------|
| Cluster | `cluster-bia` | `cluster-bia-alb` | ⚠️ Aceitável |
| Task Definition | `task-bia-alb:1` | — | ✅ |
| Desired Count | 2 | 2 | ✅ |
| Running Count | **0** | 2 | 🔴 |
| Load Balancer | `tg-alb` porta 8080 | — | ✅ |
| Max Percent | 200 | 100 | ⚠️ Diferente do padrão |
| Min Healthy | 100 | 50 | ⚠️ Diferente do padrão |
| Failed Tasks | **208** | 0 | 🔴 |
| Placement | spread por AZ + instanceId | — | ✅ |

**Problemas:**
1. 🔴 **208 tasks falharam** — todas por falta de EC2 no cluster
2. ⚠️ **Deploy config** diferente do padrão (200/100 vs 100/50)

---

## 3. Resumo dos Problemas por Severidade

### 🔴 Críticos (Impedem o funcionamento)

| # | Problema | Impacto |
|---|----------|---------|
| 1 | **ASG com min/max/desired = 0** | Nenhuma EC2 no cluster, tasks não executam |
| 2 | **SG bia-ec2 sem inbound** | ALB não consegue rotear tráfego para as EC2 |
| 3 | **SG bia-ec2 outbound restritivo** | EC2 não baixa imagens, não acessa RDS, ECS Agent falha |
| 4 | **Launch Template com SG errado** | Novas EC2 usarão bia-web em vez de bia-ec2 |

### ⚠️ Médios (Funcionam mas fora do padrão)

| # | Problema | Impacto |
|---|----------|---------|
| 5 | Target Group nomeado `tg-alb` (esperado `tg-bia-alb`) | Apenas nomenclatura |
| 6 | Health check path é `/` (recomendado `/api/versao`) | Pode dar falso-positivo |
| 7 | Deploy config 200/100 (padrão do projeto é 100/50) | Comportamento de deploy diferente |
| 8 | Service no `cluster-bia` (padrão seria `cluster-bia-alb`) | Apenas organização |

---

## 4. Fluxo de Correção (Ordem)

```
1. Corrigir SG bia-ec2 (inbound + outbound)
       │
       ▼
2. Corrigir Launch Template (SG → bia-ec2)
       │
       ▼
3. Aumentar ASG (desired=2, max=2)
       │
       ▼
4. Aguardar EC2 registrarem no cluster
       │
       ▼
5. Verificar tasks rodando + targets healthy no TG
       │
       ▼
6. Testar acesso via DNS do ALB
       │
       ▼
7. (Opcional) Ajustar health check e deploy config
```

---

## 5. Referência de IDs

| Recurso | Nome | ID |
|---------|------|----|
| VPC | padrão | vpc-0d58780cd33b85a9c |
| Subnet zona A | us-east-1a | subnet-0f5924893a60e01b3 |
| Subnet zona B | us-east-1b | subnet-05c133d510483bfa2 |
| ALB | bia-alb | arn:...loadbalancer/app/bia-alb/7b50f4659a29896e |
| Target Group | tg-alb | arn:...targetgroup/tg-alb/2e74c0b6377e4904 |
| SG bia-alb | — | sg-0b71ec6df73add1d0 |
| SG bia-ec2 | — | sg-02a4f839749673f09 |
| SG bia-db | — | sg-096a1e8518c3a982c |
| SG bia-web | — | sg-02644d8a3164e531b |
| SG bia-dev | — | sg-09c9c321387767850 |
| Cluster | cluster-bia | arn:...cluster/cluster-bia |
| ASG | Infra-ECS-...-VX1mts6Zyf02 | — |
| Launch Template | ECSLaunchTemplate_tCEKYewayvkD | lt-0e9074274a3baea81 |
| Task Definition | task-bia-alb:1 | — |
| Service | service-bia-alb | — |
| ECR | bia | 328113723783.dkr.ecr.us-east-1.amazonaws.com/bia |
| RDS | bia | bia.co3qaww06tcz.us-east-1.rds.amazonaws.com |

---

## 6. Conclusão

A infraestrutura do Cenário 2 está **parcialmente criada**. Os componentes de rede (ALB, Listener, Target Group) e aplicação (Task Definition, Service) estão corretos na essência, mas os **Security Groups e a capacidade computacional** impedem o funcionamento.

O principal bloqueio é a combinação do ASG zerado + SG `bia-ec2` mal configurado. Após corrigir esses 4 problemas críticos, o ambiente deve subir e funcionar via `http://bia-alb-1140832221.us-east-1.elb.amazonaws.com`.

Consulte o **runbook** `docs/runbook-cenario2-alb-04082026-1622.md` para o passo a passo de correção.
