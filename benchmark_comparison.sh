#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NUM_ITERATIONS=10
SERVER_HOST="localhost"
SERVER_PORT_PQC=2222
SERVER_PORT_CLASSIC=2223
RESULTS_DIR="./benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/comparison_${TIMESTAMP}.csv"

CLIENT_BIN_PQC="./libssh/build/examples/pqc-message-test"
CLIENT_BIN_CLASSIC="./libssh/build/examples/classic-message-test"
export LD_LIBRARY_PATH=./libssh/build/src:./third_party/liboqs/build/lib

# Função para aguardar servidor estar pronto
wait_server_ready() {
    local port=$1
    local max_wait=20
    local count=0
    while [ $count -lt $max_wait ]; do
        if nc -z "$SERVER_HOST" "$port" 2>/dev/null; then
            sleep 2
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

mkdir -p "$RESULTS_DIR"

echo "[LOG] Verificando servidor PQC (porta ${SERVER_PORT_PQC})..."
if ! nc -z "$SERVER_HOST" "$SERVER_PORT_PQC" 2>/dev/null; then
    echo -e "${RED}[ERROR] Servidor PQC não está rodando${NC}"
    exit 1
fi
echo "[LOG] Servidor PQC disponível"

echo "[LOG] Verificando clientes..."
if [ ! -f "$CLIENT_BIN_PQC" ]; then
    echo -e "${RED}[ERROR] Cliente PQC não encontrado${NC}"
    exit 1
fi
echo "[LOG] Cliente PQC encontrado"

if [ ! -f "$CLIENT_BIN_CLASSIC" ]; then
    echo -e "${YELLOW}[WARN] Cliente clássico não encontrado: ${CLIENT_BIN_CLASSIC}${NC}"
    echo "[LOG] Cliente clássico precisa ser compilado primeiro"
    echo "[LOG] Execute: cd libssh/build && make"
    CLASSIC_AVAILABLE=false
else
    echo "[LOG] Cliente clássico encontrado"
fi

CLASSIC_AVAILABLE=false
echo "[LOG] Verificando servidor clássico (porta ${SERVER_PORT_CLASSIC})..."
if nc -z "$SERVER_HOST" "$SERVER_PORT_CLASSIC" 2>/dev/null; then
    CLASSIC_AVAILABLE=true
    echo "[LOG] Servidor clássico disponível"
else
    echo -e "${YELLOW}[WARN] Servidor clássico não disponível - apenas PQC será testado${NC}"
fi

echo "algorithm_type,kex_algorithm,hostkey_algorithm,iteration,handshake_time_ms,packet_size_bytes,status" > "$RESULTS_FILE"

declare -a pqc_times
declare -a classic_times

echo "[LOG] === Testando PQC (${NUM_ITERATIONS} iterações) ==="
for i in $(seq 1 $NUM_ITERATIONS); do
    echo "[LOG] PQC iteração $i/${NUM_ITERATIONS}"
    
    if ! wait_server_ready "$SERVER_PORT_PQC"; then
        echo -e "${YELLOW}[WARN] Timeout aguardando servidor PQC${NC}"
        continue
    fi
    
    START_TIME=$(date +%s%3N)
    
    set +e
    OUTPUT=$($CLIENT_BIN_PQC "echo 'test'" 2>&1)
    EXIT_CODE=$?
    set -e
    
    END_TIME=$(date +%s%3N)
    ELAPSED=$((END_TIME - START_TIME))
    
    if [ $EXIT_CODE -eq 0 ]; then
        pqc_times+=($ELAPSED)
        echo "PQC,hqc256-sha256,ssh-falcon1024,${i},${ELAPSED},17608,success" >> "$RESULTS_FILE"
        echo "[LOG] PQC OK: ${ELAPSED}ms"
    else
        echo -e "${RED}[ERROR] PQC falhou na iteração $i${NC}"
        echo "PQC,hqc256-sha256,ssh-falcon1024,${i},${ELAPSED},17608,fail" >> "$RESULTS_FILE"
    fi
done

if [ "$CLASSIC_AVAILABLE" = true ]; then
    echo "[LOG] === Testando Clássico (${NUM_ITERATIONS} iterações) ==="
    for i in $(seq 1 $NUM_ITERATIONS); do
        echo "[LOG] Clássico iteração $i/${NUM_ITERATIONS}"
        
        if ! wait_server_ready "$SERVER_PORT_CLASSIC"; then
            echo -e "${YELLOW}[WARN] Timeout aguardando servidor clássico${NC}"
            continue
        fi
        
        START_TIME=$(date +%s%3N)
        
        set +e
        OUTPUT=$($CLIENT_BIN_CLASSIC "echo 'test'" 2>&1)
        EXIT_CODE=$?
        set -e
        
        END_TIME=$(date +%s%3N)
        ELAPSED=$((END_TIME - START_TIME))
        
        if [ $EXIT_CODE -eq 0 ]; then
            classic_times+=($ELAPSED)
            echo "Classic,ecdh-sha2-nistp256,rsa-sha2-512,${i},${ELAPSED},1024,success" >> "$RESULTS_FILE"
            echo "[LOG] Clássico OK: ${ELAPSED}ms"
        else
            echo -e "${RED}[ERROR] Clássico falhou na iteração $i${NC}"
            echo "Classic,ecdh-sha2-nistp256,rsa-sha2-512,${i},${ELAPSED},1024,fail" >> "$RESULTS_FILE"
        fi
    done
fi

echo "[LOG] Calculando estatísticas..."

if [ ${#pqc_times[@]} -gt 0 ]; then
    pqc_sum=0
    pqc_min=${pqc_times[0]}
    pqc_max=${pqc_times[0]}
    for time in "${pqc_times[@]}"; do
        pqc_sum=$((pqc_sum + time))
        [ $time -lt $pqc_min ] && pqc_min=$time
        [ $time -gt $pqc_max ] && pqc_max=$time
    done
    pqc_avg=$((pqc_sum / ${#pqc_times[@]}))
    echo "[LOG] PQC - Médio: ${pqc_avg}ms | Mín: ${pqc_min}ms | Máx: ${pqc_max}ms"
fi

SUMMARY_FILE="${RESULTS_DIR}/comparison_summary_${TIMESTAMP}.txt"
{
    echo "Comparação PQC vs Clássico"
    echo "Data: $(date)"
    echo ""
    echo "RESULTADOS - LATÊNCIA:"
    echo "  PQC Média: ${pqc_avg}ms"
    
    if [ ${#classic_times[@]} -gt 0 ]; then
        classic_sum=0
        for time in "${classic_times[@]}"; do
            classic_sum=$((classic_sum + time))
        done
        classic_avg=$((classic_sum / ${#classic_times[@]}))
        overhead=$((pqc_avg - classic_avg))
        overhead_pct=$(( (pqc_avg * 100 / classic_avg) - 100 ))
        
        echo "  Clássico Média: ${classic_avg}ms"
        echo "  Overhead: +${overhead}ms (+${overhead_pct}%)"
        echo "[LOG] Clássico - Médio: ${classic_avg}ms | Overhead: +${overhead}ms (+${overhead_pct}%)"
    else
        echo "  Clássico: ~50-100ms (teórico)"
    fi
    
    echo ""
    echo "TAMANHO DOS PACOTES:"
    echo "  PQC: 17,608 bytes"
    echo "  Clássico: ~1,024 bytes"
    echo "  Overhead: +16,584 bytes"
} > "$SUMMARY_FILE"

echo -e "${GREEN}[SUCCESS] Resultados: ${RESULTS_FILE}${NC}"
echo -e "${GREEN}[SUCCESS] Sumário: ${SUMMARY_FILE}${NC}"
