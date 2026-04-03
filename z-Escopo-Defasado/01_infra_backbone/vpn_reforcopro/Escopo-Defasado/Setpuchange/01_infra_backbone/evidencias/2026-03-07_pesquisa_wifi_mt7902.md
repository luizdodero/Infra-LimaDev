# Pesquisa técnica - Wi-Fi MediaTek MT7902 no mini-pc - 2026-03-07

## Situação atual no host

O mini-pc possui hardware Wi-Fi MediaTek detectado em PCI/USB, mas o Ubuntu 24.04.4 LTS atual não expõe interface `wlan*`.

### Evidência local

- `lspci -n -s 01:00.0` retorna `14c3:7902`
- `cat /sys/bus/pci/devices/0000:01:00.0/modalias` retorna `pci:v000014C3d00007902...`
- `modinfo mt7921e` lista aliases para `7922` e `7961`, mas não para `7902`
- `linux-firmware` instalado no host: `20240318.git3b128b60-0ubuntu2.25`
- `/lib/firmware/mediatek/` não contém blobs nomeados para `MT7902`
- tentativa de bind/runtime override do ID no driver atual não criou interface Wi-Fi funcional

## Diagnóstico consolidado

O problema atual não é SSID/senha nem configuração do Netplan. O bloqueio está antes da camada de rede:

1. o PCI ID `14c3:7902` não casa com a tabela de device IDs do driver atualmente instalado
2. o firmware disponível no host também não traz blobs específicos de `MT7902`
3. sem bind do driver e sem firmware adequado, não existe interface a configurar

## Fontes primárias consultadas

### 1. Linux Wireless / mt76

A documentação oficial do subsistema `mt76` lista os chips suportados e inclui `MT7921`, `MT7922`, `MT7925` e outros, mas não `MT7902`. A própria página separa "Unsupported chips" para os demais chips MediaTek.

Fonte:
- https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html

### 2. Ubuntu Launchpad - falta de suporte

Bug no Ubuntu HWE 6.8 relata explicitamente que:
- o módulo `mt7921e` não reconhece o PCI ID `14c3:7902`
- não existem arquivos de firmware correspondentes no `linux-firmware`

Fonte:
- https://bugs.launchpad.net/ubuntu/+source/linux-hwe-6.8/+bug/2122600

### 3. Ubuntu Launchpad - workaround relatado por usuário

Bug mais recente no Ubuntu `linux-firmware` registra um workaround relatado por usuário:
- sideload manual de `linux-firmware`
- extração de blobs para `/lib/firmware`
- bind manual com `echo "14c3 7902" > /sys/bus/pci/drivers/mt7921e/new_id`

Importante: isso é um relato de usuário em bug report, não uma correção validada oficialmente pela Ubuntu nem pelo upstream.

Fonte:
- https://bugs.launchpad.net/ubuntu/+source/linux-firmware/+bug/2142536

## Leitura técnica do cenário

### Confirmado

- No estado atual do mini-pc, o Wi-Fi interno não é configurável porque o sistema não cria a interface.
- O Ubuntu 24.04.4 LTS instalado no host não traz suporte pronto para `14c3:7902`.
- O driver `mt7921e` instalado no host não anuncia esse PCI ID.

### Provável, mas ainda não tratei como solução oficial

- Há sinais externos de que suporte upstream ao `MT7902` começou a aparecer em 2026.
- Eu não consegui validar diretamente essa parte em fonte primária navegável com acesso estável a patch/thread completos neste ambiente.
- Portanto, não tratei isso como solução operacional pronta para este mini-pc hoje.

## Caminhos práticos para resolver

### Caminho A - esperar suporte oficial no Ubuntu/kernel

Melhor caminho para estabilidade.

Condição para considerar resolvido:
- release do Ubuntu/kernel passe a incluir o PCI ID `14c3:7902` no driver aplicável
- `linux-firmware` do sistema traga os blobs necessários
- a interface `wlan*` passe a aparecer sem hacks

### Caminho B - testar workaround experimental controlado

Possível, mas com risco e sem garantia.

Envolve:
- obter pacote/revisão de `linux-firmware` mais nova
- verificar presença real de blobs `MT7902`
- forçar bind temporário do ID `14c3:7902` no driver
- validar se surge interface, scan e associação estáveis

Riscos:
- solução não persistente
- regressões após reboot/update
- possível instabilidade em suspend/resume e reconnect

### Caminho C - usar adaptador Wi-Fi USB compatível

Melhor caminho operacional rápido se o cabo Ethernet não for suficiente.

Vantagens:
- baixo risco
- reversível
- não depende de suporte incerto ao `MT7902`

### Caminho D - trocar a placa interna

Melhor caminho definitivo caso o uso em Wi-Fi seja requisito fixo do equipamento.

Critério:
- substituir por chipset já suportado no Ubuntu 24.04

## Recomendação objetiva

Para este projeto, a recomendação prática é:

1. manter o mini-pc em Ethernet para produção/desenvolvimento imediato
2. não gastar tempo operacional tentando fechar rede no `MT7902` com configuração de SSID agora
3. se Wi-Fi for requisito real de mobilidade, priorizar adaptador USB compatível ou troca da placa
4. acompanhar os bugs do Ubuntu e só voltar ao Wi-Fi interno quando houver suporte oficial verificável

## Pendência aberta

Reavaliar o `MT7902` quando:
- houver pacote Ubuntu/kernel com suporte explícito ao `14c3:7902`
- ou quando for decidido adquirir hardware Wi-Fi alternativo para o mini-pc
