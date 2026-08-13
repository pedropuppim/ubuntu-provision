#!/usr/bin/env bash
#
# Instala utilitários gerais no Ubuntu 24.04:
# git, curl, wget, htop, btop, zip, unzip e outras ferramentas comuns.
#
# Uso: sudo ./instalar-utilitarios.sh

set -euo pipefail

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./instalar-utilitarios.sh)" >&2
    exit 1
fi

# --- Lista de pacotes ---------------------------------------------------------

PACOTES=(
    # Essenciais
    git
    curl
    wget
    ca-certificates
    gnupg

    # Compactação
    zip
    unzip
    tar
    gzip

    # Monitoramento
    htop
    btop
    ncdu

    # Rede
    net-tools
    dnsutils
    traceroute

    # Terminal / produtividade
    tmux
    tree
    jq
    vim
    nano
    rsync

    # Compilação (útil para pacotes npm/pip com dependências nativas)
    build-essential
)

# --- Instalação ----------------------------------------------------------------

echo ">>> Atualizando índice de pacotes..."
apt-get update

echo ">>> Instalando ${#PACOTES[@]} pacotes..."
apt-get install -y "${PACOTES[@]}"

# --- Verificação final ---------------------------------------------------------

echo ""
echo ">>> Versões instaladas (principais):"
echo "git:  $(git --version | awk '{print $3}')"
echo "curl: $(curl --version | head -n1 | awk '{print $2}')"
echo "htop: $(htop --version | awk '{print $2}')"
echo "btop: $(btop --version | awk '{print $3}')"
echo "zip:  $(zip -v | sed -n 's/^This is Zip \([0-9.]*\).*/\1/p')"

echo ""
echo "✅ Instalação concluída!"
