# ubuntu-provision

Scripts para provisionamento e configuração inicial de servidores **Ubuntu 24.04**: utilitários básicos, Docker, Node.js, swap, usuários, hardening de SSH e firewall.

## Propósito

Automatizar o setup de um servidor Ubuntu recém-instalado (VPS, VM ou máquina física), padronizando as tarefas repetitivas de todo provisionamento: instalar ferramentas essenciais, criar usuário com sudo, configurar swap, instalar Docker e Node.js, proteger o SSH e ativar o firewall. Em poucos minutos o servidor sai do estado "recém-formatado" para pronto para receber aplicações, sempre com a mesma configuração.

> ✅ **Testados em Ubuntu Server 24.04 LTS.** Devem funcionar em outras versões recentes do Ubuntu (22.04+), mas sem garantia. Não são testados em Debian ou outras distribuições.

Todos os scripts:

- São interativos quando necessário (perguntam antes de sobrescrever algo);
- Validam entradas e param no primeiro erro (`set -euo pipefail`);
- Precisam ser executados como **root** (via `sudo`), exceto quando indicado.

## Como baixar

Em um servidor recém-instalado (o `git` pode não estar disponível ainda):

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/pedropuppim/ubuntu-provision.git
cd ubuntu-provision
chmod +x *.sh
```

> Se você usa chave SSH no GitHub, pode clonar com:
> `git clone git@github.com:pedropuppim/ubuntu-provision.git`

## Ordem sugerida para um servidor novo

```bash
sudo ./instalar-utilitarios.sh
sudo ./adicionar-usuario.sh <usuario>
sudo ./adicionar-swap.sh 4
sudo ./instalar-docker.sh
sudo ./instalar-node.sh
sudo ./configura-ssh.sh
sudo ./firewall.sh 22022,80,443
```

⚠️ **Atenção à ordem de SSH + firewall:** o `configura-ssh.sh` muda a porta do SSH para `22022`. Ao rodar o `firewall.sh` depois, libere a porta **22022** (e não a 22), senão você perde o acesso remoto.

---

## Scripts

### `instalar-utilitarios.sh`

Instala ferramentas comuns de administração: `git`, `curl`, `wget`, `zip`/`unzip`, `htop`, `btop`, `ncdu`, `net-tools`, `dnsutils`, `tmux`, `tree`, `jq`, `vim`, `rsync`, `build-essential`, entre outras.

```bash
sudo ./instalar-utilitarios.sh
```

### `adicionar-usuario.sh`

Cria um novo usuário e o adiciona ao grupo `sudo`. Se o grupo `docker` existir, oferece adicioná-lo também. Valida o nome do usuário e recusa nomes já existentes.

```bash
sudo ./adicionar-usuario.sh joao
# ou sem argumento, para informar o nome interativamente:
sudo ./adicionar-usuario.sh
```

### `adicionar-swap.sh`

Cria e ativa um arquivo de swap (`/swapfile`) com persistência no `/etc/fstab`. Verifica espaço em disco disponível, detecta swap já existente (perguntando antes de substituir) e oferece ajustar `vm.swappiness=10` (recomendado para servidores).

```bash
sudo ./adicionar-swap.sh 4      # cria 4 GB de swap
# ou sem argumento, para informar o tamanho interativamente:
sudo ./adicionar-swap.sh
```

> Não funciona dentro de containers LXC (ex.: CT do Proxmox) — nesse caso o swap deve ser configurado no host.

### `instalar-docker.sh`

Instala o Docker Engine, CLI, containerd, Buildx e Docker Compose (plugin) a partir do **repositório oficial do Docker**. Remove pacotes antigos/conflitantes (`docker.io`, `podman-docker` etc.) e habilita o serviço no boot.

Sobre o grupo `docker` (que permite usar o Docker sem `sudo`):

- Se executado via `sudo` por um usuário comum, esse usuário é adicionado ao grupo automaticamente;
- Se executado como `root` direto, o script pergunta qual usuário adicionar (pode pular deixando em branco).

```bash
sudo ./instalar-docker.sh
```

> A permissão do grupo só vale em sessões novas: o usuário precisa sair e entrar novamente (ou rodar `newgrp docker` no terminal atual).

### `instalar-node.sh`

Instala o **Node.js 24** (com npm) a partir do repositório oficial **NodeSource**, removendo antes versões antigas instaladas via apt.

```bash
sudo ./instalar-node.sh
```

### `configura-ssh.sh`

Hardening do SSH:

- Muda a porta para **22022**;
- Bloqueia login como **root** (`PermitRootLogin no`).

A configuração é feita via drop-in em `/etc/ssh/sshd_config.d/99-hardening.conf`, com backup do `sshd_config` original. O script valida a configuração (`sshd -t`) antes de aplicar, desativa o `ssh.socket` (que ignoraria a porta configurada no Ubuntu 22.10+) e, se o `ufw` estiver ativo, já libera a porta nova no firewall.

```bash
sudo ./configura-ssh.sh
```

> ⚠️ **Não feche a sessão atual** após rodar. Teste antes em outro terminal:
> `ssh -p 22022 usuario@ip-do-servidor`
> A porta 22 não é removida do ufw automaticamente — remova depois de confirmar o acesso:
> `sudo ufw delete allow 22/tcp`

### `firewall.sh`

Configura o `ufw` para **bloquear todas as portas de entrada**, exceto as informadas (liberadas em TCP e UDP). Saída (outgoing) fica liberada. Instala o `ufw` se necessário e o habilita no boot. Aceita portas separadas por vírgula ou espaço e avisa se a porta 22 não estiver na lista.

```bash
sudo ./firewall.sh 22022,80,443
sudo ./firewall.sh "22022 80 443"      # também aceita separado por espaço
./firewall.sh --dry-run 22022,80,443   # só mostra o que seria feito, sem aplicar
```

> ⚠️ O script **reseta** todas as regras existentes do ufw antes de aplicar as novas.

---

## Licença

Use livremente. Sem garantias — revise os scripts antes de rodar em produção.
