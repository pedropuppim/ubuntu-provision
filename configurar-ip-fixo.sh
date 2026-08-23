#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "[-] Por favor, execute este script com privilégios de root (ex: sudo ./configurar-ip-fixo.sh)"
  exit 1
fi

echo "=================================================="
echo "        Configuração de IP Fixo (Netplan)        "
echo "=================================================="

# Isola busca de interfaces em array
mapfile -t NET_INTERFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|en|ens|enp)')

if [ ${#NET_INTERFACES[@]} -eq 0 ]; then
  echo "[-] Nenhuma interface de rede física compatível foi encontrada."
  exit 1
fi

echo "[+] Interfaces de rede detectadas:"
for i in "${!NET_INTERFACES[@]}"; do
  echo "  $((i+1))) ${NET_INTERFACES[$i]}"
done

while true; do
  if ! read -r -p " Escolha a interface que deseja configurar [Padrão: 1]: " NET_INT_SEL; then
    echo "[-] Leitura abortada."
    exit 1
  fi
  NET_INT_SEL=${NET_INT_SEL:-1}

  if [[ "$NET_INT_SEL" =~ ^[0-9]+$ ]] && [ "$NET_INT_SEL" -ge 1 ] && [ "$NET_INT_SEL" -le ${#NET_INTERFACES[@]} ]; then
    NET_IFACE="${NET_INTERFACES[$((NET_INT_SEL-1))]}"
    break
  else
    echo "[-] Opção inválida! Informe um número de 1 a ${#NET_INTERFACES[@]}."
  fi
done

echo ""
echo "[+] Coletando informações atuais da interface $NET_IFACE via DHCP..."

NET_IP_CIDR_DHCP=$(ip -4 addr show "$NET_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n 1)
NET_GATEWAY_DHCP=$(ip route show dev "$NET_IFACE" default 2>/dev/null | grep -oP '(?<=via\s)\d+(\.\d+){3}' | head -n 1)

if command -v resolvectl &>/dev/null; then
  NET_DNS_DHCP=$(resolvectl status "$NET_IFACE" 2>/dev/null | awk '/DNS Servers:/ { $1=$2=""; print $0}' | xargs | tr ' ' ',')
elif command -v systemd-resolve &>/dev/null; then
  NET_DNS_DHCP=$(systemd-resolve --status "$NET_IFACE" 2>/dev/null | awk '/DNS Servers:/ { $1=$2=""; print $0}' | xargs | tr ' ' ',')
fi

[ -z "$NET_IP_CIDR_DHCP" ] && NET_IP_CIDR_DHCP="192.168.1.100/24"
[ -z "$NET_GATEWAY_DHCP" ] && NET_GATEWAY_DHCP="192.168.1.1"
[ -z "$NET_DNS_DHCP" ] && NET_DNS_DHCP="1.1.1.1, 8.8.8.8"

# 1. IP / Máscara
while true; do
  if ! read -r -p " Informe o IP estático com máscara (CIDR) [Padrão: $NET_IP_CIDR_DHCP]: " NET_IP_CIDR; then exit 1; fi
  NET_IP_CIDR=${NET_IP_CIDR:-$NET_IP_CIDR_DHCP}
  NET_IP_CIDR=$(echo "$NET_IP_CIDR" | xargs)
  
  if [[ "$NET_IP_CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
    break
  else
    echo "[-] Formato inválido! Use notação CIDR (ex: 192.168.1.100/24)."
  fi
done

# 2. Gateway
while true; do
  if ! read -r -p " Informe o Gateway (Roteador) [Padrão: $NET_GATEWAY_DHCP]: " NET_GATEWAY; then exit 1; fi
  NET_GATEWAY=${NET_GATEWAY:-$NET_GATEWAY_DHCP}
  NET_GATEWAY=$(echo "$NET_GATEWAY" | xargs)
  
  if [[ "$NET_GATEWAY" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    break
  else
    echo "[-] Gateway inválido! Informe um IP válido (ex: 192.168.1.1)."
  fi
done

# ----------------------------------------------------
# 3. Leitura e formatação do DNS (IPv4 e IPv6)
# ----------------------------------------------------
while true; do
  if ! read -r -p " Server(s) DNS [Padrão: $NET_DNS_DHCP]: " NET_DNS_INPUT; then exit 1; fi
  NET_DNS_INPUT=${NET_DNS_INPUT:-$NET_DNS_DHCP}
  
  # Regex abrangente para IPv4 e IPv6 (aceita minúsculas, maiúsculas e abreviações com ::)
  NET_IPV4_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  NET_IPV6_REGEX='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

  IFS=',' read -ra NET_DNS_ARRAY <<< "$NET_DNS_INPUT"
  NET_DNS_YAML=""
  NET_VALIDO=true
  
  for dns in "${NET_DNS_ARRAY[@]}"; do
    dns_clean=$(echo "$dns" | xargs)
    if [[ "$dns_clean" =~ $NET_IPV4_REGEX ]] || [[ "$dns_clean" =~ $NET_IPV6_REGEX ]]; then
      [ -n "$NET_DNS_YAML" ] && NET_DNS_YAML+=", "
      NET_DNS_YAML+="\"$dns_clean\""
    else
      NET_VALIDO=false
      break
    fi
  done

  if $NET_VALIDO && [ -n "$NET_DNS_YAML" ]; then
    break
  else
    echo "[-] DNS inválido! Informe IPs válidos separados por vírgula."
  fi
done



NETPLAN_DIR="/etc/netplan"
BACKUP_DIR="/etc/netplan/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp $NETPLAN_DIR/*.yaml "$BACKUP_DIR/" 2>/dev/null || true

TARGET_NETPLAN="$NETPLAN_DIR/01-static-$NET_IFACE.yaml"

echo ""
echo "[+] Gerando arquivo de configuração: $TARGET_NETPLAN"

cat <<EOF > "$TARGET_NETPLAN"
network:
  version: 2
  renderer: networkd
  ethernets:
    $NET_IFACE:
      dhcp4: no
      addresses:
        - $NET_IP_CIDR
      routes:
        - to: default
          via: $NET_GATEWAY
      nameservers:
        addresses: [$NET_DNS_YAML]
EOF

chmod 600 "$TARGET_NETPLAN"

echo "[+] Testando e aplicando as configurações do Netplan..."

if netplan apply; then
  echo "=================================================="
  echo "  [OK] IP estático configurado com sucesso!"
  echo "  Interface: $NET_IFACE"
  echo "  Endereço IP: $NET_IP_CIDR"
  echo "  Gateway: $NET_GATEWAY"
  echo "  DNS: $NET_DNS_INPUT"
  echo "=================================================="
  exit 0
else
  echo "[-] Erro ao aplicar as configurações do Netplan. Restaurando backup..."
  cp "$BACKUP_DIR"/* "$NETPLAN_DIR/" 2>/dev/null
  netplan apply
  exit 1
fi
