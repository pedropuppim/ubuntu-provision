#!/usr/bin/env bash
#
# limpeza.sh — Manutenção de espaço em disco:
#   - Remove pacotes órfãos e limpa o cache do apt;
#   - Reduz os logs do journald (opcional);
#   - docker system prune (opcional, se o Docker estiver instalado).
#
# Uso: sudo ./limpeza.sh

set -euo pipefail

JOURNAL_LIMITE="200M"

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./limpeza.sh)" >&2
    exit 1
fi

DISPONIVEL_ANTES=$(df -B1 --output=avail / | tail -1 | tr -dc '0-9')

echo ">>> Espaço em disco antes:"
df -h /

# --- apt ---------------------------------------------------------------------

echo ""
echo ">>> Removendo pacotes órfãos (autoremove --purge)..."
apt-get autoremove --purge -y

echo ">>> Limpando cache do apt..."
apt-get clean

# --- journald ----------------------------------------------------------------

echo ""
echo ">>> Uso atual dos logs do journal:"
journalctl --disk-usage
read -rp "Reduzir os logs do journal para no máximo $JOURNAL_LIMITE? [s/N] " RESPOSTA
if [[ "${RESPOSTA,,}" == "s" ]]; then
    journalctl --vacuum-size="$JOURNAL_LIMITE"
fi

# --- Docker (se instalado) ---------------------------------------------------

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo ""
    read -rp "Executar 'docker system prune' (remove containers parados, redes sem uso e imagens sem tag)? [s/N] " RESPOSTA
    if [[ "${RESPOSTA,,}" == "s" ]]; then
        docker system prune -f
        read -rp "Remover TAMBÉM todas as imagens não usadas por nenhum container (prune -a)? [s/N] " RESPOSTA
        if [[ "${RESPOSTA,,}" == "s" ]]; then
            docker system prune -af
        fi
    fi
fi

# --- Verificação final -------------------------------------------------------

DISPONIVEL_DEPOIS=$(df -B1 --output=avail / | tail -1 | tr -dc '0-9')
LIBERADO=$(( DISPONIVEL_DEPOIS - DISPONIVEL_ANTES ))
(( LIBERADO < 0 )) && LIBERADO=0

echo ""
echo ">>> Espaço em disco depois:"
df -h /
echo ""
echo "✅ Limpeza concluída! Espaço liberado: $(numfmt --to=iec "$LIBERADO")"
