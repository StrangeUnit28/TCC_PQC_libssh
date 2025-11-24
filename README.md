# TCC - Integração de Criptografia Pós-Quântica na libssh

## Descrição

Este projeto integra algoritmos de criptografia pós-quântica (PQC) na biblioteca libssh, implementando:

- **HQC-256**: Key Exchange pós-quântico (Hamming Quasi-Cyclic)
- **Falcon-1024**: Assinatura digital pós-quântica

Utiliza **liboqs v0.15.0** para implementação dos algoritmos PQC.

Ambiente testado: Ubuntu com Docker para o servidor SSH.

## Executar o Projeto

### Pré-requisitos

- Ubuntu (testado em 20.04+)
- Docker e Docker Compose
- Git com submódulos

### 1. Clonar o Repositório

```bash
git clone --recursive https://github.com/StrangeUnit28/TCC_PQC_libssh.git
cd TCC_PQC_libssh
```

### 2. Compilar a libssh com PQC

```bash
# Compilar liboqs primeiro
cd third_party/liboqs
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=../../.. -DOQS_BUILD_ONLY_LIB=ON ..
make -j$(nproc)
cd ../../..

# Compilar libssh
cd libssh
mkdir -p build && cd build
cmake .. -DWITH_EXAMPLES=ON -DWITH_SERVER=ON
make -j$(nproc)
cd ../..
```

### 3. Iniciar o Servidor SSH (Docker)

```bash
docker compose up -d
```

O servidor estará disponível na porta 2222.

### 4. Testar a Comunicação PQC

```bash
./test_pqc.sh
```

Ou manualmente:

```bash
LD_LIBRARY_PATH=./libssh/build/src:./third_party/liboqs/build/lib \
./libssh/build/examples/pqc-message-test "echo 'Test message'"
```

### 5. Verificar Logs do Servidor

```bash
docker compose logs -f
HQC-256 server shared secret established
Using Falcon-1024 hostkey: 0x62a318eb09c0
Falcon signature SUCCESS!
HQC-256 key exchange completed (server)
```

## Detalhes Técnicos

### Arquivos Modificados para Integração PQC

| Arquivo | Objetivo |
|---------|----------|
| `libssh/src/server.c` | Adicionar Falcon ao key exchange do servidor |
| `libssh/src/bind.c` | Carregar chave Falcon na sessão via `ssh_key_dup()` |
| `libssh/src/kex.c` | Incluir Falcon nos métodos KEX padrão e priorizar HQC |
| `libssh/src/pki_crypto.c` | Implementar assinatura e conversão Falcon |
| `libssh/src/pki_falcon.c` | Criar `pki_falcon_key_dup()` com cópia de chaves |
| `libssh/src/session.c` | Liberar `falcon1024_key` ao destruir sessão |
| `libssh/include/libssh/session.h` | Adicionar campo `falcon1024_key` à struct srv |
| `libssh/include/libssh/pki_falcon.h` | Forward declarations (compatibilidade C90) |

### Principais Modificações de Código

**1. server.c - server_set_kex() (linhas 107-124)**
```c
if (session->srv.falcon1024_key != NULL) {
    len = strlen(hostkeys);
    if (len > 0) snprintf(hostkeys + len, sizeof(hostkeys) - len, ",");
    snprintf(hostkeys + len, sizeof(hostkeys) - len, "%s",
             ssh_key_type_to_char(ssh_key_type(session->srv.falcon1024_key)));
}
```

**2. pki_falcon.c - pki_falcon_key_dup() (linhas 453-516)**
```c
// Copia chave pública (2.481 bytes)
new_key->falcon->public_key = malloc(key->falcon->public_key_len);
memcpy(new_key->falcon->public_key, key->falcon->public_key, 
       key->falcon->public_key_len);
### 5. Verificar Logs do Servidor

```bash
# Ver logs em tempo real
docker compose logs -f

# Verificar negociação de algoritmos PQC
docker compose logs | grep -E "(Negotiated|HQC-256|Falcon)"
```

## Saída Esperada

Ao executar o teste (`test_pqc.sh`), você verá:

```
[CLIENT] Connecting to localhost:2222...
[CLIENT] ssh_connect returned: 0 (SSH_OK=0)
[CLIENT] Connected! Authenticating as myuser...
[CLIENT] ssh_userauth_password returned: 0
[CLIENT] Authenticated!
Sua mensagem aqui
```

Logs do servidor mostram:
- `Negotiated: hqc256-sha256@libssh.org,ssh-falcon1024@libssh.org`
- `Initializing HQC-256 key exchange (server)`
- `HQC-256 server shared secret established`
- `Using Falcon-1024 hostkey`
- `Falcon signature SUCCESS!`

## Algoritmos PQC Implementados

**HQC-256 (Key Exchange)**
- Chave pública: 7.245 bytes
- Resistente a ataques de computadores quânticos

**Falcon-1024 (Assinatura Digital)**
- Chave pública: 1.793 bytes
- Chave privada: 2.305 bytes
- Assinatura: ~1.280 bytes

## Resolução de Problemas

**Porta 2222 em uso:**
```bash
docker compose down
pkill -9 samplesshd-cb
docker compose up -d
```

**Servidor não inicia:**
```bash
docker compose logs
# Verificar se liboqs está instalada corretamente
```

**Cliente falha na autenticação:**
- Verificar usuário: `myuser` / senha: `mypassword` (configurado em `samplesshd-cb.c`)
- Logs do servidor: `docker compose logs | tail -50`

## Arquivos Modificados

**libssh (submódulo):**
- `src/kex.c` - Implementação HQC-256 key exchange
- `src/pki_falcon.c` - Assinatura e verificação Falcon-1024
- `src/pki.c`, `src/pki_crypto.c` - Suporte a tipo Falcon
- `src/bind.c`, `src/server.c` - Hostkey Falcon no servidor
- `src/session.c` - Estado de sessão HQC-256
- `include/libssh/session.h`, `include/libssh/pki_falcon.h` - Declarações
- `examples/samplesshd-cb.c` - Callback para comando remoto
- `examples/pqc_message_test.c` - Cliente de teste
- `examples/generate_falcon_hostkey.c` - Gerador de chaves Falcon

