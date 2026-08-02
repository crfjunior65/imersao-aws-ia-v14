# 📊 Relatório de Custos — Projeto BIA na AWS

> Análise gerada em 01/08/2026 | Região: us-east-1 (N. Virginia) | Conta: 328113723783

---

## 1. Estado Atual da Infraestrutura

Resultado da análise da conta AWS no momento da geração deste relatório:

| Recurso | Status | Observação |
|---|---|---|
| ECS Clusters | ❌ Nenhum | Nenhum cluster criado ainda |
| RDS | ⚠️ Sem permissão | `role-acesso-ssm` não tem `rds:DescribeDBInstances` |
| EC2 Running | ✅ 1 instância | `bia-dev` (t3.micro) em `us-east-1a` |
| ALB | ❌ Nenhum | Nenhum load balancer criado |
| ECR | ❌ Nenhum repositório | Repositório `bia` ainda não criado |
| ElastiCache | ⚠️ Sem permissão | `role-acesso-ssm` não tem permissão |
| VPC | ✅ 1 VPC padrão | `vpc-0d58780cd33b85a9c` — `172.31.0.0/16` |
| Subnets | ✅ 6 subnets | 1 por AZ (a, b, c, d, e, f) |
| Security Groups | ✅ 1 customizado | `bia-dev` já criado |

---

## 2. Estimativa de Custos por Cenário

Preços on-demand em us-east-1, sem Free Tier, calculados para 730h/mês (mês cheio).

### 💰 Cenário 1 — ECS sem ALB (ponto de partida)

```
Internet → EC2 t3.micro (ECS bridge) → RDS PostgreSQL t3.micro
```

| Recurso | Tipo | Qtd | Preço/hora | Preço/mês |
|---|---|---|---|---|
| EC2 (ECS cluster) | t3.micro | 1 | $0,0104 | **$7,59** |
| RDS PostgreSQL | db.t3.micro | 1 | $0,0180 | **$13,14** |
| RDS Storage | gp2 20 GB | 1 | — | **$2,30** |
| ECR | armazenamento ~500 MB | — | $0,10/GB | **$0,05** |
| Transferência de dados | saída estimada | — | — | **~$1,00** |
| **TOTAL CENÁRIO 1** | | | | **~$24/mês** |

---

### 💰 Cenário 2 — ECS com ALB (2 AZs)

```
Internet → ALB (bia-alb) → EC2 zona A + EC2 zona B (ECS bridge) → RDS PostgreSQL t3.micro
```

| Recurso | Tipo | Qtd | Preço/hora | Preço/mês |
|---|---|---|---|---|
| EC2 zona A (ECS) | t3.micro | 1 | $0,0104 | **$7,59** |
| EC2 zona B (ECS) | t3.micro | 1 | $0,0104 | **$7,59** |
| RDS PostgreSQL | db.t3.micro | 1 | $0,0180 | **$13,14** |
| RDS Storage | gp2 20 GB | 1 | — | **$2,30** |
| ALB | base | 1 | $0,0252 | **$18,40** |
| ALB LCU | estimativa baixo tráfego | — | $0,008/LCU-h | **~$2,00** |
| ECR | armazenamento ~500 MB | — | $0,10/GB | **$0,05** |
| Transferência de dados | saída estimada | — | — | **~$2,00** |
| **TOTAL CENÁRIO 2** | | | | **~$53/mês** |

---

### 💰 Cenário 3 — ECS com ALB + Cache (awsvpc + Cloud Map)

```
Internet → ALB (bia-alb) → EC2 t3.small zona A + zona B (ECS awsvpc)
                                ├── Task bia-app  (SG: bia-app, porta 8080)
                                └── Task bia-cache (SG: bia-cache, porta 6379)
                                        ↑ Cloud Map DNS interno
→ RDS PostgreSQL t3.micro
```

| Recurso | Tipo | Qtd | Preço/hora | Preço/mês |
|---|---|---|---|---|
| EC2 zona A (ECS) | t3.small | 1 | $0,0208 | **$15,18** |
| EC2 zona B (ECS) | t3.small | 1 | $0,0208 | **$15,18** |
| RDS PostgreSQL | db.t3.micro | 1 | $0,0180 | **$13,14** |
| RDS Storage | gp2 20 GB | 1 | — | **$2,30** |
| ALB | base | 1 | $0,0252 | **$18,40** |
| ALB LCU | estimativa baixo tráfego | — | $0,008/LCU-h | **~$2,00** |
| Cloud Map | operações DNS | — | $0,50/1M queries | **~$0,50** |
| ECR | armazenamento ~500 MB | — | $0,10/GB | **$0,05** |
| Transferência de dados | saída estimada | — | — | **~$2,00** |
| **TOTAL CENÁRIO 3** | | | | **~$69/mês** |

---

## 3. Visão Consolidada

```
Cenário 1 (sem ALB)        ~$24/mês   ████░░░░░░░░░░░░░░░░░
Cenário 2 (com ALB)        ~$53/mês   ████████████░░░░░░░░░
Cenário 3 (ALB + Cache)    ~$69/mês   ████████████████░░░░░
```

| | Cenário 1 | Cenário 2 | Cenário 3 |
|---|---|---|---|
| Custo mensal | ~$24 | ~$53 | ~$69 |
| Custo anual | ~$288 | ~$636 | ~$828 |
| Alta disponibilidade | ❌ | ✅ (2 AZs) | ✅ (2 AZs) |
| Cache | ❌ | ❌ | ✅ |
| Load Balancer | ❌ | ✅ | ✅ |
| Network Mode ECS | bridge | bridge | awsvpc |
| EC2 type | t3.micro | t3.micro | t3.small |

---

## 4. Custos Não Incluídos na Estimativa

Itens que podem compor o custo real mas não foram incluídos acima:

| Item | Custo estimado | Observação |
|---|---|---|
| EC2 `bia-dev` (t3.micro) | ~$7,59/mês | Ambiente de desenvolvimento, sempre rodando |
| IPv4 público por instância | ~$3,65/mês por IP | Cobrado desde fevereiro/2024 ($0,005/hora) |
| Backup RDS | Gratuito até 100% do storage | Acima disso: $0,095/GB/mês |
| CloudWatch Logs | Gratuito até 5 GB/mês | $0,50/GB após o limite |
| Route 53 (domínio customizado) | ~$0,50/hosted zone/mês | Somente se usar domínio próprio |
| NAT Gateway | ~$32/mês + tráfego | Somente se usar subnets privadas |

---

## 5. Otimizações de Custo Possíveis

### 5.1 Reserved Instances (compromisso de 1 ano, no upfront)

| Recurso | On-Demand/mês | Reserved/mês | Economia |
|---|---|---|---|
| EC2 t3.micro | $7,59 | ~$4,90 | ~35% |
| EC2 t3.small | $15,18 | ~$9,80 | ~35% |
| RDS db.t3.micro | $13,14 | ~$8,50 | ~35% |

> Com Reserved Instances aplicadas ao Cenário 2: **~$37/mês** (vs $53 on-demand)

### 5.2 Free Tier (contas novas — válido por 12 meses)

| Benefício | Impacto |
|---|---|
| 750h/mês EC2 t2/t3.micro | EC2 do cluster gratuita no Cenário 1 |
| 750h/mês RDS db.t2/t3.micro | RDS gratuito |
| 20 GB storage RDS | Storage gratuito |
| 500 MB/mês ECR | ECR gratuito |

> **Cenário 1 com Free Tier ativo → ~$0/mês nos primeiros 12 meses**

---

## 6. Observações sobre Permissões IAM

A `role-acesso-ssm` atual **não possui permissões** para os seguintes serviços, o que impediu a coleta de dados reais:

| Permissão ausente | Impacto |
|---|---|
| `rds:DescribeDBInstances` | Não foi possível confirmar se RDS já existe na conta |
| `elasticache:DescribeCacheClusters` | Não foi possível verificar clusters ElastiCache existentes |

Para adicionar capacidade de leitura/diagnóstico ao agente, sugerimos incluir uma policy inline com as permissões de leitura (`Describe*`, `List*`) para RDS e ElastiCache.

---

## 7. Recomendação para a Imersão

Para o contexto educacional da **Imersão AWS & IA**, a progressão recomendada é:

1. **Começar pelo Cenário 1** — custo mínimo (~$24/mês), sem ALB, foco em entender ECS + RDS
2. **Evoluir para o Cenário 2** — adicionar ALB e segunda AZ, aprender sobre Target Groups e alta disponibilidade
3. **Finalizar no Cenário 3** — introduzir cache como serviço ECS com Cloud Map, preparando para ElastiCache

> **Custo total estimado para rodar os 3 cenários durante 2 dias do evento:** menos de $5,00 (assumindo que cada cenário fica ativo por poucas horas).

---

*Relatório gerado automaticamente pelo agente Kiro-BIA em 01/08/2026.*
*Preços baseados em tabela on-demand us-east-1. Valores sujeitos a alteração pela AWS.*
