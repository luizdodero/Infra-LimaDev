método de Deploy:

Playbook Ansible
Github Actions

VPS:


Firewall UFW portas bloqueadas (exceto realmente necessárias)
Tailscale para acesso adm/interno
Db quando necessário + container (quando for compartilhar vps)
Fail2ban (ssh)
aplicações rodando em usuário com direitos restritos
Caddy Proxy reverso
SSL Lets encrypt
ssh somente com chave, sem senha
Aplicações conforme o caso (container se for compartilhar VPS)
