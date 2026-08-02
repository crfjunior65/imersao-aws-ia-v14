# BIA Deploy Manager — Guia Completo

> Script: `bia-deploy.sh`  
> Localização: raiz do projeto e `scripts/ecs/unix/bia-deploy.sh`  
> Projeto: BIA — Formação AWS / Imersão AWS & IA

---

## O que é

O `bia-deploy.sh` é o script central de deploy do projeto BIA. Ele substitui os scripts antigos (`build.sh` e `deploy.sh`) com uma solução interativa que cobre todo o ciclo de vida de uma entrega:

- **Build** da imagem Docker com tag baseada no commit hash do Git
- **Push** para o Amazon ECR com duas tags (`latest` + hash do commit)
- **Deploy** no ECS registrando uma nova revision na task definition
- **Rollback** para qualquer revision anterior com confirmação antes de executar
- **Listagem** de todas as revisions disponíveis com data, imagem e status de uso

---

## Pré-requisitos

| Requisito | Detalhe |
|-----------|---------|
| AWS CLI v2 | Configurado e com permissões de ECS + ECR |
| Docker | Em execução na máquina |
| Git | Projeto dentro de um repositório git |
| Python 3 | Já disponível no Amazon Linux 2023 / Ubuntu |
| IAM | Role `role-acesso-ssm` (na EC2 bia-dev) já cobre as permissões necessárias |

---

## Como executar

Da raiz do projeto:

```bash
./bia-deploy.sh
```

Ou pelo caminho completo:

```bash
./scripts/ecs/unix/bia-deploy.sh
```

---

## Passo a passo do menu

### Passo 1 — Selecionar o ambiente

Ao executar, o primeiro menu exibe os dois ambientes disponíveis:

```
Selecione o ambiente:
  1) cluster-bia       / service-bia       (sem ALB)
  2) cluster-bia-alb   / service-bia-alb   (com ALB)
```

| Opção | Cluster | Service | Task Definition |
|-------|---------|---------|-----------------|
| 1 | `cluster-bia` | `service-bia` | `task-bia` |
| 2 | `cluster-bia-alb` | `service-bia-alb` | `task-bia-alb` |

Após a escolha, o script confirma os recursos selecionados antes de continuar.

### Passo 2 — Selecionar a ação

```
Selecione a ação:
  1) Build + Push + Deploy  (commit hash atual)
  2) Deploy de revision     (escolhe revision existente)
  3) Rollback               (lista revisions, você escolhe)
  4) Listar revisions
```

---

## Ação 1 — Build + Push + Deploy

Esta é a ação principal do ciclo de desenvolvimento. Use quando você fez alterações no código e quer subir uma nova versão.

### O que acontece internamente

**1. Leitura do commit hash**

```bash
COMMIT_HASH=$(git rev-parse --short=7 HEAD)
```

Pega os primeiros 7 caracteres do hash do commit atual. Exemplo: `a1b2c3d`.

**2. Docker build**

```bash
docker build -t 328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:latest .
docker tag  bia:latest  328113723783.dkr.ecr.us-east-1.amazonaws.com/bia:a1b2c3d
```

Gera a imagem e cria duas tags: `latest` e o hash do commit.

**3. Login no ECR e Push**

```bash
aws ecr get-login-password --region us-east-1 | docker login ...
docker push .../bia:latest
docker push .../bia:a1b2c3d
```

Envia ambas as tags para o registry. Isso garante rastreabilidade — cada imagem no ECR corresponde a um commit específico do Git.

**4. Registro de nova revision na Task Definition**

O script busca a task definition atual via AWS CLI, atualiza apenas o campo `image` do container com a nova URI (incluindo o hash), e registra uma nova revision:

```
task-def-bia:1  →  imagem: ...bia:f9e8d7c  (anterior)
task-def-bia:2  →  imagem: ...bia:a1b2c3d  (nova — registrada agora)
```

> Campos internos do ECS que não podem ser re-registrados são removidos automaticamente: `taskDefinitionArn`, `revision`, `status`, `requiresAttributes`, `compatibilities`, `registeredAt`, `registeredBy`.

**5. Deploy no ECS**

```bash
aws ecs update-service \
  --cluster cluster-bia \
  --service service-bia \
  --task-definition task-def-bia:2
```

O ECS inicia o rolling update substituindo as tasks em execução pela nova revision. A estratégia padrão é **min 50% / max 100%**.

### Output esperado

```
▶ Executando docker build...
✔ Build concluído.
▶ Autenticando no ECR...
✔ Login no ECR realizado.
▶ Enviando imagem para o ECR (tags: latest + a1b2c3d)...
✔ Push concluído: .../bia:a1b2c3d
▶ Buscando task definition atual: task-def-bia...
▶ Registrando nova revision com imagem a1b2c3d...
✔ Nova revision registrada: task-def-bia:2
▶ Iniciando deploy no ECS...
✔ Deploy disparado!

  Ambiente:  cluster-bia / service-bia
  Imagem:    .../bia:a1b2c3d
  Revision:  task-def-bia:2

⚠ O deploy está em andamento no ECS (rolling update). Acompanhe pelo console AWS.
```

---

## Ação 2 — Deploy de revision existente

Use quando quer fazer o deploy de uma versão já existente no ECR **sem fazer um novo build**. Útil para promover uma imagem já validada para outro ambiente.

### Fluxo

1. O script lista todas as revisions disponíveis (igual à Ação 4)
2. Você digita o número da revision desejada
3. O script valida se ela existe e executa o `update-service`

```
Digite o número da revision para deploy: 3
▶ Fazendo deploy da revision task-def-bia:3...
✔ Deploy disparado: task-def-bia:3
```

---

## Ação 3 — Rollback

Use quando uma nova versão apresenta problema e você precisa reverter rapidamente para uma versão anterior estável.

### Fluxo

1. O script lista todas as revisions com a revision atualmente em uso marcada com `◀ em uso`
2. Você digita o número da revision para a qual deseja reverter
3. O script exige confirmação antes de executar:

```
Confirma rollback para task-def-bia:1 no cluster cluster-bia? [s/N]:
```

4. Somente após digitar `s` o rollback é executado

> O rollback é apenas um `update-service` apontando para uma revision anterior. O ECS faz o rolling update normalmente, sem interrupção total do serviço.

---

## Ação 4 — Listar revisions

Exibe todas as revisions ativas da task definition do ambiente selecionado, ordenadas da mais recente para a mais antiga.

### Exemplo de saída

```
▶ Buscando revisions de task-def-bia...

  REVISION   REGISTRADO EM          IMAGEM TAG           STATUS
  --------   -------------------    ---------            ------
  5          2026-08-02 04:00:00    a1b2c3d              ◀ em uso
  4          2026-08-01 20:15:00    f9e8d7c
  3          2026-08-01 18:30:00    1234abc
  2          2026-08-01 15:00:00    deadbee
  1          2026-08-01 10:00:00    latest
```

| Coluna | Descrição |
|--------|-----------|
| REVISION | Número da revision da task definition no ECS |
| REGISTRADO EM | Data e hora em que a revision foi criada |
| IMAGEM TAG | Tag da imagem usada (geralmente o short commit hash) |
| STATUS | Indica qual revision o service está usando atualmente |

---

## Configurações internas do script

```bash
ECR_REGISTRY="328113723783.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="bia"
REGION="us-east-1"
```

Para alterar o registry ou a região, edite essas variáveis no início do arquivo.

---

## Relação entre commits, imagens e revisions

```
git commit  →  commit hash: a1b2c3d
                    │
                    ▼
             ECR image tag: .../bia:a1b2c3d
                    │
                    ▼
         task-def-bia:5  (nova revision registrada)
                    │
                    ▼
         ECS service atualizado → rolling update
```

Isso cria uma cadeia de rastreabilidade completa: dado qualquer revision do ECS, você sabe exatamente qual commit do Git originou aquele deploy.

---

## Cenários de uso

### Cenário: Deploy normal de nova feature

```bash
# Você fez o commit da sua feature
git add .
git commit -m "feat: nova funcionalidade X"

# Executa o script
./bia-deploy.sh
# → Opção de ambiente: 1 (sem ALB) ou 2 (com ALB)
# → Ação: 1 (Build + Push + Deploy)
```

### Cenário: Bug em produção, precisa reverter

```bash
./bia-deploy.sh
# → Seleciona o ambiente afetado
# → Ação: 3 (Rollback)
# → Vê a lista de revisions, identifica a última estável
# → Digita o número e confirma com "s"
```

### Cenário: Verificar qual versão está rodando

```bash
./bia-deploy.sh
# → Seleciona o ambiente
# → Ação: 4 (Listar revisions)
# → A linha com "◀ em uso" indica a versão atual
```

### Cenário: Promover versão já buildada para outro ambiente

```bash
./bia-deploy.sh
# → Seleciona o ambiente de destino
# → Ação: 2 (Deploy de revision)
# → Escolhe a revision que contém a imagem desejada
```

---

## Comportamento em caso de erro

O script usa `set -e` — qualquer comando que retorne erro interrompe a execução imediatamente. Erros são exibidos em vermelho com o símbolo `✘`.

Casos tratados explicitamente:

| Situação | Comportamento |
|----------|---------------|
| Não está em repositório git | Erro com mensagem explicativa |
| Revision digitada não é número | Erro com mensagem explicativa |
| Revision não existe no ECS | Erro com mensagem explicativa |
| Nenhuma revision ativa encontrada | Erro com mensagem explicativa |
| Rollback negado na confirmação | Cancela sem executar nada |

---

## Arquivos do projeto relacionados

| Arquivo | Relação |
|---------|---------|
| `Dockerfile` | Imagem que o script builda |
| `buildspec.yml` | Equivalente para o pipeline CodeBuild (automático via GitHub) |
| `scripts/ecs/unix/build.sh` | Script anterior de build (substituído) |
| `scripts/ecs/unix/deploy.sh` | Script anterior de deploy (substituído) |
