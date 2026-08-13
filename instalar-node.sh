#!/usr/bin/env bash
#
# Instala Node.js 24 (com npm) no Ubuntu 24.04
# usando o repositório oficial NodeSource.
#
# Uso: sudo ./instalar-node.sh

set -euo pipefail

NODE_MAJOR=24

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./instalar-node.sh)" >&2
    exit 1
fi

# --- Remove versões antigas/conflitantes -------------------------------------

echo ">>> Removendo pacotes antigos (se existirem)..."
for pkg in nodejs npm libnode-dev; do
    apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

# --- Configura o repositório oficial do NodeSource ---------------------------

echo ">>> Instalando dependências..."
apt-get update
apt-get install -y ca-certificates curl gnupg

echo ">>> Adicionando chave GPG oficial do NodeSource..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg

echo ">>> Adicionando repositório do Node.js ${NODE_MAJOR}.x..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nodesource.gpg] \
https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list

# --- Instala Node.js (o npm vem junto) ---------------------------------------

echo ">>> Instalando Node.js ${NODE_MAJOR}..."
apt-get update
apt-get install -y nodejs

# --- Verificação final --------------------------------------------------------

echo ""
echo ">>> Versões instaladas:"
echo "node: $(node --version)"
echo "npm:  $(npm --version)"

echo ""
echo "✅ Instalação concluída!"
