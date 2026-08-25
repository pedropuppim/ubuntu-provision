#!/usr/bin/env bash
#
# Instala Docker Engine + Docker Compose (plugin) no Ubuntu 24.04
# e, opcionalmente, adiciona um usuário ao grupo docker (perguntando).
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

# --- Adiciona usuário ao grupo docker (opcional) -------------------------------

USUARIO_DOCKER=""

read -rp "Deseja adicionar algum usuário ao grupo docker? [s/N] " RESPOSTA
if [[ "${RESPOSTA,,}" == "s" ]]; then
    # Sugere o usuário que invocou o script via sudo (se não for root)
    SUGESTAO=""
    if [[ "$USUARIO" != "root" ]]; then
        SUGESTAO="$USUARIO"
    fi

    if [[ -n "$SUGESTAO" ]]; then
        read -rp "Qual usuário? [$SUGESTAO]: " NOME
        NOME="${NOME:-$SUGESTAO}"
    else
        read -rp "Qual usuário? " NOME
    fi

    if [[ -z "$NOME" || "$NOME" == "root" ]]; then
        echo "Aviso: nenhum usuário válido informado; ninguém foi adicionado ao grupo docker." >&2
    elif id "$NOME" >/dev/null 2>&1; then
        USUARIO_DOCKER="$NOME"
    else
        echo "Aviso: usuário '$NOME' não existe; ninguém foi adicionado ao grupo docker." >&2
        echo "       Depois de criá-lo, rode: sudo usermod -aG docker $NOME" >&2
    fi
fi

if [[ -n "$USUARIO_DOCKER" ]]; then
    echo ">>> Adicionando '$USUARIO_DOCKER' ao grupo docker..."
    usermod -aG docker "$USUARIO_DOCKER"
fi

# --- Verificação final ---------------------------------------------------------

echo ""
echo ">>> Versões instaladas:"
docker --version
docker compose version

echo ""
echo "✅ Instalação concluída!"
if [[ -n "$USUARIO_DOCKER" ]]; then
    echo "⚠️  A permissão do grupo docker só vale em sessões novas."
    echo "    '$USUARIO_DOCKER' deve sair e entrar novamente na sessão,"
    echo "    ou executar 'newgrp docker' no terminal atual."
fi
