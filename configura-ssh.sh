#!/usr/bin/env bash
#
# configura-ssh.sh — Configura o SSH do Ubuntu para:
#   - Escutar na porta escolhida pelo usuário (padrão: 22022)
#   - Não permitir login como root
#
# Uso: sudo ./configura-ssh.sh
#
set -euo pipefail

DROPIN=/etc/ssh/sshd_config.d/99-hardening.conf

# ---------------------------------------------------------------------------
# Pré-checagens
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "ERRO: execute como root (sudo $0)" >&2
    exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
    echo "openssh-server não encontrado, instalando..."
    apt-get update -qq
    apt-get install -y openssh-server
fi

# ---------------------------------------------------------------------------
# Pergunta a porta desejada
# ---------------------------------------------------------------------------
while true; do
    read -rp "Qual porta o SSH deve usar? [22022]: " PORTA
    PORTA=${PORTA:-22022}
    if [[ "$PORTA" =~ ^[0-9]+$ ]] && (( PORTA >= 1 && PORTA <= 65535 )); then
        break
    fi
    echo "Porta inválida: informe um número entre 1 e 65535." >&2
done

# ---------------------------------------------------------------------------
# Backup da configuração atual
# ---------------------------------------------------------------------------
BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
cp /etc/ssh/sshd_config "$BACKUP"
echo "Backup salvo em: $BACKUP"

# ---------------------------------------------------------------------------
# Configuração via drop-in (o Include no topo do sshd_config faz o drop-in
# vencer, pois no OpenSSH a primeira ocorrência de cada opção prevalece)
# ---------------------------------------------------------------------------
mkdir -p /etc/ssh/sshd_config.d
cat > "$DROPIN" <<EOF
# Gerado por configura-ssh.sh em $(date '+%Y-%m-%d %H:%M:%S')
Port $PORTA
PermitRootLogin no
EOF
echo "Criado $DROPIN"

# Garante que o sshd_config principal tem o Include (padrão no Ubuntu 20.04+)
if ! grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
    echo "Include adicionado ao /etc/ssh/sshd_config"
fi

# ---------------------------------------------------------------------------
# Ubuntu 22.10+ usa socket activation (ssh.socket) e ignora o Port do
# sshd_config; desativa o socket e usa o serviço tradicional
# ---------------------------------------------------------------------------
if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
    echo "Desativando ssh.socket (socket activation ignora a porta do sshd_config)..."
    systemctl disable --now ssh.socket
    systemctl enable ssh.service
fi

# ---------------------------------------------------------------------------
# Valida a configuração antes de aplicar
# ---------------------------------------------------------------------------
# O sshd -t exige o diretório de privilege separation, que o systemd só cria
# quando o serviço sobe
mkdir -p -m 0755 /run/sshd

if ! sshd -t; then
    echo "ERRO: configuração inválida, restaurando backup..." >&2
    rm -f "$DROPIN"
    cp "$BACKUP" /etc/ssh/sshd_config
    exit 1
fi

# ---------------------------------------------------------------------------
# Firewall: libera a porta nova antes de reiniciar o serviço
# ---------------------------------------------------------------------------
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw allow "$PORTA/tcp" comment 'SSH'
    echo "Regra do ufw adicionada para $PORTA/tcp"
    echo "AVISO: a porta 22 NÃO foi removida do ufw; remova depois de testar:"
    echo "       sudo ufw delete allow 22/tcp"
fi

# ---------------------------------------------------------------------------
# Aplica
# ---------------------------------------------------------------------------
systemctl restart ssh
systemctl --no-pager --lines=0 status ssh

echo
echo "============================================================"
echo " SSH configurado com sucesso:"
echo "   - Porta: $PORTA"
echo "   - Login root: bloqueado"
echo
echo " IMPORTANTE: NÃO feche esta sessão ainda!"
echo " Teste em outro terminal:"
echo "   ssh -p $PORTA $(logname 2>/dev/null || echo usuario)@$(hostname -I 2>/dev/null | awk '{print $1}')"
echo "============================================================"
