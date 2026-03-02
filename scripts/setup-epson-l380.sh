#!/usr/bin/env bash
###############################################################################
#  setup-epson-l380.sh — Instalador/Configurador do serviço de impressão e
#  digitalização Epson L380 via Print On-Demand (homelab)
#
#  Configura na máquina cliente:
#    1. Dependências (sane-airscan, cups, ghostscript, curl)
#    2. Scanner via eSCL/AirScan (sane-airscan → homelab)
#    3. Impressora CUPS via backend "ondemand" (CUPS → homelab)
#    4. Script utilitário "scan" em /usr/local/bin
#    5. Testa conectividade e funcionalidade
#
#  Uso:
#    chmod +x setup-epson-l380.sh
#    sudo ./setup-epson-l380.sh
#    sudo ./setup-epson-l380.sh --ip 192.168.15.2
#    sudo ./setup-epson-l380.sh --uninstall
#
#  Requisitos:
#    - Linux com apt (Debian/Ubuntu) ou pacman (Arch)
#    - Rede local com acesso ao homelab (porta 9877)
#    - Executar como root (sudo)
###############################################################################
set -euo pipefail

VERSION="1.0.0"
SERVICE_PORT=9877
PRINTER_NAME="L380"
PRINTER_DESC="EPSON L380 Series (On-Demand via homelab)"
SCANNER_NAME="EPSON L380 (homelab)"
BACKEND_PATH="/usr/lib/cups/backend/ondemand"
AIRSCAN_CONF="/etc/sane.d/airscan.conf"
SCAN_SCRIPT="/usr/local/bin/scan"
SCAN_DIR="\$HOME/Documentos/Scans"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Funções auxiliares ──────────────────────────────────────────────────────

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Epson L380 — Instalador Print & Scan On-Demand${NC}  v${VERSION}  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

info()    { echo -e "  ${BLUE}ℹ${NC}  $*"; }
ok()      { echo -e "  ${GREEN}✓${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; }
fail()    { echo -e "  ${RED}✗${NC}  $*"; }
step()    { echo -e "\n${BOLD}[$1/$TOTAL_STEPS]${NC} $2"; }
ask()     { echo -ne "  ${CYAN}?${NC}  $* "; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "Este script precisa ser executado como root (sudo)."
        echo "  Uso: sudo $0"
        exit 1
    fi
}

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    elif command -v pacman &>/dev/null; then
        PKG_MGR="pacman"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    else
        warn "Gerenciador de pacotes não detectado. Instale manualmente."
        PKG_MGR="unknown"
    fi
}

pkg_install() {
    local pkgs=("$@")
    case "$PKG_MGR" in
        apt)
            apt-get update -qq 2>/dev/null
            apt-get install -y -qq "${pkgs[@]}" 2>/dev/null
            ;;
        pacman)
            pacman -Sy --noconfirm "${pkgs[@]}" 2>/dev/null
            ;;
        dnf)
            dnf install -y "${pkgs[@]}" 2>/dev/null
            ;;
        *)
            warn "Instale manualmente: ${pkgs[*]}"
            return 1
            ;;
    esac
}

test_connectivity() {
    local ip="$1"
    local port="$2"
    # Tenta curl com timeout curto
    if curl -sf --connect-timeout 5 "http://${ip}:${port}/status" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# ─── Desinstalação ───────────────────────────────────────────────────────────

uninstall() {
    banner
    echo -e "${BOLD}Desinstalando configuração Epson L380 On-Demand...${NC}\n"

    # Remover impressora CUPS
    if lpstat -p "$PRINTER_NAME" &>/dev/null; then
        lpadmin -x "$PRINTER_NAME" 2>/dev/null && ok "Impressora CUPS '$PRINTER_NAME' removida" || warn "Falha ao remover impressora"
    else
        info "Impressora '$PRINTER_NAME' não encontrada no CUPS"
    fi

    # Remover backend CUPS
    if [[ -f "$BACKEND_PATH" ]]; then
        rm -f "$BACKEND_PATH"
        ok "Backend CUPS '$BACKEND_PATH' removido"
    else
        info "Backend CUPS não encontrado"
    fi

    # Remover entrada airscan.conf
    if [[ -f "$AIRSCAN_CONF" ]]; then
        if grep -q "homelab" "$AIRSCAN_CONF" 2>/dev/null; then
            sed -i '/EPSON L380.*homelab/d' "$AIRSCAN_CONF"
            ok "Entrada do scanner removida de $AIRSCAN_CONF"
        else
            info "Entrada do scanner não encontrada em $AIRSCAN_CONF"
        fi
    fi

    # Remover script scan
    if [[ -f "$SCAN_SCRIPT" ]]; then
        rm -f "$SCAN_SCRIPT"
        ok "Script '$SCAN_SCRIPT' removido"
    fi

    echo ""
    ok "Desinstalação concluída!"
    exit 0
}

# ─── Instalação principal ────────────────────────────────────────────────────

TOTAL_STEPS=6
SERVER_IP=""
UNINSTALL=false
SKIP_TEST=false
NON_INTERACTIVE=false

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ip)       SERVER_IP="$2"; shift 2 ;;
        --uninstall|-u) UNINSTALL=true; shift ;;
        --skip-test)    SKIP_TEST=true; shift ;;
        --non-interactive|-y) NON_INTERACTIVE=true; shift ;;
        --help|-h)
            echo "Uso: sudo $0 [opções]"
            echo ""
            echo "Opções:"
            echo "  --ip IP            IP do servidor homelab (será solicitado se omitido)"
            echo "  --uninstall, -u    Remove toda a configuração"
            echo "  --skip-test        Pula o teste de impressão/scan"
            echo "  --non-interactive  Não faz perguntas (usa defaults)"
            echo "  --help, -h         Mostra esta ajuda"
            exit 0
            ;;
        *) fail "Opção desconhecida: $1"; exit 1 ;;
    esac
done

# ─── Início ──────────────────────────────────────────────────────────────────

check_root

if $UNINSTALL; then
    uninstall
fi

banner
detect_pkg_manager
info "Gerenciador de pacotes: ${BOLD}$PKG_MGR${NC}"
info "Sistema: $(uname -o) $(uname -r)"

# ─── Etapa 1: Solicitar IP ──────────────────────────────────────────────────

step 1 "Configuração do servidor"

if [[ -z "$SERVER_IP" ]]; then
    # Tentar detectar automaticamente via mDNS
    DETECTED_IP=""
    if command -v avahi-browse &>/dev/null; then
        info "Procurando scanner na rede via mDNS..."
        DETECTED_IP=$(avahi-browse -rtpk _uscan._tcp 2>/dev/null | \
            grep "^=" | grep -i "epson" | \
            awk -F';' '{print $8}' | head -1)
    fi

    # Tentar IPs comuns
    if [[ -z "$DETECTED_IP" ]]; then
        for try_ip in 192.168.15.2 192.168.1.2 192.168.0.2 10.0.0.2; do
            if test_connectivity "$try_ip" "$SERVICE_PORT"; then
                DETECTED_IP="$try_ip"
                break
            fi
        done
    fi

    if $NON_INTERACTIVE; then
        if [[ -n "$DETECTED_IP" ]]; then
            SERVER_IP="$DETECTED_IP"
        else
            fail "Modo não-interativo: use --ip para especificar o servidor"
            exit 1
        fi
    else
        if [[ -n "$DETECTED_IP" ]]; then
            ask "IP do servidor homelab [${GREEN}$DETECTED_IP${NC}]: "
            read -r input_ip
            SERVER_IP="${input_ip:-$DETECTED_IP}"
        else
            ask "IP do servidor homelab: "
            read -r SERVER_IP
            if [[ -z "$SERVER_IP" ]]; then
                fail "IP não informado. Abortando."
                exit 1
            fi
        fi
    fi
fi

API_URL="http://${SERVER_IP}:${SERVICE_PORT}"
info "Servidor: ${BOLD}$API_URL${NC}"

# Testar conectividade
echo -n "  "
if test_connectivity "$SERVER_IP" "$SERVICE_PORT"; then
    ok "Servidor acessível em ${SERVER_IP}:${SERVICE_PORT}"
    # Obter info do serviço
    SVC_INFO=$(curl -sf --connect-timeout 5 "${API_URL}/status" 2>/dev/null || echo "{}")
    SVC_PRINTER=$(echo "$SVC_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('config',{}).get('printer','?'))" 2>/dev/null || echo "?")
    info "Impressora remota: ${BOLD}$SVC_PRINTER${NC}"
else
    fail "Servidor NÃO acessível em ${SERVER_IP}:${SERVICE_PORT}"
    echo ""
    warn "Verifique se:"
    echo "    • O serviço print-ondemand está rodando no servidor"
    echo "    • A porta $SERVICE_PORT está acessível (firewall)"
    echo "    • O IP $SERVER_IP está correto"
    echo ""
    if ! $NON_INTERACTIVE; then
        ask "Continuar mesmo assim? [s/N]: "
        read -r cont
        if [[ "$cont" != "s" && "$cont" != "S" ]]; then
            exit 1
        fi
    else
        exit 1
    fi
fi

# ─── Etapa 2: Instalar dependências ─────────────────────────────────────────

step 2 "Instalando dependências"

DEPS_TO_INSTALL=()

# Verificar cada dependência
declare -A PKG_MAP_APT=(
    [curl]="curl"
    [sane-airscan]="sane-airscan"
    [scanimage]="sane-utils"
    [gs]="ghostscript"
    [lpstat]="cups"
    [lpadmin]="cups-client"
    [convert]="imagemagick"
    [avahi-browse]="avahi-utils"
)

declare -A PKG_MAP_PACMAN=(
    [curl]="curl"
    [sane-airscan]="sane-airscan"
    [scanimage]="sane"
    [gs]="ghostscript"
    [lpstat]="cups"
    [lpadmin]="cups"
    [convert]="imagemagick"
    [avahi-browse]="avahi"
)

check_and_collect_deps() {
    local cmd="$1"
    local pkg_apt="${PKG_MAP_APT[$cmd]:-}"
    local pkg_pacman="${PKG_MAP_PACMAN[$cmd]:-}"

    if command -v "$cmd" &>/dev/null; then
        ok "$cmd — instalado"
        return 0
    fi

    # sane-airscan é lib, não comando — checar arquivo
    if [[ "$cmd" == "sane-airscan" ]]; then
        if [[ -f /usr/lib/x86_64-linux-gnu/sane/libsane-airscan.so.1 ]] || \
           [[ -f /usr/lib/sane/libsane-airscan.so.1 ]] || \
           dpkg -l sane-airscan &>/dev/null 2>&1; then
            ok "sane-airscan — instalado"
            return 0
        fi
    fi

    case "$PKG_MGR" in
        apt)    [[ -n "$pkg_apt" ]] && DEPS_TO_INSTALL+=("$pkg_apt") ;;
        pacman) [[ -n "$pkg_pacman" ]] && DEPS_TO_INSTALL+=("$pkg_pacman") ;;
        dnf)    [[ -n "$pkg_apt" ]] && DEPS_TO_INSTALL+=("$pkg_apt") ;;
    esac
    warn "$cmd — NÃO instalado (será instalado: ${pkg_apt:-$pkg_pacman})"
}

for cmd in curl sane-airscan scanimage gs lpstat lpadmin avahi-browse; do
    check_and_collect_deps "$cmd"
done

# ImageMagick é opcional
if ! command -v convert &>/dev/null; then
    info "convert (ImageMagick) — opcional, não instalado"
fi

if [[ ${#DEPS_TO_INSTALL[@]} -gt 0 ]]; then
    # Remover duplicatas
    DEPS_UNIQUE=($(echo "${DEPS_TO_INSTALL[@]}" | tr ' ' '\n' | sort -u))
    info "Instalando: ${DEPS_UNIQUE[*]}"
    if pkg_install "${DEPS_UNIQUE[@]}"; then
        ok "Dependências instaladas"
    else
        warn "Algumas dependências podem não ter sido instaladas"
    fi
else
    ok "Todas as dependências já estão instaladas"
fi

# ─── Etapa 3: Configurar Scanner (airscan) ──────────────────────────────────

step 3 "Configurando scanner (eSCL/AirScan)"

AIRSCAN_ENTRY="\"$SCANNER_NAME\" = http://${SERVER_IP}:${SERVICE_PORT}/eSCL, eSCL"

if [[ -f "$AIRSCAN_CONF" ]]; then
    # Verificar se já existe entrada
    if grep -q "$SCANNER_NAME" "$AIRSCAN_CONF" 2>/dev/null; then
        # Atualizar IP se mudou
        OLD_LINE=$(grep "$SCANNER_NAME" "$AIRSCAN_CONF")
        if [[ "$OLD_LINE" == *"$SERVER_IP"* ]]; then
            ok "Scanner já configurado em $AIRSCAN_CONF (IP correto)"
        else
            sed -i "/$SCANNER_NAME/c\\$AIRSCAN_ENTRY" "$AIRSCAN_CONF"
            ok "IP do scanner atualizado em $AIRSCAN_CONF"
        fi
    else
        # Adicionar após a seção [devices]
        if grep -q "^\[devices\]" "$AIRSCAN_CONF"; then
            sed -i "/^\[devices\]/a\\$AIRSCAN_ENTRY" "$AIRSCAN_CONF"
        else
            # Criar seção [devices]
            echo -e "\n[devices]\n$AIRSCAN_ENTRY" >> "$AIRSCAN_CONF"
        fi
        ok "Scanner adicionado em $AIRSCAN_CONF"
    fi
else
    # Criar arquivo
    mkdir -p /etc/sane.d
    cat > "$AIRSCAN_CONF" <<EOF
# sane-airscan configuration — gerado por setup-epson-l380.sh
[devices]
$AIRSCAN_ENTRY

[options]
discovery = enable
model = network

[debug]
#trace = ~/airscan/trace
#enable = true
EOF
    ok "Arquivo $AIRSCAN_CONF criado"
fi

# Verificar scanner
info "Testando detecção do scanner..."
if command -v scanimage &>/dev/null; then
    FOUND=$(scanimage -L 2>/dev/null | grep -c "airscan\|escl.*${SERVER_IP}" || true)
    if [[ "$FOUND" -gt 0 ]]; then
        ok "Scanner detectado ($FOUND dispositivo(s))"
        scanimage -L 2>/dev/null | grep -i "airscan\|escl.*${SERVER_IP}" | while read -r line; do
            info "  → $line"
        done
    else
        warn "Scanner não detectado automaticamente"
        info "O scanner pode aparecer após o serviço ser iniciado no homelab"
    fi
fi

# ─── Etapa 4: Configurar Impressora CUPS ────────────────────────────────────

step 4 "Configurando impressora CUPS"

# Garantir CUPS rodando
if ! systemctl is-active cups &>/dev/null; then
    systemctl enable --now cups 2>/dev/null || warn "Falha ao iniciar CUPS"
fi

# Instalar backend CUPS
info "Instalando backend on-demand em $BACKEND_PATH..."

cat > "$BACKEND_PATH" <<'BACKEND_EOF'
#!/bin/bash
# CUPS Backend: Redireciona impressão para Print On-Demand API
# Gerado por setup-epson-l380.sh

ONDEMAND_URL="${ONDEMAND_URL:-__API_URL__}"

# Modo descoberta (sem argumentos)
if [ $# -eq 0 ]; then
    echo "network ondemand \"Unknown\" \"Print On-Demand (VM Windows)\""
    exit 0
fi

JOB_ID="$1"
USER="$2"
TITLE="$3"
COPIES="$4"
OPTIONS="$5"
FILENAME="$6"

log() { echo "INFO: [ondemand] $*" >&2; }

log "Job $JOB_ID de $USER: '$TITLE' ($COPIES cópias)"

# Se FILENAME vazio, ler de stdin
if [ -z "$FILENAME" ]; then
    TMPFILE=$(mktemp /tmp/cups_ondemand_XXXXXX)
    cat > "$TMPFILE"
    FILENAME="$TMPFILE"
    CLEANUP=1
else
    CLEANUP=0
fi

MIME=$(file -b --mime-type "$FILENAME")
log "Tipo: $MIME"
PRINTFILE="$FILENAME"

# Converter PostScript/PDF para imagem
if echo "$MIME" | grep -qE "postscript|pdf"; then
    log "Convertendo $MIME para JPEG..."
    JPGFILE=$(mktemp /tmp/cups_ondemand_XXXXXX.jpg)

    if command -v gs &>/dev/null; then
        gs -dBATCH -dNOPAUSE -sDEVICE=jpeg -dJPEGQ=95 \
           -r300 -dFirstPage=1 -dLastPage=1 \
           -sOutputFile="$JPGFILE" "$FILENAME" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$JPGFILE" ]; then
            PRINTFILE="$JPGFILE"
            log "Conversão GS OK"
        else
            rm -f "$JPGFILE"
        fi
    fi

    # Fallback: pdftoppm
    if [ "$PRINTFILE" = "$FILENAME" ] && command -v pdftoppm &>/dev/null; then
        PPMBASE=$(mktemp /tmp/cups_ondemand_XXXXXX)
        pdftoppm -jpeg -r 300 -f 1 -l 1 "$FILENAME" "$PPMBASE" 2>/dev/null
        PPMFILE=$(ls "${PPMBASE}"*.jpg 2>/dev/null | head -1)
        if [ -n "$PPMFILE" ] && [ -s "$PPMFILE" ]; then
            PRINTFILE="$PPMFILE"
            log "Conversão pdftoppm OK"
        else
            rm -f "${PPMBASE}"*
        fi
    fi

    # Fallback: ImageMagick
    if [ "$PRINTFILE" = "$FILENAME" ] && command -v convert &>/dev/null; then
        IMGFILE=$(mktemp /tmp/cups_ondemand_XXXXXX.jpg)
        convert -density 300 "${FILENAME}[0]" -quality 95 "$IMGFILE" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$IMGFILE" ]; then
            PRINTFILE="$IMGFILE"
            log "Conversão ImageMagick OK"
        else
            rm -f "$IMGFILE"
        fi
    fi

    if [ "$PRINTFILE" = "$FILENAME" ]; then
        log "ERRO: Não foi possível converter $MIME"
        [ "$CLEANUP" = "1" ] && rm -f "$TMPFILE"
        exit 1
    fi
fi

# Enviar para API
log "Enviando para $ONDEMAND_URL/print ($COPIES cópias)..."
RESPONSE=$(curl -s --max-time 300 \
    -X POST "$ONDEMAND_URL/print" \
    -F "file=@${PRINTFILE};filename=${TITLE:-print_job}.jpg" \
    -F "copies=${COPIES:-1}" \
    -w "\n%{http_code}" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
log "HTTP: $HTTP_CODE"

# Cleanup
[ "$CLEANUP" = "1" ] && rm -f "$TMPFILE"
[ "$PRINTFILE" != "$FILENAME" ] && rm -f "$PRINTFILE"

[ "$HTTP_CODE" = "200" ] && exit 0 || { log "ERRO: HTTP $HTTP_CODE"; exit 1; }
BACKEND_EOF

# Substituir URL no backend
sed -i "s|__API_URL__|${API_URL}|g" "$BACKEND_PATH"
chmod 700 "$BACKEND_PATH"
chown root:root "$BACKEND_PATH"
ok "Backend CUPS instalado: $BACKEND_PATH"

# Adicionar impressora CUPS
DEVICE_URI="ondemand://${SERVER_IP}:${SERVICE_PORT}"

if lpstat -p "$PRINTER_NAME" &>/dev/null 2>&1; then
    # Atualizar URI se mudou
    CURRENT_URI=$(lpstat -v "$PRINTER_NAME" 2>/dev/null | awk '{print $NF}')
    if [[ "$CURRENT_URI" == "$DEVICE_URI" ]]; then
        ok "Impressora '$PRINTER_NAME' já configurada (URI correto)"
    else
        lpadmin -p "$PRINTER_NAME" -v "$DEVICE_URI" 2>/dev/null
        ok "URI da impressora '$PRINTER_NAME' atualizado"
    fi
else
    lpadmin -p "$PRINTER_NAME" \
        -v "$DEVICE_URI" \
        -m raw \
        -D "$PRINTER_DESC" \
        -L "homelab (${SERVER_IP})" \
        -o printer-is-shared=false 2>/dev/null

    cupsenable "$PRINTER_NAME" 2>/dev/null
    cupsaccept "$PRINTER_NAME" 2>/dev/null
    ok "Impressora '$PRINTER_NAME' adicionada ao CUPS"
fi

# Definir como padrão se não há outra
DEFAULT_PRINTER=$(lpstat -d 2>/dev/null | awk -F': ' '{print $2}')
if [[ -z "$DEFAULT_PRINTER" ]]; then
    lpadmin -d "$PRINTER_NAME" 2>/dev/null
    ok "Impressora '$PRINTER_NAME' definida como padrão"
else
    info "Impressora padrão atual: $DEFAULT_PRINTER"
fi

# ─── Etapa 5: Instalar script utilitário "scan" ─────────────────────────────

step 5 "Instalando utilitário de scan"

cat > "$SCAN_SCRIPT" <<'SCAN_EOF'
#!/bin/bash
# scan — Escanear documentos via API On-Demand (Epson L380)
# Instalado por setup-epson-l380.sh
#
# Uso:
#   scan                        Scan padrão (300 DPI, JPEG, Color)
#   scan -p                     Preview rápido (150 DPI)
#   scan -r 600                 Scan em 600 DPI
#   scan -f png -m Gray         Scan PNG em escala de cinza
#   scan -o relatorio.jpg       Scan com nome personalizado
#   scan -v                     Scan e abrir no visualizador

API_URL="${SCAN_API_URL:-__API_URL__}"
RESOLUTION=300
FORMAT="jpeg"
MODE="Color"
OUTPUT=""
PREVIEW=false
VIEW=false

show_help() {
    cat <<HELP
Uso: scan [opções]

Opções:
  -r, --resolution DPI   Resolução: 75-1200 (padrão: 300)
  -f, --format FMT       Formato: jpeg, png, tiff (padrão: jpeg)
  -m, --mode MODE        Modo: Color, Gray, Lineart (padrão: Color)
  -o, --output FILE      Arquivo de saída (padrão: ~/Documentos/Scans/scan_DATA.ext)
  -p, --preview          Preview rápido (150 DPI)
  -v, --view             Abre a imagem após escanear
  -s, --status           Mostra status do serviço
  -h, --help             Mostra esta ajuda

Exemplos:
  scan                          Scan padrão A4 300 DPI Color JPEG
  scan -p -v                    Preview rápido e abre para visualizar
  scan -r 600 -f png            Scan 600 DPI em PNG
  scan -m Gray -o doc.jpg       Scan em escala de cinza
HELP
}

show_status() {
    echo "Consultando serviço..."
    STATUS=$(curl -sf --connect-timeout 5 "$API_URL/status" 2>/dev/null)
    if [[ -z "$STATUS" ]]; then
        echo "❌ Serviço inacessível em $API_URL"
        exit 1
    fi
    echo "$STATUS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
c = d.get('config', {})
print(f\"✅ Serviço ativo\")
print(f\"   VM: {d.get('vm_status','?')}\")
print(f\"   Impressora: {c.get('printer','?')}\")
print(f\"   IP VM: {c.get('vm_ip','?')}\")
print(f\"   Scans: {d.get('scans_completed',0)} ok / {d.get('scans_failed',0)} falhas\")
print(f\"   Impressões: {d.get('jobs_completed',0)} ok / {d.get('jobs_failed',0)} falhas\")
" 2>/dev/null || echo "$STATUS" | python3 -m json.tool 2>/dev/null || echo "$STATUS"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--resolution) RESOLUTION="$2"; shift 2 ;;
        -f|--format)     FORMAT="$2"; shift 2 ;;
        -m|--mode)       MODE="$2"; shift 2 ;;
        -o|--output)     OUTPUT="$2"; shift 2 ;;
        -p|--preview)    PREVIEW=true; RESOLUTION=150; shift ;;
        -v|--view)       VIEW=true; shift ;;
        -s|--status)     show_status ;;
        -h|--help)       show_help; exit 0 ;;
        *) echo "Opção desconhecida: $1. Use -h para ajuda."; exit 1 ;;
    esac
done

# Extensão
case "$FORMAT" in
    jpeg) EXT="jpg" ;;
    png)  EXT="png" ;;
    tiff) EXT="tif" ;;
    *)    EXT="$FORMAT" ;;
esac

# Nome do arquivo
if [[ -z "$OUTPUT" ]]; then
    SCAN_DIR="${HOME}/Documentos/Scans"
    mkdir -p "$SCAN_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTPUT="${SCAN_DIR}/scan_${TIMESTAMP}.${EXT}"
fi

# Criar diretório se necessário
mkdir -p "$(dirname "$OUTPUT")" 2>/dev/null

echo "🖨️  Escaneando..."
echo "   Resolução: ${RESOLUTION} DPI"
echo "   Formato:   ${FORMAT}"
echo "   Modo:      ${MODE}"
echo "   Saída:     ${OUTPUT}"
echo ""

# Verificar serviço
if ! curl -sf --connect-timeout 5 "$API_URL/status" >/dev/null 2>&1; then
    echo "❌ Serviço inacessível em $API_URL"
    echo "   Verifique a conectividade com o homelab."
    exit 1
fi

START_TIME=$(date +%s)

if $PREVIEW; then
    HTTP_CODE=$(curl -s --max-time 300 -X GET \
        -o "$OUTPUT" -w "%{http_code}" \
        "$API_URL/scan/preview")
else
    HTTP_CODE=$(curl -s --max-time 600 -X POST \
        -o "$OUTPUT" -w "%{http_code}" \
        "$API_URL/scan?resolution=${RESOLUTION}&format=${FORMAT}&mode=${MODE}")
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [[ "$HTTP_CODE" == "200" ]] && [[ -s "$OUTPUT" ]]; then
    SIZE=$(du -h "$OUTPUT" | cut -f1)
    echo "✅ Scan concluído! (${ELAPSED}s)"
    echo "   Arquivo: $OUTPUT"
    echo "   Tamanho: $SIZE"

    # Mostrar info da imagem se possível
    if command -v python3 &>/dev/null; then
        python3 -c "
from PIL import Image
img = Image.open('$OUTPUT')
dpi = img.info.get('dpi', ('?','?'))
print(f'   Dimensões: {img.size[0]}x{img.size[1]} px')
print(f'   DPI: {dpi[0]}x{dpi[1]}')
" 2>/dev/null || true
    fi

    if $VIEW; then
        xdg-open "$OUTPUT" 2>/dev/null &
    fi
else
    echo "❌ Erro no scan (HTTP $HTTP_CODE, ${ELAPSED}s)"
    if [[ -s "$OUTPUT" ]]; then
        head -c 500 "$OUTPUT" 2>/dev/null
        echo ""
    fi
    rm -f "$OUTPUT"
    exit 1
fi
SCAN_EOF

# Substituir URL no script
sed -i "s|__API_URL__|${API_URL}|g" "$SCAN_SCRIPT"
chmod +x "$SCAN_SCRIPT"
ok "Script 'scan' instalado em $SCAN_SCRIPT"
info "Uso: scan -h para ver opções"

# ─── Etapa 6: Testes ────────────────────────────────────────────────────────

step 6 "Validação"

TESTS_PASSED=0
TESTS_TOTAL=0

run_test() {
    local desc="$1"
    local cmd="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if eval "$cmd" >/dev/null 2>&1; then
        ok "$desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        fail "$desc"
    fi
}

run_test "Serviço acessível (HTTP)" \
    "curl -sf --connect-timeout 5 '${API_URL}/status'"

run_test "eSCL Capabilities" \
    "curl -sf --connect-timeout 5 '${API_URL}/eSCL/ScannerCapabilities'"

run_test "Scanner detectável via SANE" \
    "scanimage -L 2>/dev/null | grep -qi 'airscan\|escl.*${SERVER_IP}'"

run_test "Backend CUPS instalado" \
    "test -x '$BACKEND_PATH'"

run_test "Impressora CUPS configurada" \
    "lpstat -p '$PRINTER_NAME' 2>/dev/null"

run_test "Script 'scan' acessível" \
    "which scan"

if ! $SKIP_TEST && ! $NON_INTERACTIVE; then
    echo ""
    ask "Deseja fazer um teste de impressão real? [s/N]: "
    read -r do_print
    if [[ "$do_print" == "s" || "$do_print" == "S" ]]; then
        info "Enviando página de teste para impressão..."
        PRINT_RESULT=$(curl -sf --max-time 300 \
            -X POST "${API_URL}/print" \
            -F "path=/tmp/test_page.jpg" \
            -F "copies=1" 2>/dev/null || echo "ERRO")
        if echo "$PRINT_RESULT" | grep -q '"status".*"sent"'; then
            ok "Impressão de teste enviada com sucesso!"
        else
            warn "Impressão pode ter falhado: $PRINT_RESULT"
        fi
    fi

    ask "Deseja fazer um teste de scan real? [s/N]: "
    read -r do_scan
    if [[ "$do_scan" == "s" || "$do_scan" == "S" ]]; then
        info "Escaneando página de teste (150 DPI, rápido)..."
        SCAN_OUT="/tmp/setup_test_scan.jpg"
        HTTP=$(curl -sf --max-time 300 \
            -X POST "${API_URL}/scan?resolution=150&format=jpeg&mode=Color" \
            -o "$SCAN_OUT" -w "%{http_code}" 2>/dev/null)
        if [[ "$HTTP" == "200" ]] && [[ -s "$SCAN_OUT" ]]; then
            SIZE=$(du -h "$SCAN_OUT" | cut -f1)
            ok "Scan de teste OK ($SIZE)"
            info "Arquivo: $SCAN_OUT"
        else
            warn "Scan pode ter falhado (HTTP $HTTP)"
        fi
    fi
fi

# ─── Resumo ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Resumo da Instalação${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Servidor:    ${BOLD}${SERVER_IP}:${SERVICE_PORT}${NC}"
echo -e "  Impressora:  ${BOLD}${PRINTER_NAME}${NC} (CUPS: ondemand://...)"
echo -e "  Scanner:     ${BOLD}${SCANNER_NAME}${NC} (eSCL/AirScan)"
echo -e "  Testes:      ${BOLD}${TESTS_PASSED}/${TESTS_TOTAL} passaram${NC}"
echo ""
echo -e "  ${BOLD}Como usar:${NC}"
echo ""
echo -e "  ${GREEN}Imprimir:${NC}"
echo "    lp -d $PRINTER_NAME arquivo.pdf"
echo "    lpr -P $PRINTER_NAME foto.jpg"
echo ""
echo -e "  ${GREEN}Escanear:${NC}"
echo "    scan                    # Scan 300 DPI Color JPEG"
echo "    scan -p -v              # Preview rápido e visualizar"
echo "    scan -r 600 -f png      # 600 DPI em PNG"
echo "    scan -s                 # Status do serviço"
echo ""
echo -e "  ${GREEN}GUI (simple-scan / Document Scanner):${NC}"
echo "    O scanner aparece como '${SCANNER_NAME}'"
echo ""
echo -e "  ${GREEN}Desinstalar:${NC}"
echo "    sudo $0 --uninstall"
echo ""

if [[ $TESTS_PASSED -eq $TESTS_TOTAL ]]; then
    echo -e "  ${GREEN}${BOLD}✓ Instalação concluída com sucesso!${NC}"
else
    echo -e "  ${YELLOW}${BOLD}⚠ Instalação concluída com $(( TESTS_TOTAL - TESTS_PASSED )) aviso(s)${NC}"
fi
echo ""
