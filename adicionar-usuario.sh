#!/usr/bin/env bash
#
# Cria um novo usuário no Ubuntu e o adiciona ao grupo sudo.
#
# Uso: sudo ./adicionar-usuario.sh <nome-do-usuario>
#      (se o nome for omitido, o script pergunta interativamente)

set -euo pipefail

# --- Verificações iniciais ---------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute como root (sudo ./adicionar-usuario.sh <usuario>)" >&2
    exit 1
fi

# --- Nome do usuário ---------------------------------------------------------

NOVO_USUARIO="${1:-}"

if [[ -z "$NOVO_USUARIO" ]]; then
    read -rp "Nome do novo usuário: " NOVO_USUARIO
fi

# Valida o nome (padrão de nomes de usuário do Ubuntu)
if [[ ! "$NOVO_USUARIO" =~ ^[a-z][-a-z0-9_]*$ ]]; then
    echo "Erro: nome inválido '$NOVO_USUARIO'." >&2
    echo "Use apenas letras minúsculas, números, '-' e '_', começando com letra." >&2
    exit 1
fi

if id "$NOVO_USUARIO" >/dev/null 2>&1; then
    echo "Erro: o usuário '$NOVO_USUARIO' já existe." >&2
    exit 1
fi

# --- Cria o usuário ----------------------------------------------------------

echo ">>> Criando usuário '$NOVO_USUARIO'..."
adduser --gecos "" "$NOVO_USUARIO"

# --- Adiciona ao grupo sudo --------------------------------------------------

echo ">>> Adicionando '$NOVO_USUARIO' ao grupo sudo..."
usermod -aG sudo "$NOVO_USUARIO"

# Se o grupo docker existir, oferece adicionar também
if getent group docker >/dev/null 2>&1; then
    read -rp "Adicionar '$NOVO_USUARIO' também ao grupo docker? [s/N] " RESPOSTA
    if [[ "${RESPOSTA,,}" == "s" ]]; then
        usermod -aG docker "$NOVO_USUARIO"
        echo ">>> '$NOVO_USUARIO' adicionado ao grupo docker."
    fi
fi

# --- Verificação final -------------------------------------------------------

echo ""
echo ">>> Grupos de '$NOVO_USUARIO':"
id -nG "$NOVO_USUARIO"

echo ""
echo "✅ Usuário '$NOVO_USUARIO' criado com acesso sudo!"
echo "   Para testar: su - $NOVO_USUARIO && sudo whoami"
