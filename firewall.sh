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

# --- Detecta porta(s) do SSH ativo e avisa se alguma ficaria bloqueada --------

SSH_PORTAS=()
if pgrep -x sshd >/dev/null 2>&1; then
    # Portas em que o sshd está escutando (funciona com IPv4 e IPv6)
    mapfile -t SSH_PORTAS < <(ss -tlnp 2>/dev/null | awk '/sshd/ {n=split($4,a,":"); print a[n]}' | sort -un)
    # Fallback: configuração do sshd
    if [[ ${#SSH_PORTAS[@]} -eq 0 ]]; then
        mapfile -t SSH_PORTAS < <(sshd -T 2>/dev/null | awk '$1=="port"{print $2}' | sort -un)
    fi
    # Último recurso: assume a porta padrão
    if [[ ${#SSH_PORTAS[@]} -eq 0 ]]; then
        SSH_PORTAS=(22)
    fi
fi

SSH_BLOQUEADAS=()
for ssh_porta in "${SSH_PORTAS[@]}"; do
    if [[ " ${PORTAS[*]} " != *" $ssh_porta "* ]]; then
        SSH_BLOQUEADAS+=("$ssh_porta")
    fi
done

if [[ ${#SSH_BLOQUEADAS[@]} -gt 0 ]]; then
    echo "⚠️  AVISO: SSH está ATIVO na(s) porta(s) ${SSH_BLOQUEADAS[*]}, que NÃO está(ão) na lista de liberadas." >&2
    echo "   Se este for um servidor remoto, você vai PERDER o acesso SSH." >&2
    if [[ $DRY_RUN -eq 0 ]]; then
        read -rp "   Continuar mesmo assim e bloquear a(s) porta(s) do SSH? [s/N] " RESPOSTA
        if [[ "${RESPOSTA,,}" != "s" ]]; then
            echo "Abortado. Nenhuma regra foi alterada."
            exit 1
        fi
    fi
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
