# Projeto BIA — Formação AWS & IA

> **Atividade de solidificação de conhecimento** após a Imersão AWS & IA (01-02/08/2026)  
> **Objetivo:** Aplicar na prática os conceitos aprendidos, evoluindo a infraestrutura do zero até um ambiente produtivo com CI/CD  
> **Aluno:** Carlos Roberto (crfjunior65)

### 🛠️ Tecnologias & Serviços

![Node.js](https://img.shields.io/badge/Node.js-24.x-339933?style=flat-square&logo=node.js&logoColor=white)
![Express](https://img.shields.io/badge/Express-4.17-000000?style=flat-square&logo=express&logoColor=white)
![React](https://img.shields.io/badge/React-17-61DAFB?style=flat-square&logo=react&logoColor=black)
![Vite](https://img.shields.io/badge/Vite-Build-646CFF?style=flat-square&logo=vite&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.3-4169E1?style=flat-square&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis/Valkey-8.1-DC382D?style=flat-square&logo=redis&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?style=flat-square&logo=docker&logoColor=white)
![Sequelize](https://img.shields.io/badge/Sequelize-6.6-52B0E7?style=flat-square&logo=sequelize&logoColor=white)

![AWS ECS](https://img.shields.io/badge/AWS-ECS-FF9900?style=flat-square&logo=amazon-ecs&logoColor=white)
![AWS EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=flat-square&logo=amazon-ec2&logoColor=white)
![AWS ALB](https://img.shields.io/badge/AWS-ALB-FF9900?style=flat-square&logo=amazon-aws&logoColor=white)
![AWS RDS](https://img.shields.io/badge/AWS-RDS-527FFF?style=flat-square&logo=amazon-rds&logoColor=white)
![AWS ECR](https://img.shields.io/badge/AWS-ECR-FF9900?style=flat-square&logo=amazon-aws&logoColor=white)
![AWS CodePipeline](https://img.shields.io/badge/AWS-CodePipeline-FF9900?style=flat-square&logo=amazon-aws&logoColor=white)
![AWS CodeBuild](https://img.shields.io/badge/AWS-CodeBuild-FF9900?style=flat-square&logo=amazon-aws&logoColor=white)
![AWS ACM](https://img.shields.io/badge/AWS-ACM_(TLS_1.3)-FF9900?style=flat-square&logo=amazon-aws&logoColor=white)
![AWS Route53](https://img.shields.io/badge/AWS-Route_53-8C4FFF?style=flat-square&logo=amazon-route-53&logoColor=white)
![AWS CloudWatch](https://img.shields.io/badge/AWS-CloudWatch-FF4F8B?style=flat-square&logo=amazon-cloudwatch&logoColor=white)
![AWS IAM](https://img.shields.io/badge/AWS-IAM-DD344C?style=flat-square&logo=amazon-aws&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-CI/CD_Trigger-181717?style=flat-square&logo=github&logoColor=white)

![Kiro](https://img.shields.io/badge/Kiro-AI_Agent-4A90D9?style=flat-square&logo=amazonaws&logoColor=white)
![MCP](https://img.shields.io/badge/MCP-Model_Context_Protocol-8B5CF6?style=flat-square&logo=openai&logoColor=white)
![AI Agents](https://img.shields.io/badge/AI_Agents-DevOps_%26_Cloud-10B981?style=flat-square&logo=robot-framework&logoColor=white)
![AI-Ops](https://img.shields.io/badge/AI--Ops-Infrastructure_as_Conversation-F59E0B?style=flat-square&logo=chatbot&logoColor=white)

---

## 🎯 O que foi implementado

Partindo de uma aplicação rodando localmente via Docker Compose, evoluí a infraestrutura progressivamente até alcançar um ambiente de produção com alta disponibilidade, HTTPS e deploy automatizado.

### Cenários concluídos

| Cenário | Descrição | Status |
|---------|-----------|--------|
| 1 | ECS com EC2 única (sem ALB) | ✅ Concluído |
| 2 | ECS com ALB em 2 AZs + HTTPS | ✅ Concluído |
| CI/CD | Pipeline GitHub → CodePipeline → ECS | ✅ Concluído |
| 3 | ECS com ALB + Cache (awsvpc) | 🔲 Próximo |

---

## 🏗️ Arquitetura Final (Cenário 2 + CI/CD)

```
     git push (main)
          │
          ▼ webhook
     CodePipeline → CodeBuild → ECR → ECS Deploy
                                         │
                                         ▼
     https://bia.junior.tec.br
          │
          ▼
     ┌──────────┐
     │ ALB      │  TLS 1.3 (*.junior.tec.br)
     │ zona A+B │  HTTP 80 → redirect HTTPS 443
     └────┬─────┘
          │
     ┌────┴────┐
     ▼         ▼
   EC2-A     EC2-B     (t3.micro, ECS Agent)
   task      task      (task-bia-alb, bridge mode)
     │         │
     ▼         ▼
   ┌─────────────┐
   │  RDS (PG)   │  PostgreSQL 18.3
   └─────────────┘
```

---

## 🚀 Como fazer deploy

Basta fazer push na branch `main`:

```bash
git add .
git commit -m "feat: minha alteração"
git push origin main
```

O pipeline dispara automaticamente e em ~6 minutos a nova versão está no ar.

### Acompanhar o pipeline

```bash
aws codepipeline get-pipeline-state --name pipeline-bia --region us-east-1 \
  --query 'stageStates[].{Stage:stageName,Status:latestExecution.status}'
```

---

## 🛠️ Rodando localmente

### Pré-requisitos
- Docker + Docker Compose
- Node.js 24.x (opcional, para dev sem Docker)

### Subir com Docker Compose

```bash
docker compose up -d
```

A aplicação estará disponível em `http://localhost:3001`.

### Rodar migrations

```bash
docker compose exec server bash -c 'npx sequelize db:migrate'
```

---

## 📁 Estrutura do Projeto

```
/bia
├── api/                    # Controllers, routes e models (Express + Sequelize)
├── client/                 # Frontend React + Vite
├── config/                 # Configuração do Express e conexão com banco
├── database/               # Migrations do Sequelize
├── docs/                   # Documentação, análises e runbooks
├── lib/                    # Módulos auxiliares (boot, cache)
├── scripts/                # Scripts de deploy, setup e utilitários
├── tests/                  # Testes unitários (Jest)
├── .kiro/                  # Configurações do Kiro (agentes, rules, MCP)
├── buildspec.yml           # Build spec do CodeBuild (CI/CD)
├── compose.yml             # Docker Compose (dev local)
├── Dockerfile              # Imagem de produção (Node + Vite build)
├── bia-deploy.sh           # Script interativo de deploy manual
└── package.json            # Dependências Node.js
```

---

## 🌐 URLs e Endpoints

| Ambiente | URL |
|----------|-----|
| Produção (ALB) | `https://bia.junior.tec.br` |
| Local (Docker) | `http://localhost:3001` |

### Rotas da API

| Rota | Método | Descrição |
|------|--------|-----------|
| `/api/versao` | GET | Versão da aplicação (não usa banco) |
| `/api/tarefas` | GET | Listar todas as tarefas |
| `/api/tarefas` | POST | Criar tarefa |
| `/api/tarefas/:uuid` | GET | Buscar tarefa por UUID |
| `/api/tarefas/:uuid` | DELETE | Deletar tarefa |
| `/api/tarefas/update_priority/:uuid` | PUT | Atualizar prioridade |
| `/api/cache-config` | GET | Status do cache Redis |

---

## ☁️ Recursos AWS Utilizados

| Serviço | Recurso | Função |
|---------|---------|--------|
| **ECS** | cluster-bia | Orquestração de containers |
| **EC2** | 2x t3.micro (ASG) | Hosts para tasks ECS |
| **ECR** | bia | Registry de imagens Docker |
| **ALB** | bia-alb | Load balancing + TLS termination |
| **RDS** | PostgreSQL 18.3 | Banco de dados |
| **ACM** | *.junior.tec.br | Certificado SSL wildcard |
| **Route 53** | bia.junior.tec.br | DNS (cross-account) |
| **CodePipeline** | pipeline-bia | Orquestração CI/CD |
| **CodeBuild** | codebuild-bia | Build Docker + push ECR |
| **CodeConnections** | GitHub-Bia | Integração GitHub → AWS |
| **S3** | codepipeline-us-east-1-* | Artefatos do pipeline |
| **CloudWatch** | /ecs/task-bia-alb | Logs da aplicação |
| **IAM** | Roles diversos | Permissões (least privilege) |

---

## 💰 Gestão de Custos

### Parar o ambiente (economizar quando não estiver usando)

```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "Infra-ECS-Cluster-cluster-bia-581e3f53-ECSAutoScalingGroup-VX1mts6Zyf02" \
  --min-size 0 --max-size 0 --desired-capacity 0 --region us-east-1
```

### Religar o ambiente

```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "Infra-ECS-Cluster-cluster-bia-581e3f53-ECSAutoScalingGroup-VX1mts6Zyf02" \
  --min-size 2 --max-size 2 --desired-capacity 2 --region us-east-1
```

---

## 📚 Documentação Detalhada

Todos os runbooks e análises estão na pasta `docs/`:

| Arquivo | Descrição |
|---------|-----------|
| [analise-projeto-04082026-1851.md](docs/analise-projeto-04082026-1851.md) | Análise consolidada do ambiente |
| [cenario2-concluido-04082026-1745.md](docs/cenario2-concluido-04082026-1745.md) | Cenário 2 concluído |
| [runbook-cenario2-alb-04082026-1622.md](docs/runbook-cenario2-alb-04082026-1622.md) | Runbook ECS + ALB |
| [runbook-https-acm-crossaccount-04082026-1734.md](docs/runbook-https-acm-crossaccount-04082026-1734.md) | Runbook HTTPS cross-account |
| [runbook-pipeline-cicd-04082026-1800.md](docs/runbook-pipeline-cicd-04082026-1800.md) | Runbook CI/CD Pipeline |
| [runbook-cenario1-ecs.md](docs/runbook-cenario1-ecs.md) | Runbook Cenário 1 (original) |
| [projeto-bia.md](docs/projeto-bia.md) | Documentação base do projeto |

---

## 🧠 Conceitos Praticados

- **ECS com EC2 launch type** — cluster, task definitions, services, rolling updates
- **Networking** — VPC, subnets, security groups (referência entre SGs)
- **Load Balancing** — ALB, target groups, listeners, health checks, portas dinâmicas
- **Alta Disponibilidade** — Multi-AZ, ASG, placement strategy spread
- **TLS/HTTPS** — ACM certificates, TLS termination no ALB, redirect HTTP→HTTPS
- **Cross-Account** — DNS em conta separada, validação de certificado via CNAME
- **CI/CD** — CodePipeline, CodeBuild, CodeConnections (GitHub webhook)
- **IAM** — Roles com least privilege, trust policies, PassRole
- **Docker** — Multi-stage builds, ECR, image tagging com commit hash
- **Infraestrutura como evolução** — do simples ao complexo, passo a passo
- **AI-Ops (Infraestrutura como Conversa)** — construção e troubleshooting da infra usando agentes de IA
- **Kiro + Agentes customizados** — criação de agentes especializados (DevOps, Cloud AWS) com regras e contexto do projeto
- **MCP (Model Context Protocol)** — integração de agentes com AWS CLI, ECS, IAM, banco de dados via MCP servers

---

## 📎 Referências

- **Evento:** [Imersão AWS & IA](https://org.imersaoaws.com.br/github/readme) — 01/08 e 02/08/2026
- **Instrutor:** Henrylle Maia (@henryllemaia)
- **Projeto original:** [github.com/henrylle/bia](https://github.com/henrylle/bia)
- **Meu fork:** [github.com/crfjunior65/imersao-aws-ia-v14](https://github.com/crfjunior65/imersao-aws-ia-v14)
