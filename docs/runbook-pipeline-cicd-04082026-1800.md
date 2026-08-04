# Runbook — Pipeline CI/CD: GitHub → CodePipeline → CodeBuild → ECS

> **Data:** 04/08/2026 18:00 (BRT)  
> **Conta AWS:** 328113723783 | **Região:** us-east-1  
> **Repositório GitHub:** `crfjunior65/imersao-aws-ia-v14`  
> **Tempo estimado:** 20-30 minutos

---

## Visão Geral

```
┌──────────┐     ┌──────────────┐     ┌────────────┐     ┌──────────┐
│  GitHub  │────▶│ CodePipeline │────▶│ CodeBuild  │────▶│   ECS    │
│  (push)  │     │  (orquestra) │     │ (build+push)│    │ (deploy) │
└──────────┘     └──────────────┘     └────────────┘     └──────────┘
                                            │
                                            ▼
                                      ┌──────────┐
                                      │   ECR    │
                                      │ (imagem) │
                                      └──────────┘
```

**Fluxo:**
1. Você faz `git push` no GitHub (branch `main`)
2. CodePipeline detecta a mudança via GitHub Connection
3. CodeBuild builda a imagem Docker e envia para o ECR
4. CodePipeline faz deploy no ECS usando `imagedefinitions.json`

---

## Pré-requisitos

| Item | Status |
|------|--------|
| Repositório GitHub | ✅ `crfjunior65/imersao-aws-ia-v14` |
| ECR Repository | ✅ `328113723783.dkr.ecr.us-east-1.amazonaws.com/bia` |
| ECS Cluster | ✅ `cluster-bia` |
| ECS Service | ✅ `service-bia-alb` |
| `buildspec.yml` | ⚠️ Precisa atualizar ECR_REGISTRY (está com conta antiga) |

---

## Passo 1 — Atualizar o `buildspec.yml`

### Por que?

O `buildspec.yml` atual referencia o ECR registry `380278406175` (conta antiga). Precisamos atualizar para a conta atual `328113723783`.

### Alteração

```yaml
env:
  variables:
    ECR_REGISTRY: 328113723783.dkr.ecr.us-east-1.amazonaws.com
    ECR_REPO: bia
```

### Comando

```bash
# No diretório do projeto, editar o buildspec.yml:
sed -i 's/380278406175/328113723783/' buildspec.yml
```

### Commit

```bash
git add buildspec.yml
git commit -m "fix: atualizar ECR registry no buildspec.yml"
git push origin main
```

> ⚠️ Faça este push ANTES de configurar o pipeline, senão o primeiro build vai falhar.

---

## Passo 2 — Criar Connection com GitHub (CodeConnections)

### Por que?

O CodePipeline precisa de uma "connection" para acessar seu repositório GitHub. Isso é feito via **AWS CodeConnections** (antigo CodeStar Connections) usando um GitHub App.

### ⚠️ ATENÇÃO: Este passo requer o Console AWS

A criação da connection exige autenticação OAuth no navegador (autorizar o GitHub App da AWS). **Não pode ser feito 100% via CLI.**

### Procedimento

1. Acesse: **Console AWS → Developer Tools → Settings → Connections**
   - URL direta: `https://us-east-1.console.aws.amazon.com/codesuite/settings/connections`
2. Clique em **Create connection**
3. Selecione **GitHub**
4. Connection name: `github-bia`
5. Clique em **Connect to GitHub**
6. Autorize o **AWS Connector for GitHub** na sua conta GitHub
7. Selecione **Install a new app** (ou use existente)
8. Selecione o repositório `crfjunior65/imersao-aws-ia-v14`
9. Clique em **Connect**

### Verificação (via CLI após criar)

```bash
aws codeconnections list-connections --region us-east-1
```

**Resultado esperado:** Connection com status `Available` e ARN tipo:
```
arn:aws:codeconnections:us-east-1:328113723783:connection/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

> 📋 **Anote o ARN da connection** — será usado nos passos seguintes.

---

## Passo 3 — Criar IAM Role para o CodeBuild

### Por que?

O CodeBuild precisa de permissões para:
- Baixar código do repositório (via connection)
- Fazer login e push no ECR
- Escrever logs no CloudWatch

### Comando — Criar Trust Policy

```bash
cat > /tmp/codebuild-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

### Comando — Criar a Role

```bash
aws iam create-role \
  --role-name role-codebuild-bia \
  --assume-role-policy-document file:///tmp/codebuild-trust.json
```

### Comando — Criar Policy com permissões necessárias

```bash
cat > /tmp/codebuild-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:328113723783:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:us-east-1:328113723783:repository/bia"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codeconnections:UseConnection"
      ],
      "Resource": "arn:aws:codeconnections:us-east-1:328113723783:connection/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::codepipeline-us-east-1-*/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name role-codebuild-bia \
  --policy-name policy-codebuild-bia \
  --policy-document file:///tmp/codebuild-policy.json
```

### Verificação

```bash
aws iam get-role --role-name role-codebuild-bia --query 'Role.Arn'
```

**Resultado:** `arn:aws:iam::328113723783:role/role-codebuild-bia`

---

## Passo 4 — Criar IAM Role para o CodePipeline

### Por que?

O CodePipeline precisa de permissões para:
- Acessar o GitHub via connection
- Disparar o CodeBuild
- Fazer deploy no ECS
- Acessar o S3 (artifacts)

### Comando — Trust Policy

```bash
cat > /tmp/codepipeline-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

### Comando — Criar a Role

```bash
aws iam create-role \
  --role-name role-codepipeline-bia \
  --assume-role-policy-document file:///tmp/codepipeline-trust.json
```

### Comando — Policy

```bash
cat > /tmp/codepipeline-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::codepipeline-us-east-1-*",
        "arn:aws:s3:::codepipeline-us-east-1-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codeconnections:UseConnection"
      ],
      "Resource": "arn:aws:codeconnections:us-east-1:328113723783:connection/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "arn:aws:codebuild:us-east-1:328113723783:project/codebuild-bia"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::328113723783:role/ecsTaskExecutionRole"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name role-codepipeline-bia \
  --policy-name policy-codepipeline-bia \
  --policy-document file:///tmp/codepipeline-policy.json
```

---

## Passo 5 — Criar projeto CodeBuild

### Por que?

O CodeBuild é responsável por executar o `buildspec.yml`: buildar a imagem Docker e enviar para o ECR.

### Comando

```bash
cat > /tmp/codebuild-project.json << 'EOF'
{
  "name": "codebuild-bia",
  "description": "Build da imagem BIA para ECR",
  "source": {
    "type": "CODEPIPELINE",
    "buildspec": "buildspec.yml"
  },
  "artifacts": {
    "type": "CODEPIPELINE"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:5.0",
    "computeType": "BUILD_GENERAL1_SMALL",
    "privilegedMode": true
  },
  "serviceRole": "arn:aws:iam::328113723783:role/role-codebuild-bia",
  "timeoutInMinutes": 15
}
EOF

aws codebuild create-project \
  --region us-east-1 \
  --cli-input-json file:///tmp/codebuild-project.json
```

### Parâmetros explicados

| Parâmetro | Valor | Por que |
|-----------|-------|---------|
| `source.type` | CODEPIPELINE | Recebe código do pipeline |
| `privilegedMode` | true | **Obrigatório** para rodar `docker build` |
| `image` | amazonlinux2-x86_64-standard:5.0 | Imagem com Docker pré-instalado |
| `computeType` | BUILD_GENERAL1_SMALL | 3 GB RAM, 2 vCPUs (suficiente) |
| `timeoutInMinutes` | 15 | Build da BIA leva ~5 min |

### Verificação

```bash
aws codebuild batch-get-projects --names codebuild-bia --region us-east-1 \
  --query 'projects[0].{Name:name,Status:created}'
```

---

## Passo 6 — Criar o CodePipeline

### Por que?

O CodePipeline orquestra todo o fluxo: detecta push no GitHub → aciona CodeBuild → faz deploy no ECS.

### Comando

> ⚠️ Substitua `CONNECTION_ARN` pelo ARN obtido no Passo 2.

```bash
cat > /tmp/pipeline.json << 'EOF'
{
  "pipeline": {
    "name": "pipeline-bia",
    "roleArn": "arn:aws:iam::328113723783:role/role-codepipeline-bia",
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "GitHub",
            "actionTypeId": {
              "category": "Source",
              "owner": "AWS",
              "provider": "CodeStarSourceConnection",
              "version": "1"
            },
            "configuration": {
              "ConnectionArn": "CONNECTION_ARN",
              "FullRepositoryId": "crfjunior65/imersao-aws-ia-v14",
              "BranchName": "main",
              "OutputArtifactFormat": "CODE_ZIP"
            },
            "outputArtifacts": [
              { "name": "SourceCode" }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "DockerBuild",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "codebuild-bia"
            },
            "inputArtifacts": [
              { "name": "SourceCode" }
            ],
            "outputArtifacts": [
              { "name": "BuildOutput" }
            ]
          }
        ]
      },
      {
        "name": "Deploy",
        "actions": [
          {
            "name": "DeployECS",
            "actionTypeId": {
              "category": "Deploy",
              "owner": "AWS",
              "provider": "ECS",
              "version": "1"
            },
            "configuration": {
              "ClusterName": "cluster-bia",
              "ServiceName": "service-bia-alb",
              "FileName": "imagedefinitions.json"
            },
            "inputArtifacts": [
              { "name": "BuildOutput" }
            ]
          }
        ]
      }
    ],
    "artifactStore": {
      "type": "S3",
      "location": "codepipeline-us-east-1-328113723783"
    },
    "pipelineType": "V2",
    "executionMode": "QUEUED"
  }
}
EOF

aws codepipeline create-pipeline \
  --region us-east-1 \
  --cli-input-json file:///tmp/pipeline.json
```

### Nota sobre o S3 bucket

O pipeline precisa de um bucket S3 para armazenar artefatos. Se o bucket `codepipeline-us-east-1-328113723783` não existir, crie antes:

```bash
aws s3 mb s3://codepipeline-us-east-1-328113723783 --region us-east-1
```

### Verificação

```bash
aws codepipeline get-pipeline --name pipeline-bia --region us-east-1 \
  --query 'pipeline.{Name:name,Stages:stages[].name}'
```

**Resultado esperado:**
```json
{
  "Name": "pipeline-bia",
  "Stages": ["Source", "Build", "Deploy"]
}
```

---

## Passo 7 — Testar o Pipeline (primeiro trigger)

### Por que?

O pipeline é disparado automaticamente na criação e também a cada push na branch `main`.

### Verificar execução

```bash
aws codepipeline list-pipeline-executions \
  --pipeline-name pipeline-bia \
  --region us-east-1 \
  --query 'pipelineExecutionSummaries[0].{Status:status,Start:startTime}'
```

### Acompanhar o Build

```bash
# Ver builds do CodeBuild
aws codebuild list-builds-for-project \
  --project-name codebuild-bia \
  --region us-east-1

# Ver logs do build (último)
aws codebuild batch-get-builds \
  --ids $(aws codebuild list-builds-for-project --project-name codebuild-bia --region us-east-1 --query 'ids[0]' --output text) \
  --region us-east-1 \
  --query 'builds[0].{Status:buildStatus,Duration:buildComplete,Phases:phases[].{Name:phaseType,Status:phaseStatus}}'
```

### Teste manual — Disparar push

```bash
# Faz uma alteração mínima para triggar o pipeline
echo "# Pipeline test $(date)" >> README.md
git add README.md
git commit -m "ci: testar pipeline"
git push origin main
```

Após ~5-7 minutos, o deploy deve completar automaticamente.

---

## Passo 8 — Validar deploy automático

### Verificar que o ECS recebeu nova task definition

```bash
aws ecs describe-services \
  --cluster cluster-bia \
  --services service-bia-alb \
  --region us-east-1 \
  --query 'services[0].{TaskDef:taskDefinition,Running:runningCount,Events:events[:2].message}'
```

### Testar a aplicação

```bash
curl -s https://bia.junior.tec.br/api/versao
```

---

## Troubleshooting

### Pipeline falha no Source

- Verifique se a connection está `Available`: `aws codeconnections list-connections`
- Confirme que o repositório e branch existem
- A connection precisa ter acesso ao repo

### Build falha no CodeBuild

- Verifique os logs: Console → CodeBuild → Build history → View logs
- Erros comuns:
  - `docker: permission denied` → `privilegedMode` não está `true`
  - `unable to login to ECR` → role sem permissão `ecr:GetAuthorizationToken`
  - `denied: no identity-based policy` → role sem permissão de push no ECR

### Deploy falha no ECS

- `imagedefinitions.json` não encontrado → verifique o `buildspec.yml` (artifacts)
- ECS não atualiza → role do pipeline sem `ecs:UpdateService`
- Task não inicia → mesmos problemas de SG/ECR/RDS do cenário anterior

### Pipeline não dispara no push

- Connection precisa estar `Available` (não `Pending`)
- Branch precisa ser exatamente `main`
- Verifique webhook: Console → Pipeline → Settings → Triggers

---

## Resumo dos Recursos Criados

| Recurso | Nome | Tipo |
|---------|------|------|
| Connection | `github-bia` | CodeConnections (GitHub) |
| IAM Role | `role-codebuild-bia` | Para CodeBuild |
| IAM Role | `role-codepipeline-bia` | Para CodePipeline |
| Projeto | `codebuild-bia` | CodeBuild |
| Pipeline | `pipeline-bia` | CodePipeline v2 |
| Bucket | `codepipeline-us-east-1-328113723783` | S3 (artefatos) |

---

## Fluxo Completo Após Implementação

```
Desenvolvedor faz git push (main)
        │
        ▼
CodePipeline detecta push (webhook via Connection)
        │
        ▼
Stage: Source → baixa código ZIP do GitHub
        │
        ▼
Stage: Build → CodeBuild executa buildspec.yml
        │  ├── docker build -t .../bia:latest
        │  ├── docker tag .../bia:{commit_hash}
        │  ├── docker push (latest + hash)
        │  └── gera imagedefinitions.json
        │
        ▼
Stage: Deploy → ECS recebe imagedefinitions.json
        │  ├── Registra nova task definition revision
        │  ├── Atualiza service-bia-alb
        │  └── Rolling update (max 200%, min 100%)
        │
        ▼
Aplicação atualizada em https://bia.junior.tec.br 🚀
```
