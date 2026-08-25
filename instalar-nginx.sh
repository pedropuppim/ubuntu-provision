#!/usr/bin/env bash
#
# instalar-nginx.sh — Instala o nginx, habilita o serviço e (opcionalmente)
# libera as portas 80/443 no ufw. Para HTTPS, use depois o instalar-certbot.sh.
#
# Uso: sudo ./instalar-nginx.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./instalar-nginx.sh)" >&2
    exit 1
fi

# --- Instalação ----------------------------------------------------------------

if command -v nginx >/dev/null 2>&1; then
    echo ">>> nginx já instalado: $(nginx -v 2>&1)"
    read -rp "Reinstalar/atualizar mesmo assim? [s/N] " RESPOSTA
    if [[ "${RESPOSTA,,}" != "s" ]]; then
        echo "Nada a fazer."
        exit 0
    fi
fi

echo ">>> Instalando nginx..."
apt-get update -qq
apt-get install -y nginx

echo ">>> Habilitando e iniciando o serviço..."
systemctl enable --now nginx

# --- Firewall: portas 80 e 443 -------------------------------------------------

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    if ! ufw status | grep -qE '(^| )(80|443)(/tcp)?\s'; then
        echo ""
        echo "AVISO: o ufw está ativo e as portas 80/443 parecem bloqueadas."
        read -rp "Liberar as portas 80 e 443 no ufw agora? [s/N] " RESPOSTA
        if [[ "${RESPOSTA,,}" == "s" ]]; then
            ufw allow 80/tcp comment 'HTTP'
            ufw allow 443/tcp comment 'HTTPS'
            echo ">>> Portas 80 e 443 liberadas."
        fi
    fi
fi

# --- Verificação final ----------------------------------------------------------

echo ""
if systemctl is-active --quiet nginx; then
    nginx -v
    echo ""
    echo "✅ nginx instalado e rodando!"
    echo "   - Teste local:       curl -I http://localhost"
    echo "   - Sites disponíveis: /etc/nginx/sites-available/"
    echo "   - Para HTTPS:        sudo ./instalar-certbot.sh"
else
    echo "[-] nginx instalado, mas o serviço não está ativo. Verifique:" >&2
    echo "    sudo systemctl status nginx" >&2
    echo "    sudo nginx -t" >&2
    exit 1
fi
