#!/usr/bin/env bash
#
# info-servidor.sh — Mostra um resumo do estado do servidor: sistema, recursos,
# rede, portas escutando, firewall, SSH, Docker, Node.js e atualizações
# pendentes. Somente leitura — não altera nada.
#
# Uso: ./info-servidor.sh
#      sudo ./info-servidor.sh   (mostra também firewall e processos das portas)

set -euo pipefail

titulo() {
    echo ""
    echo "=== $1 ==="
}

# --- Sistema -----------------------------------------------------------------

titulo "Sistema"
echo "Hostname : $(hostname)"
echo "SO       : $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Kernel   : $(uname -r) ($(uname -m))"
echo "Uptime   : $(uptime -p)"

# --- CPU ---------------------------------------------------------------------

titulo "CPU"
MODELO=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//' || true)
echo "Modelo  : ${MODELO:-desconhecido}"
echo "Núcleos : $(nproc)"
echo "Load    : $(cut -d' ' -f1-3 /proc/loadavg)"

# --- Memória e swap ----------------------------------------------------------

titulo "Memória"
free -h

titulo "Swap"
if [[ -n "$(swapon --show 2>/dev/null)" ]]; then
    swapon --show
else
    echo "(sem swap ativo)"
fi

# --- Disco -------------------------------------------------------------------

titulo "Disco"
df -h -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null || df -h

# --- Rede --------------------------------------------------------------------

titulo "Rede"
echo "IP(s)   : $(hostname -I 2>/dev/null || echo 'desconhecido')"
echo "Gateway : $(ip route 2>/dev/null | awk '/^default/ {print $3; exit}' || true)"

titulo "Portas escutando"
# Sem root o ss não mostra o nome do processo, mas lista as portas
ss -tulnp 2>/dev/null || ss -tuln

# --- Firewall ----------------------------------------------------------------

titulo "Firewall (ufw)"
if ! command -v ufw >/dev/null 2>&1; then
    echo "(ufw não instalado)"
elif [[ $EUID -ne 0 ]]; then
    echo "(execute com sudo para ver o status do ufw)"
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
        || echo "(configuração padrão: porta 22)"
fi

# --- Docker ------------------------------------------------------------------

titulo "Docker"
if command -v docker >/dev/null 2>&1; then
    docker --version
    if docker ps >/dev/null 2>&1; then
        docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
    else
        echo "(sem permissão para listar containers — use sudo ou o grupo docker)"
    fi
else
    echo "(não instalado)"
fi

# --- Node.js -----------------------------------------------------------------

titulo "Node.js"
if command -v node >/dev/null 2>&1; then
    echo "node $(node --version) / npm $(npm --version 2>/dev/null || echo '?')"
else
    echo "(não instalado)"
fi

# --- Atualizações ------------------------------------------------------------

titulo "Atualizações"
PENDENTES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ' || true)
echo "Pacotes com atualização pendente: ${PENDENTES:-0}"
if [[ -f /var/run/reboot-required ]]; then
    echo "⚠️  Reboot pendente ($(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' '))"
else
    echo "Reboot pendente: não"
fi

echo ""
