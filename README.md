# TCC - Post-Quantum Cryptography (PQC) Integration in libssh# TCC: Integração de Algoritmos Pós-Quânticos na libssh



Este projeto integra algoritmos de criptografia pós-quântica (PQC) na biblioteca libssh:## Sobre este Repositório



- **Falcon-1024**: Assinatura digital pós-quânticaEste repositório faz parte do Trabalho de Conclusão de Curso (TCC) sobre a integração de algoritmos de criptografia pós-quântica na biblioteca libssh.

- **HQC-256**: Troca de chaves pós-quântica (Key Exchange)

### Objetivo

## 🎯 Objetivo

O objetivo deste projeto é a integração dos seguintes algoritmos pós-quânticos:

Estabelecer conexões SSH seguras contra ataques de computadores quânticos usando apenas os exemplos nativos da libssh (`ssh-client` e `samplesshd-cb`).- **Falcon**: Para assinatura digital

- **HQC (Hamming Quasi-Cyclic)**: Para encapsulamento de chaves (KEM)

## 🏗️ Arquitetura

### Estrutura do Ambiente

```

┌─────────────────┐         SSH sobre PQC         ┌──────────────────┐Este repositório contém a configuração necessária para o ambiente de testes da libssh modificada:

│  Host (Client)  │ ════════════════════════════> │ Docker (Server)  │

│   ssh-client    │    Port 2222                  │  samplesshd-cb   │- **Cliente**: A libssh clonada e modificada roda localmente 

└─────────────────┘                                └──────────────────┘- **Servidor**: Um container Docker executando o servidor libssh para testes de comunicação

```

### Ambiente de Desenvolvimento

**Algoritmos Negociados:**

- KEX: `hqc256-sha256@libssh.org` (7.245 bytes chave pública)O ambiente foi configurado para permitir testes completos da comunicação SSH com os algoritmos pós-quânticos integrados, utilizando:

- Hostkey: `ssh-falcon1024@libssh.org` (2.481B pub / 10.507B priv)- Cliente SSH local com as modificações implementadas

- Servidor SSH em container Docker para isolamento e facilidade de testes

## 🚀 Quick Start

**Nota**: A parte teórica do TCC foi desenvolvida separadamente e não está incluída neste repositório, que foca exclusivamente na implementação prática e no ambiente de testes.

### 1. Compilar libssh

```bash
cd libssh
mkdir -p build && cd build
cmake .. -DWITH_EXAMPLES=ON -DWITH_SERVER=ON -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
cd ../..
```

### 2. Iniciar Servidor

```bash
docker compose up -d
```

### 3. Provar Integração PQC

**Prova Automatizada Completa:**
```bash
./prove_pqc_integration.sh
```

Este script verifica:
- ✓ Compilação do cliente e servidor
- ✓ Chaves Falcon-1024 (10.507 bytes priv, 2.481 bytes pub)
- ✓ Negociação dos algoritmos PQC
- ✓ Key exchange HQC-256 completado
- ✓ Assinatura Falcon executada
- ✓ 8 arquivos modificados no código

**Demonstração Interativa (com logs em tempo real):**
```bash
./demo_pqc_live.sh
```

**Teste Manual:**
```bash
./quick_test_pqc.sh
# ou
./libssh/build/examples/ssh-client -p 2222 localhost
```

**Evidências da Integração nos Logs:**

```
✓ Negotiated: hqc256-sha256@libssh.org,ssh-falcon1024@libssh.org
✓ Initializing HQC-256 key exchange (server)
✓ HQC-256 server shared secret established
✓ Using Falcon-1024 hostkey: 0x62a318eb09c0
✓ Falcon signature SUCCESS!
✓ HQC-256 key exchange completed (server)
```

## 🔧 Modificações Implementadas

### 8 Arquivos Modificados para Integração Completa

| Arquivo | Mudanças | Objetivo |
|---------|----------|----------|
| `libssh/src/server.c` | +45 linhas | Adicionar Falcon ao key exchange do servidor |
| `libssh/src/bind.c` | +17 linhas | Carregar chave Falcon na sessão via `ssh_key_dup()` |
| `libssh/src/kex.c` | +8 linhas | Incluir Falcon nos métodos KEX padrão e priorizar HQC |
| `libssh/src/pki_crypto.c` | +47 linhas | Implementar assinatura e conversão Falcon |
| `libssh/src/pki_falcon.c` | +65 linhas | Criar `pki_falcon_key_dup()` com cópia de chaves |
| `libssh/src/session.c` | +2 linhas | Liberar `falcon1024_key` ao destruir sessão |
| `libssh/include/libssh/session.h` | +1 linha | Adicionar campo `falcon1024_key` à struct srv |
| `libssh/include/libssh/pki_falcon.h` | +6 linhas | Forward declarations (compatibilidade C90) |

### Detalhes das Principais Modificações

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

// Copia chave privada (10.507 bytes)
new_key->falcon->secret_key = malloc(key->falcon->secret_key_len);
memcpy(new_key->falcon->secret_key, key->falcon->secret_key,
       key->falcon->secret_key_len);
```

**3. kex.c - Priorização de Algoritmos (linha 194)**
```c
#define DEFAULT_KEY_EXCHANGE \
    HQC256 \           // Prioridade 1
    MLKEM768X25519 \   // Prioridade 2
    SNTRUP761X25519 \  // Prioridade 3
    CURVE25519 \
    ECDH \
```

## 🐛 5 Problemas Críticos Resolvidos

### 1. Server Crash no Key Exchange
- **Sintoma**: Servidor encerrava com código 1, cliente recebia "Socket error: disconnected"
- **Log**: `[KEX_DEBUG] server_set_kex returned: -1`
- **Causa**: `server_set_kex()` só verificava ed25519/ecdsa/rsa, não Falcon
- **Solução**: Adicionada verificação e construção de hostkeys para Falcon

### 2. ssh_key_dup() Retornando NULL
- **Sintoma**: `[BIND_DEBUG] ssh_key_dup returned: (nil)`
- **Causa**: Switch statement sem caso para `SSH_KEYTYPE_FALCON_1024`
- **Solução**: Implementada `pki_falcon_key_dup()` com alocação dinâmica

### 3. Cliente Não Oferecia Falcon
- **Sintoma**: Lista de hostkeys do cliente sem Falcon na negociação
- **Causa**: Macros `DEFAULT_HOSTKEYS` e `PUBLIC_KEY_ALGORITHMS` sem Falcon
- **Solução**: Criada macro `FALCON_HOSTKEYS`, incluída em ambas as listas

### 4. Extração de Chave Pública Falhava
- **Sintoma**: "Could not get the public key from the private key"
- **Causa**: `ssh_get_key_params()` sem caso para Falcon
- **Solução**: Adicionado `case SSH_KEYTYPE_FALCON_1024:` retornando `session->srv.falcon1024_key`

### 5. Conversão de Assinatura Falhava
- **Sintoma**: "Unknown signature key type: ssh-falcon1024@libssh.org"
- **Causa**: `pki_signature_to_blob()` sem caso Falcon
- **Solução**: Adicionado caso chamando `ssh_pki_falcon_signature_to_blob()`

## 📁 Estrutura do Projeto

```
TCC_PQC_libssh/
├── libssh/                     # Biblioteca libssh modificada
│   ├── src/                    # Código-fonte (8 arquivos modificados)
│   ├── include/libssh/         # Headers (2 arquivos modificados)
│   ├── build/                  # Build CMake (criar com mkdir)
│   └── examples/               # Contém samplesshd-cb.c (servidor)
├── third_party/liboqs/         # Open Quantum Safe (dependência)
├── docker-compose.yml          # Orquestração Docker
├── Dockerfile                  # Imagem Ubuntu 22.04 + libssh + liboqs
├── start_ssh_server.sh         # Script de inicialização do container
├── quick_test_pqc.sh           # Script de teste rápido
└── server_data/                # Volume persistente para chaves Falcon
    ├── ssh_host_falcon1024_key
    └── ssh_host_falcon1024_key.pub
```

## 🔍 Verificação de Logs

```bash
# Ver logs do servidor em tempo real
docker compose logs -f

# Procurar por negociação PQC
docker compose logs | grep -E "(Negotiated|HQC-256|Falcon)"

# Verificar chaves geradas
ls -lh server_data/
```

## 📊 Métricas dos Algoritmos

| Algoritmo | Tipo | Tamanho Chave Pública | Tamanho Chave Privada |
|-----------|------|----------------------|----------------------|
| Falcon-1024 | Assinatura | 2.481 bytes | 10.507 bytes |
| HQC-256 | KEX | 7.245 bytes | - |

**Comparação com Algoritmos Clássicos:**
- RSA-2048 privada: ~2.048 bytes → Falcon-1024: ~10.507 bytes **(5x maior)**
- RSA-2048 pública: ~256 bytes → Falcon-1024: ~2.481 bytes **(10x maior)**
- ECDH Curve25519: ~32 bytes → HQC-256: ~7.245 bytes **(226x maior)**

## ✅ Validação da Integração

### Scripts de Prova

Este projeto inclui 3 scripts para provar que a integração PQC está funcionando:

**1. `prove_pqc_integration.sh` - Prova Automatizada Completa**
```bash
./prove_pqc_integration.sh
```
Verifica automaticamente:
- Compilação do cliente e servidor
- Presença e tamanho correto das chaves Falcon
- Execução de conexão de teste
- Análise de logs do servidor (6 evidências)
- Verificação dos 8 arquivos modificados
- Configuração dos algoritmos no código

**2. `demo_pqc_live.sh` - Demonstração Interativa**
```bash
./demo_pqc_live.sh
```
Mostra logs do servidor em tempo real durante uma conexão PQC.

**3. `quick_test_pqc.sh` - Teste Rápido**
```bash
./quick_test_pqc.sh
```
Teste simples de conectividade.

### Evidências Coletadas

O script `prove_pqc_integration.sh` coleta e valida 6 evidências nos logs:

**[EVIDÊNCIA 1] Algoritmos Negociados**
```
Negotiated: hqc256-sha256@libssh.org,ssh-falcon1024@libssh.org
```

**[EVIDÊNCIA 2] Inicialização HQC-256**
```
Initializing HQC-256 key exchange (server)
```

**[EVIDÊNCIA 3] Shared Secret Estabelecido**
```
HQC-256 server shared secret established
```

**[EVIDÊNCIA 4] Chave Falcon Utilizada**
```
Using Falcon-1024 hostkey: 0x62a318eb09c0
```

**[EVIDÊNCIA 5] Assinatura Digital**
```
Falcon signature SUCCESS!
```

**[EVIDÊNCIA 6] Key Exchange Completo**
```
HQC-256 key exchange completed (server)
```

## 🐳 Docker

O container servidor inclui:
- Ubuntu 22.04 base
- libssh compilado com PQC
- liboqs (Open Quantum Safe)
- samplesshd-cb configurado na porta 2222
- Volume persistente para chaves

## 🎓 Contexto Acadêmico

Trabalho de Conclusão de Curso (TCC) investigando a viabilidade de integração de criptografia pós-quântica em protocolos SSH existentes, preparando infraestruturas de comunicação remota para a era dos computadores quânticos.

## 📝 Notas Técnicas

- **C90 Compliance**: Todas as modificações seguem C90 (declarações no início de blocos)
- **Forward Declarations**: Adicionadas em `pki_falcon.h` para evitar dependências circulares
- **Memory Management**: `pki_falcon_key_dup()` usa malloc/memcpy; `ssh_key_free()` libera
- **Key Exchange Order**: HQC-256 priorizado para forçar uso de PQC puro

## 📄 Licença

Este projeto segue a licença da libssh original (LGPL 2.1).
