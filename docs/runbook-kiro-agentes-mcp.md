# Runbook: Configuração de Agentes e MCPs no Kiro CLI

> **Ambiente:** EC2 `bia-dev` — Amazon Linux 2023, us-east-1  
> **Role IAM:** `role-acesso-ssm`  
> **Projeto:** BIA v4.3.0  

---

## Visão Geral

Este runbook descreve como instalar, configurar e validar os agentes Kiro e os servidores MCP disponíveis no projeto BIA para que o Kiro tenha acesso completo à infraestrutura AWS e ao banco de dados local.

### Agentes disponíveis

| Agente | Arquivo | Descrição |
|--------|---------|-----------|
| `bia` | `.kiro/agents/bia.json` | DevOps AWS generalista |
| `kiro-bia` | `.kiro/agents/kiro-bia.json` | Especialista completo no projeto BIA (recomendado) |

### MCPs disponíveis

| MCP | Arquivo de referência | Função |
|-----|-----------------------|--------|
| `aws-mcp` | `.kiro/mcp-aws.json` | Acesso à API AWS via proxy |
| `postgres` | `.kiro/mcp-db.json` | Query direto no PostgreSQL local |
| `awslabs.ecs-mcp-server` | `.kiro/mcp-ecs.json` | Gerenciamento de clusters ECS |

---

## Pré-requisitos

### 1. Verificar `uv` / `uvx`

Todos os MCPs usam `uvx` para execução. Verifique:

```bash
uvx --version
```

Saída esperada: `uvx 0.x.x`

Se não estiver instalado:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
```

### 2. Verificar credenciais AWS

```bash
aws sts get-caller-identity
```

Saída esperada: role `role-acesso-ssm` com account `328113723783`.

### 3. Docker (necessário para o MCP Postgres)

```bash
docker info 2>&1 | grep "Server Version"
```

O Docker precisa estar em execução para subir o container do PostgreSQL.

---

## Parte 1 — Ativar os Agentes

Os agentes já existem em `.kiro/agents/`. Não é necessário criá-los. Basta selecioná-los no chat.

### Selecionar agente no chat

Digite no chat do Kiro:

```
/agent kiro-bia
```

ou para o agente generalista:

```
/agent bia
```

### Verificar agentes disponíveis via CLI

```bash
kiro-cli agent list
```

### Validar configuração dos agentes

```bash
kiro-cli agent validate --path .kiro/agents/kiro-bia.json
kiro-cli agent validate --path .kiro/agents/bia.json
```

> **Agente recomendado:** `kiro-bia` — contém contexto completo do projeto, MCPs de postgres e aws já embutidos na configuração, e todas as regras de nomenclatura e arquitetura dos 3 cenários ECS.

---

## Parte 2 — Ativar os MCPs

Os MCPs são ativados de duas formas: embutidos no agente (já configurado no `kiro-bia`) ou no escopo do workspace.

### Opção A — MCPs já embutidos no agente `kiro-bia` (recomendado)

O agente `kiro-bia` já tem `aws-mcp` e `postgres` configurados em `mcpServers`. Ao selecionar esse agente, os MCPs sobem automaticamente — **nenhuma configuração extra necessária**.

Verifique no chat após selecionar o agente:

```
/mcp
```

### Opção B — Importar MCPs no escopo workspace

Para disponibilizar os MCPs em qualquer agente do projeto:

```bash
cd /home/ec2-user/bia

kiro-cli mcp import --file .kiro/mcp-aws.json workspace
kiro-cli mcp import --file .kiro/mcp-db.json workspace
kiro-cli mcp import --file .kiro/mcp-ecs.json workspace
```

Verificar importação:

```bash
kiro-cli mcp list workspace
```

### Opção C — Criar `mcp.json` unificado manualmente

Crie o arquivo `.kiro/settings/mcp.json` com todos os servidores:

```bash
cat > .kiro/settings/mcp.json << 'EOF'
{
  "mcpServers": {
    "aws-mcp": {
      "command": "uvx",
      "args": [
        "mcp-proxy-for-aws@latest",
        "https://aws-mcp.us-east-1.api.aws/mcp",
        "--metadata",
        "AWS_REGION=us-east-1"
      ]
    },
    "postgres": {
      "command": "uvx",
      "args": ["--with", "mcp<2", "postgres-mcp", "--access-mode=unrestricted"],
      "env": {
        "DATABASE_URI": "postgresql://postgres:postgres@localhost:5433/bia"
      }
    },
    "awslabs.ecs-mcp-server": {
      "command": "uvx",
      "args": ["--from", "awslabs-ecs-mcp-server", "ecs-mcp-server"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "ALLOW_WRITE": "false",
        "ALLOW_SENSITIVE_DATA": "false"
      }
    }
  }
}
EOF
```

---

## Parte 3 — Pré-requisitos por MCP

### MCP `aws-mcp` — Status: ✅ Pronto

Nenhuma ação necessária. A role `role-acesso-ssm` tem credenciais válidas e o endpoint responde.

**Teste rápido:**
```bash
aws sts get-caller-identity
```

---

### MCP `postgres` — Requer Docker rodando

O MCP conecta em `localhost:5433`. O banco precisa estar no ar via Docker Compose.

**Subir o banco:**
```bash
cd /home/ec2-user/bia
docker compose up -d
```

**Verificar se a porta está ouvindo:**
```bash
ss -tlnp | grep 5433
```

Saída esperada: linha com `0.0.0.0:5433`.

**Executar migrations (primeira vez):**
```bash
docker compose exec server bash -c 'npx sequelize db:migrate'
```

**Verificar conectividade do MCP:**
```bash
uvx --with "mcp<2" postgres-mcp --help 2>&1 | head -3
```

---

### MCP `ecs-mcp-server` — Requer permissões IAM

O servidor inicia corretamente, mas a role `role-acesso-ssm` não possui permissões ECS/ECR.

**Permissões necessárias na role:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:DescribeClusters",
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ecs:DescribeTaskDefinition",
        "ecs:ListTaskDefinitions",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "logs:DescribeLogGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

**Adicionar via AWS Console:**
1. IAM → Roles → `role-acesso-ssm`
2. Add permissions → Create inline policy
3. Colar o JSON acima
4. Nome: `bia-ecs-mcp-read`

**Adicionar via AWS CLI** (requer permissão `iam:PutRolePolicy`):
```bash
aws iam put-role-policy \
  --role-name role-acesso-ssm \
  --policy-name bia-ecs-mcp-read \
  --policy-document file://docs/iam-ecs-mcp-policy.json
```

**Testar após adicionar permissões:**
```bash
aws ecs list-clusters --region us-east-1
```

---

## Parte 4 — Validação Final

Execute esta sequência para confirmar que tudo está funcionando:

```bash
# 1. uvx disponível
uvx --version

# 2. AWS autenticado
aws sts get-caller-identity

# 3. Docker e banco no ar
docker compose ps
ss -tlnp | grep 5433

# 4. Agentes válidos
kiro-cli agent validate --path .kiro/agents/kiro-bia.json
kiro-cli agent validate --path .kiro/agents/bia.json

# 5. MCPs listados
kiro-cli mcp list
```

**No chat do Kiro, após selecionar o agente `kiro-bia`:**

```
/mcp
```

Resultado esperado:

```
@aws-mcp    ✓ Initialized   (tools: listados)
@postgres   ✓ Initialized   (tools: listados)
```

---

## Referência Rápida

| Ação | Comando |
|------|---------|
| Selecionar agente | `/agent kiro-bia` |
| Ver status dos MCPs | `/mcp` |
| Listar MCPs configurados | `kiro-cli mcp list` |
| Importar MCP de arquivo | `kiro-cli mcp import --file .kiro/mcp-aws.json workspace` |
| Ver status de um MCP | `kiro-cli mcp status --name aws-mcp` |
| Subir banco local | `docker compose up -d` |
| Verificar porta postgres | `ss -tlnp \| grep 5433` |
| Validar agente | `kiro-cli agent validate --path .kiro/agents/kiro-bia.json` |

---

## Troubleshooting

**MCP `postgres` não inicializa:**
- Causa: Docker Compose não está rodando
- Solução: `docker compose up -d` e aguardar a porta 5433

**MCP `aws-mcp` não inicializa:**
- Causa: `uvx` não encontrado ou sem credenciais AWS
- Solução: verificar `uvx --version` e `aws sts get-caller-identity`

**MCP `ecs-mcp-server` retorna AccessDenied:**
- Causa: role `role-acesso-ssm` sem permissões ECS
- Solução: adicionar a inline policy `bia-ecs-mcp-read` conforme Parte 3

**Agente não aparece no `/agent`:**
- Causa: arquivo JSON inválido
- Solução: `kiro-cli agent validate --path .kiro/agents/<nome>.json`

**`uvx` não encontrado:**
- Causa: `uv` não instalado ou não está no PATH
- Solução: `curl -LsSf https://astral.sh/uv/install.sh | sh && source ~/.bashrc`
