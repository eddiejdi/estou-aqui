#!/bin/bash
###############################################################################
# Pi-hole DNS enforcement
# Instala regras de iptables/ipset que forçam todo o DNS a passar pelo Pi-hole
# e bloqueiam resolvers públicos conhecidos. Executar no gateway/roteador.
###############################################################################
set -euo pipefail

PIHOLE=${PIHOLE:-192.168.15.2}

# lista de upstreams públicos que não devem ser acessados diretamente
DNS_NETS=(
  8.8.8.8/32
  8.8.4.4/32
  1.1.1.1/32
  1.0.0.1/32
  9.9.9.9/32
  208.67.220.0/22
  45.90.28.0/22
)

echo "🔒 Aplicando políticas de DNS forçado (Pi-hole: $PIHOLE)"

# create ipset if missing
if ! ipset list dns_providers >/dev/null 2>&1; then
  ipset create dns_providers hash:net
fi

for net in "${DNS_NETS[@]}"; do
  ipset add dns_providers "$net" 2>/dev/null || true
done

# permitir queries legítimas ao Pi-hole
iptables -C OUTPUT -p udp --dport 53 -d $PIHOLE -j ACCEPT 2>/dev/null || \
    iptables -A OUTPUT -p udp --dport 53 -d $PIHOLE -j ACCEPT
iptables -C OUTPUT -p tcp --dport 53 -d $PIHOLE -j ACCEPT 2>/dev/null || \
    iptables -A OUTPUT -p tcp --dport 53 -d $PIHOLE -j ACCEPT

# redirecionar todo o restante
iptables -t nat -C PREROUTING -p udp --dport 53 -j DNAT --to-destination $PIHOLE:53 2>/dev/null || \
    iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination $PIHOLE:53
iptables -t nat -C PREROUTING -p tcp --dport 53 -j DNAT --to-destination $PIHOLE:53 2>/dev/null || \
    iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination $PIHOLE:53

# bloquear resolvers externos
iptables -C FORWARD -p udp --dport 53 -m set --match-set dns_providers dst -j REJECT 2>/dev/null || \
    iptables -A FORWARD -p udp --dport 53 -m set --match-set dns_providers dst -j REJECT
iptables -C FORWARD -p tcp --dport 53 -m set --match-set dns_providers dst -j REJECT 2>/dev/null || \
    iptables -A FORWARD -p tcp --dport 53 -m set --match-set dns_providers dst -j REJECT

echo "✅ Regras aplicadas. Para remover usar 'iptables -t nat -D PREROUTING ...' e 'ipset destroy dns_providers'"
