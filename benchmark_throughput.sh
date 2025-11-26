#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NUM_ITERATIONS=5
FILE_SIZES=("1M" "10M" "50M")
SERVER_HOST="localhost"
SERVER_PORT=2222
RESULTS_DIR="./benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/throughput_${TIMESTAMP}.csv"
TEMP_DIR="/tmp/ssh_benchmark_$$"

CLIENT_BIN="./libssh/build/examples/pqc-message-test"
export LD_LIBRARY_PATH=./libssh/build/src:./third_party/liboqs/build/lib

# Função para aguardar servidor estar pronto
wait_server_ready() {
    local max_wait=20
    local count=0
    while [ $count -lt $max_wait ]; do
        if nc -z "$SERVER_HOST" "$SERVER_PORT" 2>/dev/null; then
            sleep 2
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

mkdir -p "$RESULTS_DIR" "$TEMP_DIR"

echo "[LOG] Verificando conectividade com ${SERVER_HOST}:${SERVER_PORT}..."
if ! nc -z "$SERVER_HOST" "$SERVER_PORT" 2>/dev/null; then
    echo -e "${RED}[ERROR] Servidor não está rodando${NC}"
    exit 1
fi
echo "[LOG] Servidor acessível"

echo "[LOG] Usando cliente: ${CLIENT_BIN}"
if [ ! -f "$CLIENT_BIN" ]; then
    echo -e "${RED}[ERROR] Cliente não encontrado: ${CLIENT_BIN}${NC}"
    exit 1
fi
echo "[LOG] Cliente encontrado"

echo "file_size,iteration,transfer_time_sec,throughput_mbps,direction" > "$RESULTS_FILE"

size_to_bytes() {
    local size=$1
    case $size in
        *M) echo $((${size%M} * 1048576)) ;;
        *K) echo $((${size%K} * 1024)) ;;
        *) echo $size ;;
    esac
}

calculate_throughput() {
    local size_bytes=$1
    local time_sec=$2
    local size_mb=$(echo "scale=2; $size_bytes / 1048576" | bc)
    echo "scale=2; ($size_mb * 8) / $time_sec" | bc
}

for size in "${FILE_SIZES[@]}"; do
    echo "[LOG] === Testando tamanho: ${size} ==="
    testfile="${TEMP_DIR}/testfile_${size}"
    dd if=/dev/urandom of="$testfile" bs=$size count=1 2>/dev/null
    size_bytes=$(size_to_bytes "$size")
    
    echo "[LOG] Testes de UPLOAD (${size})..."
    for i in $(seq 1 $NUM_ITERATIONS); do
        echo "[LOG] Upload iteração $i/${NUM_ITERATIONS}"
        
        if ! wait_server_ready; then
            echo -e "${YELLOW}[WARN] Timeout aguardando servidor${NC}"
            continue
        fi
        
        START_TIME=$(date +%s%N)
        
        # Simular upload: criar arquivo remoto via comando dd
        set +e
        OUTPUT=$($CLIENT_BIN "dd if=/dev/zero of=/tmp/uploaded_test bs=$size count=1 2>&1" 2>&1)
        EXIT_CODE=$?
        set -e
        
        END_TIME=$(date +%s%N)
        ELAPSED_SEC=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
        
        if [ $EXIT_CODE -eq 0 ]; then
            THROUGHPUT=$(calculate_throughput $size_bytes $ELAPSED_SEC)
            echo "${size},${i},${ELAPSED_SEC},${THROUGHPUT},upload" >> "$RESULTS_FILE"
            echo "[LOG] Upload OK: ${ELAPSED_SEC}s, ${THROUGHPUT} Mbps"
        else
            echo -e "${RED}[ERROR] Upload falhou${NC}"
        fi
    done
    
    echo "[LOG] Testes de DOWNLOAD (${size})..."
    for i in $(seq 1 $NUM_ITERATIONS); do
        echo "[LOG] Download iteração $i/${NUM_ITERATIONS}"
        
        if ! wait_server_ready; then
            echo -e "${YELLOW}[WARN] Timeout aguardando servidor${NC}"
            continue
        fi
        
        START_TIME=$(date +%s%N)
        
        # Simular download: ler arquivo remoto via cat
        set +e
        OUTPUT=$($CLIENT_BIN "cat /tmp/uploaded_test 2>&1" 2>&1)
        EXIT_CODE=$?
        set -e
        
        END_TIME=$(date +%s%N)
        ELAPSED_SEC=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
        
        if [ $EXIT_CODE -eq 0 ]; then
            THROUGHPUT=$(calculate_throughput $size_bytes $ELAPSED_SEC)
            echo "${size},${i},${ELAPSED_SEC},${THROUGHPUT},download" >> "$RESULTS_FILE"
            echo "[LOG] Download OK: ${ELAPSED_SEC}s, ${THROUGHPUT} Mbps"
        else
            echo -e "${RED}[ERROR] Download falhou${NC}"
        fi
    done
    
    rm -f "$testfile"
done

rm -rf "$TEMP_DIR"

SUMMARY_FILE="${RESULTS_DIR}/throughput_summary_${TIMESTAMP}.txt"
{
    echo "Benchmark Throughput SSH PQC"
    echo "Data: $(date)"
    echo ""
    echo "RESULTADOS:"
    echo ""
    for size in "${FILE_SIZES[@]}"; do
        upload_avg=$(awk -F',' -v size="$size" '$1==size && $5=="upload" {sum+=$4; count++} END {if(count>0) print sum/count; else print 0}' "$RESULTS_FILE")
        download_avg=$(awk -F',' -v size="$size" '$1==size && $5=="download" {sum+=$4; count++} END {if(count>0) print sum/count; else print 0}' "$RESULTS_FILE")
        echo "Arquivo ${size}:"
        echo "  Upload:   ${upload_avg} Mbps"
        echo "  Download: ${download_avg} Mbps"
        echo ""
    done
} > "$SUMMARY_FILE"

echo "[LOG] Limpando arquivos temporários..."
rm -rf "$TEMP_DIR"

echo -e "${GREEN}[SUCCESS] Resultados: ${RESULTS_FILE}${NC}"
echo -e "${GREEN}[SUCCESS] Sumário: ${SUMMARY_FILE}${NC}"
