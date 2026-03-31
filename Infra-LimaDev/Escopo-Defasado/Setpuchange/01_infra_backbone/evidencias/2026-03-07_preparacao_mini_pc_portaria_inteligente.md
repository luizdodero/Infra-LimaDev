# Preparação do mini-pc para Portaria Inteligente - 2026-03-07

## Escopo concluído

Bootstrap operacional do `mini-pc` para servir como host edge da Portaria Inteligente.

- expansão do LVM raiz para uso efetivo do SSD
- atualização do Ubuntu 24.04.4 LTS
- instalação de pacotes base, Python venv e Docker oficial
- tuning de kernel e governor de CPU em `performance`
- instalação e validação de `ollama`, `piper`, `kokoro-onnx` e `faster-whisper`
- ativação do UFW com portas de backbone e mídia
- validação de Tailscale, NTP e acesso SSH na porta `22022`

## Inventário validado

| Item | Valor |
|------|-------|
| Host | `mini-pc` |
| Usuário SSH | `limadev` |
| Porta SSH | `22022` |
| IP local | `192.168.15.3` |
| IP Tailscale | `100.87.104.42` |
| MagicDNS | `mini-pc.tailed51fe.ts.net` |
| CPU | AMD Ryzen 5 7430U |
| Disco raiz | `/dev/mapper/ubuntu--vg-ubuntu--lv` |
| Uso do disco raiz | `467G` total / `424G` livres |

## Componentes validados

| Componente | Resultado |
|------------|-----------|
| Docker | `29.3.0` |
| Docker Compose | `v5.1.0` |
| Hello World | OK |
| Tailscale | conectado |
| Ping para `note-limdev` | OK (`11ms`) |
| UFW | ativo |
| Governor CPU | `performance` |
| `vm.swappiness` | `10` |
| Ollama | `qwen2.5:3b-instruct-q4_K_M` |
| Piper | `pt_BR-faber-medium.onnx` |
| Kokoro | `kokoro-v1.0.onnx` |
| faster-whisper | `small` |
| `portaria-piper.service` | ativo e habilitado |

## Testes rápidos

- `ollama run qwen2.5:3b-instruct-q4_K_M 'Responda em português em uma frase: qual é a capital do Brasil?'`
  Resultado: "capital do Brasil é Brasília."
- Piper gerou `/tmp/teste_piper.wav`
- Kokoro gerou `/tmp/teste_kokoro.wav`
- faster-whisper transcreveu o áudio de teste em português
- reboot do host validado com retorno do SSH `22022` e healthcheck `http://127.0.0.1:18888/health`

## Observações operacionais

- O host ficou com timezone `UTC`.
- O dispositivo `sdb` (`57.3G`, removível) não foi formatado nem montado por segurança.
- O acesso `sudo` temporário usado no bootstrap foi removido ao final.
- O helper container `portaria-bootstrap` foi apagado após a preparação.
- Auto login local habilitado em `tty1` para `limadev`.
- SSH permaneceu separado na porta `22022`.

## Pendências para a próxima fase

- Informar a URL do repositório do aplicativo para clonar em `/srv/portaria/`.
- Publicar Asterisk, LiveKit e os serviços do projeto sobre a base já preparada.
- Decidir se será necessário ajustar o timezone do host para `America/Sao_Paulo`.
- Se o requisito incluir ligar sozinho apos falta de energia, ajustar a BIOS para retorno automatico de energia.
