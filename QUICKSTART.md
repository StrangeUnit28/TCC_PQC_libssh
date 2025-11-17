# Guia Rápido: Executar Cliente e Servidor SSH

Este guia mostra como executar o cliente e servidor SSH simultaneamente para testar a conexão.

## ✅ Pré-requisitos verificados

- ✓ Cliente compilado em: `libssh/build/examples/ssh-client`
- ✓ Imagem Docker: `libssh-server:latest` (537MB)
- ✓ Portas 2222 e 22 disponíveis

## 🚀 Executar: 3 passos simples

### PASSO 1: Iniciar o Servidor (Terminal 1)

Abra um terminal e execute:

```bash
cd ~/Documentos/TCC/TCC_PQC_libssh

# Iniciar container do servidor
docker run -it --rm --name libssh-server-test \
  -p 2222:2222 \
  libssh-server:latest /bin/bash
```

**Dentro do container**, execute:

```bash
# Criar diretório para chaves
mkdir -p /opt/libssh/server_keys

# Gerar chave RSA do servidor
ssh-keygen -t rsa -f /opt/libssh/server_keys/ssh_host_rsa_key -N ''

# Iniciar servidor (ESCOLHA UMA OPÇÃO):

# Opção A - Servidor com callback (mais simples):
./samplesshd-cb -p 2222 -r /opt/libssh/server_keys/ssh_host_rsa_key 0.0.0.0

# Opção B - Servidor com keyboard-interactive:
./samplesshd-kbdint -p 2222 -r /opt/libssh/server_keys/ssh_host_rsa_key 0.0.0.0
```

**Aguarde até ver**: `Listening on 0.0.0.0:2222`

---

### PASSO 2: Conectar o Cliente (Terminal 2)

Abra um **NOVO terminal** e execute:

```bash
cd ~/Documentos/TCC/TCC_PQC_libssh/libssh/build/examples

# Conectar ao servidor
./ssh-client root@localhost -p 2222
```

---

### PASSO 3: Autenticação

O cliente vai perguntar:

```
The server is unknown. Do you trust the host key (yes/no)?
```
**Resposta**: `yes`

```
This new key will be written on disk for further usage. do you agree?
```
**Resposta**: `yes`

```
Automatic pubkey failed. Do you want to try a specific key? (y/n)
```
**Resposta**: `n` (para usar senha)

```
Password:
```
**Senhas possíveis** (depende do servidor):
- Para `samplesshd-cb`: veja o código ou tente `admin`, `test`, `password`
- Para `samplesshd-kbdint`: tente `password`, `admin`

---

## 🔍 Solução de Problemas

### Problema: Porta 2222 já em uso

```bash
# Verificar o que está usando a porta
sudo lsof -i :2222

# Matar processo ou usar porta diferente
docker run -it --rm --name libssh-server-test \
  -p 3333:2222 \
  libssh-server:latest /bin/bash

# E conectar em:
./ssh-client root@localhost -p 3333
```

### Problema: Senha não funciona

**Solução 1**: Usar autenticação por chave pública

No cliente, quando perguntar `Do you want to try a specific key?`, responda `y` e forneça:
```
~/.ssh/id_rsa
```

Se não tiver chave, gere uma:
```bash
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
```

**Solução 2**: Ver o código do servidor para descobrir a senha

No container do servidor:
```bash
# Ver o código fonte do servidor
less /opt/libssh/examples/samplesshd-cb.c
# Procure por "password" ou "auth"
```

### Problema: Container não inicia

```bash
# Ver logs de erro
docker logs libssh-server-test

# Verificar se Docker está rodando
docker ps

# Reconstruir imagem se necessário
cd ~/Documentos/TCC/TCC_PQC_libssh
docker build -t libssh-server:latest .
```

### Problema: Cliente não encontrado

```bash
# Recompilar cliente
cd ~/Documentos/TCC/TCC_PQC_libssh/libssh/build
make -j$(nproc)

# Verificar binário
ls -lh examples/ssh-client
```

---

## 🎯 O que você verá quando funcionar

**Terminal 1 (Servidor):**
```
Listening on 0.0.0.0:2222
Socket created: 5
Connection from 172.17.0.1:xxxxx
User root authenticated
Channel opened
```

**Terminal 2 (Cliente):**
```
Welcome to libssh server
root@[container-id]:~$ 
```

Você terá acesso a um shell remoto no container! 🎉

---

## 📝 Comandos Rápidos

### Parar tudo

**Terminal do Cliente**: Ctrl+D ou `exit`  
**Terminal do Servidor**: Ctrl+C

### Reiniciar teste

```bash
# Parar container
docker stop libssh-server-test  # (se não usou --rm)

# Ou simplesmente Ctrl+C no terminal do servidor e reinicie
```

---

## 🔐 Alternativa: Usar SSH padrão do sistema

Você também pode testar com o cliente SSH padrão:

```bash
ssh -p 2222 root@localhost
```

---

**Desenvolvido para**: TCC sobre integração de algoritmos pós-quânticos (Falcon e HQC) na libssh
