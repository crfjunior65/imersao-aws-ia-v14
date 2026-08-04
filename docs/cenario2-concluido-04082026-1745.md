# Cenário 2 — ECS com ALB + HTTPS — CONCLUÍDO ✅

> **Data de conclusão:** 04/08/2026 17:45 (BRT)  
> **Conta AWS:** 328113723783  
> **Região:** us-east-1  
> **URL de produção:** `https://bia.junior.tec.br`

---

## Resumo Executivo

O Cenário 2 do projeto BIA foi implementado com sucesso. A aplicação agora roda em **alta disponibilidade** com:

- **2 Availability Zones** (us-east-1a + us-east-1b)
- **Application Load Balancer** distribuindo tráfego
- **HTTPS** com certificado wildcard `*.junior.tec.br` (TLS 1.3)
- **Redirecionamento automático** HTTP → HTTPS (301)
- **Domínio customizado** cross-account com Route 53

---

## Arquitetura Final

```
          Usuário
            │
            ▼
   https://bia.junior.tec.br
            │
    ┌───────▼───────┐
    │  Route 53     │  (conta 275263720574)
    │  CNAME → ALB  │
    └───────┬───────┘
            │
    ┌───────▼───────┐
    │   bia-alb     │  SG: bia-alb (80→redirect, 443→forward)
    │   (ALB)       │  Cert: *.junior.tec.br (TLS 1.3)
    │  zona A + B   │
    └───────┬───────┘
            │
    ┌───────▼───────┐
    │   tg-alb      │  Target Group (instance, porta dinâmica)
    │  deregistration: 30s
    └───────┬───────┘
            │
      ┌─────┴─────┐
      ▼           ▼
  ┌───────┐   ┌───────┐
  │ EC2-A │   │ EC2-B │   SG: bia-ec2 (All TCP de bia-alb)
  │ t3.mi │   │ t3.mi │   ECS Agent → cluster-bia
  │ :32768│   │ :32768│   task-bia-alb:2
  └───┬───┘   └───┬───┘
      │           │
      ▼           ▼
  ┌─────────────────┐
  │   RDS (bia)     │  SG: bia-db (5432 de bia-ec2)
  │  PostgreSQL 16  │
  └─────────────────┘
```

---

## Inventário de Recursos

### Rede e Balanceamento

| Recurso | Nome | ID / ARN |
|---------|------|----------|
| ALB | `bia-alb` | `arn:...loadbalancer/app/bia-alb/7b50f4659a29896e` |
| Listener HTTPS | porta 443 | `arn:...listener/.../46a523c1de5b8b60` |
| Listener HTTP | porta 80 (redirect) | `arn:...listener/.../ff217fe019836438` |
| Target Group | `tg-alb` | `arn:...targetgroup/tg-alb/2e74c0b6377e4904` |
| Certificado ACM | `*.junior.tec.br` | `arn:aws:acm:us-east-1:328113723783:certificate/c65f9f38-ab90-43b7-a677-2a9b5d33e668` |

### Computação (ECS)

| Recurso | Nome | Detalhe |
|---------|------|---------|
| Cluster | `cluster-bia` | ACTIVE, 2 container instances |
| Service | `service-bia-alb` | Running 2/2, steady state |
| Task Definition | `task-bia-alb:2` | bridge, EC2, porta 0→8080 |
| EC2 zona A | `i-07919041f2be4afb8` | t3.micro, us-east-1a |
| EC2 zona B | `i-06e93f03278c4ccdc` | t3.micro, us-east-1b |
| ASG | `Infra-ECS-...-VX1mts6Zyf02` | min=2, max=2, desired=2 |
| Launch Template | `lt-0e9074274a3baea81` v2 | SG bia-ec2, ECS-optimized AMI |

### Security Groups

| Nome | ID | Inbound | Outbound |
|------|----|---------|----------|
| `bia-alb` | sg-0b71ec6df73add1d0 | 80+443 de 0.0.0.0/0 | All |
| `bia-ec2` | sg-02a4f839749673f09 | All TCP de bia-alb | 0.0.0.0/0 |
| `bia-db` | sg-096a1e8518c3a982c | 5432 de bia-dev, bia-web, bia-ec2 | All |

### DNS e Certificado (Cross-Account)

| Item | Conta | Valor |
|------|-------|-------|
| Hosted Zone `junior.tec.br` | 275263720574 | Route 53 |
| Registro `bia.junior.tec.br` | 275263720574 | CNAME → ALB DNS |
| CNAME validação ACM | 275263720574 | `_56f53f6...junior.tec.br` |
| Certificado ACM `*.junior.tec.br` | 328113723783 | ISSUED |

---

## Configuração do Deploy

| Parâmetro | Valor |
|-----------|-------|
| Imagem ECR | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:2e1b46e` |
| VITE_API_URL (build) | `https://bia.junior.tec.br` |
| Deploy strategy | Rolling Update (max 200%, min 100%) |
| Placement | spread por AZ + instanceId |
| Deregistration delay | 30s |
| Health check path | `/` |
| SSL Policy | ELBSecurityPolicy-TLS13-1-2-2021-06 |

---

## Testes Realizados

| Teste | Comando | Resultado |
|-------|---------|-----------|
| HTTPS API | `curl https://bia.junior.tec.br/api/versao` | `Bia 4.3.0` ✅ |
| HTTPS + RDS | `curl https://bia.junior.tec.br/api/tarefas` | 6 tarefas, 57ms ✅ |
| Redirect HTTP→HTTPS | `curl -I http://bia.junior.tec.br` | 301 → HTTPS ✅ |
| Frontend | `curl https://bia.junior.tec.br/` | HTTP 200, 840 bytes ✅ |
| TLS Version | curl verbose | TLSv1.3 ✅ |
| Certificado | curl verbose | CN=*.junior.tec.br, Amazon RSA 2048 M04 ✅ |
| Targets healthy | describe-target-health | 2/2 healthy ✅ |
| Balanceamento AZ | ALB + placement spread | zona A + zona B ✅ |

---

## Problemas Resolvidos Durante Implementação

| # | Problema | Solução |
|---|----------|---------|
| 1 | ASG com capacidade 0 | Aumentado para min=2, max=2, desired=2 |
| 2 | SG bia-ec2 sem inbound | Adicionado All TCP de bia-alb |
| 3 | SG bia-ec2 outbound restritivo | Corrigido para 0.0.0.0/0 |
| 4 | Launch Template com SG errado (bia-web) | Criada versão 2 com SG bia-ec2 |
| 5 | ASG fixado em LT v1 | Atualizado para LT v2 |
| 6 | Certificado ACM em outra conta | Solicitado novo na conta BIA + validação DNS cross-account |
| 7 | Sem listener HTTPS | Criado listener 443 com TLS 1.3 |
| 8 | HTTP sem redirect | Listener 80 alterado para redirect 301 → HTTPS |

---

## Runbooks Gerados

| Arquivo | Descrição |
|---------|-----------|
| `docs/analise-cenario2-alb-04082026-1622.md` | Análise detalhada do ambiente antes das correções |
| `docs/runbook-cenario2-alb-04082026-1622.md` | Passo a passo para corrigir SGs, LT, ASG e validar |
| `docs/runbook-https-acm-crossaccount-04082026-1734.md` | Procedimento HTTPS com ACM cross-account |
| `docs/cenario2-concluido-04082026-1745.md` | Este documento (estado final) |

---

## Evolução — Próximos Passos

O Cenário 2 está completo. As evoluções possíveis são:

### Cenário 3 — ECS com ALB + Cache (awsvpc)
- Network mode `awsvpc` (ENI por task)
- Redis/Valkey como ECS Service com Service Discovery (Cloud Map)
- EC2 t3.small (mais ENIs)
- SGs: bia-cluster, bia-app, bia-cache

### Melhorias opcionais no Cenário 2
- Health check path `/api/versao` (mais preciso)
- Deploy config 100/50 (padrão do projeto)
- Renomear TG `tg-alb` → `tg-bia-alb` (nomenclatura)
- CI/CD via CodePipeline (deploy automático no push)
