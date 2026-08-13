#!/usr/bin/env bash
#
# Instala Docker Engine + Docker Compose (plugin) no Ubuntu 24.04
# e adiciona o usuário que executou o script ao grupo docker.
#
# Uso: sudo ./instalar-docker.sh

set -euo pipefail

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./instalar-docker.sh)" >&2
    exit 1
fi

# Usuário real que invocou o script (mesmo rodando com sudo)
USUARIO="${SUDO_USER:-$USER}"

if [[ "$USUARIO" == "root" ]]; then
    echo "Aviso: script executado diretamente como root; nenhum usuário comum será adicionado ao grupo docker."
fi

echo ">>> Instalando Docker para o usuário: $USUARIO"

# --- Remove versões antigas/conflitantes -------------------------------------

echo ">>> Removendo pacotes antigos (se existirem)..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

# --- Configura o repositório oficial do Docker -------------------------------

echo ">>> Instalando dependências..."
apt-get update
apt-get install -y ca-certificates curl

echo ">>> Adicionando chave GPG oficial do Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo ">>> Adicionando repositório do Docker..."
UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

# --- Instala Docker Engine + Compose -----------------------------------------

echo ">>> Instalando Docker Engine, CLI, containerd, Buildx e Compose..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- Habilita e inicia o serviço ----------------------------------------------

echo ">>> Habilitando serviço do Docker..."
systemctl enable --now docker

# --- Adiciona o usuário ao grupo docker ---------------------------------------

if [[ "$USUARIO" != "root" ]]; then
    echo ">>> Adicionando '$USUARIO' ao grupo docker..."
    usermod -aG docker "$USUARIO"
fi

# --- Verificação final ---------------------------------------------------------

echo ""
echo ">>> Versões instaladas:"
docker --version
docker compose version

echo ""
echo "✅ Instalação concluída!"
if [[ "$USUARIO" != "root" ]]; then
    echo "⚠️  Para usar o docker sem sudo, saia e entre novamente na sessão"
    echo "    (ou execute: newgrp docker)"
fi
