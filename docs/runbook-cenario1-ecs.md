# Runbook — Cenário 1: BIA no ECS sem ALB

> Gerado em 02/08/2026 | Região: us-east-1 | Conta: 328113723783  
> Nível: Iniciante | Objetivo: Subir a aplicação BIA no ECS com EC2, sem Load Balancer

---

## Visão Geral

Neste cenário vamos colocar a aplicação BIA rodando dentro do **Amazon ECS** usando uma instância **EC2 t3.micro**. O acesso externo será feito diretamente pelo IP público da EC2 na porta mapeada pelo ECS (modo bridge).

```
Internet
    │
    ▼
EC2 t3.micro (us-east-1a)
  Security Group: bia-web
  ECS Cluster: cluster-bia
    │
    ▼
  ECS Task (bridge mode)
    Container: bia (porta 8080)
    Task Definition: task-def-bia
    Service: service-bia
    │
    ▼
  RDS PostgreSQL (bia.co3qaww06tcz.us-east-1.rds.amazonaws.com)
  Security Group: bia-db
```

---

## Inventário da Infraestrutura Existente

Recursos já criados e disponíveis na conta antes deste runbook:

| Recurso | Nome/ID | Status |
|---|---|---|
| VPC padrão | `vpc-0d58780cd33b85a9c` | ✅ Existe |
| Subnet zona A | `subnet-0f5924893a60e01b3` | ✅ Existe |
| Security Group | `bia-dev` (`sg-09c9c321387767850`) | ✅ Existe |
| Security Group | `bia-db` (`sg-096a1e8518c3a982c`) | ✅ Existe |
| Security Group | `bia-web` (`sg-02644d8a3164e531b`) | ✅ Existe |
| IAM Instance Profile | `role-acesso-ssm` | ✅ Existe |
| ECR Repositório | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia` | ✅ Existe |
| Imagem ECR | `latest` / `89f2ec3` | ✅ Existe |
| RDS PostgreSQL | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` | ✅ Existe |
| AMI Amazon Linux 2023 | `ami-0006118602dfc1c09` | ✅ Disponível |

---

## Recursos que Serão Criados

| # | Recurso | Nome | Descrição |
|---|---|---|---|
| 1 | Security Group (regra) | `bia-web` | Liberar porta da task para internet |
| 2 | Security Group (regra) | `bia-db` | Liberar porta 5432 de bia-web |
| 3 | ECS Cluster | `cluster-bia` | Cluster que vai hospedar as tasks |
| 4 | EC2 Instance | `bia-ec2-zona-a` | Instância que entra no cluster ECS |
| 5 | ECS Task Definition | `task-def-bia` | Especificação do container BIA |
| 6 | ECS Service | `service-bia` | Mantém a task rodando continuamente |

---

## Pré-requisitos

Antes de executar este runbook, confirme:

- [x] Imagem Docker publicada no ECR (`328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:latest`)
- [x] RDS PostgreSQL criado e acessível (`bia.co3qaww06tcz.us-east-1.rds.amazonaws.com`)
- [x] Banco `bia` criado e migrations executadas
- [x] Security Group `bia-web` criado
- [x] Security Group `bia-db` criado
- [x] IAM Instance Profile `role-acesso-ssm` disponível

---

## Recurso 1 — Security Group: bia-web (regras)

### O que é

O `bia-web` é o Security Group associado à EC2 do cluster ECS no Cenário 1. Ele controla quem pode acessar a instância pela internet.

### Por que é necessário

No modo `bridge` do ECS, as tasks recebem uma porta aleatória mapeada na EC2 (ex: `32768`, `32769`). O ALB (Cenário 2) gerencia isso automaticamente, mas no Cenário 1 precisamos liberar o tráfego diretamente.

### Estado atual

O SG `bia-web` já existe com 1 regra inbound: porta 80 de `0.0.0.0/0`. Precisamos **atualizar** para a porta correta da task.

> ⚠️ **Nota:** A porta exata é definida pelo ECS no momento do deploy. Após o serviço subir, verificamos a porta mapeada e atualizamos a regra.

### Configuração final esperada

| Direção | Protocolo | Porta | Origem | Descrição |
|---|---|---|---|---|
| Inbound | TCP | `<porta-da-task>` | `0.0.0.0/0` | acesso público à aplicação |
| Outbound | All | All | `0.0.0.0/0` | saída padrão |

---

## Recurso 2 — Security Group: bia-db (regra adicional)

### O que é

O `bia-db` protege o RDS PostgreSQL. Precisamos adicionar uma regra permitindo que as tasks ECS (que rodam na EC2 com SG `bia-web`) acessem o banco na porta 5432.

### Por que é necessário

Sem esta regra, a aplicação rodando no ECS não consegue conectar no RDS — mesmo que tudo mais esteja correto.

### Regra a adicionar

| Direção | Protocolo | Porta | Origem | Descrição |
|---|---|---|---|---|
| Inbound | TCP | 5432 | `bia-web` (sg-02644d8a3164e531b) | acesso vindo de bia-web |

---

## Recurso 3 — ECS Cluster: cluster-bia

### O que é

O **ECS Cluster** é o agrupamento lógico que organiza os recursos de computação (EC2) e as tasks que rodam sobre eles. É o "container de containers".

### Por que é necessário

Sem um cluster, não há onde registrar a EC2 nem onde lançar as tasks. O cluster é o primeiro recurso ECS a ser criado.

### Configuração

| Atributo | Valor |
|---|---|
| Nome | `cluster-bia` |
| Tipo | EC2 (não Fargate) |
| Região | `us-east-1` |

> **Importante:** Criar o cluster **não cria** a EC2. O cluster é apenas o agrupamento lógico. A EC2 se registra no cluster automaticamente via User Data.

---

## Recurso 4 — EC2: bia-ec2-zona-a

### O que é

A instância EC2 que vai **hospedar fisicamente** as tasks do ECS. Ela executa o ECS Agent, que é o processo responsável por registrar a instância no cluster e gerenciar o ciclo de vida das tasks.

### Por que é necessário

O ECS no modo EC2 (não Fargate) precisa de instâncias EC2 para rodar os containers. A instância precisa ter o **ECS Agent** instalado e configurado para apontar para o cluster correto.

### Como o ECS Agent é configurado

O ECS Agent é instalado automaticamente nas AMIs do Amazon Linux 2023 com ECS otimizado. A configuração do cluster é feita via **User Data**:

```bash
#!/bin/bash
echo ECS_CLUSTER=cluster-bia >> /etc/ecs/ecs.config
```

Este script é executado na primeira inicialização da instância e registra a EC2 no cluster `cluster-bia`.

### Configuração da Instância

| Atributo | Valor |
|---|---|
| Nome (Tag) | `bia-ec2-zona-a` |
| Tipo | `t3.micro` |
| AMI | `ami-0006118602dfc1c09` (Amazon Linux 2023 ECS Optimized) |
| Subnet | `subnet-0f5924893a60e01b3` (us-east-1a) |
| Security Group | `bia-web` (`sg-02644d8a3164e531b`) |
| IAM Instance Profile | `role-acesso-ssm` |
| IP Público | Habilitado |
| User Data | `echo ECS_CLUSTER=cluster-bia >> /etc/ecs/ecs.config` |

> **Por que role-acesso-ssm?**  
> O ECS Agent precisa de permissões para se comunicar com a API do ECS, fazer pull de imagens no ECR e publicar logs no CloudWatch. A `role-acesso-ssm` já tem essas permissões e também permite acesso via SSM Session Manager (sem SSH).

---

## Recurso 5 — ECS Task Definition: task-def-bia

### O que é

A **Task Definition** é o "blueprint" do container — define qual imagem usar, quanta memória e CPU alocar, quais variáveis de ambiente injetar e como mapear as portas.

### Por que é necessário

Sem a Task Definition, o ECS não sabe como lançar o container da BIA. É o equivalente ao `docker run` com todos os parâmetros definidos de forma declarativa.

### Configuração

| Atributo | Valor |
|---|---|
| Nome | `task-def-bia` |
| Network Mode | `bridge` |
| Requer Compatibilidade | `EC2` |

#### Container: bia

| Atributo | Valor |
|---|---|
| Nome do container | `bia` |
| Imagem | `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:latest` |
| Memory Soft Limit | `400` MB |
| CPU | `1024` units (1 vCPU) |
| Port Mapping | `0:8080` (host port 0 = porta aleatória no host) |
| Protocol | `tcp` |

> **Por que host port 0?**  
> No modo bridge com porta `0`, o ECS escolhe automaticamente uma porta disponível na EC2 (ex: 32768). Isso permite rodar múltiplas tasks na mesma instância sem conflito de porta.

#### Variáveis de Ambiente do Container

| Variável | Valor |
|---|---|
| `DB_USER` | `postgres` |
| `DB_PWD` | `l93Xp4KhciaomhgrdyEn` |
| `DB_HOST` | `bia.co3qaww06tcz.us-east-1.rds.amazonaws.com` |
| `DB_PORT` | `5432` |
| `VERSAO_API` | `4.3.0` |

---

## Recurso 6 — ECS Service: service-bia

### O que é

O **ECS Service** é o controlador que garante que um número desejado de tasks esteja sempre rodando. Se uma task morrer, o Service lança uma nova automaticamente.

### Por que é necessário

Sem o Service, a task roda uma vez e para. O Service é quem garante a **disponibilidade contínua** da aplicação.

### Configuração

| Atributo | Valor |
|---|---|
| Nome | `service-bia` |
| Cluster | `cluster-bia` |
| Task Definition | `task-def-bia` |
| Desired Count | `1` |
| Launch Type | `EC2` |
| Deployment Type | `Rolling Update` |
| Minimum Healthy Percent | `50%` |
| Maximum Percent | `100%` |
| AZ Rebalancing | Desativado |

> **Por que Minimum 50% / Maximum 100%?**  
> Com 1 task desejada, durante um deploy:  
> - A task antiga é parada (0 tasks = 0% → abaixo de 50% momentaneamente)  
> - A nova task é iniciada  
> Isso é aceitável para o ambiente educacional. Em produção com mais tasks, o rolling update manteria pelo menos 50% sempre rodando.

---

## Ordem de Execução

```
1. Atualizar regras do SG bia-web
2. Adicionar regra no SG bia-db (origem bia-web)
3. Criar ECS Cluster (cluster-bia)
4. Lançar EC2 com User Data apontando para cluster-bia
5. Aguardar EC2 registrar no cluster (~2 min)
6. Criar Task Definition (task-def-bia)
7. Criar Service (service-bia)
8. Aguardar task ficar RUNNING (~1 min)
9. Descobrir porta mapeada e atualizar SG bia-web
10. Testar acesso via IP público da EC2
```

---

## Verificação Final

Após todos os recursos criados, validar:

```bash
# 1. Verificar se a task está RUNNING
aws ecs list-tasks --cluster cluster-bia --region us-east-1

# 2. Descobrir a porta mapeada
aws ecs describe-tasks \
  --cluster cluster-bia \
  --tasks <task-arn> \
  --region us-east-1 \
  --query 'tasks[0].containers[0].networkBindings'

# 3. Pegar o IP público da EC2
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bia-ec2-zona-a" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --region us-east-1

# 4. Testar a aplicação
curl http://<IP-PUBLICO-EC2>:<PORTA>/api/versao
curl http://<IP-PUBLICO-EC2>:<PORTA>/api/ping
curl http://<IP-PUBLICO-EC2>:<PORTA>/api/tarefas
```

---

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| Task fica em `PENDING` | EC2 não registrou no cluster | Verificar User Data e aguardar ~2min |
| Task para com `STOPPED` | Erro na aplicação ou no banco | Ver logs: `aws ecs describe-tasks` + CloudWatch |
| `connection refused` na porta | Porta errada no SG ou task não subiu | Verificar porta mapeada e regra do SG bia-web |
| `ETIMEDOUT` no banco | SG bia-db sem regra de bia-web | Adicionar regra 5432 de bia-web no bia-db |
| Task não aparece no cluster | IAM role sem permissão ECS | Verificar policies da role-acesso-ssm |

---

## Custos Estimados (Cenário 1)

| Recurso | Tipo | Custo/mês |
|---|---|---|
| EC2 | t3.micro | ~$7,59 |
| RDS | db.t3.micro | ~$13,14 |
| RDS Storage | 20 GB gp2 | ~$2,30 |
| ECR | ~230 MB | ~$0,02 |
| **Total** | | **~$23/mês** |

> Com Free Tier ativo (conta nova): **~$0/mês** nos primeiros 12 meses.

---

*Runbook gerado pelo agente Kiro-BIA em 02/08/2026.*  
*Próximo passo após validação: [Cenário 2 — ECS com ALB](./runbook-cenario2-ecs-alb.md)*
