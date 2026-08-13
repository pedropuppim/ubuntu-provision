#!/usr/bin/env bash
#
# Cria e ativa um arquivo de swap no Ubuntu 24.04, com persistência no /etc/fstab.
# Pergunta o tamanho em GB (ou aceita como argumento).
#
# Uso: sudo ./adicionar-swap.sh [tamanho-em-GB]

set -euo pipefail

SWAPFILE="/swapfile"

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./adicionar-swap.sh)" >&2
    exit 1
fi

# --- Tamanho do swap ---------------------------------------------------------

TAMANHO_GB="${1:-}"

if [[ -z "$TAMANHO_GB" ]]; then
    read -rp "Quantos GB de swap deseja criar? " TAMANHO_GB
fi

if [[ ! "$TAMANHO_GB" =~ ^[1-9][0-9]*$ ]]; then
    echo "Erro: informe um número inteiro positivo de GB (ex: 4)." >&2
    exit 1
fi

# --- Verifica swap existente -------------------------------------------------

if swapon --show | grep -q "^$SWAPFILE"; then
    echo ">>> O arquivo $SWAPFILE já está ativo:"
    swapon --show
    read -rp "Deseja substituí-lo pelo novo de ${TAMANHO_GB}GB? [s/N] " RESPOSTA
    if [[ "${RESPOSTA,,}" != "s" ]]; then
        echo "Operação cancelada."
        exit 0
    fi
    echo ">>> Desativando swap atual..."
    swapoff "$SWAPFILE"
    rm -f "$SWAPFILE"
fi

# --- Verifica espaço em disco ------------------------------------------------

DISPONIVEL_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
if (( TAMANHO_GB >= DISPONIVEL_GB )); then
    echo "Erro: espaço insuficiente. Disponível em /: ${DISPONIVEL_GB}GB, solicitado: ${TAMANHO_GB}GB." >&2
    exit 1
fi

# --- Cria o arquivo de swap --------------------------------------------------

echo ">>> Criando arquivo de swap de ${TAMANHO_GB}GB em $SWAPFILE (via dd)..."
# dd é usado em vez de fallocate: em vários sistemas de arquivos (XFS, btrfs,
# ZFS, storages de container) o fallocate gera arquivo com "holes" e o swapon
# recusa com "it appears to have holes".
rm -f "$SWAPFILE"
dd if=/dev/zero of="$SWAPFILE" bs=1M count=$(( TAMANHO_GB * 1024 )) status=progress

chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE"

if ! swapon "$SWAPFILE"; then
    echo "" >&2
    echo "Erro: não foi possível ativar o swap." >&2
    echo "Se esta máquina for um container LXC (ex: Proxmox CT), o swap deve ser" >&2
    echo "configurado no host, nas opções do container — não dentro dele." >&2
    rm -f "$SWAPFILE"
    exit 1
fi

# --- Persistência no /etc/fstab ----------------------------------------------

if ! grep -qE "^$SWAPFILE\s" /etc/fstab; then
    echo ">>> Adicionando entrada no /etc/fstab..."
    cp /etc/fstab /etc/fstab.bak
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
else
    echo ">>> Entrada já existe no /etc/fstab, mantendo."
fi

# --- Ajusta swappiness (opcional, padrão recomendado para servidores) ---------

read -rp "Ajustar vm.swappiness para 10 (recomendado para servidores)? [s/N] " RESPOSTA
if [[ "${RESPOSTA,,}" == "s" ]]; then
    sysctl vm.swappiness=10
    echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
    echo ">>> vm.swappiness=10 aplicado e persistido."
fi

# --- Verificação final -------------------------------------------------------

echo ""
echo ">>> Swap ativo:"
swapon --show
echo ""
free -h
echo ""
echo "✅ Swap de ${TAMANHO_GB}GB criado e ativado com persistência no boot!"
