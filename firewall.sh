#!/usr/bin/env bash
#
# firewall.sh — bloqueia TODAS as portas de entrada, exceto as informadas.
#
# Uso:
#   sudo ./firewall.sh 22,80,443
#   sudo ./firewall.sh "22 80 443"
#   sudo ./firewall.sh 22 80 443
#   ./firewall.sh --dry-run 22,80,443   # só mostra o que seria feito
#
# As portas liberadas valem para TCP e UDP. Saída (outgoing) fica liberada.

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if [[ $# -eq 0 ]]; then
    echo "Uso: $0 [--dry-run] <portas liberadas separadas por vírgula ou espaço>" >&2
    echo "Exemplo: sudo $0 22,80,443" >&2
    exit 1
fi

# Junta todos os argumentos e troca vírgulas por espaço
IFS=' ' read -r -a PORTAS <<< "$(echo "$*" | tr ',' ' ')"

if [[ ${#PORTAS[@]} -eq 0 ]]; then
    echo "ERRO: nenhuma porta informada." >&2
    exit 1
fi

# Valida cada porta (1-65535)
for porta in "${PORTAS[@]}"; do
    if ! [[ "$porta" =~ ^[0-9]+$ ]] || (( porta < 1 || porta > 65535 )); then
        echo "ERRO: porta inválida: '$porta' (use números de 1 a 65535)" >&2
        exit 1
    fi
done

# Avisa se o SSH (22) não está na lista — risco de perder acesso remoto
if [[ ! " ${PORTAS[*]} " =~ " 22 " ]]; then
    echo "AVISO: a porta 22 (SSH) NÃO está na lista de liberadas." >&2
    echo "       Se este for um servidor remoto, você pode perder o acesso." >&2
fi

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

if [[ $DRY_RUN -eq 0 ]]; then
    if [[ $EUID -ne 0 ]]; then
        echo "ERRO: execute como root (sudo $0 $*)" >&2
        exit 1
    fi
    if ! command -v ufw >/dev/null 2>&1; then
        echo "ufw não encontrado, instalando..."
        apt-get update -qq && apt-get install -y -qq ufw
    fi
fi

echo ">> Resetando regras do ufw..."
run ufw --force reset

echo ">> Política padrão: bloquear entrada, liberar saída..."
run ufw default deny incoming
run ufw default allow outgoing

for porta in "${PORTAS[@]}"; do
    echo ">> Liberando porta $porta (TCP e UDP)..."
    run ufw allow "$porta"
done

echo ">> Ativando o firewall..."
run ufw --force enable

if [[ $DRY_RUN -eq 0 ]]; then
    echo ">> Habilitando ufw na inicialização..."
    run systemctl enable ufw 2>/dev/null || true
    echo
    ufw status verbose
    echo
    echo "Firewall ativo: tudo bloqueado, exceto porta(s): ${PORTAS[*]}"
fi
