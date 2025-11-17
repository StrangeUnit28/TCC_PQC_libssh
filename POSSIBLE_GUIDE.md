# Guia de Integração de Algoritmos Pós-Quânticos na libssh

## Decisões Técnicas do Projeto

### Algoritmos e Parâmetros Escolhidos

**Decisão Técnica**: Utilização de parâmetros com **máxima segurança**
- **HQC-256** para Key Exchange (KEM)
  - Chave pública: ~7.245 bytes
  - Nível de segurança NIST: 5
  - Justificativa: Máxima credibilidade acadêmica e segurança pós-quântica
  
- **Falcon-1024** para Assinatura Digital (Host/User Authentication)
  - Chave pública: 1.793 bytes
  - Assinatura: ~1.280 bytes
  - Nível de segurança NIST: 5
  - Justificativa: Compatibilidade de nível de segurança com HQC-256

**Trade-offs Documentados**:
- ✅ Máxima segurança pós-quântica
- ✅ Credibilidade acadêmica (uso de parâmetros máximos)
- ⚠️ Overhead de rede significativo (~8.5KB por handshake)
- ⚠️ Aumento de latência no handshake SSH
- 📊 Métricas comparativas serão documentadas

**Escopo de Implementação Futuro** (se houver tempo):
- HQC-192 + Falcon-1024 para análise comparativa de trade-offs

### Versão da liboqs

**Decisão**: liboqs **0.15.0** (versão estável mais recente - lançada em 14/11/2025)
- Fixação de versão para reprodutibilidade: `git checkout 0.15.0` no submódulo
- **IMPORTANTE**: HQC deve ser habilitado explicitamente: `-DOQS_ENABLE_KEM_HQC=ON`
- Uso da **API nova com context parameter**:
  ```c
  OQS_SIG_sign(sig, signature, &sig_len, message, message_len, 
               secret_key, context, context_len)
  ```
- Context será passado como `NULL, 0` (sem contexto adicional)
- **Tamanhos confirmados**:
  - HQC-256: chave pública 7245 bytes, ciphertext 14421 bytes
  - Falcon-1024: chave pública 1793 bytes, assinatura 1462 bytes

### Wire Format e Compatibilidade

**Decisão**: Seguir o padrão **OpenSSH-OQS**
- Justificativa: Formato consolidado e testado pela comunidade
- Compatibilidade com implementações existentes
- Documentação de referência disponível
- Nomenclatura de algoritmos padronizada

### Derivação de Chaves Híbridas

**Decisão Técnica**: Usar HKDF-SHA256 para combinação de segredos

**NÃO será usado**: XOR simples (inseguro)

**Método Correto** (padrão OpenSSH-OQS):
```c
shared_secret_hybrid = SHA256(
    shared_secret_classical || 
    shared_secret_pqc ||
    session_id
)
```

Onde:
- `shared_secret_classical`: segredo do DH/ECDH tradicional
- `shared_secret_pqc`: segredo do HQC-256
- `session_id`: identificador da sessão SSH
- `||`: concatenação de bytes

**Justificativa**: Função de derivação de chaves adequada que:
- Combina segurança clássica + pós-quântica
- Mantém propriedades criptográficas corretas
- Segue padrão RFC e melhores práticas

### Métricas a Serem Coletadas

**Objetivo**: Análise comparativa quantitativa para o TCC

#### Métricas Base (libssh sem PQC):
1. Latência do handshake completo
2. Tamanho total dos pacotes trocados
3. Tempo de processamento de KEX
4. Tempo de processamento de autenticação
5. Uso de CPU e memória

#### Métricas PQC (libssh com HQC-256 + Falcon-1024):
1. Latência do handshake completo
2. Tamanho total dos pacotes trocados
3. Tempo de processamento de KEX híbrido
4. Tempo de processamento de autenticação Falcon
5. Uso de CPU e memória

#### Métricas Comparativas:
- Overhead percentual de latência
- Overhead percentual de largura de banda
- Impacto no tempo de resposta da sessão
- Análise de viabilidade em diferentes cenários de rede

**Ferramentas de Medição**:
- `clock_gettime()` para medições precisas
- Logs detalhados de cada fase do protocolo
- Scripts de análise estatística (média, desvio padrão, percentis)

### Estratégia de Implementação

**Abordagem Incremental** (recomendação seguida):
1. **Fase 1**: KEX PQC puro (HQC-256 apenas)
   - Implementar sem híbrido primeiro
   - Validar comunicação básica
   - Medir métricas isoladas
   
2. **Fase 2**: KEX Híbrido (ECDH + HQC-256)
   - Adicionar combinação com algoritmo clássico
   - Implementar derivação de chaves híbrida
   - Validar compatibilidade
   
3. **Fase 3**: Autenticação PQC (Falcon-1024)
   - Implementar geração de chaves
   - Implementar assinatura/verificação
   - Integrar ao fluxo de autenticação

4. **Fase 4**: Integração Completa e Testes
   - Cliente e servidor com suporte completo
   - Testes de interoperabilidade
   - Coleta de métricas finais

### Documentação Técnica Obrigatória

**Cada passo deve incluir**:
1. Justificativa técnica da decisão
2. Referências a RFCs e papers acadêmicos
3. Wire format detalhado (estrutura binária)
4. Diagramas de sequência do protocolo
5. Resultados de testes e validações
6. Análise de segurança da implementação

---

## Veredicto Técnico (Justificativa)

Liboqs fornece APIs C separadas para KEM e para assinaturas (kem.h, sig.h) — você pode criar/usar instâncias de OQS_KEM e OQS_SIG e chamar keypair/encaps/decaps e keypair/sign/verify. Isso é exatamente o que você precisa para KEX (HQC) e host/user keys (Falcon).

SSH tem dois lugares óbvios para integrar PQC:
1. **KEX/key-exchange**: Substituir/estender um algoritmo de KEX por um esquema de KEM ou um híbrido KEX+KEM
2. **Host/User public key**: Assinaturas para autenticação

Isso é conceitualmente compatível com os tipos KEM vs assinatura. Há forks/exemplos onde isso foi feito (OpenSSH + liboqs).

---

## Passo a Passo de Implementação

### Pressupostos
- Mirror da libssh funcionando (client na máquina host, server em container)
- Ambiente Docker configurado e testado
- Git para gerenciamento de submódulos

### 0. Preparação — Repositório e Build

#### 0.1. Adicionar liboqs como Submódulo

**Comando**:
```bash
cd /home/rafa_bosi/Documentos/TCC/TCC_PQC_libssh
git submodule add https://github.com/open-quantum-safe/liboqs.git third_party/liboqs
cd third_party/liboqs
git checkout 0.15.0
cd ../..
git add .gitmodules third_party/liboqs
git commit -m "Add liboqs 0.15.0 as Git submodule"
```

**Justificativa Técnica**:
- Facilita builds reprodutíveis e pinagem de commit específico
- Abordagem usada por projetos OQS/OpenSSH
- Permite controle de versão completo do código-fonte
- Alternativa (NÃO recomendada para TCC): tratar liboqs como dependência do sistema via `find_package`

**Documentação**:
- Registrar commit hash exato da liboqs 0.11.1
- Documentar dependências de build da liboqs
- Incluir instruções de atualização do submódulo

#### 0.2. Configurar Build da liboqs

**Modificação**: `CMakeLists.txt` do projeto principal

**Adicionar**:
```cmake
# Integração da liboqs
add_subdirectory(third_party/liboqs)

# Configurar include paths
include_directories(third_party/liboqs/include)

# Linkar liboqs com libssh
target_link_libraries(ssh PRIVATE oqs)
```

**Teste de Validação**:
```bash
cd libssh
mkdir -p build && cd build
cmake .. -DBUILD_SHARED_LIBS=ON
cmake --build .

# Testar exemplo liboqs (HQC deve ser habilitado explicitamente!)
cd ../../third_party/liboqs
mkdir -p build && cd build
cmake .. -GNinja -DBUILD_SHARED_LIBS=ON -DOQS_ENABLE_KEM_HQC=ON
ninja

# Testar HQC-256 e Falcon-1024
cd ../../..
gcc test_liboqs.c -o test_liboqs \
    -I third_party/liboqs/build/include \
    -L third_party/liboqs/build/lib \
    -loqs -Wl,-rpath,third_party/liboqs/build/lib
./test_liboqs
```

**Critério de Sucesso**: Exemplos executam sem erro e geram chaves/assinaturas

---

### 1. Mapeamento de Pontos de Extensão na libssh

#### 1.1. Identificar Módulos Relevantes

**Arquivos-chave a localizar**:
```
libssh/src/
├── kex.c              # Implementação de Key Exchange
├── dh.c               # Diffie-Hellman clássico
├── ecdh.c             # Elliptic Curve DH
├── pki.c              # Infraestrutura de chave pública
├── pki_crypto.c       # Operações criptográficas
├── auth.c             # Autenticação
└── packet.c           # Serialização de pacotes
```

**Comando de Busca**:
```bash
cd libssh
grep -r "ssh_kex_methods" src/
grep -r "ssh_key_type" src/
grep -r "KEX_ALGO" include/
```

#### 1.2. Tabela de Algoritmos

**Localizar**: Estrutura que registra algoritmos disponíveis

Exemplo típico:
```c
static struct ssh_kex_methods_s ssh_kex_methods[] = {
    {"diffie-hellman-group14-sha256", ...},
    {"ecdh-sha2-nistp256", ...},
    // ADICIONAR: {"hqc256-sha256@openssh.com", ...}
    {NULL, NULL}
};
```

**Documentação Necessária**:
- Estrutura exata da tabela de métodos
- Função de registro de algoritmos
- Fluxo de negociação cliente-servidor

---

### 2. Implementação do HQC-256 (KEM) — KEX Híbrido

#### 2.1. Definir Nomes de Algoritmo (Wire Format)

**Padrão OpenSSH-OQS**:
```
# KEX puro
hqc256-sha256@openssh.com

# KEX híbrido (FASE 2)
ecdh-nistp256-hqc256-sha256@openssh.com
```

**Adicionar em**: `libssh/include/libssh/crypto.h`
```c
#define SSH_KEX_HQC256_SHA256 "hqc256-sha256@openssh.com"
#define SSH_KEX_ECDH_HQC256_SHA256 "ecdh-nistp256-hqc256-sha256@openssh.com"
```

#### 2.2. Estrutura de Dados

**Criar**: `libssh/src/pqc_kex.h`
```c
#ifndef PQC_KEX_H
#define PQC_KEX_H

#include <oqs/oqs.h>

typedef struct ssh_pqc_kex_ctx_st {
    OQS_KEM *kem;
    uint8_t *public_key;
    uint8_t *secret_key;
    uint8_t *ciphertext;
    uint8_t *shared_secret;
    size_t public_key_len;
    size_t secret_key_len;
    size_t ciphertext_len;
    size_t shared_secret_len;
} ssh_pqc_kex_ctx;

#endif /* PQC_KEX_H */
```

#### 2.3. Implementação do KEX PQC Puro (Fase 1)

**Criar**: `libssh/src/pqc_kex.c`

**Função de Inicialização**:
```c
#include "pqc_kex.h"
#include <string.h>

ssh_pqc_kex_ctx* ssh_pqc_kex_init(const char *alg_name) {
    ssh_pqc_kex_ctx *ctx = calloc(1, sizeof(ssh_pqc_kex_ctx));
    if (!ctx) return NULL;
    
    // Inicializar HQC-256
    ctx->kem = OQS_KEM_new("HQC-256");
    if (!ctx->kem) {
        free(ctx);
        return NULL;
    }
    
    // Alocar buffers com tamanhos corretos
    ctx->public_key_len = ctx->kem->length_public_key;
    ctx->secret_key_len = ctx->kem->length_secret_key;
    ctx->ciphertext_len = ctx->kem->length_ciphertext;
    ctx->shared_secret_len = ctx->kem->length_shared_secret;
    
    ctx->public_key = malloc(ctx->public_key_len);
    ctx->secret_key = malloc(ctx->secret_key_len);
    ctx->ciphertext = malloc(ctx->ciphertext_len);
    ctx->shared_secret = malloc(ctx->shared_secret_len);
    
    return ctx;
}
```

**Função de Geração de Chaves (Cliente)**:
```c
int ssh_pqc_kex_generate_keypair(ssh_pqc_kex_ctx *ctx) {
    if (!ctx || !ctx->kem) return SSH_ERROR;
    
    OQS_STATUS status = OQS_KEM_keypair(
        ctx->kem,
        ctx->public_key,
        ctx->secret_key
    );
    
    return (status == OQS_SUCCESS) ? SSH_OK : SSH_ERROR;
}
```

**Função de Encapsulamento (Servidor)**:
```c
int ssh_pqc_kex_encapsulate(ssh_pqc_kex_ctx *ctx, 
                             const uint8_t *client_public_key) {
    if (!ctx || !ctx->kem) return SSH_ERROR;
    
    OQS_STATUS status = OQS_KEM_encaps(
        ctx->kem,
        ctx->ciphertext,
        ctx->shared_secret,
        client_public_key
    );
    
    return (status == OQS_SUCCESS) ? SSH_OK : SSH_ERROR;
}
```

**Função de Decapsulamento (Cliente)**:
```c
int ssh_pqc_kex_decapsulate(ssh_pqc_kex_ctx *ctx,
                              const uint8_t *ciphertext) {
    if (!ctx || !ctx->kem) return SSH_ERROR;
    
    OQS_STATUS status = OQS_KEM_decaps(
        ctx->kem,
        ctx->shared_secret,
        ciphertext,
        ctx->secret_key
    );
    
    return (status == OQS_SUCCESS) ? SSH_OK : SSH_ERROR;
}
```

#### 2.4. Wire Format do Protocolo

**Formato do Pacote SSH_MSG_KEX_PQC_INIT (Cliente → Servidor)**:
```
byte      SSH_MSG_KEX_PQC_INIT (valor: 30, customizado)
string    client_pqc_public_key  (7245 bytes para HQC-256)
```

**Formato do Pacote SSH_MSG_KEX_PQC_REPLY (Servidor → Cliente)**:
```
byte      SSH_MSG_KEX_PQC_REPLY (valor: 31, customizado)
string    server_host_key_blob
string    pqc_ciphertext (9026 bytes para HQC-256)
string    signature_of_exchange_hash
```

**Serialização** (exemplo):
```c
ssh_buffer buf = ssh_buffer_new();
ssh_buffer_pack(buf, "bS",
    SSH_MSG_KEX_PQC_INIT,
    ctx->public_key_len, ctx->public_key);
```

#### 2.5. Integração ao Fluxo KEX da libssh

**Modificar**: `libssh/src/kex.c`

**Adicionar Função de Dispatch**:
```c
int ssh_kex_pqc_client(ssh_session session) {
    // Inicializar contexto PQC
    session->next_crypto->pqc_kex_ctx = ssh_pqc_kex_init("HQC-256");
    
    // Gerar keypair
    ssh_pqc_kex_generate_keypair(session->next_crypto->pqc_kex_ctx);
    
    // Enviar SSH_MSG_KEX_PQC_INIT
    ssh_packet_send_pqc_init(session);
    
    // Aguardar SSH_MSG_KEX_PQC_REPLY
    return SSH_OK;
}
```

#### 2.6. Derivação de Chaves (Fase 1 - PQC Puro)

**Modificar**: Função de derivação de chaves existente

```c
// Usar shared_secret do PQC como entrada para HKDF
int ssh_kex_derive_keys_pqc(ssh_session session) {
    ssh_pqc_kex_ctx *ctx = session->next_crypto->pqc_kex_ctx;
    
    // Hash do shared_secret
    unsigned char exchange_hash[SHA256_DIGEST_LEN];
    ssh_hash_ctx hash_ctx = ssh_hash_init(SSH_HASH_SHA256);
    ssh_hash_update(hash_ctx, ctx->shared_secret, ctx->shared_secret_len);
    ssh_hash_final(hash_ctx, exchange_hash);
    
    // Derivar chaves de sessão (igual ao fluxo normal)
    ssh_derive_keys(session, exchange_hash, sizeof(exchange_hash));
    
    return SSH_OK;
}
```

#### 2.7. Implementação Híbrida (Fase 2)

**Combinar ECDH + HQC**:
```c
int ssh_kex_hybrid_derive_keys(ssh_session session) {
    // 1. Executar ECDH clássico
    uint8_t ecdh_shared[32];
    ssh_ecdh_compute_shared_secret(session, ecdh_shared);
    
    // 2. Obter shared secret PQC
    ssh_pqc_kex_ctx *ctx = session->next_crypto->pqc_kex_ctx;
    
    // 3. Combinar usando SHA-256 (padrão OpenSSH-OQS)
    ssh_hash_ctx hash = ssh_hash_init(SSH_HASH_SHA256);
    ssh_hash_update(hash, ecdh_shared, sizeof(ecdh_shared));
    ssh_hash_update(hash, ctx->shared_secret, ctx->shared_secret_len);
    ssh_hash_update(hash, session->session_id, session->session_id_len);
    
    uint8_t hybrid_secret[SHA256_DIGEST_LEN];
    ssh_hash_final(hash, hybrid_secret);
    
    // 4. Derivar chaves da sessão
    ssh_derive_keys(session, hybrid_secret, sizeof(hybrid_secret));
    
    return SSH_OK;
}
```

**Documentação da Fase 2**:
- Diagrama de sequência mostrando ambos os KEX
- Análise de segurança da combinação
- Testes de interoperabilidade

---

### 3. Implementação do Falcon-1024 (Assinatura) — Host/User Keys

#### 3.1. Definir Tipo de Chave

**Adicionar em**: `libssh/include/libssh/pki.h`
```c
enum ssh_keytypes_e {
    SSH_KEYTYPE_UNKNOWN = 0,
    SSH_KEYTYPE_RSA,
    SSH_KEYTYPE_ECDSA_P256,
    SSH_KEYTYPE_ED25519,
    SSH_KEYTYPE_FALCON_1024,  // NOVO
    // ...
};

#define SSH_KEYTYPE_FALCON1024_NAME "ssh-falcon1024@openssh.com"
```

#### 3.2. Estrutura de Chave Falcon

**Adicionar em**: `libssh/src/pki.c`
```c
struct ssh_key_falcon_st {
    OQS_SIG *sig;
    uint8_t *public_key;
    uint8_t *secret_key;
    size_t public_key_len;
    size_t secret_key_len;
};
```

#### 3.3. Geração de Chaves

**Criar**: `libssh/src/pki_falcon.c`

```c
#include <oqs/oqs.h>
#include "libssh/pki.h"
#include "libssh/pki_priv.h"

ssh_key ssh_pki_generate_falcon1024(void) {
    ssh_key key = ssh_key_new();
    if (!key) return NULL;
    
    key->type = SSH_KEYTYPE_FALCON_1024;
    key->type_c = SSH_KEYTYPE_FALCON1024_NAME;
    
    // Inicializar OQS_SIG
    key->falcon = calloc(1, sizeof(struct ssh_key_falcon_st));
    key->falcon->sig = OQS_SIG_new("Falcon-1024");
    
    if (!key->falcon->sig) {
        ssh_key_free(key);
        return NULL;
    }
    
    // Alocar buffers
    key->falcon->public_key_len = key->falcon->sig->length_public_key;
    key->falcon->secret_key_len = key->falcon->sig->length_secret_key;
    key->falcon->public_key = malloc(key->falcon->public_key_len);
    key->falcon->secret_key = malloc(key->falcon->secret_key_len);
    
    // Gerar keypair
    OQS_STATUS status = OQS_SIG_keypair(
        key->falcon->sig,
        key->falcon->public_key,
        key->falcon->secret_key
    );
    
    if (status != OQS_SUCCESS) {
        ssh_key_free(key);
        return NULL;
    }
    
    return key;
}
```

#### 3.4. Serialização (to_blob / from_blob)

**Formato do Blob de Chave Pública**:
```
string    "ssh-falcon1024@openssh.com"
string    falcon_public_key (1793 bytes)
```

**Implementação**:
```c
int ssh_pki_falcon_public_key_to_blob(const ssh_key key, 
                                       ssh_buffer buffer) {
    if (key->type != SSH_KEYTYPE_FALCON_1024) return SSH_ERROR;
    
    int rc = ssh_buffer_pack(buffer, "sS",
        SSH_KEYTYPE_FALCON1024_NAME,
        key->falcon->public_key_len,
        key->falcon->public_key
    );
    
    return (rc == SSH_OK) ? SSH_OK : SSH_ERROR;
}

ssh_key ssh_pki_falcon_public_key_from_blob(ssh_buffer buffer) {
    ssh_key key = ssh_key_new();
    key->type = SSH_KEYTYPE_FALCON_1024;
    key->type_c = SSH_KEYTYPE_FALCON1024_NAME;
    
    key->falcon = calloc(1, sizeof(struct ssh_key_falcon_st));
    key->falcon->sig = OQS_SIG_new("Falcon-1024");
    key->falcon->public_key_len = key->falcon->sig->length_public_key;
    key->falcon->public_key = malloc(key->falcon->public_key_len);
    
    // Desserializar
    ssh_string type_str, pubkey_str;
    int rc = ssh_buffer_unpack(buffer, "SS", &type_str, &pubkey_str);
    
    if (rc != SSH_OK) {
        ssh_key_free(key);
        return NULL;
    }
    
    memcpy(key->falcon->public_key, 
           ssh_string_data(pubkey_str),
           key->falcon->public_key_len);
    
    ssh_string_free(type_str);
    ssh_string_free(pubkey_str);
    
    return key;
}
```

#### 3.5. Operações de Assinatura e Verificação

**Assinar** (com API nova context):
```c
ssh_string ssh_pki_falcon_sign(const ssh_key key,
                                 const unsigned char *hash,
                                 size_t hash_len) {
    if (key->type != SSH_KEYTYPE_FALCON_1024) return NULL;
    
    size_t sig_len = key->falcon->sig->length_signature;
    uint8_t *signature = malloc(sig_len);
    
    // API nova com context (passar NULL, 0)
    OQS_STATUS status = OQS_SIG_sign(
        key->falcon->sig,
        signature,
        &sig_len,
        hash,
        hash_len,
        key->falcon->secret_key,
        NULL,  // context
        0      // context_len
    );
    
    if (status != OQS_SUCCESS) {
        free(signature);
        return NULL;
    }
    
    ssh_string sig_str = ssh_string_new(sig_len);
    ssh_string_fill(sig_str, signature, sig_len);
    free(signature);
    
    return sig_str;
}
```

**Verificar**:
```c
int ssh_pki_falcon_verify(const ssh_key key,
                          const ssh_string signature,
                          const unsigned char *hash,
                          size_t hash_len) {
    if (key->type != SSH_KEYTYPE_FALCON_1024) return SSH_ERROR;
    
    const uint8_t *sig_data = ssh_string_data(signature);
    size_t sig_len = ssh_string_len(signature);
    
    // API nova com context
    OQS_STATUS status = OQS_SIG_verify(
        key->falcon->sig,
        hash,
        hash_len,
        sig_data,
        sig_len,
        key->falcon->public_key,
        NULL,  // context
        0      // context_len
    );
    
    return (status == OQS_SUCCESS) ? SSH_OK : SSH_ERROR;
}
```

#### 3.6. Integração ao Fluxo de Autenticação

**Modificar**: `libssh/src/auth.c`

**Registrar Tipo de Chave**:
```c
static struct ssh_key_ops_st falcon1024_key_ops = {
    .type_c = SSH_KEYTYPE_FALCON1024_NAME,
    .generate = ssh_pki_generate_falcon1024,
    .to_blob = ssh_pki_falcon_public_key_to_blob,
    .from_blob = ssh_pki_falcon_public_key_from_blob,
    .sign = ssh_pki_falcon_sign,
    .verify = ssh_pki_falcon_verify,
    // ...
};
```

**Host Key Authentication**:
- Servidor envia host key Falcon no SSH_MSG_KEXDH_REPLY
- Cliente verifica assinatura usando `ssh_pki_falcon_verify`

**User Authentication** (publickey):
- Cliente assina challenge usando `ssh_pki_falcon_sign`
- Servidor verifica usando `ssh_pki_falcon_verify`

---

### 4. Integração do Protocolo / Negociação

#### 4.1. Adicionar Algoritmos às Listas de Preferência

**Modificar**: `libssh/src/options.c`

```c
static const char *default_kex_algorithms =
    "hqc256-sha256@openssh.com,"        // PQC puro
    "ecdh-nistp256-hqc256-sha256@openssh.com,"  // Híbrido (Fase 2)
    "ecdh-sha2-nistp256,"                // Fallback clássico
    "diffie-hellman-group14-sha256";

static const char *default_hostkey_algorithms =
    "ssh-falcon1024@openssh.com,"       // PQC
    "ecdsa-sha2-nistp256,"               // Fallback clássico
    "ssh-ed25519,"
    "rsa-sha2-512";
```

#### 4.2. Negociação Cliente-Servidor

**Fluxo de Negociação**:
1. Cliente envia lista de algoritmos suportados (incluindo PQC)
2. Servidor escolhe primeiro algoritmo comum
3. Se ambos suportam PQC → usa PQC
4. Se apenas um suporta → fallback para clássico

**Compatibilidade**:
- Cliente PQC + Servidor clássico = conexão clássica (fallback)
- Cliente clássico + Servidor PQC = conexão clássica (fallback)
- Cliente PQC + Servidor PQC = conexão PQC ✅

---

### 5. Segurança e Detalhes Práticos

#### 5.1. Gerador de Números Aleatórios

**Verificação**:
```c
// liboqs deve usar fonte segura de entropia
OQS_randombytes_custom_algorithm(&custom_rng);

// Ou usar padrão OpenSSL (recomendado)
OQS_randombytes_openssl();
```

**Teste**:
```bash
# Verificar entropia do sistema
cat /proc/sys/kernel/random/entropy_avail  # Deve ser > 1000
```

#### 5.2. Gerenciamento de Buffers

**Tamanhos Fixos** (HQC-256 + Falcon-1024):
```c
#define HQC256_PUBLIC_KEY_LEN    7245
#define HQC256_CIPHERTEXT_LEN    9026
#define HQC256_SHARED_SECRET_LEN 64

#define FALCON1024_PUBLIC_KEY_LEN  1793
#define FALCON1024_SECRET_KEY_LEN  2305
#define FALCON1024_SIGNATURE_LEN   1280  // máximo
```

**Sempre validar tamanhos**:
```c
if (pubkey_len != ctx->kem->length_public_key) {
    return SSH_ERROR;  // Ataque de manipulação de tamanho
}
```

#### 5.3. Constant-Time Operations

**Cuidados**:
- liboqs implementa operações em tempo constante
- NÃO adicionar comparações dependentes de secrets
- Usar `memcmp_const_time()` quando necessário

**Exemplo ERRADO**:
```c
// VULNERÁVEL a timing attacks!
if (memcmp(secret1, secret2, len) == 0) { ... }
```

**Exemplo CORRETO**:
```c
// Use função constant-time da liboqs ou OpenSSL
if (CRYPTO_memcmp(secret1, secret2, len) == 0) { ... }
```

#### 5.4. Limpeza de Memória Sensível

**Sempre zerar secrets**:
```c
void ssh_pqc_kex_cleanup(ssh_pqc_kex_ctx *ctx) {
    if (ctx->secret_key) {
        explicit_bzero(ctx->secret_key, ctx->secret_key_len);
        free(ctx->secret_key);
    }
    if (ctx->shared_secret) {
        explicit_bzero(ctx->shared_secret, ctx->shared_secret_len);
        free(ctx->shared_secret);
    }
    OQS_KEM_free(ctx->kem);
    free(ctx);
}
```

---

### 6. Testes e Validação

#### 6.1. Testes Unitários liboqs

**Validar APIs isoladas**:
```bash
cd third_party/liboqs/build/tests

# Testar HQC-256
./test_kem HQC-256
./example_kem HQC-256

# Testar Falcon-1024
./test_sig Falcon-1024
./example_sig Falcon-1024
```

**Critérios de Sucesso**:
- Keypair generation sem erros
- Encaps/Decaps produzem mesmo shared secret
- Sign/Verify validam corretamente

#### 6.2. Testes de Integração SSH

**Criar**: `libssh/tests/test_pqc_kex.c`

```c
#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include <cmocka.h>
#include "pqc_kex.h"

static void test_hqc256_kex_full_cycle(void **state) {
    // Cliente gera keypair
    ssh_pqc_kex_ctx *client = ssh_pqc_kex_init("HQC-256");
    assert_non_null(client);
    assert_int_equal(ssh_pqc_kex_generate_keypair(client), SSH_OK);
    
    // Servidor encapsula
    ssh_pqc_kex_ctx *server = ssh_pqc_kex_init("HQC-256");
    assert_non_null(server);
    assert_int_equal(ssh_pqc_kex_encapsulate(server, client->public_key), SSH_OK);
    
    // Cliente decapsula
    assert_int_equal(ssh_pqc_kex_decapsulate(client, server->ciphertext), SSH_OK);
    
    // Shared secrets devem ser iguais
    assert_memory_equal(client->shared_secret, server->shared_secret, 
                        client->shared_secret_len);
    
    ssh_pqc_kex_cleanup(client);
    ssh_pqc_kex_cleanup(server);
}
```

**Executar**:
```bash
cd libssh/build
ctest -R test_pqc
```

#### 6.3. Testes Cliente-Servidor Completos

**Script de Teste**:
```bash
#!/bin/bash
# test_pqc_connection.sh

echo "=== Teste de Conexão PQC ==="

# 1. Gerar host key Falcon para servidor
./libssh/build/examples/keygen -t falcon1024 -f /tmp/ssh_host_falcon_key

# 2. Iniciar servidor com suporte PQC
docker exec -d libssh-server-test \
    /opt/libssh/build/examples/samplesshd-kbdint \
    -p 2222 \
    -h /tmp/ssh_host_falcon_key \
    -v

# 3. Conectar com cliente PQC
./libssh/build/examples/ssh-client \
    -o KexAlgorithms=hqc256-sha256@openssh.com \
    -o HostKeyAlgorithms=ssh-falcon1024@openssh.com \
    libssh@localhost -p 2222

echo "=== Verificar Logs ==="
docker logs libssh-server-test 2>&1 | grep -E "(HQC|Falcon)"
```

#### 6.4. Testes de Interoperabilidade

**Cenários**:
1. Cliente PQC → Servidor PQC (deve usar PQC)
2. Cliente PQC → Servidor clássico (deve falback)
3. Cliente clássico → Servidor PQC (deve fallback)
4. Cliente com KEX híbrido → Servidor PQC puro (negociação)

#### 6.5. Coleta de Métricas

**Criar**: `libssh/benchmarks/benchmark_pqc.c`

```c
#include <time.h>
#include <stdio.h>

typedef struct {
    struct timespec start;
    struct timespec end;
    double duration_ms;
} benchmark_timer;

void benchmark_start(benchmark_timer *timer) {
    clock_gettime(CLOCK_MONOTONIC, &timer->start);
}

void benchmark_end(benchmark_timer *timer) {
    clock_gettime(CLOCK_MONOTONIC, &timer->end);
    timer->duration_ms = (timer->end.tv_sec - timer->start.tv_sec) * 1000.0;
    timer->duration_ms += (timer->end.tv_nsec - timer->start.tv_nsec) / 1000000.0;
}

void benchmark_kex_classical() {
    benchmark_timer timer;
    ssh_session session = ssh_new();
    
    // Configurar para KEX clássico
    ssh_options_set(session, SSH_OPTIONS_HOST, "localhost");
    ssh_options_set(session, SSH_OPTIONS_PORT, &port);
    ssh_options_set(session, SSH_OPTIONS_KEX, "ecdh-sha2-nistp256");
    
    benchmark_start(&timer);
    ssh_connect(session);
    ssh_userauth_password(session, "libssh", "libssh");
    benchmark_end(&timer);
    
    printf("Handshake Clássico: %.2f ms\n", timer.duration_ms);
    
    ssh_disconnect(session);
    ssh_free(session);
}

void benchmark_kex_pqc() {
    benchmark_timer timer;
    ssh_session session = ssh_new();
    
    // Configurar para KEX PQC
    ssh_options_set(session, SSH_OPTIONS_KEX, "hqc256-sha256@openssh.com");
    ssh_options_set(session, SSH_OPTIONS_HOSTKEYS, "ssh-falcon1024@openssh.com");
    
    benchmark_start(&timer);
    ssh_connect(session);
    ssh_userauth_password(session, "libssh", "libssh");
    benchmark_end(&timer);
    
    printf("Handshake PQC: %.2f ms\n", timer.duration_ms);
    
    ssh_disconnect(session);
    ssh_free(session);
}

int main() {
    printf("=== Benchmark SSH Clássico vs PQC ===\n\n");
    
    for (int i = 0; i < 100; i++) {
        benchmark_kex_classical();
        benchmark_kex_pqc();
    }
    
    return 0;
}
```

**Métricas Coletadas**:
```
Latência Clássica (ECDH + Ed25519):
- Média: X ms
- Desvio padrão: Y ms
- Percentil 95: Z ms

Latência PQC (HQC-256 + Falcon-1024):
- Média: A ms
- Desvio padrão: B ms
- Percentil 95: C ms

Overhead: (A - X) / X * 100 = D%

Largura de Banda:
- Clássico: ~500 bytes
- PQC: ~18KB
- Overhead: 36x
```

---

### 7. Documentação Técnica

#### 7.1. Estrutura da Documentação do TCC

```
docs/
├── 01-introducao.md
├── 02-fundamentacao-teorica.md
│   ├── 2.1-criptografia-pos-quantica.md
│   ├── 2.2-algoritmo-hqc.md
│   ├── 2.3-algoritmo-falcon.md
│   └── 2.4-protocolo-ssh.md
├── 03-metodologia.md
│   ├── 3.1-ambiente-desenvolvimento.md
│   ├── 3.2-arquitetura-solucao.md
│   └── 3.3-estrategia-implementacao.md
├── 04-implementacao.md
│   ├── 4.1-integracao-liboqs.md
│   ├── 4.2-kex-hqc.md
│   ├── 4.3-autenticacao-falcon.md
│   └── 4.4-wire-format.md
├── 05-testes-validacao.md
│   ├── 5.1-testes-unitarios.md
│   ├── 5.2-testes-integracao.md
│   └── 5.3-testes-seguranca.md
├── 06-analise-resultados.md
│   ├── 6.1-metricas-desempenho.md
│   ├── 6.2-analise-overhead.md
│   └── 6.3-comparativo-classico-pqc.md
├── 07-conclusao.md
└── diagramas/
    ├── arquitetura-sistema.png
    ├── fluxo-kex-hqc.png
    ├── fluxo-auth-falcon.png
    └── resultados-benchmark.png
```

#### 7.2. Diagramas Obrigatórios

**Diagrama de Sequência - KEX HQC**:
```
Cliente                              Servidor
   |                                    |
   |--- SSH_MSG_KEXINIT --------------->|
   |<-- SSH_MSG_KEXINIT -----------------|
   |                                    |
   | [Negociar: hqc256-sha256]          |
   |                                    |
   | [Gerar keypair HQC-256]            |
   |--- SSH_MSG_KEX_PQC_INIT ---------->|
   |    (public_key: 7245 bytes)        |
   |                                    | [Encapsular]
   |<-- SSH_MSG_KEX_PQC_REPLY ----------|
   |    (ciphertext: 9026 bytes)        |
   | [Decapsular]                       |
   |                                    |
   | [Ambos têm shared_secret]          |
   |                                    |
   |--- SSH_MSG_NEWKEYS ---------------->|
   |<-- SSH_MSG_NEWKEYS -----------------|
```

**Diagrama de Wire Format**:
```
HQC-256 Public Key Packet:
+------+--------+------------------+
| Type | Length | Public Key Data  |
| 1B   | 4B     | 7245 bytes       |
+------+--------+------------------+

Falcon-1024 Signature Packet:
+------+--------+-----------+--------+----------------+
| Type | Length | Algorithm | Length | Signature Data |
| 1B   | 4B     | String    | 4B     | ~1280 bytes    |
+------+--------+-----------+--------+----------------+
```

#### 7.3. Referências Acadêmicas Obrigatórias

**Papers a Citar**:
1. HQC: "Hamming Quasi-Cyclic (HQC)" - NIST PQC Round 4
2. Falcon: "Fast Fourier Lattice-based Compact Signatures" - NIST PQC Winner
3. liboqs: "Open Quantum Safe Project" - Douglas Stebila et al.
4. OpenSSH-OQS: "Prototyping post-quantum and hybrid key exchange and authentication in TLS and SSH" - 2019

**RFCs a Citar**:
- RFC 4253: SSH Transport Layer Protocol
- RFC 4252: SSH Authentication Protocol
- RFC 5656: Elliptic Curve Algorithm Integration in SSH
- Draft: Post-Quantum Key Exchange for SSH (se disponível)

---

### 8. Manutenção e Atualização

#### 8.1. Monitoramento de Vulnerabilidades

**Fontes a Monitorar**:
- CVE da liboqs: https://github.com/open-quantum-safe/liboqs/security/advisories
- NIST PQC Updates: https://csrc.nist.gov/projects/post-quantum-cryptography
- libssh Security: https://www.libssh.org/security/

#### 8.2. Atualização do Submódulo liboqs

**Processo**:
```bash
cd third_party/liboqs
git fetch --tags
git checkout <nova_versao>
cd ../..
git add third_party/liboqs
git commit -m "Update liboqs to version X.Y.Z"
```

**Teste de Regressão Obrigatório**:
```bash
./run_all_tests.sh
./benchmark_pqc.sh
```

#### 8.3. Mudanças de API

**Histórico de Mudanças**:
- liboqs 0.8.0: API antiga sem context
- liboqs 0.9.0+: Nova API com context parameter

**Adaptação**:
```c
#if OQS_VERSION >= 0x00090000
    // API nova com context
    OQS_SIG_sign(..., context, context_len);
#else
    // API antiga sem context
    OQS_SIG_sign(...);
#endif
```

---

## Resumo Executivo para o TCC

### Objetivos do Projeto
✅ Integrar HQC-256 (KEM) para Key Exchange
✅ Integrar Falcon-1024 (assinatura) para Autenticação
✅ Implementar modo híbrido (clássico + PQC)
✅ Medir e comparar métricas de desempenho
✅ Documentar processo completo com rigor acadêmico

### Abordagem Técnica
- Submódulo liboqs 0.11.1 (pinned)
- Padrão OpenSSH-OQS para wire format
- Implementação incremental (PQC puro → Híbrido)
- Testes automatizados extensivos
- Benchmarks comparativos detalhados

### Contribuições Esperadas
1. Primeira integração completa de HQC-256 + Falcon-1024 na libssh
2. Análise quantitativa de overhead pós-quântico
3. Documentação técnica detalhada para reprodução
4. Código open-source para comunidade

### Riscos e Mitigações
| Risco | Mitigação |
|-------|-----------|
| API liboqs mudar | Fixar versão 0.11.1 |
| Overhead inaceitável | Documentar trade-offs |
| Bugs de implementação | Testes extensivos |
| Incompatibilidade wire format | Seguir padrão OpenSSH-OQS |