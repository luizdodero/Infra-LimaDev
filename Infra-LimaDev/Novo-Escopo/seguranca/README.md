# 06_seguranca

## Objetivo
Reduzir superficie de ataque no ecossistema de 5 nos com controles tecnicos e evidencias de auditoria.

## Pastas

- `scans`: resultados de Nmap/ZAP e validacoes periodicas.
- `hardening`: baseline de seguranca por host.
- `chaves_ssh`: padrao de chaves e rotacao.
- `politicas`: controles operacionais e regras de acesso.

## Checklist inicial

- [ ] Executar varredura inicial de portas e servicos expostos.
- [ ] Definir baseline minima de hardening por no.
- [ ] Separar chaves SSH por maquina/uso (especialmente VS Code remoto).
- [ ] Definir calendario de revisao e rotacao de credenciais.
- [x] Concluir bootstrap do `mini-pc` com chave dedicada antes de abrir novos fluxos de desenvolvimento nele.
