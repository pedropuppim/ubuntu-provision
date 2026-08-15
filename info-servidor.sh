#!/usr/bin/env bash
#
# info-servidor.sh — Mostra um resumo do estado do servidor: sistema, recursos,
# rede, portas escutando, firewall, SSH, Docker, Node.js e atualizações
# pendentes. Somente leitura — não altera nada.
#
# Uso: ./info-servidor.sh
#      sudo ./info-servidor.sh   (mostra também firewall e processos das portas)

set -euo pipefail

# --- Cores (só quando a saída é um terminal e NO_COLOR não está definido) -----

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    NEGRITO=$'\e[1m'
    DIM=$'\e[2m'
    CIANO=$'\e[36m'
    VERDE=$'\e[32m'
    AMARELO=$'\e[33m'
    VERMELHO=$'\e[31m'
    RESET=$'\e[0m'
else
    NEGRITO='' DIM='' CIANO='' VERDE='' AMARELO='' VERMELHO='' RESET=''
fi

titulo() {
    echo ""
    echo "${NEGRITO}${CIANO}━━━ $1 ━━━${RESET}"
}

# rotulo "Label" "valor"  →  "Label   : valor" com o label colorido
# (padding manual porque %-8s do printf conta bytes, não caracteres acentuados)
rotulo() {
    local pad=$(( ${#1} < 8 ? 8 - ${#1} : 0 ))
    printf '%s%s%*s%s: %s\n' "$DIM" "$1" "$pad" '' "$RESET" "$2"
}

ok()    { echo "${VERDE}$1${RESET}"; }
aviso() { echo "${AMARELO}$1${RESET}"; }
nada()  { echo "${DIM}$1${RESET}"; }

# --- Sistema -----------------------------------------------------------------

titulo "Sistema"
rotulo "Hostname" "$(hostname)"
rotulo "SO" "$(. /etc/os-release && echo "$PRETTY_NAME")"
rotulo "Kernel" "$(uname -r) ($(uname -m))"
rotulo "Uptime" "$(uptime -p)"

# --- CPU ---------------------------------------------------------------------

titulo "CPU"
MODELO=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//' || true)
rotulo "Modelo" "${MODELO:-desconhecido}"
rotulo "Núcleos" "$(nproc)"
rotulo "Load" "$(cut -d' ' -f1-3 /proc/loadavg)"

# --- Memória e swap ----------------------------------------------------------

titulo "Memória"
free -h

titulo "Swap"
if [[ -n "$(swapon --show 2>/dev/null)" ]]; then
    swapon --show
else
    nada "(sem swap ativo)"
fi

# --- Disco -------------------------------------------------------------------

titulo "Disco"
df -h -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null || df -h

# --- Rede --------------------------------------------------------------------

titulo "Rede"
rotulo "IP(s)" "$(hostname -I 2>/dev/null || echo 'desconhecido')"
rotulo "Gateway" "$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}' || true)"

titulo "Portas escutando"
# Sem root o ss não mostra o nome do processo, mas lista as portas
ss -tulnp 2>/dev/null || ss -tuln

# --- Firewall ----------------------------------------------------------------

titulo "Firewall (ufw)"
if ! command -v ufw >/dev/null 2>&1; then
    nada "(ufw não instalado)"
elif [[ $EUID -ne 0 ]]; then
    aviso "(execute com sudo para ver o status do ufw)"
else
    ufw status verbose
fi

# --- SSH ---------------------------------------------------------------------

titulo "SSH"
if [[ $EUID -eq 0 ]] && command -v sshd >/dev/null 2>&1; then
    mkdir -p -m 0755 /run/sshd
    sshd -T 2>/dev/null | grep -iE '^(port|permitrootlogin|passwordauthentication) ' || true
else
    grep -rhiE '^\s*(Port|PermitRootLogin|PasswordAuthentication)\s' \
        /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null \
        || nada "(configuração padrão: porta 22)"
fi

# --- Docker ------------------------------------------------------------------

titulo "Docker"
if command -v docker >/dev/null 2>&1; then
    ok "$(docker --version)"
    if docker ps >/dev/null 2>&1; then
        docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
    else
        aviso "(sem permissão para listar containers — use sudo ou o grupo docker)"
    fi
else
    nada "(não instalado)"
fi

# --- Node.js -----------------------------------------------------------------

titulo "Node.js"
if command -v node >/dev/null 2>&1; then
    ok "node $(node --version) / npm $(npm --version 2>/dev/null || echo '?')"
else
    nada "(não instalado)"
fi

# --- Atualizações ------------------------------------------------------------

titulo "Atualizações"
PENDENTES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ' || true)
PENDENTES=${PENDENTES:-0}
if [[ $PENDENTES -gt 0 ]]; then
    aviso "Pacotes com atualização pendente: $PENDENTES"
else
    ok "Pacotes com atualização pendente: 0"
fi
if [[ -f /var/run/reboot-required ]]; then
    echo "${VERMELHO}⚠️  Reboot pendente ($(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' '))${RESET}"
else
    ok "Reboot pendente: não"
fi

echo ""
