#!/usr/bin/env bash

# Garante privilégios de root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Por favor, execute este script com privilégios de root (ex: sudo ./menu.sh)"
  exit 1
fi

# Arquivo para persistir os passos concluídos
STATE_FILE=".provision_done"
touch "$STATE_FILE"

# Função auxiliar para checar se um passo foi concluído
foi_executado() {
  grep -q "^$1$" "$STATE_FILE"
}

# Função auxiliar para marcar passo como concluído
marcar_concluido() {
  if ! foi_executado "$1"; then
    echo "$1" >> "$STATE_FILE"
  fi
}

# DECLARAÇÃO DA FUNÇÃO QUE ESTAVA FALTANDO
executar_script_isolado() {
  local script_name="$1"
  local state_key="$2"
  shift 2

  if [ -f "./$script_name" ]; then
    chmod +x "./$script_name"
    # Inclui USER e SUDO_USER para evitar o erro 'unbound variable'
    if env -i PATH="$PATH" TERM="$TERM" HOME="$HOME" USER="${USER:-root}" SUDO_USER="$SUDO_USER" ./"$script_name" "$@"; then
      [ -n "$state_key" ] && marcar_concluido "$state_key"
    fi
  else
    echo "[-] Script ./$script_name não encontrado no diretório atual!"
  fi
}

executar_script() {
  local script_name="$1"
  local state_key="$2"
  shift 2

  if [ -f "./$script_name" ]; then
    chmod +x "./$script_name"
    if "./$script_name" "$@"; then
      marcar_concluido "$state_key"
    fi
  else
    echo "[-] Script ./$script_name não encontrado no diretório atual!"
  fi
}

while true; do
  clear
  echo "=================================================="
  echo "      Provisionamento Automático do Ubuntu        "
  echo "=================================================="
  
  foi_executado "atualizacao_sistema" && status_0="[OK]" || status_0="[  ]"
  foi_executado "utilitarios"         && status_1="[OK]" || status_1="[  ]"
  foi_executado "relogio"             && status_2="[OK]" || status_2="[  ]"
  foi_executado "usuario"             && status_3="[OK]" || status_3="[  ]"
  foi_executado "swap"                && status_4="[OK]" || status_4="[  ]"
  foi_executado "docker"              && status_5="[OK]" || status_5="[  ]"
  foi_executado "node"                && status_6="[OK]" || status_6="[  ]"
  foi_executado "certbot"             && status_7="[OK]" || status_7="[  ]"
  foi_executado "atualizacoes"        && status_8="[OK]" || status_8="[  ]"
  foi_executado "ssh"                 && status_9="[OK]" || status_9="[  ]"
  foi_executado "firewall"            && status_10="[OK]" || status_10="[  ]"
  foi_executado "ip_fixo"             && status_11="[OK]" || status_11="[  ]"
  foi_executado "fail2ban"            && status_12="[OK]" || status_12="[  ]"
  foi_executado "nginx"               && status_13="[OK]" || status_13="[  ]"

  echo " $status_0 0) Atualizar Sistema e Scripts (APT & GitHub)"
  echo " $status_1 1) Instalar Utilitários"
  echo " $status_2 2) Configurar Fuso Horário (Relógio)"
  echo " $status_3 3) Adicionar Novo Usuário"
  echo " $status_4 4) Criar/Configurar Arquivo SWAP"
  echo " $status_5 5) Instalar Docker e Docker Compose"
  echo " $status_6 6) Instalar Node.js"
  echo " $status_7 7) Instalar Certbot (SSL / Let's Encrypt)"
  echo " $status_8 8) Ativar Atualizações Automáticas"
  echo " $status_9 9) Configurar Segurança do SSH"
  echo " $status_10 10) Configurar Firewall (UFW)"
  echo " $status_11 11) Configurar IP Fixo (Netplan)"
  echo " $status_12 12) Instalar Fail2ban (proteção SSH)"
  echo " $status_13 13) Instalar Nginx (servidor web)"
  echo "--------------------------------------------------"
  echo "      🛠️  Ferramentas de Apoio e Manutenção:"
  echo "      L) Executar Limpeza de Disco (limpeza.sh)"
  echo "      I) Exibir Resumo / Info do Servidor (info-servidor.sh)"
  echo "      U) Atualizar Repositório dos Scripts (git pull)"
  echo "--------------------------------------------------"
  echo "      A) Executar TODOS os passos pendentes de instalação"
  echo "      R) Resetar status dos procedimentos"
  echo "      S) Sair"
  echo "=================================================="
  
  read -r -p " Escolha uma opção: " OPC_RAW
  # Remove caracteres especiais/invisíveis mantendo apenas alfanuméricos
  OPC=$(echo "$OPC_RAW" | tr -cd 'a-zA-Z0-9')
  OPC_LOWER="${OPC,,}"

  case "$OPC_LOWER" in
    0)
      if foi_executado "atualizacao_sistema"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi

      echo "[+] Atualizando os pacotes do sistema (APT)..."
      if apt-get update && apt-get upgrade -y && apt-get full-upgrade -y; then
        echo "[+] Atualizando repositório do GitHub..."
        if [ -d ".git" ]; then
          git pull origin master || git pull origin main
        else
          echo "[!] Repositório git local não detectado. Baixando versão mais recente..."
          cd ..
          git clone https://github.com/pedropuppim/ubuntu-provision.git
          cd ubuntu-provision || exit 1
        fi
        chmod +x *.sh 2>/dev/null || true
        marcar_concluido "atualizacao_sistema"
        echo "[+] Atualização concluída com sucesso!"
      else
        echo "[-] Ocorreu um erro durante a atualização do APT."
      fi
      read -r -p "Pressione Enter para continuar..."
      ;;

    1)
      if foi_executado "utilitarios"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "instalar-utilitarios.sh" "utilitarios"
      read -r -p "Pressione Enter para continuar..."
      ;;

    2)
      if foi_executado "relogio"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      read -r -p "Informe o fuso horário [Padrão: America/Sao_Paulo]: " FUSO
      FUSO=${FUSO:-America/Sao_Paulo}
      executar_script "configurar-relogio.sh" "relogio" "$FUSO"
      read -r -p "Pressione Enter para continuar..."
      ;;

    3)
      if foi_executado "usuario"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      read -r -p "Informe o nome do novo usuário: " USUARIO
      if [ -n "$USUARIO" ]; then
        executar_script "adicionar-usuario.sh" "usuario" "$USUARIO"
      else
        echo "[-] Nome de usuário não informado. Operação cancelada."
      fi
      read -r -p "Pressione Enter para continuar..."
      ;;

    4)
      if foi_executado "swap"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      read -r -p "Informe o tamanho da SWAP em GB [Padrão: 4]: " TAMANHO
      TAMANHO=${TAMANHO:-4}
      executar_script "adicionar-swap.sh" "swap" "$TAMANHO"
      read -r -p "Pressione Enter para continuar..."
      ;;

    5)
      if foi_executado "docker"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "instalar-docker.sh" "docker"
      read -r -p "Pressione Enter para continuar..."
      ;;

    6)
      if foi_executado "node"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "instalar-node.sh" "node"
      read -r -p "Pressione Enter para continuar..."
      ;;

    7)
      if foi_executado "certbot"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "instalar-certbot.sh" "certbot"
      read -r -p "Pressione Enter para continuar..."
      ;;

    8)
      if foi_executado "atualizacoes"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "atualizacoes-automaticas.sh" "atualizacoes"
      read -r -p "Pressione Enter para continuar..."
      ;;

    9)
      if foi_executado "ssh"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "configura-ssh.sh" "ssh"
      read -r -p "Pressione Enter para continuar..."
      ;;

    10)
      if foi_executado "firewall"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      read -r -p "Informe as portas liberadas separadas por vírgula [Padrão: 22022,80,443]: " PORTAS
      PORTAS=${PORTAS:-22022,80,443}
      executar_script "firewall.sh" "firewall" "$PORTAS"
      read -r -p "Pressione Enter para continuar..."
      ;;

    11)
      if foi_executado "ip_fixo"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "configurar-ip-fixo.sh" "ip_fixo"
      read -r -p "Pressione Enter para continuar..."
      ;;

    12)
      if foi_executado "fail2ban"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "instalar-fail2ban.sh" "fail2ban"
      read -r -p "Pressione Enter para continuar..."
      ;;

    13)
      if foi_executado "nginx"; then
        read -r -p "[!] Passo já executado. Executar novamente mesmo assim? (s/N): " RESP
        [[ ! "${RESP,,}" =~ ^s$ ]] && continue
      fi
      executar_script "instalar-nginx.sh" "nginx"
      read -r -p "Pressione Enter para continuar..."
      ;;

    l)
      echo "[+] Executando rotina de limpeza de disco..."
      executar_script "limpeza.sh" "limpeza_temp"
      read -r -p "Pressione Enter para continuar..."
      ;;

    i)
      echo "[+] Coletando e exibindo informações do servidor..."
      executar_script "info-servidor.sh" "info_temp"
      read -r -p "Pressione Enter para continuar..."
      ;;

    u)
      echo "[+] Atualizando repositório dos scripts (git pull)..."
      if [ -d ".git" ]; then
        git fetch origin 2>/dev/null || true
        BRANCH_PADRAO=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
        BRANCH_PADRAO=${BRANCH_PADRAO:-master}
        BRANCH_ATUAL=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [ -n "$BRANCH_ATUAL" ] && [ "$BRANCH_ATUAL" != "$BRANCH_PADRAO" ]; then
          echo "[!] Branch atual é '$BRANCH_ATUAL'. Mudando para '$BRANCH_PADRAO'..."
          if ! git checkout "$BRANCH_PADRAO"; then
            echo "[-] Não foi possível mudar para a branch '$BRANCH_PADRAO'. Verifique alterações locais."
            read -r -p "Pressione Enter para continuar..."
            continue
          fi
        fi
        if git pull origin "$BRANCH_PADRAO"; then
          chmod +x *.sh 2>/dev/null || true
          echo "[+] Repositório atualizado com sucesso!"
        else
          echo "[-] Falha ao atualizar o repositório. Verifique a conexão ou conflitos locais."
        fi
      else
        echo "[-] Repositório git local não detectado neste diretório."
      fi
      read -r -p "Pressione Enter para continuar..."
      ;;

    a)
      # Definição de Cores ANSI
      CYAN='\033[1;36m'
      VERDE='\033[1;32m'
      AMARELO='\033[1;33m'
      RESET='\033[0m'

      echo -e "${CYAN}=================================================="${RESET}
      echo -e "${CYAN}   INICIANDO EXECUÇÃO SEQUENCIAL DE PENDÊNCIAS    "${RESET}
      echo -e "${CYAN}=================================================="${RESET}
      
      if ! foi_executado "atualizacao_sistema"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 0/13] Atualizando Pacotes do Sistema (APT)..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        if apt-get update && apt-get upgrade -y && apt-get full-upgrade -y; then
          marcar_concluido "atualizacao_sistema"
          echo -e "${VERDE}[✓] Passo 0 (APT) concluído com sucesso!${RESET}"
        fi
      fi

      if ! foi_executado "utilitarios"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 1/13] Instalando Utilitários do Sistema..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "instalar-utilitarios.sh" "utilitarios"
        echo -e "${VERDE}[✓] Passo 1 (Utilitários) concluído!${RESET}"
      fi

      if ! foi_executado "relogio"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 2/13] Configurando Fuso Horário (Relógio)..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        read -r -p "Fuso horário [Padrão: America/Sao_Paulo]: " FUSO_ALL
        FUSO_ALL=${FUSO_ALL:-America/Sao_Paulo}
        executar_script_isolado "configurar-relogio.sh" "relogio" "$FUSO_ALL"
        echo -e "${VERDE}[✓] Passo 2 (Fuso Horário) concluído!${RESET}"
      fi

      if ! foi_executado "usuario"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 3/13] Adicionando Novo Usuário..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        read -r -p "Informe o nome do novo usuário: " USUARIO_ALL
        if [ -n "$USUARIO_ALL" ]; then
          executar_script_isolado "adicionar-usuario.sh" "usuario" "$USUARIO_ALL"
          echo -e "${VERDE}[✓] Passo 3 (Novo Usuário) concluído!${RESET}"
        fi
      fi

      if ! foi_executado "swap"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 4/13] Criando/Configurando SWAP..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        read -r -p "Tamanho SWAP em GB [Padrão: 4]: " SWAP_ALL
        SWAP_ALL=${SWAP_ALL:-4}
        executar_script_isolado "adicionar-swap.sh" "swap" "$SWAP_ALL"
        echo -e "${VERDE}[✓] Passo 4 (SWAP) concluído!${RESET}"
      fi

      if ! foi_executado "docker"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 5/13] Instalando Docker e Docker Compose..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "instalar-docker.sh" "docker"
        echo -e "${VERDE}[✓] Passo 5 (Docker) concluído!${RESET}"
      fi

      if ! foi_executado "node"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 6/13] Instalando Node.js..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "instalar-node.sh" "node"
        echo -e "${VERDE}[✓] Passo 6 (Node.js) concluído!${RESET}"
      fi

      if ! foi_executado "certbot"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 7/13] Instalando Certbot (SSL / Let's Encrypt)..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "instalar-certbot.sh" "certbot"
        echo -e "${VERDE}[✓] Passo 7 (Certbot) concluído!${RESET}"
      fi

      if ! foi_executado "atualizacoes"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 8/13] Ativando Atualizações Automáticas..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "atualizacoes-automaticas.sh" "atualizacoes"
        echo -e "${VERDE}[✓] Passo 8 (Atualizações Automáticas) concluído!${RESET}"
      fi

      if ! foi_executado "ssh"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 9/13] Configurando Segurança do SSH..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "configura-ssh.sh" "ssh"
        echo -e "${VERDE}[✓] Passo 9 (SSH) concluído!${RESET}"
      fi

      if ! foi_executado "firewall"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 10/13] Configurando Firewall (UFW)..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        read -r -p "Portas do Firewall [Padrão: 22022,80,443]: " PORTAS_ALL
        PORTAS_ALL=${PORTAS_ALL:-22022,80,443}
        executar_script_isolado "firewall.sh" "firewall" "$PORTAS_ALL"
        echo -e "${VERDE}[✓] Passo 10 (Firewall) concluído!${RESET}"
      fi

      if ! foi_executado "ip_fixo"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 11/13] Configurando IP Fixo (Netplan)..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "configurar-ip-fixo.sh" "ip_fixo"
        echo -e "${VERDE}[✓] Passo 11 (IP Fixo) concluído!${RESET}"
      fi

      if ! foi_executado "fail2ban"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 12/13] Instalando Fail2ban (proteção SSH)..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "instalar-fail2ban.sh" "fail2ban"
        echo -e "${VERDE}[✓] Passo 12 (Fail2ban) concluído!${RESET}"
      fi

      if ! foi_executado "nginx"; then
        echo -e "\n${AMARELO}--------------------------------------------------"${RESET}
        echo -e "${AMARELO}[PASSO 13/13] Instalando Nginx (servidor web)..."${RESET}
        echo -e "${AMARELO}--------------------------------------------------"${RESET}
        executar_script_isolado "instalar-nginx.sh" "nginx"
        echo -e "${VERDE}[✓] Passo 13 (Nginx) concluído!${RESET}"
      fi

      echo -e "\n${VERDE}=================================================="${RESET}
      echo -e "${VERDE} [OK] PROCESSO COMPLETO FINALIZADO COM SUCESSO!   "${RESET}
      echo -e "${VERDE}=================================================="${RESET}
      read -r -p "Pressione Enter para continuar..."
      ;;

    r)
      read -r -p "[?] Tem certeza que deseja resetar o histórico de execução? (s/N): " CONF
      if [[ "${CONF,,}" =~ ^s$ ]]; then
        > "$STATE_FILE"
        echo "[+] Histórico de execução resetado."
      fi
      sleep 1
      ;;

    s)
      echo "Saindo..."
      exit 0
      ;;

    *)
      echo "[-] Opção inválida: '$OPC_RAW'"
      sleep 1.5
      ;;
  esac
done
