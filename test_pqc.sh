#!/bin/bash
set -e

MESSAGE="${1:-Teste PQC: Falcon-1024 + HQC-256}"

echo "Mensagem: \"$MESSAGE\""
echo "Enviando via SSH PQC..."

docker compose logs --tail=0 > /dev/null 2>&1

if [ ! -f "./libssh/build/examples/pqc-message-test" ]; then
    echo "Compilando cliente..."
    cd libssh/build && make pqc-message-test && cd ../..
fi

LD_LIBRARY_PATH=./libssh/build/src:./third_party/liboqs/build/lib \
    ./libssh/build/examples/pqc-message-test "echo 'RECEBIDO: $MESSAGE'" 2>&1 | tee /tmp/pqc_output.txt

echo "Teste concluído"

LOGS=$(docker compose logs --tail=50 2>&1)
if echo "$LOGS" | grep -q "PQC_EXEC"; then
    echo "Logs do servidor:"
    echo "$LOGS" | grep "PQC_EXEC" | tail -5
fi
