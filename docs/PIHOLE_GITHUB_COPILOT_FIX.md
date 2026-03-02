# Fix: GitHub Copilot não funciona sem DNS secundário

**Data:** 20/02/2026  
**Status:** ✅ **RESOLVIDO**

---

## 📋 Problema

O GitHub Copilot no VS Code não funcionava quando configurado apenas com o DNS primário do homelab (192.168.15.2 - Pi-hole). Era necessário configurar um DNS secundário (1.1.1.1 - Cloudflare) para que funcionasse.

### Sintomas

- GitHub Copilot não consegue se conectar aos serviços da GitHub
- Erros de conectividade ou timeout
- Funciona apenas quando DNS secundário está configurado

---

## 🔍 Diagnóstico

### DNS bloqueado pelo Pi-hole

O Pi-hole estava bloqueando o domínio `default.exp-tas.com`, que é essencial para o funcionamento do GitHub Copilot:

```bash
# Antes da correção
$ dig @192.168.15.2 default.exp-tas.com +short
0.0.0.0  # Bloqueado!

# Com DNS secundário (Cloudflare)
$ dig @1.1.1.1 default.exp-tas.com +short
deault-exp-tas-com.e-0014.e-msedge.net.
e-0014.e-msedge.net.
13.107.5.93
```

### Domínios testados

| Domínio | Status no Pi-hole (antes) | Função |
|---------|---------------------------|---------|
| `github.com` | ✅ Resolvendo | GitHub principal |
| `api.github.com` | ✅ Resolvendo | API GitHub |
| `copilot-proxy.githubusercontent.com` | ✅ Resolvendo | Proxy Copilot |
| `default.exp-tas.com` | ❌ **BLOQUEADO** | Telemetria/Analytics |
| `api.githubcopilot.com` | ✅ Resolvendo | API Copilot |
| `vscode.dev` | ✅ Resolvendo | VS Code Web |
| `vscode-auth.github.com` | ✅ Resolvendo | Autenticação VS Code |

---

## ✅ Solução

### 1. Adicionar domínio à whitelist do Pi-hole

```bash
ssh homelab@192.168.15.2 'docker exec pihole pihole allow default.exp-tas.com'
```

**Resultado:**
```
[✓] Added 1 domain(s):
  - default.exp-tas.com
```

### 2. Verificar resolução DNS

```bash
$ dig @192.168.15.2 default.exp-tas.com +short
deault-exp-tas-com.e-0014.e-msedge.net.
e-0014.e-msedge.net.
13.107.5.93  # ✅ Agora resolve!
```

### 3. Testar GitHub Copilot

Agora o GitHub Copilot funciona **sem necessidade de DNS secundário**! 🎉

---

## 🔧 Script de correção automática

Caso precise aplicar em outro ambiente ou após reset do Pi-hole:

```bash
#!/bin/bash
# Arquivo: scripts/pihole-whitelist-github-copilot.sh

HOMELAB_HOST="${HOMELAB_HOST:-192.168.15.2}"

echo "🔧 Adicionando domínios do GitHub Copilot à whitelist do Pi-hole..."

ssh homelab@$HOMELAB_HOST 'docker exec pihole pihole allow \
  default.exp-tas.com \
  api.githubcopilot.com \
  copilot-proxy.githubusercontent.com \
  vscode-auth.github.com'

echo ""
echo "✅ Whitelist atualizada!"
echo ""
echo "🧪 Testando resolução DNS..."
dig @$HOMELAB_HOST default.exp-tas.com +short

echo ""
echo "✨ GitHub Copilot deve funcionar agora sem DNS secundário!"
```

---

## 📝 Notas adicionais

### Por que o domínio estava bloqueado?

O domínio `default.exp-tas.com` pertence ao Microsoft Edge Analytics e é usado para:
- Telemetria do GitHub Copilot
- Métricas de uso
- Análise de experiência do usuário

Provavelmente estava em alguma lista de bloqueio de telemetria/tracking do Pi-hole.

### Manter whitelist persistente

A whitelist do Pi-hole é persistente. Os domínios adicionados permanecerão mesmo após reiniciar o container Docker.

**Localização dos dados persistentes:**
```bash
ssh homelab@192.168.15.2 'docker exec pihole ls -la /etc/pihole/'
```

### Alternativas

Se não quiser desbloquear o domínio de telemetria mas ainda precisar usar o Copilot:
1. Manter DNS secundário configurado (1.1.1.1)
2. Configurar bypass específico no Pi-hole para seu IP
3. Usar DNS-over-HTTPS no VS Code (não recomendado)

---

## 🧪 Verificação de saúde

Para verificar se o Copilot está funcionando corretamente sem DNS secundário:

```bash
# 1. Remover DNS secundário temporariamente
# (ou usar apenas 192.168.15.2 na configuração de rede)

# 2. Testar resolução de todos os domínios críticos
for domain in \
  github.com \
  api.github.com \
  copilot-proxy.githubusercontent.com \
  default.exp-tas.com \
  api.githubcopilot.com \
  vscode-auth.github.com; do
  echo "Testing: $domain"
  dig @192.168.15.2 "$domain" +short | head -1
  echo "---"
done

# 3. Abrir VS Code e verificar status do Copilot no painel de extensões
```

---

## 📚 Referências

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [GitHub Copilot Network Requirements](https://docs.github.com/en/copilot/configuring-github-copilot/configuring-network-settings-for-github-copilot)
- [Pi-hole Whitelist Management](https://docs.pi-hole.net/core/pihole-command/#whitelisting-blacklisting-and-regex)
- [Troubleshooting DNS Issues](https://discourse.pi-hole.net/t/commonly-whitelisted-domains/212)

---

**Criado por:** Dev Agent Local  
**Timestamp:** 2026-02-20T18:45:00-03:00
