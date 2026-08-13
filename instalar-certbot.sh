#!/usr/bin/env bash
#
# instalar-certbot.sh — Instala o Certbot (Let's Encrypt) com o plugin do
# servidor web detectado (nginx ou apache). Se nenhum dos dois estiver
# instalado, oferece instalar o nginx.
#
# Uso: sudo ./instalar-certbot.sh

set -euo pipefail

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./instalar-certbot.sh)" >&2
    exit 1
fi

# --- Detecta o servidor web --------------------------------------------------

TEM_NGINX=0
TEM_APACHE=0
command -v nginx >/dev/null 2>&1 && TEM_NGINX=1
command -v apache2 >/dev/null 2>&1 && TEM_APACHE=1

PLUGIN=""
if [[ $TEM_NGINX -eq 1 && $TEM_APACHE -eq 1 ]]; then
    echo "Encontrei nginx E apache instalados."
    read -rp "Qual deles o certbot deve configurar? [1=nginx, 2=apache] " RESPOSTA
    case "$RESPOSTA" in
        1) PLUGIN="nginx" ;;
        2) PLUGIN="apache" ;;
        *) echo "Erro: opção inválida." >&2; exit 1 ;;
    esac
elif [[ $TEM_NGINX -eq 1 ]]; then
    PLUGIN="nginx"
    echo ">>> Servidor web detectado: nginx"
elif [[ $TEM_APACHE -eq 1 ]]; then
    PLUGIN="apache"
    echo ">>> Servidor web detectado: apache"
else
    echo "Nenhum servidor web (nginx ou apache) foi encontrado."
    read -rp "Deseja instalar o nginx agora? [s/N] " RESPOSTA
    if [[ "${RESPOSTA,,}" != "s" ]]; then
        echo "Operação cancelada: o certbot precisa de um servidor web para configurar."
        echo "(Para certificado sem servidor web, veja o modo standalone: certbot certonly --standalone)"
        exit 0
    fi
    echo ">>> Instalando nginx..."
    apt-get update -qq
    apt-get install -y nginx
    systemctl enable --now nginx
    PLUGIN="nginx"
fi

# --- Firewall: portas 80 e 443 -----------------------------------------------

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    if ! ufw status | grep -qE '(^| )443(/tcp)?\s'; then
        echo ""
        echo "AVISO: o ufw está ativo e as portas 80/443 parecem bloqueadas."
        echo "       O Let's Encrypt precisa da porta 80 para emitir/renovar certificados."
        read -rp "Liberar as portas 80 e 443 no ufw agora? [s/N] " RESPOSTA
        if [[ "${RESPOSTA,,}" == "s" ]]; then
            ufw allow 80/tcp comment 'HTTP'
            ufw allow 443/tcp comment 'HTTPS'
            echo ">>> Portas 80 e 443 liberadas."
        fi
    fi
fi

# --- Instala certbot + plugin ------------------------------------------------

echo ">>> Instalando certbot e python3-certbot-$PLUGIN..."
apt-get update -qq
apt-get install -y certbot "python3-certbot-$PLUGIN"

# --- Renovação automática ----------------------------------------------------

if systemctl is-enabled certbot.timer >/dev/null 2>&1; then
    echo ">>> Renovação automática ativa (certbot.timer)."
else
    echo ">>> Habilitando renovação automática (certbot.timer)..."
    systemctl enable --now certbot.timer
fi

# --- Emissão de certificado (opcional) ---------------------------------------

echo ""
read -rp "Deseja emitir um certificado agora? [s/N] " RESPOSTA
if [[ "${RESPOSTA,,}" == "s" ]]; then
    read -rp "Domínio(s), separados por espaço (ex: exemplo.com www.exemplo.com): " DOMINIOS
    if [[ -z "$DOMINIOS" ]]; then
        echo "Erro: nenhum domínio informado." >&2
        exit 1
    fi
    ARGS=()
    for d in $DOMINIOS; do
        ARGS+=(-d "$d")
    done
    # O certbot pergunta e-mail e termos de uso interativamente
    certbot --"$PLUGIN" "${ARGS[@]}"
else
    echo ""
    echo "Para emitir um certificado depois:"
    echo "  sudo certbot --$PLUGIN -d seu-dominio.com"
fi

# --- Verificação final -------------------------------------------------------

echo ""
certbot --version
echo ""
echo "✅ Certbot instalado com o plugin do $PLUGIN!"
echo "   - Renovação automática: certbot.timer (systemctl status certbot.timer)"
echo "   - Teste de renovação:   sudo certbot renew --dry-run"
