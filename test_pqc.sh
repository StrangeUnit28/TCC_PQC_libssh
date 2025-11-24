#!/bin/bash

################################################################################
# TESTE DE TROCA DE MENSAGEM PQC
# 
# Objetivo: Testar troca REAL de mensagem cifrada usando PQC
#           (Falcon-1024 + HQC-256)
#
# Uso: ./test_pqc.sh ["mensagem customizada"]
################################################################################

set -e

# Cores
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

MESSAGE="${1:-Ola, mensagem de teste usando PQC! (Falcon-1024 + HQC-256)}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  TESTE DE MENSAGEM CIFRADA PQC                               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Mensagem a enviar:${NC}"
echo "   \"$MESSAGE\""
echo ""

echo -e "${CYAN}Enviando via SSH com PQC (Falcon-1024 + HQC-256)...${NC}"
echo ""

# Limpar logs
docker compose logs --tail=0 > /dev/null 2>&1

# Usar cliente LOCAL conectando no servidor no CONTAINER (porta 2222)
echo -e "${CYAN}Executando cliente LOCAL conectando no servidor do container...${NC}"

# Compilar cliente local se não existir
if [ ! -f "./libssh/build/examples/pqc-message-test" ]; then
    echo -e "${YELLOW}Compilando cliente...${NC}"
    cd libssh/build && make pqc-message-test && cd ../..
fi

# Executar cliente LOCAL
LD_LIBRARY_PATH=./libssh/build/src:./third_party/liboqs/build/lib \
    ./libssh/build/examples/pqc-message-test "echo 'RECEBIDO NO SERVIDOR PQC: $MESSAGE'" 2>&1 | tee /tmp/pqc_output.txt

echo ""
echo -e "${GREEN}Teste concluido!${NC}"
echo ""

# Verificar nos logs do servidor
LOGS=$(docker compose logs --tail=50 2>&1)

if echo "$LOGS" | grep -q "PQC_EXEC"; then
    echo -e "${GREEN}Servidor executou o comando:${NC}"
    echo "$LOGS" | grep "PQC_EXEC" | tail -5
fi

echo ""
