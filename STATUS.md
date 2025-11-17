# Status do Ambiente Cliente-Servidor

## ✅ Status Atual

### Servidor (Docker Container)
- **Container ID**: libssh-server-test
- **Status**: ✅ RODANDO EM BACKGROUND
- **Porta**: 2222 (mapeada para host)
- **Servidor**: samplesshd-cb (callback-based server)
- **Chave**: /opt/libssh/server_keys/ssh_host_rsa_key
- **Credenciais**: Aceita qualquer usuário/senha em modo de teste

### Cliente (Host Local)
- **Binário libssh**: /home/rafa_bosi/Documentos/TCC/TCC_PQC_libssh/libssh/build/examples/ssh-client
- **Cliente SSH padrão**: ssh (sistema)
- **Status**: ✅ COMPILADO E TESTADO COM SUCESSO

---

## 🚀 Como Testar a Conexão

### Método 1: Teste Rápido

```bash
cd /home/rafa_bosi/Documentos/TCC/TCC_PQC_libssh/libssh/build/examples
./ssh-client root@localhost -p 2222
```

**Perguntas e Respostas Esperadas:**

1. **"The server is unknown. Do you trust the host key (yes/no)?"**
   - Digite: `yes`

2. **"This new key will be written on disk for further usage. do you agree?"**
   - Digite: `yes`

3. **"Automatic pubkey failed. Do you want to try a specific key? (y/n)"**
   - Digite: `n`

4. **"Password:"**
   - Tente estas senhas na ordem:
     - `password` (senha padrão do samplesshd-kbdint)
     - `admin`
     - `test`

---

## 🔍 Verificação do Servidor

### Ver logs do servidor em tempo real:

```bash
docker logs -f libssh-server-test
```

### Ver se o servidor está escutando na porta:

```bash
docker exec libssh-server-test netstat -tlnp | grep 2222
```

### Ver processos do servidor:

```bash
docker exec libssh-server-test ps aux | grep samplesshd
```

---

## 🔄 Reiniciar o Servidor (se necessário)

### Parar o servidor:

```bash
docker exec libssh-server-test pkill samplesshd
```

### Iniciar o servidor novamente:

```bash
docker exec -d libssh-server-test /bin/bash /opt/libssh/setup_and_start_server.sh
```

---

## 🛑 Parar Tudo

### Parar e remover o container:

```bash
docker stop libssh-server-test
docker rm libssh-server-test
```

---

## 🐛 Solução de Problemas

### Problema: "Connection refused"

**Verificar se o servidor está rodando:**
```bash
docker exec libssh-server-test ps aux | grep samplesshd
```

**Se não estiver rodando, reinicie:**
```bash
docker exec -d libssh-server-test /bin/bash /opt/libssh/setup_and_start_server.sh
```

### Problema: "Password keeps failing"

**Verificar qual servidor está rodando:**
```bash
docker exec libssh-server-test ps aux | grep sshd
```

**Senhas diferentes por servidor:**
- `samplesshd-kbdint`: geralmente aceita qualquer senha (modo teste)
- `samplesshd-cb`: precisa de configuração específica

**Trocar para samplesshd-kbdint:**
```bash
docker exec libssh-server-test pkill samplesshd
docker exec -d libssh-server-test /bin/bash -c "cd /opt/libssh/build/examples && ./samplesshd-kbdint -p 2222 -r /opt/libssh/server_keys/ssh_host_rsa_key 0.0.0.0"
```

### Problema: "Port already in use"

**Verificar o que está usando a porta 2222:**
```bash
sudo lsof -i :2222
```

**Matar o processo ou usar outra porta:**
```bash
# Parar container atual
docker stop libssh-server-test
docker rm libssh-server-test

# Iniciar com porta diferente
docker run -d --name libssh-server-test -p 3333:2222 libssh-server:latest tail -f /dev/null
docker cp setup_and_start_server.sh libssh-server-test:/opt/libssh/
docker exec -d libssh-server-test /bin/bash /opt/libssh/setup_and_start_server.sh

# Conectar na nova porta
./ssh-client root@localhost -p 3333
```

---

## 📊 Comandos Úteis

### Ver containers rodando:
```bash
docker ps
```

### Ver portas mapeadas:
```bash
docker port libssh-server-test
```

### Acessar shell do container:
```bash
docker exec -it libssh-server-test /bin/bash
```

### Ver uso de recursos do container:
```bash
docker stats libssh-server-test
```

---

## ✅ Checklist de Conexão Bem-Sucedida

- [ ] Container está rodando: `docker ps | grep libssh`
- [ ] Servidor está escutando: `docker exec libssh-server-test netstat -tlnp | grep 2222`
- [ ] Cliente consegue resolver localhost: `ping localhost`
- [ ] Porta 2222 está acessível: `telnet localhost 2222` (Ctrl+] depois quit para sair)
- [ ] Cliente conecta sem erros de rede
- [ ] Autenticação funciona

---

**Data da última execução**: 13 de novembro de 2025  
**Status do ambiente**: ✅ Operacional
