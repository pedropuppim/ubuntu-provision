#!/usr/bin/env bash
#
# instalar-fail2ban.sh — Instala e configura o fail2ban com jail para o SSH.
# Detecta automaticamente a(s) porta(s) do sshd (incluindo portas customizadas
# como 22022) e cria /etc/fail2ban/jail.local com backend systemd (journald),
# adequado ao Ubuntu 24.04.
#
# Uso: sudo ./instalar-fail2ban.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./instalar-fail2ban.sh)" >&2
    exit 1
fi

# --- Detecta porta(s) do SSH (mesma lógica do firewall.sh) --------------------

SSH_PORTAS=()
if pgrep -x sshd >/dev/null 2>&1; then
    mapfile -t SSH_PORTAS < <(ss -tlnp 2>/dev/null | awk '/sshd/ {n=split($4,a,":"); print a[n]}' | sort -un)
fi
if [[ ${#SSH_PORTAS[@]} -eq 0 ]]; then
    mapfile -t SSH_PORTAS < <(sshd -T 2>/dev/null | awk '$1=="port"{print $2}' | sort -un) || true
fi
if [[ ${#SSH_PORTAS[@]} -eq 0 ]]; then
    SSH_PORTAS=(22)
fi

PORTAS_DETECTADAS=$(IFS=,; echo "${SSH_PORTAS[*]}")
echo ">>> Porta(s) SSH detectada(s): $PORTAS_DETECTADAS"

read -rp "Porta(s) SSH a proteger, separadas por vírgula [Padrão: $PORTAS_DETECTADAS]: " PORTAS_INPUT
PORTAS_INPUT=${PORTAS_INPUT:-$PORTAS_DETECTADAS}
PORTAS_INPUT=$(echo "$PORTAS_INPUT" | tr -d ' ')

for porta in ${PORTAS_INPUT//,/ }; do
    if ! [[ "$porta" =~ ^[0-9]+$ ]] || (( porta < 1 || porta > 65535 )); then
        echo "ERRO: porta inválida: '$porta' (use números de 1 a 65535)" >&2
        exit 1
    fi
done

# --- Parâmetros da jail --------------------------------------------------------

read -rp "Máximo de tentativas antes de banir [Padrão: 5]: " MAXRETRY
MAXRETRY=${MAXRETRY:-5}
read -rp "Tempo de banimento (ex: 1h, 30m, 86400) [Padrão: 1h]: " BANTIME
BANTIME=${BANTIME:-1h}
read -rp "Janela de detecção das tentativas (ex: 10m) [Padrão: 10m]: " FINDTIME
FINDTIME=${FINDTIME:-10m}

if ! [[ "$MAXRETRY" =~ ^[0-9]+$ ]]; then
    echo "ERRO: maxretry inválido: '$MAXRETRY'" >&2
    exit 1
fi

# --- Instalação ----------------------------------------------------------------

echo ">>> Instalando fail2ban..."
apt-get update -qq
apt-get install -y fail2ban

# --- Configuração (jail.local, nunca editar jail.conf) --------------------------

JAIL_LOCAL="/etc/fail2ban/jail.local"
if [[ -f "$JAIL_LOCAL" ]]; then
    BACKUP="$JAIL_LOCAL.bak"
    echo ">>> $JAIL_LOCAL já existe. Salvando backup em $BACKUP"
    cp "$JAIL_LOCAL" "$BACKUP"
fi

echo ">>> Gerando $JAIL_LOCAL..."
cat <<EOF > "$JAIL_LOCAL"
[DEFAULT]
# Ubuntu 24.04 usa journald; sem backend systemd o fail2ban não encontra os logs do sshd
backend = systemd
bantime = $BANTIME
findtime = $FINDTIME
maxretry = $MAXRETRY
# Nunca banir localhost
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = $PORTAS_INPUT
EOF

# --- Ativação -------------------------------------------------------------------

echo ">>> Habilitando e reiniciando o fail2ban..."
systemctl enable fail2ban
systemctl restart fail2ban

# Aguarda o serviço subir antes de consultar o status
sleep 2

# --- Verificação final ----------------------------------------------------------

echo ""
if fail2ban-client status sshd >/dev/null 2>&1; then
    fail2ban-client status sshd
    echo ""
    echo "✅ fail2ban instalado e protegendo o SSH na(s) porta(s): $PORTAS_INPUT"
    echo "   - Ver banidos:    sudo fail2ban-client status sshd"
    echo "   - Desbanir IP:    sudo fail2ban-client set sshd unbanip <IP>"
    echo "   - Configuração:   $JAIL_LOCAL"
else
    echo "[-] fail2ban instalado, mas a jail sshd não subiu. Verifique:" >&2
    echo "    sudo systemctl status fail2ban" >&2
    echo "    sudo journalctl -u fail2ban -n 50" >&2
    exit 1
fi
