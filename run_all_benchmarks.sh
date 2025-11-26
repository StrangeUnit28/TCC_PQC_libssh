#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESULTS_DIR="./benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${RESULTS_DIR}/RELATORIO_${TIMESTAMP}.md"

clear
echo -e "${BLUE}Benchmark SSH PQC - HQC-256 + Falcon-1024${NC}\n"

for cmd in ssh scp nc dd bc awk docker; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Erro: '$cmd' não encontrado${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Dependências OK${NC}\n"

echo -e "${YELLOW}Iniciando ambiente...${NC}"
docker compose up -d --build
sleep 5

for i in {1..30}; do
    if nc -z localhost 2222 2>/dev/null; then
        echo -e "${GREEN}✓ Servidor SSH ativo${NC}\n"
        break
    fi
    [ $i -eq 30 ] && { echo -e "${RED}Erro: Timeout aguardando servidor${NC}"; exit 1; }
    sleep 1
done

mkdir -p "$RESULTS_DIR"
chmod +x benchmark_*.sh 2>/dev/null || true

echo -e "${BLUE}Executando testes...${NC}\n"

echo -e "${YELLOW}[1/4] Latência...${NC}"
if ./benchmark_latency.sh > /dev/null 2>&1; then
    LATENCY_SUCCESS=true
    echo -e "${GREEN}✓ Completo${NC}"
else
    LATENCY_SUCCESS=false
    echo -e "${RED}✗ Falhou${NC}"
fi

echo -e "${YELLOW}[2/4] Throughput...${NC}"
if ./benchmark_throughput.sh > /dev/null 2>&1; then
    THROUGHPUT_SUCCESS=true
    echo -e "${GREEN}✓ Completo${NC}"
else
    THROUGHPUT_SUCCESS=false
    echo -e "${RED}✗ Falhou${NC}"
fi

echo -e "${YELLOW}[3/4] Comparação...${NC}"
if ./benchmark_comparison.sh > /dev/null 2>&1; then
    COMPARISON_SUCCESS=true
    echo -e "${GREEN}✓ Completo${NC}"
else
    COMPARISON_SUCCESS=false
    echo -e "${RED}✗ Falhou${NC}"
fi

echo -e "${YELLOW}[4/4] Gráficos...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
    source venv/bin/activate
    pip install -q pandas matplotlib
else
    source venv/bin/activate
fi

if python3 generate_graphs.py > /dev/null 2>&1; then
    GRAPHS_SUCCESS=true
    echo -e "${GREEN}✓ Completo${NC}"
else
    GRAPHS_SUCCESS=false
    echo -e "${RED}✗ Falhou${NC}"
fi
deactivate


{
    cat << EOF
# Relatório Benchmark SSH PQC

**Data:** $(date '+%d/%m/%Y %H:%M:%S')
**Algoritmos:** HQC-256 + Falcon-1024

## Latência

EOF
    LATEST_LATENCY=$(ls -t ${RESULTS_DIR}/latency_summary_*.txt 2>/dev/null | head -1)
    if [ -n "$LATEST_LATENCY" ] && [ "$LATENCY_SUCCESS" = true ]; then
        AVG_TIME=$(grep "Tempo Médio Total:" "$LATEST_LATENCY" | awk '{print $4}')
        echo "Tempo médio: **${AVG_TIME}**"
        echo ""
        tail -n +5 "$LATEST_LATENCY" | head -n 10
    else
        echo "Dados não disponíveis"
    fi

    cat << EOF

## Throughput

EOF
    LATEST_THROUGHPUT=$(ls -t ${RESULTS_DIR}/throughput_summary_*.txt 2>/dev/null | head -1)
    if [ -n "$LATEST_THROUGHPUT" ] && [ "$THROUGHPUT_SUCCESS" = true ]; then
        grep -A 15 "RESULTADOS:" "$LATEST_THROUGHPUT" | grep -v "Dados completos"
    else
        echo "Dados não disponíveis"
    fi

    cat << EOF

## Comparação PQC vs Clássico

| Métrica | PQC | Clássico |
|---------|-----|----------|
| KEX | HQC-256 | ECDH-P256 |
| Assinatura | Falcon-1024 | RSA-3072 |

EOF
    LATEST_COMPARISON=$(ls -t ${RESULTS_DIR}/comparison_summary_*.txt 2>/dev/null | head -1)
    if [ -n "$LATEST_COMPARISON" ] && [ "$COMPARISON_SUCCESS" = true ]; then
        OVERHEAD_MS=$(grep "Overhead:" "$LATEST_COMPARISON" | head -1 | awk '{print $2}')
        echo "Overhead: **${OVERHEAD_MS}**"
        echo ""
        grep -A 10 "RESULTADOS" "$LATEST_COMPARISON" | head -n 15
    else
        echo "Dados não disponíveis"
    fi

    cat << EOF

## Tamanhos

| Componente | Bytes |
|------------|-------|
| Chave Pública HQC | 7,245 |
| Ciphertext HQC | 14,421 |
| Assinatura Falcon | ~1,280 |
| Pacote KEX_REPLY | 17,608 |

## Arquivos

EOF
    ls -1 ${RESULTS_DIR}/*.csv 2>/dev/null | sed 's/^/- /' || echo "Nenhum"
    echo ""
    ls -1 ${RESULTS_DIR}/graficos/*.png 2>/dev/null | sed 's/^/- /' || echo "Nenhum gráfico"
} > "$REPORT_FILE"

echo -e "${GREEN}✓ Relatório: ${REPORT_FILE}${NC}\n"

echo -e "${BLUE}Resumo:${NC}"
[ "$LATENCY_SUCCESS" = true ] && echo -e "  ${GREEN}✓${NC} Latência" || echo -e "  ${RED}✗${NC} Latência"
[ "$THROUGHPUT_SUCCESS" = true ] && echo -e "  ${GREEN}✓${NC} Throughput" || echo -e "  ${RED}✗${NC} Throughput"
[ "$COMPARISON_SUCCESS" = true ] && echo -e "  ${GREEN}✓${NC} Comparação" || echo -e "  ${RED}✗${NC} Comparação"
[ "$GRAPHS_SUCCESS" = true ] && echo -e "  ${GREEN}✓${NC} Gráficos" || echo -e "  ${RED}✗${NC} Gráficos"

echo -e "\n${YELLOW}Resultados em: ${RESULTS_DIR}/${NC}"
echo -e "${YELLOW}Visualizar: cat ${REPORT_FILE}${NC}\n"

# Se rodando via make test, pular prompt de limpeza
if [ "${SKIP_CLEANUP_PROMPT}" = "true" ]; then
    echo -e "${YELLOW}Servidor ainda rodando. Para parar: docker-compose down${NC}"
    exit 0
fi

echo -e "${YELLOW}Limpar ambiente? (y/n)${NC}"
read -t 10 -n 1 cleanup
if [ "$cleanup" = "y" ]; then
    docker-compose down
    echo -e "\n${GREEN}✓ Ambiente limpo${NC}"
else
    echo -e "\n${YELLOW}Servidor ainda rodando. Para parar: docker-compose down${NC}"
fi
