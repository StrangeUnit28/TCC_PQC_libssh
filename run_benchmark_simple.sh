#!/bin/bash
# run_benchmark_simple.sh - Usa servidor existente (Docker ou local)

set -e

BENCHMARK_DIR="$(pwd)"
SERVER_HOST="${SSH_BENCHMARK_HOST:-localhost}"
SERVER_PORT="${SSH_BENCHMARK_PORT:-2222}"
NUM_ITERATIONS="${SSH_BENCHMARK_ITERATIONS:-50}"

echo "==================================="
echo "  SSH KEX Benchmark"
echo "==================================="
echo ""
echo "Configuração:"
echo "  Servidor: $SERVER_HOST:$SERVER_PORT"
echo "  Iterações: $NUM_ITERATIONS"
echo ""
echo "IMPORTANTE: Certifique-se de que o servidor SSH"
echo "está rodando antes de continuar!"
echo ""
echo "Para iniciar o servidor:"
echo "  ./run_test_server.sh"
echo ""
read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar..."

# Verificar conectividade
echo ""
echo "Verificando conectividade..."
if ! timeout 5 bash -c "echo > /dev/tcp/$SERVER_HOST/$SERVER_PORT" 2>/dev/null; then
    echo "✗ Servidor não está respondendo em $SERVER_HOST:$SERVER_PORT"
    echo ""
    echo "Tente:"
    echo "  1. Verificar se o servidor está rodando"
    echo "  2. Verificar o firewall"
    echo "  3. Usar variáveis de ambiente:"
    echo "     export SSH_BENCHMARK_HOST=localhost"
    echo "     export SSH_BENCHMARK_PORT=2222"
    exit 1
fi
echo "✓ Servidor disponível"
echo ""

# Compilar cliente de benchmark
echo "Compilando cliente de benchmark..."
gcc benchmark_kex.c -o benchmark_kex \
    -I libssh/build/include \
    -I libssh/include \
    -L libssh/build/lib \
    -lssh \
    -lm \
    -Wl,-rpath,$(pwd)/libssh/build/lib \
    -O2 \
    -DSERVER_HOST=\"$SERVER_HOST\" \
    -DSERVER_PORT=$SERVER_PORT \
    -DNUM_ITERATIONS=$NUM_ITERATIONS

if [ $? -ne 0 ]; then
    echo "✗ Erro ao compilar"
    exit 1
fi
echo "✓ Cliente compilado"
echo ""

# Executar benchmark
echo "==================================="
echo "  Executando Benchmark"
echo "==================================="
echo ""
echo "⏱ Isto pode levar alguns minutos..."
echo "  ($NUM_ITERATIONS iterações x 2 algoritmos)"
echo ""
./benchmark_kex

# Verificar se CSV foi gerado
if [ ! -f "benchmark_results.csv" ]; then
    echo ""
    echo "✗ Arquivo de resultados não foi gerado"
    exit 1
fi

# Gerar gráfico
echo ""
echo "==================================="
echo "  Gerando Visualizações"
echo "==================================="
echo ""

if command -v python3 &> /dev/null; then
    # Verificar se matplotlib está disponível
    if python3 -c "import matplotlib" 2>/dev/null; then
        python3 plot_results.py 2>/dev/null && echo "✓ Gráfico gerado: benchmark_results.png" || echo "⚠ Erro ao gerar gráfico"
    else
        echo "⚠ matplotlib não instalado"
        echo "Instale com: pip3 install matplotlib numpy"
    fi
else
    echo "⚠ Python3 não disponível"
fi

echo ""
echo "==================================="
echo "  Benchmark Concluído"
echo "==================================="
echo ""
echo "Arquivos gerados:"
echo "  📄 benchmark_results.csv"
if [ -f "benchmark_results.png" ]; then
    echo "  📊 benchmark_results.png"
fi
echo ""
echo "Para visualizar os resultados:"
echo "  cat benchmark_results.csv"
if [ -f "benchmark_results.png" ]; then
    echo "  xdg-open benchmark_results.png  # Linux"
    echo "  open benchmark_results.png      # macOS"
fi
echo ""
