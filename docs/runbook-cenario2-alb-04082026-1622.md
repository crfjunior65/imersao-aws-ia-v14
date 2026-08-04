# Runbook — Cenário 2: ECS com ALB em Alta Disponibilidade

> **Data:** 04/08/2026 16:22 (BRT)  
> **Pré-requisito:** Leia `docs/analise-cenario2-alb-04082026-1622.md` antes de executar  
> **Conta AWS:** 328113723783 | **Região:** us-east-1  
> **Tempo estimado:** 15-20 minutos

---

## Índice

1. [Passo 1 — Corrigir Inbound do SG bia-ec2](#passo-1--corrigir-inbound-do-sg-bia-ec2)
2. [Passo 2 — Corrigir Outbound do SG bia-ec2](#passo-2--corrigir-outbound-do-sg-bia-ec2)
3. [Passo 3 — Corrigir Launch Template (SG errado)](#passo-3--corrigir-launch-template-sg-errado)
4. [Passo 4 — Aumentar capacidade do ASG](#passo-4--aumentar-capacidade-do-asg)
5. [Passo 5 — Validar EC2 no cluster ECS](#passo-5--validar-ec2-no-cluster-ecs)
6. [Passo 6 — Validar tasks rodando](#passo-6--validar-tasks-rodando)
7. [Passo 7 — Validar targets healthy no ALB](#passo-7--validar-targets-healthy-no-alb)
8. [Passo 8 — Testar acesso via ALB](#passo-8--testar-acesso-via-alb)
9. [Passo 9 — (Opcional) Ajustar Health Check](#passo-9--opcional-ajustar-health-check)
10. [Passo 10 — (Opcional) Ajustar Deploy Config do Service](#passo-10--opcional-ajustar-deploy-config-do-service)

---

## Passo 1 — Corrigir Inbound do SG bia-ec2

### Por que?

O Security Group `bia-ec2` está com **inbound vazio**. Isso significa que o ALB não consegue enviar tráfego para as instâncias EC2 do cluster.

No ECS com modo bridge e `hostPort=0`, o ECS atribui portas aleatórias (portas efêmeras) para cada task. Por isso, precisamos liberar **All TCP** vindo do ALB.

### Comando

```bash
aws ec2 authorize-security-group-ingress \
  --region us-east-1 \
  --group-id sg-02a4f839749673f09 \
  --ip-permissions '[{
    "IpProtocol": "tcp",
    "FromPort": 0,
    "ToPort": 65535,
    "UserIdGroupPairs": [{
      "GroupId": "sg-0b71ec6df73add1d0",
      "Description": "acesso vindo de bia-alb"
    }]
  }]'
```

### Verificação

```bash
aws ec2 describe-security-groups \
  --region us-east-1 \
  --group-ids sg-02a4f839749673f09 \
  --query 'SecurityGroups[0].IpPermissions'
```

**Resultado esperado:** Uma regra inbound All TCP (0-65535) com source `sg-0b71ec6df73add1d0`.

---

## Passo 2 — Corrigir Outbound do SG bia-ec2

### Por que?

O outbound atual só permite tráfego para o SG `bia-alb`. Isso impede que as EC2:
- Baixem imagens Docker do ECR
- Comuniquem com o ECS Agent (endpoints AWS)
- Acessem o RDS na porta 5432
- Enviem logs para CloudWatch

Precisamos abrir o outbound para `0.0.0.0/0` (tráfego geral de saída).

### Passo 2.1 — Remover a regra de outbound restritiva

```bash
aws ec2 revoke-security-group-egress \
  --region us-east-1 \
  --group-id sg-02a4f839749673f09 \
  --ip-permissions '[{
    "IpProtocol": "-1",
    "UserIdGroupPairs": [{
      "GroupId": "sg-0b71ec6df73add1d0"
    }]
  }]'
```

### Passo 2.2 — Adicionar outbound aberto

```bash
aws ec2 authorize-security-group-egress \
  --region us-east-1 \
  --group-id sg-02a4f839749673f09 \
  --ip-permissions '[{
    "IpProtocol": "-1",
    "IpRanges": [{"CidrIp": "0.0.0.0/0"}]
  }]'
```

### Verificação

```bash
aws ec2 describe-security-groups \
  --region us-east-1 \
  --group-ids sg-02a4f839749673f09 \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

**Resultado esperado:** Uma regra outbound All traffic para `0.0.0.0/0`.

---

## Passo 3 — Corrigir Launch Template (SG errado)

### Por que?

O Launch Template atual usa o SG `bia-web` (sg-02644d8a3164e531b) que é do Cenário 1. As novas EC2 precisam usar o SG `bia-ec2` (sg-02a4f839749673f09) para que as regras que acabamos de configurar se apliquem.

Vamos criar uma **nova versão** do Launch Template com o SG correto.

### Comando

```bash
aws ec2 create-launch-template-version \
  --region us-east-1 \
  --launch-template-id lt-0e9074274a3baea81 \
  --source-version 1 \
  --launch-template-data '{
    "SecurityGroupIds": ["sg-02a4f839749673f09"]
  }' \
  --version-description "Correcao SG para bia-ec2"
```

### Passo 3.1 — Definir a nova versão como default

```bash
aws ec2 modify-launch-template \
  --region us-east-1 \
  --launch-template-id lt-0e9074274a3baea81 \
  --default-version 2
```

### Verificação

```bash
aws ec2 describe-launch-template-versions \
  --region us-east-1 \
  --launch-template-id lt-0e9074274a3baea81 \
  --versions '$Default' \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData.SecurityGroupIds'
```

**Resultado esperado:** `["sg-02a4f839749673f09"]`

---

## Passo 4 — Aumentar capacidade do ASG

### Por que?

O Auto Scaling Group está com min=0, max=0, desired=0. Precisamos de **2 instâncias** (uma em cada AZ) para alta disponibilidade.

### Comando

```bash
aws autoscaling update-auto-scaling-group \
  --region us-east-1 \
  --auto-scaling-group-name "Infra-ECS-Cluster-cluster-bia-581e3f53-ECSAutoScalingGroup-VX1mts6Zyf02" \
  --min-size 2 \
  --max-size 2 \
  --desired-capacity 2
```

### O que acontece agora?

1. O ASG lançará 2 instâncias EC2 t3.micro (uma em cada AZ)
2. Cada instância usará a AMI ECS-optimized e o user data com `ECS_CLUSTER=cluster-bia`
3. O ECS Agent dentro das EC2 se registrará automaticamente no cluster
4. O serviço `service-bia-alb` detectará as instâncias e começará a lançar tasks

### Verificação (aguardar ~2 minutos)

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names "Infra-ECS-Cluster-cluster-bia-581e3f53-ECSAutoScalingGroup-VX1mts6Zyf02" \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Instances:Instances[].{Id:InstanceId,AZ:AvailabilityZone,State:LifecycleState}}'
```

**Resultado esperado:**
```json
{
  "Desired": 2,
  "Instances": [
    { "Id": "i-xxx", "AZ": "us-east-1a", "State": "InService" },
    { "Id": "i-yyy", "AZ": "us-east-1b", "State": "InService" }
  ]
}
```

---

## Passo 5 — Validar EC2 no cluster ECS

### Por que?

Depois que as EC2 iniciarem, o ECS Agent se registra no cluster. Precisamos confirmar que as instâncias apareceram como **Container Instances**.

### Comando (aguardar 2-3 min após o Passo 4)

```bash
aws ecs list-container-instances \
  --region us-east-1 \
  --cluster cluster-bia
```

**Resultado esperado:** 2 ARNs de container instances.

### Para ver detalhes das instâncias

```bash
aws ecs describe-container-instances \
  --region us-east-1 \
  --cluster cluster-bia \
  --container-instances $(aws ecs list-container-instances --region us-east-1 --cluster cluster-bia --query 'containerInstanceArns[]' --output text) \
  --query 'containerInstances[].{Id:ec2InstanceId,Status:status,CPU:remainingResources[?name==`CPU`].integerValue|[0],Memory:remainingResources[?name==`MEMORY`].integerValue|[0],AZ:attributes[?name==`ecs.availability-zone`].value|[0]}'
```

**Resultado esperado:**
```json
[
  { "Id": "i-xxx", "Status": "ACTIVE", "CPU": 1024, "Memory": ..., "AZ": "us-east-1a" },
  { "Id": "i-yyy", "Status": "ACTIVE", "CPU": 1024, "Memory": ..., "AZ": "us-east-1b" }
]
```

### Troubleshooting

Se as instâncias não aparecerem após 3 minutos:
1. Verifique se as EC2 estão em `running`:
   ```bash
   aws ec2 describe-instances --region us-east-1 \
     --filters "Name=tag:Name,Values=ECS Instance*" "Name=instance-state-name,Values=running" \
     --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,AZ:Placement.AvailabilityZone}'
   ```
2. Se estiverem running mas não aparecem no ECS, verifique o user data e o SG (a EC2 precisa de saída para a internet para se comunicar com o ECS endpoint)

---

## Passo 6 — Validar tasks rodando

### Por que?

Com as EC2 registradas, o ECS deve iniciar automaticamente as 2 tasks do `service-bia-alb`.

### Comando (aguardar 1-2 min após o Passo 5)

```bash
aws ecs describe-services \
  --region us-east-1 \
  --cluster cluster-bia \
  --services service-bia-alb \
  --query 'services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount,Failed:deployments[0].failedTasks}'
```

**Resultado esperado:**
```json
{
  "Desired": 2,
  "Running": 2,
  "Pending": 0,
  "Failed": 208
}
```

> Nota: O `failedTasks` ficará com o histórico (208), mas o importante é `Running=2`.

### Ver as tasks em execução

```bash
aws ecs list-tasks \
  --region us-east-1 \
  --cluster cluster-bia \
  --service-name service-bia-alb
```

---

## Passo 7 — Validar targets healthy no ALB

### Por que?

As tasks registram automaticamente as portas dinâmicas no Target Group via integração ECS ↔ ALB. Precisamos confirmar que os targets estão `healthy`.

### Comando (aguardar 30-60s após tasks running)

```bash
aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn "arn:aws:elasticloadbalancing:us-east-1:328113723783:targetgroup/tg-alb/2e74c0b6377e4904"
```

**Resultado esperado:**
```json
{
  "TargetHealthDescriptions": [
    { "Target": { "Id": "i-xxx", "Port": 32768 }, "TargetHealth": { "State": "healthy" } },
    { "Target": { "Id": "i-yyy", "Port": 32769 }, "TargetHealth": { "State": "healthy" } }
  ]
}
```

### Troubleshooting — Targets em `unhealthy`

Se os targets aparecerem como `unhealthy`:

1. **Verifique o health check path** — está configurado como `/`. Se a app não responde 200 na raiz, troque para `/api/versao`
2. **Verifique o SG bia-ec2** — o inbound deve permitir All TCP de `bia-alb`
3. **Verifique se a app está rodando** — cheque os logs no CloudWatch:
   ```bash
   aws logs tail /ecs/task-bia-alb --region us-east-1 --since 5m
   ```

---

## Passo 8 — Testar acesso via ALB

### Por que?

Este é o teste final. Se tudo estiver correto, a aplicação responde via DNS do ALB.

### Comandos de teste

```bash
# Teste básico — versão da API
curl -s http://bia-alb-1140832221.us-east-1.elb.amazonaws.com/api/versao
```

**Resultado esperado:** `Bia 4.3.0`

```bash
# Teste com banco — listar tarefas
curl -s http://bia-alb-1140832221.us-east-1.elb.amazonaws.com/api/tarefas | python3 -m json.tool
```

**Resultado esperado:** JSON com a lista de tarefas do banco.

```bash
# Teste de balanceamento — fazer várias requisições e ver a distribuição
for i in $(seq 1 6); do
  echo "Request $i:"
  curl -s http://bia-alb-1140832221.us-east-1.elb.amazonaws.com/api/versao
  echo ""
done
```

### Teste via navegador

Abra no navegador: `http://bia-alb-1140832221.us-east-1.elb.amazonaws.com`

**Resultado esperado:** Frontend React da BIA carregado com a lista de tarefas.

---

## Passo 9 — (Opcional) Ajustar Health Check

### Por que?

O health check atual verifica a raiz `/` que serve o frontend. É mais confiável usar `/api/versao` que testa o backend Node.js diretamente (sem depender do banco).

### Comando

```bash
aws elbv2 modify-target-group \
  --region us-east-1 \
  --target-group-arn "arn:aws:elasticloadbalancing:us-east-1:328113723783:targetgroup/tg-alb/2e74c0b6377e4904" \
  --health-check-path "/api/versao" \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3
```

### Verificação

```bash
aws elbv2 describe-target-groups \
  --region us-east-1 \
  --target-group-arns "arn:aws:elasticloadbalancing:us-east-1:328113723783:targetgroup/tg-alb/2e74c0b6377e4904" \
  --query 'TargetGroups[0].{Path:HealthCheckPath,Interval:HealthCheckIntervalSeconds,Healthy:HealthyThresholdCount,Unhealthy:UnhealthyThresholdCount}'
```

---

## Passo 10 — (Opcional) Ajustar Deploy Config do Service

### Por que?

O service `service-bia-alb` está com `maximumPercent=200` e `minimumHealthyPercent=100`. O padrão do projeto é `max=100%, min=50%`.

Com max=100% e min=50%:
- O ECS para uma task antes de iniciar a nova (usa menos recursos)
- Aceita ficar com metade da capacidade durante o deploy

Com max=200% e min=100%:
- O ECS inicia novas tasks antes de parar as antigas (zero downtime)
- Precisa do dobro de capacidade durante o deploy

Ambos funcionam. Ajuste conforme preferir:

### Comando (para seguir o padrão do projeto)

```bash
aws ecs update-service \
  --region us-east-1 \
  --cluster cluster-bia \
  --service service-bia-alb \
  --deployment-configuration '{
    "maximumPercent": 100,
    "minimumHealthyPercent": 50
  }'
```

---

## Checklist Final

Após executar todos os passos, confirme:

- [ ] SG `bia-ec2` inbound: All TCP de `bia-alb` ✓
- [ ] SG `bia-ec2` outbound: All traffic para `0.0.0.0/0` ✓
- [ ] Launch Template v2: SG = `bia-ec2` ✓
- [ ] ASG: desired=2, min=2, max=2 ✓
- [ ] Container Instances: 2 instâncias ACTIVE no cluster ✓
- [ ] Tasks: 2 running no service-bia-alb ✓
- [ ] Targets: 2 healthy no Target Group ✓
- [ ] `curl /api/versao` via ALB retorna "Bia 4.3.0" ✓
- [ ] `curl /api/tarefas` via ALB retorna dados do banco ✓
- [ ] Frontend carrega via ALB no navegador ✓

---

## Comandos Úteis para Troubleshooting

### Ver logs das tasks em tempo real

```bash
aws logs tail /ecs/task-bia-alb --region us-east-1 --follow
```

### Ver eventos recentes do service

```bash
aws ecs describe-services \
  --region us-east-1 \
  --cluster cluster-bia \
  --services service-bia-alb \
  --query 'services[0].events[:5].{Time:createdAt,Message:message}'
```

### Forçar novo deploy (se necessário)

```bash
aws ecs update-service \
  --region us-east-1 \
  --cluster cluster-bia \
  --service service-bia-alb \
  --force-new-deployment
```

### Verificar se as EC2 estão no SG correto

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=ECS Instance*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{Id:InstanceId,SGs:SecurityGroups[].GroupName}'
```

---

## Referência Rápida de IDs

| Recurso | ID |
|---------|-----|
| SG bia-ec2 | `sg-02a4f839749673f09` |
| SG bia-alb | `sg-0b71ec6df73add1d0` |
| SG bia-db | `sg-096a1e8518c3a982c` |
| Launch Template | `lt-0e9074274a3baea81` |
| ASG | `Infra-ECS-Cluster-cluster-bia-581e3f53-ECSAutoScalingGroup-VX1mts6Zyf02` |
| Target Group ARN | `arn:aws:elasticloadbalancing:us-east-1:328113723783:targetgroup/tg-alb/2e74c0b6377e4904` |
| Cluster | `cluster-bia` |
| Service | `service-bia-alb` |
| ALB DNS | `bia-alb-1140832221.us-east-1.elb.amazonaws.com` |
