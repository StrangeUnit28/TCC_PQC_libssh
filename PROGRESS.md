# Progresso da Implementação PQC na libssh

## ✅ Fase 0: Preparação — Repositório e Build

### Passo 0.1: Adicionar liboqs como Submódulo ✅

- **Status**: Concluído
- **Data**: 17/11/2025
- **Versão**: liboqs 0.15.0 (lançada em 14/11/2025)
- **Commit hash**: `97f6b86b1b6d109cfd43cf276ae39c2e776aed80`

**Descobertas Importantes**:
- HQC não está habilitado por padrão na liboqs
- É necessário compilar com `-DOQS_ENABLE_KEM_HQC=ON`
- Falcon-1024 está habilitado por padrão

**Comandos Executados**:
```bash
# Adicionar submódulo
git submodule add https://github.com/open-quantum-safe/liboqs.git third_party/liboqs
cd third_party/liboqs
git checkout 0.15.0

# Compilar com HQC habilitado
mkdir -p build && cd build
cmake .. -GNinja -DBUILD_SHARED_LIBS=ON -DOQS_ENABLE_KEM_HQC=ON
ninja -j4
```

**Validação**:
- ✅ HQC-256 disponível e funcional
  - Chave pública: 7245 bytes
  - Ciphertext: 14421 bytes  
  - Shared secret: 64 bytes
  
- ✅ Falcon-1024 disponível e funcional
  - Chave pública: 1793 bytes
  - Chave privada: 2305 bytes
  - Assinatura: 1462 bytes (máximo, pode variar)

**Arquivos Criados**:
- `third_party/liboqs/` - Submódulo Git
- `test_liboqs.c` - Teste de validação dos algoritmos
- `test_liboqs` - Binário de teste compilado

---

### Passo 0.2: Configurar Build da liboqs com libssh ✅

- **Status**: Concluído
- **Data**: 17/11/2025

**Desafio Encontrado**:
O linker moderno usa `--as-needed` por padrão, que remove dependências de bibliotecas cujos símbolos não são usados. Como ainda não estamos chamando funções da liboqs, ela era removida do binário final.

**Solução Implementada**:
Forçar linkagem com `--no-as-needed` temporariamente até que o código use funções da liboqs:

```cmake
# Em libssh/CMakeLists.txt
message(STATUS "Adding liboqs for PQC support...")
set(OQS_ENABLE_KEM_HQC ON CACHE BOOL "Enable HQC KEM" FORCE)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../third_party/liboqs 
                 ${CMAKE_CURRENT_BINARY_DIR}/liboqs EXCLUDE_FROM_ALL)

# Em libssh/src/CMakeLists.txt  
if (TARGET oqs)
  list(APPEND LIBSSH_LINK_LIBRARIES oqs)
  message(STATUS "liboqs target found and will be linked")
endif()

# Forçar linkagem (temporário até usar símbolos)
if (TARGET oqs)
  if (UNIX AND NOT APPLE)
    target_link_libraries(ssh PUBLIC "-Wl,--no-as-needed" oqs "-Wl,--as-needed")
  endif()
endif()
```

**Validação**:
```bash
cd libssh/build
ldd lib/libssh.so
# Saída:
#   liboqs.so.9 => .../libssh/build/liboqs/lib/liboqs.so.9

readelf -d lib/libssh.so | grep NEEDED | grep oqs
# Saída:
#   0x0000000000000001 (NEEDED)  Biblioteca Compartilhada [liboqs.so.9]
```

**Arquivos Modificados**:
- `libssh/CMakeLists.txt` - Adicionou liboqs como subdirectory
- `libssh/src/CMakeLists.txt` - Configurou linkagem com --no-as-needed
- `POSSIBLE_GUIDE.md` - Atualizado com versão correta (0.15.0)

---

## 🎯 Próximo Passo: Passo 1 - Mapeamento de Pontos de Extensão

### Próximas Ações:

1. **Modificar CMakeLists.txt da libssh** para incluir liboqs
2. **Linkar liboqs** com os exemplos da libssh
3. **Testar compilação** da libssh com liboqs integrada

---

## 📋 Próximas Fases

### Fase 1: Mapeamento de Pontos de Extensão na libssh
- [ ] Identificar módulos relevantes (kex.c, pki.c, etc.)
- [ ] Localizar tabela de algoritmos
- [ ] Documentar estrutura do código

### Fase 2: Implementação do HQC-256 (KEM)
- [ ] Definir nomes de algoritmo (wire format)
- [ ] Criar estrutura de dados (`pqc_kex.h`)
- [ ] Implementar KEX PQC puro
- [ ] Implementar serialização de pacotes
- [ ] Integrar ao fluxo KEX

### Fase 3: Implementação Híbrida (ECDH + HQC-256)
- [ ] Combinar ECDH com HQC
- [ ] Implementar derivação híbrida com SHA-256
- [ ] Testes de interoperabilidade

### Fase 4: Implementação do Falcon-1024 (Assinatura)
- [ ] Definir tipo de chave
- [ ] Criar estrutura de chave Falcon
- [ ] Implementar geração de chaves
- [ ] Implementar serialização (to_blob/from_blob)
- [ ] Implementar sign/verify com API nova (context)
- [ ] Integrar ao fluxo de autenticação

### Fase 5: Integração do Protocolo
- [ ] Adicionar algoritmos às listas de preferência
- [ ] Implementar negociação cliente-servidor
- [ ] Garantir fallback para algoritmos clássicos

### Fase 6: Testes e Validação
- [ ] Testes unitários liboqs
- [ ] Testes de integração SSH
- [ ] Testes cliente-servidor completos
- [ ] Testes de interoperabilidade
- [ ] Coleta de métricas (benchmarks)

### Fase 7: Documentação Técnica
- [ ] Criar estrutura de documentação do TCC
- [ ] Gerar diagramas de sequência
- [ ] Documentar wire format
- [ ] Escrever referências acadêmicas

---

## 📊 Status Geral

- **Fase Atual**: Passo 1 → Passo 2 (Implementação KEX)
- **Progresso Total**: ~10% (2 de 8 fases principais concluídas)
- **Última Atualização**: 17/11/2025
- **Próximo Milestone**: Implementar KEX HQC-256 puro

---

## 🔍 Observações Técnicas

### liboqs 0.15.0
- Versão muito recente (3 dias de lançamento)
- API estável com context parameter
- HQC requer habilitação explícita
- Compilação bem-sucedida em Ubuntu 22.04
- OpenSSL 3.0.13 detectado e integrado

### Ambiente de Desenvolvimento
- SO: Ubuntu 22.04 (Linux 6.8.0-85-generic)
- Compilador: GCC 13.3.0
- Build System: CMake + Ninja
- OpenSSL: 3.0.13

### Decisões Técnicas Confirmadas
- ✅ HQC-256 (parâmetro máximo de segurança)
- ✅ Falcon-1024 (parâmetro máximo de segurança)
- ✅ liboqs 0.15.0 (versão mais recente)
- ✅ Padrão OpenSSH-OQS para wire format
- ✅ SHA-256 para derivação de chaves híbridas

---

## ✅ Passo 1: Mapeamento de Pontos de Extensão

- **Status**: Concluído
- **Data**: 17/11/2025

### Análise Realizada

**Constantes e Estruturas Identificadas**:
- `SSH_KEX_METHODS = 10` tipos de métodos (`libssh/include/libssh/kex.h`)
- `enum ssh_kex_types_e`: SSH_KEX, SSH_HOSTKEYS, SSH_CRYPT_C_S, etc.

**Algoritmos KEX Existentes** (`libssh/src/kex.c`):
- **Pós-Quânticos**: `mlkem768x25519-sha256`, `sntrup761x25519-sha512`
- **ECDH**: `ecdh-sha2-nistp256/384/521`
- **DH Clássico**: `diffie-hellman-group14/16/18`

### Pontos de Extensão Definidos

**Para HQC-256 (KEX)**:
1. Adicionar macros em `libssh/src/kex.c`
2. Criar `libssh/src/kex_hqc256.c` com funções:
   - `ssh_client_kex_hqc256_init()`
   - `ssh_server_kex_hqc256_init()`
   - `ssh_client_kex_hqc256_reply()`

**Para Falcon-1024 (Autenticação)**:
1. Adicionar `SSH_KEYTYPE_FALCON1024` em `libssh/include/libssh/pki.h`
2. Criar `libssh/src/pki_falcon.c` com funções PKI completas

**Estratégia**:
- Fase 1: KEX PQC Puro (HQC-256)
- Fase 2: KEX Híbrido (ECDH + HQC-256)
- Fase 3: Autenticação (Falcon-1024)
- Fase 4: Integração e Testes

**Documentação Criada**:
- ✅ `MAPPING.md` - Mapeamento completo dos pontos de extensão

---

## ⏳ Próximo: Passo 2 - Implementação KEX HQC-256 Puro

### Ações Planejadas:
1. Criar `libssh/src/kex_hqc256.c`
2. Adicionar macros HQC256 em `kex.c`
3. Implementar funções básicas de KEX usando liboqs
4. Testar comunicação cliente-servidor

