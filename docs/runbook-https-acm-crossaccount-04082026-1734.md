# Runbook — Configurar HTTPS no ALB com Certificado ACM Cross-Account

> **Data:** 04/08/2026 17:34 (BRT)  
> **Cenário:** Certificado wildcard `*.junior.tec.br` precisa funcionar no ALB da conta do projeto BIA  
> **Tempo estimado:** 5-10 minutos

---

## Contexto do Problema

| Item | Conta DNS (275263720574) | Conta BIA (328113723783) |
|------|--------------------------|--------------------------|
| Route 53 hosted zone | ✅ `junior.tec.br` | ❌ Não tem |
| Certificado ACM | ✅ `*.junior.tec.br` (Issued) | ❌ Não tem |
| ALB `bia-alb` | ❌ Não tem | ✅ Ativo |
| Listener HTTPS 443 | — | ❌ Falta criar |

### Por que não funciona direto?

O AWS Certificate Manager (ACM) **não permite usar certificados de outra conta** no ALB. Cada certificado ACM é vinculado à conta + região onde foi solicitado. Ou seja:

- O certificado da conta 275263720574 **não aparece** como opção no ALB da conta 328113723783
- Precisamos solicitar um **novo certificado** na conta 328113723783 (mesma conta do ALB)
- A validação por DNS será feita adicionando um registro CNAME no Route 53 da conta 275263720574

---

## Diagrama do Fluxo

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTA BIA (328113723783)                       │
│                                                                   │
│  1. Solicitar certificado ACM para *.junior.tec.br               │
│     → ACM gera um CNAME de validação                             │
│                                                                   │
│  3. Após validação: Certificado fica "Issued"                    │
│                                                                   │
│  4. Criar listener HTTPS 443 no ALB com o certificado            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    CNAME de validação
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  CONTA DNS (275263720574)                         │
│                                                                   │
│  2. Adicionar registro CNAME no Route 53 (junior.tec.br)         │
│     → ACM valida automaticamente que você controla o domínio     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Passo 1 — Solicitar certificado ACM na conta BIA

### Por que?

O certificado precisa existir na mesma conta e região do ALB (328113723783 / us-east-1).

### Comando (executar na conta BIA — 328113723783)

```bash
aws acm request-certificate \
  --region us-east-1 \
  --domain-name "*.junior.tec.br" \
  --validation-method DNS \
  --query 'CertificateArn' \
  --output text
```

### Resultado esperado

```
arn:aws:acm:us-east-1:328113723783:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

> ⚠️ **Guarde esse ARN!** Você vai precisar dele no Passo 4.

---

## Passo 2 — Obter o CNAME de validação

### Por que?

O ACM gera um registro CNAME único que prova que você controla o domínio. Esse registro precisa ser adicionado no DNS (Route 53 da outra conta).

### Comando (executar na conta BIA — 328113723783)

```bash
aws acm describe-certificate \
  --region us-east-1 \
  --certificate-arn "ARN_DO_CERTIFICADO_DO_PASSO_1" \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
```

### Resultado esperado

```json
{
  "Name": "_abc123xyz.junior.tec.br.",
  "Type": "CNAME",
  "Value": "_def456uvw.acm-validations.aws."
}
```

> 📋 **Anote os valores de `Name` e `Value`** — você vai precisar no Passo 3.

---

## Passo 3 — Adicionar CNAME de validação no Route 53

### Por que?

O ACM verifica se o registro CNAME existe no DNS do domínio. Como o hosted zone está na conta 275263720574, você precisa acessar **essa conta** para criar o registro.

### Opção A: Via Console AWS (conta 275263720574)

1. Acesse o **Console AWS** da conta 275263720574
2. Vá em **Route 53 → Hosted zones → junior.tec.br**
3. Clique em **Create record**
4. Preencha:
   - **Record name:** cole o valor de `Name` (sem o `.junior.tec.br.` no final, o console adiciona automaticamente)
   - **Record type:** CNAME
   - **Value:** cole o valor de `Value` do Passo 2
   - **TTL:** 300
5. Clique em **Create records**

### Opção B: Via AWS CLI (conta 275263720574)

Se você tem CLI configurada com acesso à conta DNS:

```bash
# Primeiro descubra o Hosted Zone ID
aws route53 list-hosted-zones-by-name \
  --dns-name "junior.tec.br" \
  --query 'HostedZones[0].Id' \
  --output text \
  --profile PROFILE_CONTA_DNS

# Depois crie o registro (substitua os valores)
aws route53 change-resource-record-sets \
  --hosted-zone-id "ZONE_ID" \
  --profile PROFILE_CONTA_DNS \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "_abc123xyz.junior.tec.br",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{
          "Value": "_def456uvw.acm-validations.aws."
        }]
      }
    }]
  }'
```

---

## Passo 4 — Aguardar validação do certificado

### Por que?

O ACM consulta o DNS periodicamente. Após encontrar o CNAME, muda o status para `Issued`. Isso geralmente leva **2 a 5 minutos** (pode levar até 30 min em casos raros).

### Comando para monitorar (conta BIA — 328113723783)

```bash
aws acm describe-certificate \
  --region us-east-1 \
  --certificate-arn "ARN_DO_CERTIFICADO" \
  --query 'Certificate.Status'
```

### Resultado esperado

```
"ISSUED"
```

> Se aparecer `PENDING_VALIDATION`, aguarde mais um pouco. Use `watch` para monitorar:
> ```bash
> watch -n 10 'aws acm describe-certificate --region us-east-1 --certificate-arn "ARN" --query "Certificate.Status" --output text'
> ```

---

## Passo 5 — Criar Listener HTTPS 443 no ALB

### Por que?

Com o certificado `Issued`, podemos criar o listener HTTPS que termina o SSL/TLS no ALB e encaminha o tráfego HTTP para as tasks.

### Comando (conta BIA — 328113723783)

```bash
aws elbv2 create-listener \
  --region us-east-1 \
  --load-balancer-arn "arn:aws:elasticloadbalancing:us-east-1:328113723783:loadbalancer/app/bia-alb/7b50f4659a29896e" \
  --protocol HTTPS \
  --port 443 \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --certificates "CertificateArn=ARN_DO_CERTIFICADO" \
  --default-actions '[{
    "Type": "forward",
    "TargetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:328113723783:targetgroup/tg-alb/2e74c0b6377e4904"
  }]'
```

### Parâmetros explicados

| Parâmetro | Valor | Explicação |
|-----------|-------|------------|
| `--protocol` | HTTPS | Listener SSL/TLS |
| `--port` | 443 | Porta padrão HTTPS |
| `--ssl-policy` | ELBSecurityPolicy-TLS13-1-2-2021-06 | Política moderna (TLS 1.2+1.3) |
| `--certificates` | ARN do certificado | O wildcard criado no Passo 1 |
| `--default-actions` | forward → tg-alb | Mesmo Target Group do HTTP |

### Resultado esperado

```json
{
  "Listeners": [{
    "ListenerArn": "arn:...listener/.../...",
    "Port": 443,
    "Protocol": "HTTPS",
    "Certificates": [{ "CertificateArn": "arn:..." }]
  }]
}
```

---

## Passo 6 — (Opcional) Redirecionar HTTP → HTTPS

### Por que?

Para forçar todo o tráfego HTTP a usar HTTPS automaticamente. O listener na porta 80 passará a redirecionar em vez de servir conteúdo.

### Comando (conta BIA — 328113723783)

```bash
# Primeiro: modificar o listener HTTP existente para redirecionar
aws elbv2 modify-listener \
  --region us-east-1 \
  --listener-arn "arn:aws:elasticloadbalancing:us-east-1:328113723783:listener/app/bia-alb/7b50f4659a29896e/ff217fe019836438" \
  --default-actions '[{
    "Type": "redirect",
    "RedirectConfig": {
      "Protocol": "HTTPS",
      "Port": "443",
      "Host": "#{host}",
      "Path": "/#{path}",
      "Query": "#{query}",
      "StatusCode": "HTTP_301"
    }
  }]'
```

### Resultado

Qualquer acesso a `http://bia.junior.tec.br` será redirecionado automaticamente para `https://bia.junior.tec.br` com HTTP 301.

---

## Passo 7 — Validar HTTPS

### Testes

```bash
# Teste HTTPS direto
curl -s https://bia.junior.tec.br/api/versao

# Teste redirecionamento HTTP → HTTPS (se Passo 6 foi feito)
curl -sI http://bia.junior.tec.br/api/versao | head -5

# Verificar certificado
curl -vI https://bia.junior.tec.br 2>&1 | grep -E "(subject|issuer|expire)"
```

### Resultados esperados

```
# HTTPS direto
Bia 4.3.0

# Redirecionamento
HTTP/1.1 301 Moved Permanently
Location: https://bia.junior.tec.br/api/versao

# Certificado
subject: CN=*.junior.tec.br
issuer: C=US; O=Amazon; CN=Amazon RSA 2048 M01
expire date: ...
```

---

## Passo 8 — Verificar no navegador

1. Abra `https://bia.junior.tec.br`
2. Confirme o **cadeado verde** 🔒 na barra de endereço
3. Clique no cadeado → verifique que o certificado é `*.junior.tec.br`
4. Teste criar/deletar tarefas para garantir que a API funciona via HTTPS

---

## Checklist Final

- [ ] Certificado ACM solicitado na conta 328113723783 ✓
- [ ] CNAME de validação adicionado no Route 53 (conta 275263720574) ✓
- [ ] Status do certificado: `Issued` ✓
- [ ] Listener HTTPS 443 criado no ALB ✓
- [ ] `curl https://bia.junior.tec.br/api/versao` retorna "Bia 4.3.0" ✓
- [ ] (Opcional) HTTP redireciona para HTTPS ✓
- [ ] Frontend carrega via HTTPS no navegador com cadeado verde ✓

---

## Troubleshooting

### Certificado não sai de PENDING_VALIDATION

- Verifique se o CNAME foi adicionado corretamente: `dig _abc123xyz.junior.tec.br CNAME`
- Confirme que não tem erro de digitação no Name/Value
- Aguarde até 30 minutos (geralmente resolve em 5 min)

### Erro "certificate not found" ao criar listener

- O certificado precisa estar na mesma **região** do ALB (us-east-1)
- O status precisa ser `Issued` (não `PENDING_VALIDATION`)

### ERR_SSL_PROTOCOL_ERROR no navegador

- O listener 443 não foi criado ou não está ativo
- Verifique: `aws elbv2 describe-listeners --load-balancer-arn ...`

### Frontend não carrega via HTTPS (mixed content)

- Verifique se fez o build com `VITE_API_URL=https://bia.junior.tec.br`
- O Dockerfile já está correto, mas confirme que o deploy usou a nova imagem

---

## Referência de IDs

| Recurso | Valor |
|---------|-------|
| Conta BIA (ALB) | 328113723783 |
| Conta DNS (Route 53) | 275263720574 |
| ALB ARN | `arn:aws:elasticloadbalancing:us-east-1:328113723783:loadbalancer/app/bia-alb/7b50f4659a29896e` |
| Listener HTTP ARN | `arn:aws:elasticloadbalancing:us-east-1:328113723783:listener/app/bia-alb/7b50f4659a29896e/ff217fe019836438` |
| Target Group ARN | `arn:aws:elasticloadbalancing:us-east-1:328113723783:targetgroup/tg-alb/2e74c0b6377e4904` |
| Domínio | `bia.junior.tec.br` |
| ALB DNS | `bia-alb-1140832221.us-east-1.elb.amazonaws.com` |
