#!/usr/bin/env bash
#
# atualizacoes-automaticas.sh — Configura atualizações automáticas de segurança
# via unattended-upgrades:
#   - Atualiza a lista de pacotes e aplica patches de segurança diariamente;
#   - Remove dependências órfãs após as atualizações;
#   - Opcionalmente reinicia o servidor automaticamente quando necessário.
#
# Uso: sudo ./atualizacoes-automaticas.sh

set -euo pipefail

PERIODIC=/etc/apt/apt.conf.d/20auto-upgrades
LOCAL=/etc/apt/apt.conf.d/52unattended-upgrades-local

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./atualizacoes-automaticas.sh)" >&2
    exit 1
fi

# --- Instala o unattended-upgrades -------------------------------------------

if ! dpkg -s unattended-upgrades >/dev/null 2>&1; then
    echo ">>> Instalando unattended-upgrades..."
    apt-get update -qq
    apt-get install -y unattended-upgrades
fi

# --- Reboot automático (opcional) --------------------------------------------

REBOOT="false"
HORARIO="04:00"
read -rp "Reiniciar automaticamente quando uma atualização exigir reboot? [s/N] " RESPOSTA
if [[ "${RESPOSTA,,}" == "s" ]]; then
    REBOOT="true"
    read -rp "Horário do reboot automático [04:00]: " HORA_INFORMADA
    if [[ -n "$HORA_INFORMADA" ]]; then
        if [[ ! "$HORA_INFORMADA" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            echo "Erro: horário inválido (use o formato HH:MM, ex: 04:00)." >&2
            exit 1
        fi
        HORARIO="$HORA_INFORMADA"
    fi
fi

# --- Habilita a execução periódica -------------------------------------------

echo ">>> Configurando execução diária ($PERIODIC)..."
cat > "$PERIODIC" <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# --- Ajustes locais (drop-in; não altera o 50unattended-upgrades do pacote) ---

echo ">>> Gravando ajustes em $LOCAL..."
cat > "$LOCAL" <<EOF
// Gerado por atualizacoes-automaticas.sh em $(date '+%Y-%m-%d %H:%M:%S')
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "$REBOOT";
EOF

if [[ "$REBOOT" == "true" ]]; then
    echo "Unattended-Upgrade::Automatic-Reboot-Time \"$HORARIO\";" >> "$LOCAL"
fi

# --- Habilita os timers ------------------------------------------------------

echo ">>> Habilitando timers do apt..."
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer

# --- Verificação final -------------------------------------------------------

echo ""
echo ">>> Validando configuração (dry-run, pode demorar alguns segundos)..."
unattended-upgrade --dry-run >/dev/null

echo ""
echo "✅ Atualizações automáticas de segurança configuradas!"
echo "   - Origem: patches de segurança do Ubuntu (padrão do pacote)"
echo "   - Dependências órfãs: removidas automaticamente"
if [[ "$REBOOT" == "true" ]]; then
    echo "   - Reboot automático: sim, às $HORARIO"
else
    echo "   - Reboot automático: não (reinicie manualmente quando /var/run/reboot-required existir)"
fi
echo ""
echo "Logs em: /var/log/unattended-upgrades/"
