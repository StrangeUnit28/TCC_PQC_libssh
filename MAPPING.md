# Mapeamento de Pontos de Extensão - libssh PQC

**Data**: 17/11/2025  
**Objetivo**: Documentar os pontos onde integraremos HQC-256 e Falcon-1024

---

## 1. Estrutura de Algoritmos KEX

### 1.1 Definições Base

**Arquivo**: `libssh/include/libssh/kex.h`
- `SSH_KEX_METHODS = 10` - Número total de tipos de métodos criptográficos

**Arquivo**: `libssh/include/libssh/libssh.h` (linha ~126)
```c
enum ssh_kex_types_e {
    SSH_KEX=0,          // Algoritmos de key exchange
    SSH_HOSTKEYS,       // Algoritmos de chave de host
    SSH_CRYPT_C_S,      // Cifras cliente->servidor
    SSH_CRYPT_S_C,      // Cifras servidor->cliente
    SSH_MAC_C_S,        // MACs cliente->servidor
    SSH_MAC_S_C,        // MACs servidor->cliente
    SSH_COMP_C_S,       // Compressão cliente->servidor
    SSH_COMP_S_C,       // Compressão servidor->cliente
    SSH_LANG_C_S,       // Língua cliente->servidor
    SSH_LANG_S_C        // Língua servidor->cliente
};
```

### 1.2 Lista de Algoritmos KEX

**Arquivo**: `libssh/src/kex.c` (linhas 90-220)

Algoritmos atuais suportados:
- **Pós-Quânticos Modernos** (já presentes!):
  - `mlkem768x25519-sha256` (ML-KEM-768 híbrido)
  - `sntrup761x25519-sha512` (NTRU Prime híbrido)
  - `curve25519-sha256`
  
- **ECDH Clássicos**:
  - `ecdh-sha2-nistp256`
  - `ecdh-sha2-nistp384`
  - `ecdh-sha2-nistp521`
  
- **Diffie-Hellman Clássicos**:
  - `diffie-hellman-group18-sha512`
  - `diffie-hellman-group16-sha512`
  - `diffie-hellman-group14-sha256`
  - `diffie-hellman-group14-sha1` (legado)
  - `diffie-hellman-group1-sha1` (legado)

**Macros importantes**:
```c
#define DEFAULT_KEY_EXCHANGE \
    MLKEM768X25519 \
    SNTRUP761X25519 \
    CURVE25519 \
    ECDH \
    "diffie-hellman-group18-sha512,diffie-hellman-group16-sha512," \
    GEX_SHA256 \
    "diffie-hellman-group14-sha256"
```

---

## 2. Pontos de Extensão para HQC-256

### 2.1 Adicionar Macros de Definição

**Arquivo**: `libssh/src/kex.c` (após linha ~105)

```c
#ifdef HAVE_LIBOQS_HQC
#define HQC256 "hqc256-sha256@libssh.org,"
#define HQC256_HYBRID "ecdh-nistp256-hqc256-sha256@libssh.org,"
#else
#define HQC256 ""
#define HQC256_HYBRID ""
#endif /* HAVE_LIBOQS_HQC */
```

### 2.2 Adicionar à Lista de KEX Suportados

**Modificar**: `DEFAULT_KEY_EXCHANGE` para incluir HQC256
```c
#define DEFAULT_KEY_EXCHANGE \
    MLKEM768X25519 \
    SNTRUP761X25519 \
    HQC256 \              // ADICIONAR: KEX PQC puro
    HQC256_HYBRID \       // ADICIONAR: KEX híbrido
    CURVE25519 \
    ECDH \
    ...
```

### 2.3 Implementação da Função KEX

**Arquivo novo**: `libssh/src/kex_hqc256.c`

Funções necessárias:
```c
// Fase de cliente - gera keypair e envia chave pública
int ssh_client_kex_hqc256_init(ssh_session session);

// Fase de servidor - recebe chave pública, gera shared secret
int ssh_server_kex_hqc256_init(ssh_session session);

// Cliente recebe ciphertext e decapsula para obter shared secret
int ssh_client_kex_hqc256_reply(ssh_session session, ssh_string pubkey_blob);

// Derivação do segredo compartilhado (já existe ssh_make_sessionid)
int ssh_kex_hqc256_compute_shared_secret(ssh_session session);
```

---

## 3. Pontos de Extensão para Falcon-1024

### 3.1 Adicionar Tipo de Chave

**Arquivo**: `libssh/include/libssh/pki.h` ou equivalente

```c
enum ssh_keytypes_e {
    SSH_KEYTYPE_UNKNOWN=0,
    SSH_KEYTYPE_DSS,
    SSH_KEYTYPE_RSA,
    SSH_KEYTYPE_ECDSA_P256,
    SSH_KEYTYPE_ECDSA_P384,
    SSH_KEYTYPE_ECDSA_P521,
    SSH_KEYTYPE_ED25519,
    SSH_KEYTYPE_FALCON1024,        // ADICIONAR
    SSH_KEYTYPE_ED25519_FALCON1024 // ADICIONAR: Híbrido
};
```

### 3.2 Adicionar String de Identificação

**Arquivo**: `libssh/src/kex.c`

```c
#define FALCON_HOSTKEYS "falcon1024@libssh.org," \
                        "ed25519-falcon1024@libssh.org,"
```

**Modificar**: `HOSTKEYS` para incluir Falcon
```c
#define HOSTKEYS "ssh-ed25519," \
                 FALCON_HOSTKEYS \  // ADICIONAR
                 EC_HOSTKEYS \
                 ...
```

### 3.3 Implementação PKI

**Arquivo**: `libssh/src/pki_falcon.c`

Funções necessárias:
```c
// Geração de par de chaves
ssh_key ssh_pki_generate_falcon1024(void);

// Carregamento de chave privada
ssh_key ssh_pki_private_key_from_falcon1024(const unsigned char *privkey);

// Exportação de chave pública
int ssh_pki_export_falcon1024_pubkey(const ssh_key key, ssh_string *out);

// Assinatura
int ssh_pki_signature_sign_falcon1024(const ssh_key key, 
                                       const unsigned char *hash,
                                       size_t hash_len,
                                       ssh_signature *sig);

// Verificação
int ssh_pki_signature_verify_falcon1024(ssh_signature sig,
                                         const ssh_key key,
                                         const unsigned char *hash,
                                         size_t hash_len);
```

---

## 4. Fluxo de Integração

### Fase 1: KEX PQC Puro (HQC-256 apenas)
1. ✅ Adicionar macros de definição
2. ✅ Implementar funções básicas de KEX
3. ✅ Testar comunicação cliente-servidor
4. ✅ Validar geração de shared secret

### Fase 2: KEX Híbrido (ECDH + HQC-256)
1. ✅ Implementar combinação ECDH + HQC
2. ✅ Derivação híbrida de chaves (SHA256(ecdh_secret || hqc_secret))
3. ✅ Testar compatibilidade com clientes não-PQC

### Fase 3: Autenticação Falcon-1024
1. ✅ Adicionar tipo de chave Falcon
2. ✅ Implementar geração/carregamento de chaves
3. ✅ Implementar assinatura/verificação
4. ✅ Integrar no fluxo de autenticação do servidor

### Fase 4: Testes e Métricas
1. ✅ Testes de interoperabilidade
2. ✅ Medições de performance (tempo, banda, memória)
3. ✅ Comparação com algoritmos clássicos
4. ✅ Documentação final

---

## 5. Arquivos Principais a Modificar

### Para KEX (HQC-256):
- ✅ `libssh/src/kex.c` - Adicionar definições e registro
- ✅ `libssh/src/kex_hqc256.c` - **NOVO**: Implementação
- ✅ `libssh/include/libssh/kex.h` - Declarações de funções
- ✅ `libssh/src/CMakeLists.txt` - Adicionar novo arquivo

### Para PKI (Falcon-1024):
- ✅ `libssh/src/pki.c` - Adicionar suporte ao novo tipo
- ✅ `libssh/src/pki_falcon.c` - **NOVO**: Implementação
- ✅ `libssh/include/libssh/pki.h` - Enum e estruturas
- ✅ `libssh/src/auth.c` - Integrar verificação Falcon
- ✅ `libssh/src/CMakeLists.txt` - Adicionar novo arquivo

### Arquivos de Teste:
- ✅ `tests/client/` - Testes de cliente PQC
- ✅ `tests/server/` - Testes de servidor PQC
- ✅ `benchmarks/` - **NOVO**: Medições de performance

---

## 6. Próximos Passos

### Imediatos:
1. ✅ Criar `libssh/src/kex_hqc256.c` com estrutura básica
2. ✅ Adicionar macros HQC256 em `kex.c`
3. ✅ Implementar `ssh_client_kex_hqc256_init()` usando liboqs

### Curto Prazo:
4. ✅ Completar implementação de KEX puro
5. ✅ Testar comunicação básica
6. ✅ Implementar KEX híbrido

### Médio Prazo:
7. ✅ Começar implementação Falcon-1024
8. ✅ Integrar autenticação PQC
9. ✅ Testes de integração completa

---

**Status**: Fase de Mapeamento Completa ✅  
**Próximo**: Implementação KEX HQC-256 Puro
