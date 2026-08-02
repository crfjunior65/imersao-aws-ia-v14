#!/bin/bash

# =============================================================================
# BIA Deploy Manager
# Projeto: BIA — Formação AWS / Imersão AWS & IA
# Autor: Henrylle Maia
# Descrição: Build, push, deploy e rollback para ECS com controle por
#            commit hash e task definition revision.
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configurações
# -----------------------------------------------------------------------------
ECR_REGISTRY="328113723783.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="bia"
REGION="us-east-1"
REPOSITORY_URI="$ECR_REGISTRY/$ECR_REPO"

# -----------------------------------------------------------------------------
# Cores para output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Funções auxiliares
# -----------------------------------------------------------------------------
print_header() {
  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e "${BOLD}${BLUE}       BIA Deploy Manager v1.0             ${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""
}

print_step() {
  echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
  echo -e "${GREEN}✔ $1${NC}"
}

print_error() {
  echo -e "${RED}✘ $1${NC}"
  exit 1
}

print_warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

confirm() {
  echo -e "${YELLOW}$1 [s/N]: ${NC}"
  read -r RESP
  [[ "$RESP" =~ ^[sS]$ ]]
}

# -----------------------------------------------------------------------------
# Seleciona o ambiente (cluster + service + task definition)
# -----------------------------------------------------------------------------
select_environment() {
  echo -e "${BOLD}Selecione o ambiente:${NC}"
  echo "  1) cluster-bia       / service-bia       (sem ALB)"
  echo "  2) cluster-bia-alb   / service-bia-alb   (com ALB)"
  echo ""
  read -rp "Opção [1/2]: " ENV_OPT

  case $ENV_OPT in
    1)
      CLUSTER="cluster-bia"
      SERVICE="service-bia"
      TASK_FAMILY="task-bia"
      ;;
    2)
      CLUSTER="cluster-bia-alb"
      SERVICE="service-bia-alb"
      TASK_FAMILY="task-bia-alb"
      ;;
    *)
      print_error "Opção inválida. Use 1 ou 2."
      ;;
  esac

  echo ""
  echo -e "  Cluster:  ${CYAN}$CLUSTER${NC}"
  echo -e "  Service:  ${CYAN}$SERVICE${NC}"
  echo -e "  Task Def: ${CYAN}$TASK_FAMILY${NC}"
  echo ""
}

# -----------------------------------------------------------------------------
# Login no ECR
# -----------------------------------------------------------------------------
ecr_login() {
  print_step "Autenticando no ECR..."
  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY" > /dev/null 2>&1
  print_success "Login no ECR realizado."
}

# -----------------------------------------------------------------------------
# BUILD + PUSH + DEPLOY
# Gera tag com short commit hash (7 chars), registra nova revision
# na task definition e faz o deploy.
# -----------------------------------------------------------------------------
action_build_push_deploy() {
  # Verifica se estamos em um repositório git
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Não é um repositório git. Execute dentro do diretório do projeto."
  fi

  COMMIT_HASH=$(git rev-parse --short=7 HEAD)
  IMAGE_TAG="$COMMIT_HASH"
  IMAGE_URI="$REPOSITORY_URI:$IMAGE_TAG"
  IMAGE_LATEST="$REPOSITORY_URI:latest"

  echo -e "  Commit hash: ${CYAN}$COMMIT_HASH${NC}"
  echo -e "  Imagem:      ${CYAN}$IMAGE_URI${NC}"
  echo ""

  # ---- Build ----------------------------------------------------------------
  print_step "Executando docker build..."
  docker build -t "$REPOSITORY_URI:latest" .
  docker tag "$REPOSITORY_URI:latest" "$IMAGE_URI"
  print_success "Build concluído."

  # ---- Push -----------------------------------------------------------------
  ecr_login
  print_step "Enviando imagem para o ECR (tags: latest + $IMAGE_TAG)..."
  docker push "$IMAGE_LATEST"
  docker push "$IMAGE_URI"
  print_success "Push concluído: $IMAGE_URI"

  # ---- Registrar nova revision na Task Definition ---------------------------
  print_step "Buscando task definition atual: $TASK_FAMILY..."

  TASK_DEF_JSON=$(aws ecs describe-task-definition \
    --task-definition "$TASK_FAMILY" \
    --region "$REGION" \
    --query 'taskDefinition' \
    --output json)

  # Extrai o nome do container principal (primeiro container)
  CONTAINER_NAME=$(echo "$TASK_DEF_JSON" | python3 -c \
    "import sys,json; td=json.load(sys.stdin); print(td['containerDefinitions'][0]['name'])")

  print_step "Registrando nova revision com imagem $IMAGE_TAG..."

  # Monta novo containerDefinitions com a imagem atualizada
  NEW_TASK_DEF=$(echo "$TASK_DEF_JSON" | python3 -c "
import sys, json

td = json.load(sys.stdin)

# Atualiza a imagem do primeiro container
td['containerDefinitions'][0]['image'] = '$IMAGE_URI'

# Remove campos que não podem ser re-registrados
for field in ['taskDefinitionArn','revision','status','requiresAttributes',
              'compatibilities','registeredAt','registeredBy','deregisteredAt']:
    td.pop(field, None)

print(json.dumps(td))
")

  NEW_REVISION_ARN=$(aws ecs register-task-definition \
    --region "$REGION" \
    --cli-input-json "$NEW_TASK_DEF" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

  NEW_REVISION=$(echo "$NEW_REVISION_ARN" | awk -F: '{print $NF}')
  print_success "Nova revision registrada: ${TASK_FAMILY}:${NEW_REVISION}"

  # ---- Deploy ---------------------------------------------------------------
  print_step "Iniciando deploy no ECS..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --task-definition "${TASK_FAMILY}:${NEW_REVISION}" \
    --region "$REGION" \
    --output json > /dev/null

  print_success "Deploy disparado!"
  echo ""
  echo -e "  Ambiente:  ${CYAN}$CLUSTER / $SERVICE${NC}"
  echo -e "  Imagem:    ${CYAN}$IMAGE_URI${NC}"
  echo -e "  Revision:  ${CYAN}${TASK_FAMILY}:${NEW_REVISION}${NC}"
  echo ""
  print_warn "O deploy está em andamento no ECS (rolling update). Acompanhe pelo console AWS."
}

# -----------------------------------------------------------------------------
# DEPLOY de revision específica
# Permite escolher qualquer revision já registrada e fazer o deploy.
# -----------------------------------------------------------------------------
action_deploy_revision() {
  list_revisions
  echo ""
  read -rp "Digite o número da revision para deploy: " CHOSEN_REV

  # Valida se é número
  if ! [[ "$CHOSEN_REV" =~ ^[0-9]+$ ]]; then
    print_error "Revision inválida. Digite apenas o número."
  fi

  TASK_ARN="${TASK_FAMILY}:${CHOSEN_REV}"

  # Confirma que a revision existe
  if ! aws ecs describe-task-definition \
        --task-definition "$TASK_ARN" \
        --region "$REGION" > /dev/null 2>&1; then
    print_error "Revision ${TASK_ARN} não encontrada."
  fi

  print_step "Fazendo deploy da revision ${TASK_ARN}..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --task-definition "$TASK_ARN" \
    --region "$REGION" \
    --output json > /dev/null

  print_success "Deploy disparado: ${TASK_ARN}"
  print_warn "O deploy está em andamento no ECS (rolling update). Acompanhe pelo console AWS."
}

# -----------------------------------------------------------------------------
# ROLLBACK
# Lista revisions com detalhes e permite escolher para qual reverter.
# -----------------------------------------------------------------------------
action_rollback() {
  echo -e "${YELLOW}${BOLD}⚠ ROLLBACK — ${TASK_FAMILY}${NC}"
  echo ""
  list_revisions
  echo ""
  read -rp "Digite o número da revision para ROLLBACK: " CHOSEN_REV

  if ! [[ "$CHOSEN_REV" =~ ^[0-9]+$ ]]; then
    print_error "Revision inválida. Digite apenas o número."
  fi

  TASK_ARN="${TASK_FAMILY}:${CHOSEN_REV}"

  if ! aws ecs describe-task-definition \
        --task-definition "$TASK_ARN" \
        --region "$REGION" > /dev/null 2>&1; then
    print_error "Revision ${TASK_ARN} não encontrada."
  fi

  echo ""
  if confirm "Confirma rollback para ${TASK_ARN} no cluster ${CLUSTER}?"; then
    print_step "Executando rollback para ${TASK_ARN}..."
    aws ecs update-service \
      --cluster "$CLUSTER" \
      --service "$SERVICE" \
      --task-definition "$TASK_ARN" \
      --region "$REGION" \
      --output json > /dev/null

    print_success "Rollback disparado: ${TASK_ARN}"
    print_warn "O rollback está em andamento no ECS (rolling update). Acompanhe pelo console AWS."
  else
    echo "Rollback cancelado."
  fi
}

# -----------------------------------------------------------------------------
# Lista as revisions da task definition com detalhes
# (revision, data de registro, imagem/tag)
# -----------------------------------------------------------------------------
list_revisions() {
  print_step "Buscando revisions de ${TASK_FAMILY}..."
  echo ""

  # Busca lista de ARNs de revisions ativas
  REVISIONS=$(aws ecs list-task-definitions \
    --family-prefix "$TASK_FAMILY" \
    --status ACTIVE \
    --sort DESC \
    --region "$REGION" \
    --query 'taskDefinitionArns[]' \
    --output json)

  COUNT=$(echo "$REVISIONS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [ "$COUNT" -eq 0 ]; then
    print_error "Nenhuma revision encontrada para ${TASK_FAMILY}."
  fi

  # Pega a revision atual do service
  CURRENT_REVISION=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$REGION" \
    --query 'services[0].taskDefinition' \
    --output text 2>/dev/null | awk -F: '{print $NF}')

  printf "  %-10s %-22s %-20s %s\n" "REVISION" "REGISTRADO EM" "IMAGEM TAG" "STATUS"
  printf "  %-10s %-22s %-20s %s\n" "--------" "-------------------" "---------" "------"

  echo "$REVISIONS" | python3 -c "
import sys, json
arns = json.load(sys.stdin)
for arn in arns:
    rev = arn.split(':')[-1]
    print(rev)
" | while read -r REV; do
    DETAILS=$(aws ecs describe-task-definition \
      --task-definition "${TASK_FAMILY}:${REV}" \
      --region "$REGION" \
      --query 'taskDefinition' \
      --output json 2>/dev/null)

    IMAGE=$(echo "$DETAILS" | python3 -c \
      "import sys,json; td=json.load(sys.stdin); print(td['containerDefinitions'][0]['image'])" 2>/dev/null)

    # Extrai só a tag da imagem (após o :)
    IMAGE_TAG=$(echo "$IMAGE" | awk -F: '{print $NF}')

    REGISTERED=$(echo "$DETAILS" | python3 -c \
      "import sys,json; td=json.load(sys.stdin); print(td.get('registeredAt','N/A'))" 2>/dev/null | cut -c1-19 | tr 'T' ' ')

    # Marca a revision atual em uso
    if [ "$REV" = "$CURRENT_REVISION" ]; then
      STATUS="${GREEN}◀ em uso${NC}"
    else
      STATUS=""
    fi

    printf "  %-10s %-22s %-20s " "$REV" "$REGISTERED" "$IMAGE_TAG"
    echo -e "$STATUS"
  done

  echo ""
}

# -----------------------------------------------------------------------------
# Menu principal de ação
# -----------------------------------------------------------------------------
select_action() {
  echo -e "${BOLD}Selecione a ação:${NC}"
  echo "  1) Build + Push + Deploy  (commit hash atual)"
  echo "  2) Deploy de revision     (escolhe revision existente)"
  echo "  3) Rollback               (lista revisions, você escolhe)"
  echo "  4) Listar revisions"
  echo ""
  read -rp "Opção [1-4]: " ACTION_OPT
  echo ""
}

# =============================================================================
# INÍCIO
# =============================================================================
print_header
select_environment
select_action

case $ACTION_OPT in
  1) action_build_push_deploy ;;
  2) action_deploy_revision   ;;
  3) action_rollback          ;;
  4) list_revisions           ;;
  *) print_error "Opção inválida. Use 1, 2, 3 ou 4." ;;
esac
