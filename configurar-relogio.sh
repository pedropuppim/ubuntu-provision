#!/usr/bin/env bash
#
# configurar-relogio.sh — Configura timezone, sincronização de horário (NTP)
# e, opcionalmente, o locale pt_BR.UTF-8.
#
# Uso: sudo ./configurar-relogio.sh [timezone]
# Exemplo: sudo ./configurar-relogio.sh America/Sao_Paulo

set -euo pipefail

TZ_PADRAO="America/Sao_Paulo"

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./configurar-relogio.sh)" >&2
    exit 1
fi

# --- Timezone ----------------------------------------------------------------

TIMEZONE="${1:-}"

if [[ -z "$TIMEZONE" ]]; then
    echo "Timezone atual: $(timedatectl show -p Timezone --value)"
    read -rp "Qual timezone deseja usar? [$TZ_PADRAO] " TIMEZONE
    TIMEZONE="${TIMEZONE:-$TZ_PADRAO}"
fi

if ! timedatectl list-timezones | grep -qx "$TIMEZONE"; then
    echo "Erro: timezone '$TIMEZONE' inválido." >&2
    echo "Liste os disponíveis com: timedatectl list-timezones" >&2
    exit 1
fi

echo ">>> Aplicando timezone $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"

# --- Sincronização de horário (NTP) ------------------------------------------

if ! dpkg -s systemd-timesyncd >/dev/null 2>&1; then
    echo ">>> Instalando systemd-timesyncd..."
    apt-get update -qq
    apt-get install -y systemd-timesyncd
fi

echo ">>> Ativando sincronização automática (NTP)..."
if timedatectl set-ntp true 2>/dev/null; then
    systemctl restart systemd-timesyncd 2>/dev/null || true
else
    echo "Aviso: não foi possível ativar o NTP." >&2
    echo "       Em containers (LXC/Docker) o relógio vem do host — configure lá." >&2
fi

# --- Locale pt_BR (opcional) -------------------------------------------------

read -rp "Gerar o locale pt_BR.UTF-8 e defini-lo como padrão do sistema? [s/N] " RESPOSTA
if [[ "${RESPOSTA,,}" == "s" ]]; then
    if ! locale -a 2>/dev/null | grep -qiE '^pt_BR\.utf-?8$'; then
        echo ">>> Gerando locale pt_BR.UTF-8..."
        locale-gen pt_BR.UTF-8
    fi
    update-locale LANG=pt_BR.UTF-8
    echo ">>> Locale padrão definido como pt_BR.UTF-8 (vale para novas sessões)."
fi

# --- Verificação final -------------------------------------------------------

echo ""
timedatectl
echo ""
echo "✅ Relógio configurado!"
