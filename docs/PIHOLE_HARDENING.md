# Hardening do Pi-hole no homelab

Este documento reúne recomendações para **endurecer** o uso do Pi‑hole containerizado que roda no homelab. A ideia é minimizar superfície de ataque, evitar vazamentos de DNS e impedir alterações indesejadas.

## 1. Restrições de acesso

1. **Somente rede interna**: firewall (iptables/UFW) deve bloquear porta `80`/`443` do Web UI fora da LAN. o `docker-compose` do homelab já mapeia apenas `0.0.0.0:8053` localmente; use regra `ufw deny from any to any port 8053` em hosts não confiáveis.
2. **Autenticação forte**: defina `WEBPASSWORD` ou `PIHOLE_PASSWORD` durante criação do container.
   ```bash
   docker run -d --name pihole \
     -e WEBPASSWORD="$(openssl rand -base64 16)" \
     ... pihole/pihole:latest
   ```
   o health‑check (`scripts/homelab-health-check.sh`) já valida que a senha não está vazia.
3. **API somente via API key**: habilite e guarde a chave em `Secrets Agent` (PIHOLE_API_KEY). não expor o token no Git.
4. **Sem interfaces externas**: não habilite `FTL` em portas públicas. se precisar de acesso remoto, use túnel SSH ou VPN.

## 2. DNS seguros

* **Ativar DNSSEC** via Web UI „Settings → DNS → Use DNSSEC“.
* **Definir upstreams confiáveis** (Cloudflare/Quad9) e habilitar TLS/HTTPS/DoH se possível.
* **Lista branca mínima**: apenas domínios necessários; evitar adicionar wildcard `*` indiscriminadamente. usar script `scripts/pihole-whitelist-github-copilot.sh` ou `pihole -w` sob SSH autenticado.
* **Monitorar logs**: `docker logs pihole` e/ou configurar exportação para `loki` se já usar.

## 3. Atualizações e manutenção

* Recrie o container ao menos uma vez por semana (`docker pull pihole/pihole && docker-compose up -d pihole`) e verifique se não há vulnerabilidades.
* Revise listas de bloqueio personalizadas; mantenha apenas as necessárias.
* Rotacione `WEBPASSWORD` e `PIHOLE_API_KEY` periodicamente via Secrets Agent.

## 4. Backups e persistência

* Volume `./pihole/etc-pihole` e `./pihole/etc-dnsmasq.d` já são mapeados no compose.
* Faça backup desses diretórios antes de alterações drásticas.
* A whitelist/blacklist persistem nesse volume; use `docker exec` para exportar:
  ```bash
  ssh homelab@192.168.15.2 \
    'docker exec pihole pihole -q -w > /tmp/pihole-whitelist.txt'
  ```

## 5. Checklist de implantação segura

| Item | Como verificar | Estado |
|------|---------------|--------|
| Porta admin restrita | `ss -ltnp | grep 8053` | ✅ |
| Senha configurada | health‑check script | ✅ |
| API key armazenada | `secrets_agent get eddie/pihole_api_key` | ✅ |
| DNSSEC ativo | Web UI ou `dig +dnssec @localhost github.com` | ✅ |
| Atualizações semanais | repositório de imagens | ✅ |
| DNS forçado na rede | regras iptables/ipset instaladas (veja seção abaixo) | ❌ |

## 6. Uso responsável

* Para domínios legítimos que forem bloqueados por engano, adicione à whitelist via script ou CLI interno do container.
* **Não usar Pi-hole como firewall/IDS** – ele não foi projetado para isso. Combine com iptables/ufw para filtragem de pacotes.

## 7. Prevenção de bypass de DNS

Jogos e aplicativos avançados podem contornar o Pi‑hole de várias maneiras:

1. **DNS fixo/IPs codificados.** muitos clientes usam 8.8.8.8, 1.1.1.1, etc. diretos.
2. **DoH/DoT** (DNS‑over‑HTTPS ou TLS) que viajam em 443/853 e não são inspecionados.
3. **Portas alternativas** ou encapsulamento em VPN/QUIC.
4. **Endereços IP diretos** em vez de nomes DNS.

### Medidas recomendadas

* **Forçar redirecionamento de DNS** no gateway/roteador:
  ```bash
  # criar conjunto de IPs de resolvers públicos
  ipset create dns_providers hash:net
  ipset add dns_providers 8.8.8.8/32
  ipset add dns_providers 1.1.1.1/32
  ipset add dns_providers 9.9.9.9/32
  ipset add dns_providers 208.67.220.0/22
  
  # aceitar consultas legítimas ao Pi-hole
  iptables -A OUTPUT -p udp --dport 53 -d $PIHOLE -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 53 -d $PIHOLE -j ACCEPT
  
  # redirecionar todo o restante para o Pi-hole
  iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination $PIHOLE:53
  iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination $PIHOLE:53
  
  # bloquear resolvers públicos conhecidos
  iptables -A FORWARD -p udp --dport 53 -m set --match-set dns_providers dst -j REJECT
  iptables -A FORWARD -p tcp --dport 53 -m set --match-set dns_providers dst -j REJECT
  ```
  um script de exemplo (`scripts/pihole-enforce-dns.sh`) está disponível no repositório.

* **Bloquear DoH/DoT** por domínio ou porta (Suricata ou iptables -m string com `cloudflare-dns.com`).
* **Monitorar logs** do Pi-hole e do firewall para consultas que escapem, e alertar em caso de >5% de consultas para IPs externos.
* **Desabilitar VPN/QUIC** a menos que seja necessário; aplique regras de DPI para detectar túneis.

> O health‑check do homelab agora inclui verificações de bypass (consultas a 8.8.8.8 e presença das regras). Consulte `scripts/homelab-health-check.sh`.

## 8. Inicialização automática no boot

Para garantir que o Pi‑hole volte a funcionar após um reboot do servidor, o homelab utiliza um
serviço systemd que executa o `docker-compose` do diretório `~/pihole`.

```ini
[Unit]
Description=Pi-hole Container
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/homelab/pihole
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down

[Install]
WantedBy=multi-user.target
```

O serviço é criado com:

```sh
sudo tee /etc/systemd/system/pihole.service <<'EOF'  # ver o conteúdo acima
# ...unit file...
EOF
sudo systemctl daemon-reload
sudo systemctl enable pihole.service
sudo systemctl start pihole.service
```

Uma vez habilitado, o container sobe automaticamente em todos os boot e pode ser controlado com
`systemctl start|stop|status pihole.service`. Sempre que fizer alterações na configuração do
compose (por exemplo alterar senha ou `upstreamDNS`), reinicie o serviço.

```sh
sudo systemctl restart pihole.service
```

Essa unidade também é verificada pelo health-check para garantir que o Pi-hole esteja ativo.

## 6. Uso responsável

* Para domínios legítimos que forem bloqueados por engano, adicione à whitelist via script ou CLI interno do container.
* **Não usar Pi-hole como firewall/IDS** – ele não foi projetado para isso. Combine com iptables/ufw para filtragem de pacotes.

> 🛡️ Seguindo estas recomendações, o Pi-hole do homelab continuará a proteger a rede sem abrir novos vetores de ataque.
