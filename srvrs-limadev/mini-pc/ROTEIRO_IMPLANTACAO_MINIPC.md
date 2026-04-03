# Roteiro de Implantação — Mini PC Portaria IA v2

> **Data**: 2026-03-07
> **Hardware**: Mini PC (Ryzen 5 ou i5, 16GB RAM, 512GB SSD)
> **Objetivo**: Ambiente pronto para rodar Asterisk + LiveKit Agents + Ollama + Piper/Kokoro + faster-whisper

---

## Status atual do equipamento — 2026-03-07

Preparação base concluída remotamente para continuidade do projeto **Portaria Inteligente**.

| Item | Estado atual |
|------|--------------|
| Host | `mini-pc` |
| CPU validada | AMD Ryzen 5 7430U |
| RAM validada | 16GB |
| Disco raiz | LVM expandido para `467G` (`424G` livres) |
| IP local | `192.168.15.3` |
| IP Tailscale | `100.87.104.42` |
| MagicDNS | `mini-pc.tailed51fe.ts.net` |
| SSH operacional | `limadev@mini-pc.tailed51fe.ts.net` porta `22022` |
| Docker | `29.3.0` + Compose `v5.1.0` |
| Ollama | `qwen2.5:3b-instruct-q4_K_M` instalado e validado |
| Piper | voz `pt_BR-faber-medium` instalada e testada |
| Kokoro | `kokoro-v1.0.onnx` instalado e testado |
| faster-whisper | modelo `small` baixado e validado em CPU |
| Firewall | UFW ativo com portas de backbone/voz liberadas |
| NTP | ativo |
| Reinicio automatico | `docker`, `ollama`, `tailscaled` e `portaria-piper` sobem sozinhos no boot |
| Auto login local | ativo no `tty1` para `limadev` |
| Wi-Fi interno | pendente: chipset MediaTek `14c3:7902` sem interface funcional no Ubuntu atual |

Evidência operacional: `01_infra_backbone/evidencias/2026-03-07_preparacao_mini_pc_portaria_inteligente.md`
Pesquisa dedicada do Wi-Fi: `01_infra_backbone/evidencias/2026-03-07_pesquisa_wifi_mt7902.md`

### Divergencias entre template e host real

- O bloco da **PARTE 1** e o prompt da **PARTE 2** preservam um template de bootstrap inicial com usuario `opsbot` e hostname `portaria`.
- O host real hoje esta operacional como `mini-pc`, com acesso SSH em `limadev@mini-pc.tailed51fe.ts.net` na porta `22022`.
- Se o roteiro voltar a ser reutilizado para este mesmo equipamento, considerar `limadev` e `mini-pc` como fonte de verdade operacional, e usar o template antigo apenas como referencia historica.

### Próxima fase

- Clonar/publicar o repositório do aplicativo de voz no host (`URL_DO_REPOSITORIO` ainda não foi informada neste workspace).
- Implantar Asterisk, LiveKit e os serviços do projeto sobre a base já pronta.
- Confirmar se o dispositivo removível `sdb` (`57.3G`) é pendrive de instalação ou disco dedicado antes de qualquer formatação para NVR.
- Decidir se o host deve permanecer em `UTC` ou ser ajustado para `America/Sao_Paulo` para facilitar leitura operacional dos logs.
- Ajustar na BIOS a politica de retorno de energia (`Restore on AC Power Loss` / `AC Back` -> `Power On`) se a exigencia for religar sozinho apos queda total de energia.
- Resolver o Wi-Fi interno MediaTek `14c3:7902` por um destes caminhos: suporte upstream/Ubuntu, adaptador USB compatível ou troca da placa interna.

### Observacao de seguranca

- O auto login foi habilitado apenas no console local `tty1`.
- O acesso SSH continua separado e segue exigindo chave na porta `22022`.

---

## PARTE 1 — Ações manuais do operador (acesso físico)

Estas etapas exigem teclado/monitor conectados ao mini PC ou acesso à interface do roteador.

### 1.1 Backup da licença Windows

No Windows atual, abrir CMD como Administrador:

```
wmic path softwarelicensingservice get OA3xOriginalProductKey
```

Anotar a chave e guardar em local seguro.

### 1.2 Preparar pendrive de boot

1. Baixar ISO: **Ubuntu Server 24.04.x LTS** — https://ubuntu.com/download/server
2. Gravar no pendrive (8GB+) usando Rufus (Windows) ou balenaEtcher

### 1.3 BIOS do mini PC

Ligar o mini PC e entrar na BIOS (F2 / Del / F12):

1. **Boot order**: colocar USB em primeiro
2. **C-States**: desabilitar C6/C7 se disponível (evita picos de latência em VoIP)
3. **Performance mode**: ativar se houver opção de perfil de energia
4. Salvar e reiniciar pelo pendrive

### 1.4 Instalar Ubuntu Server 24.04

> Referencia historica: os nomes abaixo refletem o template original de instalacao. O host em operacao hoje nao usa mais esse perfil.

Seguir o instalador com estas escolhas:

| Tela | Escolha |
|------|---------|
| Idioma | English (sistema em inglês, menos problema com locale) |
| Teclado | Portuguese (Brazil) — ou o que for físico |
| Rede | DHCP (o IP fixo será reservado no roteador — passo 1.5) |
| Disco | "Use an entire disk" → marcar **LVM** |
| Volume lógico | **EDITAR** o LV para usar os 512GB inteiros (o instalador sugere ~200GB — expandir) |
| Perfil | Template original: Nome `portaria` / Usuario `opsbot` / Senha: (definir e anotar) |
| SSH | Marcar **Install OpenSSH server** |
| Snaps adicionais | Não marcar nenhum |

Aguardar instalação, remover pendrive, reiniciar.

### 1.5 Reservar IP fixo no roteador

1. Acessar a interface do roteador (geralmente 192.168.1.1)
2. Localizar o mini PC na lista de dispositivos DHCP
   Template inicial: `portaria`
   Estado atual validado: `mini-pc`
3. Criar **reserva DHCP** pelo endereço MAC → IP fixo. Exemplo: `192.168.1.100`
4. Anotar o IP escolhido
   Estado atual validado na ultima checagem: `192.168.15.3`

### 1.6 Primeiro acesso SSH

Do seu Vaio (ou outro computador na mesma rede):

```bash
# template inicial
ssh opsbot@192.168.1.100

# estado atual validado
ssh -p 22022 limadev@mini-pc.tailed51fe.ts.net
```

Aceitar a fingerprint. A partir daqui, tudo pode ser feito remotamente.

> Estado atual deste mini PC: acesso validado em `2026-03-07` via `ssh -p 22022 limadev@mini-pc.tailed51fe.ts.net`

### 1.7 Conectar HD externo (se houver, para NVR)

Conectar o HD externo na porta USB 3.0 (azul). Será configurado pelo agente no passo 2.

---

## PARTE 2 — Prompt para o agente de infraestrutura

Copie o bloco abaixo integralmente e envie ao agente com acesso SSH ao mini PC.

---

````markdown
## Contexto

> Se este prompt for reutilizado para o `mini-pc` ja preparado em 2026-03-07, substituir os placeholders pelos valores reais abaixo:
> - usuario SSH: `limadev`
> - host: `mini-pc.tailed51fe.ts.net`
> - porta SSH: `22022`
> - IP Tailscale: `100.87.104.42`
> - IP local validado na ultima checagem: `192.168.15.3`

Você tem acesso SSH a um mini PC recém-instalado com Ubuntu Server 24.04 LTS.
- **Usuário**: `limadev`
- **Host / MagicDNS**: `mini-pc.tailed51fe.ts.net`
- **Porta SSH**: `22022`
- **IP na rede local**: `192.168.15.3`
- **IP Tailscale**: `100.87.104.42`
- **Senha sudo**: `NAO REGISTRAR NESTE DOCUMENTO`
- **Chave SSH privada**: `NAO REGISTRAR NESTE DOCUMENTO`
- **Processador**: `AMD Ryzen 5 7430U`
- **RAM**: 16GB
- **SSD**: 512GB (Ubuntu instalado com LVM, volume lógico pode precisar de expansão)
- **HD externo USB**: `NAO VALIDADO` (o dispositivo removivel `sdb` apareceu no host, mas nao foi formatado nem assumido como disco de NVR)

O mini PC será o servidor edge do projeto **Portaria Inteligente**: um sistema de atendimento por voz com IA que roda 100% local. Os serviços que rodarão nele:
- **Asterisk** (PBX SIP, `network_mode: host`)
- **LiveKit Server + livekit-sip** (pipeline de voz IA)
- **Ollama** (LLM local — Qwen2.5-3B)
- **faster-whisper** (STT local)
- **Piper TTS** (TTS local, vozes pt-BR)
- **Kokoro TTS** (TTS alternativo para avaliação)
- **Tailscale** (VPN para comunicar com VPS remota)

## Tarefas — executar na ordem

### T1. Expandir volume lógico LVM (se necessário)

O instalador do Ubuntu costuma alocar apenas ~200GB do SSD. Verificar e expandir:

```bash
# Verificar tamanho atual
df -h /
sudo lvs

# Se o LV estiver menor que 480GB, expandir:
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

Confirmar que `/` tem ~480GB+ disponíveis.

### T2. Atualizar sistema e instalar pacotes base

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  ca-certificates curl gnupg lsb-release \
  git htop tmux tree jq unzip wget \
  cpufrequtils net-tools
```

### T3. Desabilitar serviços desnecessários

```bash
sudo systemctl disable --now snapd snapd.socket snapd.seeded 2>/dev/null || true
sudo systemctl disable --now ModemManager 2>/dev/null || true
sudo systemctl disable --now bluetooth 2>/dev/null || true
sudo systemctl disable --now cups cups-browsed 2>/dev/null || true
sudo apt remove --purge -y cloud-init landscape-common 2>/dev/null || true
sudo apt autoremove -y
```

### T4. Tuning de kernel para VoIP e IA

Criar `/etc/sysctl.d/99-portaria.conf`:

```ini
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.rmem_max=26214400
net.core.wmem_max=26214400
```

Aplicar:

```bash
sudo sysctl --system
```

Criar `/etc/security/limits.d/portaria.conf`:

```ini
*               soft    rtprio          99
*               hard    rtprio          99
*               soft    nofile          65536
*               hard    nofile          65536
*               soft    memlock         unlimited
*               hard    memlock         unlimited
```

### T5. CPU governor → performance

```bash
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
sudo systemctl enable cpufrequtils
sudo systemctl restart cpufrequtils
# Verificar:
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Deve retornar: performance
```

### T6. Instalar Docker (repositório oficial)

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker opsbot
```

Configurar log rotation do Docker — criar `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Reiniciar Docker:

```bash
sudo systemctl restart docker
```

**Fazer logout e login** para o grupo `docker` entrar em efeito, depois verificar:

```bash
docker run --rm hello-world
```

### T7. Instalar Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

Anotar o IP Tailscale atribuído (formato `100.x.y.z`) — será necessário para a VPS se comunicar com este mini PC.

Verificar conectividade com a VPS (se já estiver na mesma tailnet):

```bash
tailscale status
ping -c 3 100.123.109.53    # IP Tailscale da VPS
```

### T8. Criar estrutura de diretórios do projeto

```bash
sudo mkdir -p /srv/portaria/{models/ollama,models/whisper,models/piper,models/kokoro,recordings,sessions}
sudo chown -R opsbot:opsbot /srv/portaria
```

### T9. Instalar Ollama e baixar modelo LLM

```bash
curl -fsSL https://ollama.com/install.sh | sh

# Baixar modelo Qwen2.5-3B quantizado
ollama pull qwen2.5:3b-instruct-q4_K_M
```

Testar:

```bash
ollama run qwen2.5:3b-instruct-q4_K_M "Responda em português: qual é a capital do Brasil?"
```

Verificar que a API está acessível:

```bash
curl -s http://localhost:11434/v1/models | jq .
```

### T10. Instalar Piper TTS e voz pt-BR

```bash
cd /srv/portaria/models/piper

# Baixar binário Piper
wget -q https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz
tar xzf piper_linux_x86_64.tar.gz
rm piper_linux_x86_64.tar.gz

# Baixar voz pt-BR faber-medium
wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx
wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx.json
```

Testar:

```bash
echo "Portaria do Condomínio Solares, em que posso ajudar?" | \
  /srv/portaria/models/piper/piper --model /srv/portaria/models/piper/pt_BR-faber-medium.onnx \
  --output_file /tmp/teste_piper.wav

# Verificar que o WAV foi gerado
ls -lh /tmp/teste_piper.wav
```

### T11. Instalar Kokoro TTS (ONNX) para avaliação

```bash
cd /srv/portaria/models/kokoro

pip3 install kokoro-onnx

# Baixar modelo ONNX e vozes
python3 -c "
from kokoro_onnx import Kokoro
import urllib.request, os

model_url = 'https://github.com/thewh1teagle/kokoro-onnx/releases/latest/download/kokoro-v1.0.onnx'
voices_url = 'https://github.com/thewh1teagle/kokoro-onnx/releases/latest/download/voices-v1.0.bin'

if not os.path.exists('kokoro-v1.0.onnx'):
    print('Baixando modelo...')
    urllib.request.urlretrieve(model_url, 'kokoro-v1.0.onnx')
if not os.path.exists('voices-v1.0.bin'):
    print('Baixando vozes...')
    urllib.request.urlretrieve(voices_url, 'voices-v1.0.bin')
print('OK')
"
```

Testar:

```bash
python3 -c "
from kokoro_onnx import Kokoro
import soundfile as sf

kokoro = Kokoro('/srv/portaria/models/kokoro/kokoro-v1.0.onnx',
                '/srv/portaria/models/kokoro/voices-v1.0.bin')

samples, sr = kokoro.create('Portaria do Condomínio Solares, em que posso ajudar?',
                            voice='pm_alex', lang='pt-br')
sf.write('/tmp/teste_kokoro.wav', samples, sr)
print(f'OK — {len(samples)/sr:.2f}s @ {sr}Hz')
"
```

### T12. Instalar faster-whisper e baixar modelo STT

```bash
pip3 install faster-whisper
```

Baixar o modelo `small` para teste inicial:

```bash
python3 -c "
from faster_whisper import WhisperModel
print('Baixando modelo small...')
model = WhisperModel('small', device='cpu', compute_type='int8',
                     download_root='/srv/portaria/models/whisper')
print('OK')
"
```

Testar com o áudio gerado pelo Piper:

```bash
python3 -c "
from faster_whisper import WhisperModel
model = WhisperModel('small', device='cpu', compute_type='int8',
                     download_root='/srv/portaria/models/whisper')
segments, info = model.transcribe('/tmp/teste_piper.wav', language='pt')
for seg in segments:
    print(f'[{seg.start:.1f}s-{seg.end:.1f}s] {seg.text}')
"
```

### T13. HD externo (apenas se indicado SIM no contexto)

```bash
# Identificar o disco
lsblk

# Formatar (ATENÇÃO: confirmar que é o disco correto, ex: /dev/sdb)
sudo mkfs.ext4 -L nvr /dev/sdb1

# Montar
sudo mkdir -p /mnt/nvr
UUID=$(sudo blkid -s UUID -o value /dev/sdb1)
echo "UUID=$UUID /mnt/nvr ext4 defaults,nofail,noatime 0 2" | sudo tee -a /etc/fstab
sudo mount -a

# Verificar
df -h /mnt/nvr
```

### T14. Firewall (UFW)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 5060/udp comment "SIP Asterisk"
sudo ufw allow 5060/tcp comment "SIP Asterisk TCP"
sudo ufw allow 10000:20000/udp comment "RTP audio"
sudo ufw allow 7880/tcp comment "LiveKit HTTP API"
sudo ufw allow 7881/tcp comment "LiveKit RTC"
sudo ufw allow 7881/udp comment "LiveKit RTC UDP"
sudo ufw allow from 100.64.0.0/10 comment "Tailscale"
sudo ufw --force enable
sudo ufw status numbered
```

### T15. Verificar NTP

```bash
timedatectl status
# Deve mostrar: NTP service: active
# Se não:
sudo timedatectl set-ntp true
```

### T16. Clonar repositório do projeto

```bash
cd /srv/portaria
git clone [URL_DO_REPOSITORIO] portaria-ia-mvp
```

(Se for repo privado, configurar chave SSH ou token antes.)

### T17. Validação final

Executar estes comandos e reportar a saída completa:

```bash
echo "=== SISTEMA ==="
uname -a
lsb_release -a
free -h
df -h / /mnt/nvr 2>/dev/null
nproc
cat /proc/cpuinfo | grep "model name" | head -1

echo "=== DOCKER ==="
docker --version
docker compose version
docker ps

echo "=== TAILSCALE ==="
tailscale status

echo "=== OLLAMA ==="
ollama list
curl -s http://localhost:11434/v1/models | jq '.data[].id'

echo "=== PIPER ==="
ls -lh /srv/portaria/models/piper/*.onnx

echo "=== KOKORO ==="
ls -lh /srv/portaria/models/kokoro/*.onnx

echo "=== FASTER-WHISPER ==="
ls /srv/portaria/models/whisper/

echo "=== PROJETO ==="
ls /srv/portaria/portaria-ia-mvp/

echo "=== FIREWALL ==="
sudo ufw status

echo "=== KERNEL TUNING ==="
sysctl vm.swappiness
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

echo "=== REDE ==="
ip addr show | grep "inet " | grep -v 127.0.0.1
```

## Credenciais a entregar

Ao final, reportar:

> Registrar apenas identificadores operacionais. Nao registrar senha sudo, chave privada SSH, token ou segredo neste documento.

| Item | Valor |
|------|-------|
| IP rede local | `192.168.15.3` |
| IP Tailscale | `100.87.104.42` |
| Usuário SSH | `limadev` |
| Porta SSH | `22022` |
| Host / MagicDNS | `mini-pc.tailed51fe.ts.net` |
| Senha sudo | `NAO REGISTRADA NESTE DOCUMENTO` |
| Chave SSH privada | `NAO REGISTRADA NESTE DOCUMENTO` |
| Docker funcionando? | `sim` |
| Ollama modelo instalado | qwen2.5:3b-instruct-q4_K_M |
| Piper voz instalada | pt_BR-faber-medium |
| Kokoro modelo instalado | kokoro-v1.0.onnx |
| faster-whisper modelo | small (int8) |
| Tailscale conectado à tailnet? | `sim` |
| Firewall ativo? | `sim` |
| HD externo montado? | `N.A. / nao validado` |
| Saída completa da validação T17 | `ver 01_infra_backbone/evidencias/2026-03-07_preparacao_mini_pc_portaria_inteligente.md` |
````

---

*Referência: `docs/ADR_ARQUITETURA_V2_EDGE.md` — Fase 1*
