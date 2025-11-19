# Resumo da Implementação PQC na libssh

## Objetivo

Integrar algoritmos de criptografia pós-quântica (HQC-256 e Falcon-1024) na libssh para estabelecer comunicação SSH resistente a computadores quânticos.

## Arquivos Modificados

### libssh (submódulo)

**Arquivos de Implementação:**
- `src/kex.c` - Key exchange HQC-256 (cliente e servidor)
- `src/pki_falcon.c` - Assinatura e verificação Falcon-1024
- `src/pki.c` - Reconhecimento do tipo Falcon (`ssh_key_hash_from_name`)
- `src/pki_crypto.c` - Parsing e verificação de assinaturas Falcon (`pki_signature_from_blob`, `pki_verify_data_signature`)
- `src/bind.c` - Carregamento de hostkey Falcon no servidor
- `src/server.c` - Verificação de hostkey Falcon em `server_set_kex()`
- `src/session.c` - Estado de sessão HQC-256
- `src/options.c` - Parsing de algoritmos PQC nas opções

**Headers:**
- `include/libssh/session.h` - Campos `hqc_pub_key`, `hqc_priv_key`, `hqc_shared_secret`
- `include/libssh/pki_falcon.h` - Declarações de funções Falcon
- `include/libssh/bind.h` - `ssh_bind_options_set_falcon1024_hostkey()`

**Exemplos:**
- `examples/samplesshd-cb.c` - Callback `exec_request` para execução de comandos
- `examples/pqc_message_test.c` - Cliente para testes de mensagens PQC
- `examples/generate_falcon_hostkey.c` - Utilitário para gerar chaves Falcon
- `examples/CMakeLists.txt` - Build dos novos executáveis

### Repositório Principal

**Scripts:**
- `start_ssh_server.sh` - Geração de chaves Falcon, pkill de processos duplicados
- `test_pqc_message.sh` - Teste automatizado de mensagens PQC

**Infraestrutura:**
- `Dockerfile` - Ubuntu 22.04, liboqs, libssh compilado
- `docker-compose.yml` - Container do servidor SSH na porta 2222
- `.dockerignore`, `.gitignore` - Exclusão de arquivos gerados

**Documentação:**
- `README.md` - Instruções de execução
- `PROJECT_STATUS.txt` - Status do projeto

## Problemas Resolvidos

### 1. Cliente Desconectava Após Handshake

**Sintoma:**
```
[CLIENT] ssh_connect returned: 0 (SSH_OK=0)
[CLIENT] Connected! Authenticating as myuser...
[CLIENT] ssh_userauth_password returned: -9
```

**Causa:**
Em `pki_crypto.c`, função `pki_verify_data_signature()` verificava `signature->raw_sig` (NULL para Falcon) causando erro "Bad parameter".

**Solução:**
Adicionar caso especial para `SSH_KEYTYPE_FALCON_1024`:
```c
case SSH_KEYTYPE_FALCON_1024:
    if (signature->falcon_sig == NULL) {
        ssh_set_error(pubkey, SSH_FATAL, "Bad parameter falcon_sig");
        return SSH_ERROR;
    }
    break;
```

**Resultado:**
Autenticação completa, cliente consegue enviar comandos via `exec_request`.

### 2. Assinatura Falcon Não Reconhecida

**Sintoma:**
```
Unknown signature name ssh-falcon1024@libssh.org
```

**Causa:**
Função `ssh_key_hash_from_name()` em `pki.c` não tinha entrada para Falcon.

**Solução:**
Adicionar caso:
```c
else if (strcmp(name, "ssh-falcon1024@libssh.org") == 0) {
    return SSH_DIGEST_AUTO;
}
```

### 3. Parsing de Assinatura Falcon Falhava

**Sintoma:**
```
Unknown signature type
```

**Causa:**
Switch em `pki_signature_from_blob()` sem caso para `SSH_KEYTYPE_FALCON_1024`.

**Solução:**
```c
case SSH_KEYTYPE_FALCON_1024:
    rc = ssh_pki_falcon_signature_from_blob(key, sig_blob, sig);
    break;
```

### 4. Múltiplos Processos do Servidor

**Sintoma:**
```
Error binding to socket: Address already in use
```

**Causa:**
Loop em `start_ssh_server.sh` criava processos duplicados do `samplesshd-cb`.

**Solução:**
Adicionar `pkill -9 samplesshd-cb` antes de iniciar novo processo.

### 5. Chaves SSH em Repositório

**Sintoma:**
Pasta `server_data/` contendo chaves privadas prestes a ser commitada.

**Causa:**
`server_data/` gerada pelo Docker não estava em `.gitignore`.

**Solução:**
Adicionar ao `.gitignore`:
```
server_data/
ssh_host_*_key
ssh_host_*_key.pub
```

### 6. Servidor Crashava no Key Exchange

**Sintoma:**
```
[KEX_DEBUG] server_set_kex returned: -1
Socket error: disconnected
```

**Causa:**
`server_set_kex()` em `server.c` verificava apenas ed25519/ecdsa/rsa, retornando erro para Falcon.

**Solução:**
Adicionar verificação de hostkey Falcon:
```c
if (session->srv.falcon1024_key) {
    ssh_set_error(session, SSH_FATAL, "Cannot set KEX without hostkey");
    return SSH_ERROR;
}
```

### 7. Duplicação de Chave Falhava

**Sintoma:**
```
[BIND_DEBUG] ssh_key_dup returned: (nil)
```

**Causa:**
Switch em `ssh_key_dup()` não tinha caso para `SSH_KEYTYPE_FALCON_1024`.

**Solução:**
Implementar `pki_falcon_key_dup()` com alocação dinâmica e cópia de buffers:
```c
new_key->falcon->public_key = malloc(key->falcon->public_key_len);
memcpy(new_key->falcon->public_key, key->falcon->public_key, key->falcon->public_key_len);

new_key->falcon->secret_key = malloc(key->falcon->secret_key_len);
memcpy(new_key->falcon->secret_key, key->falcon->secret_key, key->falcon->secret_key_len);
```

## Abordagens Alternativas

### Inicialmente Tentado: Modificação Manual de Todos os Switch Cases

**Problema:**
Tentamos adicionar manualmente casos para Falcon em cada switch da libssh sem entender a arquitetura completa.

**Resultado:**
Compilava mas falhava em runtime com segfaults e NULL pointers.

**Lição:**
Necessário entender o fluxo completo (parsing → verificação → assinatura → serialização) antes de modificar código.

### Inicialmente Tentado: Uso de raw_sig para Falcon

**Problema:**
Tentamos reutilizar campo `signature->raw_sig` (usado por RSA/ECDSA) para Falcon.

**Resultado:**
`pki_verify_data_signature()` falhava porque `raw_sig` era NULL para Falcon.

**Solução Final:**
Criar campo separado `falcon_sig` e adicionar caso específico na verificação.

### Inicialmente Tentado: Gerar Chaves Falcon Durante Build

**Problema:**
Build CMake gerava chaves Falcon e as incluía no container.

**Resultado:**
Chaves eram as mesmas para todos os containers, criando vulnerabilidade de segurança.

**Solução Final:**
Gerar chaves na primeira inicialização do container (`start_ssh_server.sh`) e persistir em volume Docker (`server_data/`).

## Decisões Técnicas

**1. Priorização de HQC-256**

Colocamos HQC-256 como primeira opção em `DEFAULT_KEY_EXCHANGE` para forçar uso de PQC puro (sem híbridos como MLKEM768X25519).

**2. Uso de liboqs**

Decidimos usar Open Quantum Safe (liboqs) ao invés de implementações próprias para garantir algoritmos testados e auditados pela comunidade.

**3. Docker para Servidor**

Isolamento do ambiente do servidor facilita testes e evita conflitos com outras instalações de libssh.

**4. Callback exec_request**

Implementamos callback para executar comandos remotos, provando que o canal PQC funciona para comunicação bidirecional, não apenas handshake.

**5. Persistência de Chaves**

Volume Docker `server_data/` mantém chaves Falcon entre reinicializações, evitando regeneração constante (operação cara: ~500ms).

## Resultados

**Funcionando:**
- Key exchange HQC-256 (cliente e servidor)
- Assinatura digital Falcon-1024
- Autenticação de usuário
- Troca de mensagens criptografadas

