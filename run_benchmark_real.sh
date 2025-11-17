#!/bin/bash
# run_benchmark_real.sh - Benchmark real com servidor Docker e cliente host

set -e

BENCHMARK_DIR="$(pwd)"
DOCKER_IMAGE="libssh-pqc-server"
CONTAINER_NAME="libssh-benchmark-server"
SERVER_PORT=2222
NUM_ITERATIONS=50

echo "==================================="
echo "  SSH KEX Benchmark - Real Setup"
echo "==================================="
echo ""
echo "Configuração:"
echo "  - Servidor: Container Docker"
echo "  - Cliente: Máquina Host"
echo "  - Iterações: $NUM_ITERATIONS"
echo "  - Porta: $SERVER_PORT"
echo ""

# Função para limpar ao sair
cleanup() {
    echo ""
    echo "Limpando ambiente..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
}
trap cleanup EXIT

# Verificar se imagem Docker existe
if ! docker images | grep -q "$DOCKER_IMAGE"; then
    echo "⚠ Imagem Docker não encontrada!"
    echo "Construindo imagem Docker..."
    
    # Criar Dockerfile se não existir
    if [ ! -f "Dockerfile.benchmark" ]; then
        cat > Dockerfile.benchmark << 'DOCKERFILE'
FROM ubuntu:22.04

# Instalar dependências
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libssl-dev \
    zlib1g-dev \
    libssh-dev \
    git \
    ninja-build \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório de trabalho
WORKDIR /opt

# Copiar código
COPY libssh/ /opt/libssh/
COPY third_party/liboqs/ /opt/third_party/liboqs/

# Compilar liboqs
WORKDIR /opt/third_party/liboqs
RUN mkdir -p build && cd build && \
    cmake .. -GNinja -DOQS_ENABLE_KEM_HQC=ON -DBUILD_SHARED_LIBS=ON && \
    ninja && \
    ninja install

# Compilar libssh
WORKDIR /opt/libssh
RUN mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON && \
    make -j$(nproc)

# Criar usuário de teste
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser:testpass" | chpasswd

# Gerar host keys
RUN mkdir -p /etc/ssh && \
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "" && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

# Configurar SSH
RUN mkdir -p /run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Expor porta SSH
EXPOSE 22

# Script de inicialização
COPY docker_start.sh /opt/docker_start.sh
RUN chmod +x /opt/docker_start.sh

CMD ["/opt/docker_start.sh"]
DOCKERFILE
    fi
    
    # Criar script de inicialização do container
    cat > docker_start.sh << 'STARTSCRIPT'
#!/bin/bash

# Adicionar libssh ao LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/libssh/build/lib:/opt/third_party/liboqs/build/lib:$LD_LIBRARY_PATH

# Iniciar servidor SSH padrão na porta 22
/usr/sbin/sshd -D &

# Aguardar SSH padrão iniciar
sleep 2

# Iniciar servidor libssh customizado na porta 2222
cd /opt/libssh/build/examples
./ssh_server_fork 0.0.0.0 2222 /etc/ssh/ssh_host_rsa_key &

echo "Servidores iniciados:"
echo "  - OpenSSH padrão: porta 22"
echo "  - libssh PQC: porta 2222"

# Manter container rodando
tail -f /dev/null
STARTSCRIPT
    chmod +x docker_start.sh
    
    docker build -t $DOCKER_IMAGE -f Dockerfile.benchmark .
    echo "✓ Imagem Docker construída"
fi

# Parar container existente
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Iniciar container servidor
echo ""
echo "Iniciando servidor Docker..."
docker run -d \
    --name $CONTAINER_NAME \
    -p $SERVER_PORT:2222 \
    $DOCKER_IMAGE

# Aguardar servidor iniciar
echo "Aguardando servidor inicializar..."
sleep 5

# Verificar se servidor está respondendo
echo "Verificando conectividade..."
if ! timeout 5 bash -c "echo > /dev/tcp/localhost/$SERVER_PORT" 2>/dev/null; then
    echo "✗ Servidor não está respondendo na porta $SERVER_PORT"
    docker logs $CONTAINER_NAME
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
    -O2

echo "✓ Cliente compilado"
echo ""

# Executar benchmark
echo "==================================="
echo "  Executando Benchmark"
echo "==================================="
echo ""
./benchmark_kex

# Gerar gráfico se Python disponível
echo ""
echo "==================================="
echo "  Gerando Visualizações"
echo "==================================="

if command -v python3 &> /dev/null && python3 -c "import matplotlib" 2>/dev/null; then
    python3 << 'EOF'
import csv
import matplotlib.pyplot as plt
import numpy as np
import sys

try:
    # Ler CSV
    curve25519_data = []
    hqc256_data = []
    
    with open('benchmark_results.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['Algorithm'] == 'Curve25519':
                curve25519_data.append(float(row['Latency_ms']))
            elif row['Algorithm'] == 'HQC-256':
                hqc256_data.append(float(row['Latency_ms']))
    
    # Criar figura
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('SSH KEX Performance: Curve25519 vs HQC-256', fontsize=16, fontweight='bold')
    
    # 1. Box plot
    ax1 = axes[0, 0]
    bp = ax1.boxplot([curve25519_data, hqc256_data], 
                      labels=['Curve25519', 'HQC-256'], 
                      patch_artist=True)
    bp['boxes'][0].set_facecolor('lightblue')
    bp['boxes'][1].set_facecolor('lightcoral')
    ax1.set_ylabel('Latência (ms)', fontsize=12)
    ax1.set_title('Distribuição de Latência', fontsize=12, fontweight='bold')
    ax1.grid(True, alpha=0.3)
    
    # 2. Série temporal
    ax2 = axes[0, 1]
    iterations = range(1, len(curve25519_data) + 1)
    ax2.plot(iterations, curve25519_data, 'o-', label='Curve25519', 
             color='blue', alpha=0.7, markersize=4)
    ax2.plot(iterations, hqc256_data, 's-', label='HQC-256', 
             color='red', alpha=0.7, markersize=4)
    ax2.set_xlabel('Iteração', fontsize=12)
    ax2.set_ylabel('Latência (ms)', fontsize=12)
    ax2.set_title('Latência por Iteração', fontsize=12, fontweight='bold')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    # 3. Histograma
    ax3 = axes[1, 0]
    ax3.hist(curve25519_data, bins=20, alpha=0.6, label='Curve25519', color='blue', edgecolor='black')
    ax3.hist(hqc256_data, bins=20, alpha=0.6, label='HQC-256', color='red', edgecolor='black')
    ax3.set_xlabel('Latência (ms)', fontsize=12)
    ax3.set_ylabel('Frequência', fontsize=12)
    ax3.set_title('Distribuição de Frequência', fontsize=12, fontweight='bold')
    ax3.legend()
    ax3.grid(True, alpha=0.3, axis='y')
    
    # 4. Tabela de estatísticas
    ax4 = axes[1, 1]
    ax4.axis('off')
    
    overhead_pct = ((np.mean(hqc256_data) - np.mean(curve25519_data)) / np.mean(curve25519_data) * 100)
    
    stats_data = [
        ['Métrica', 'Curve25519', 'HQC-256', 'Overhead'],
        ['Média (ms)', f'{np.mean(curve25519_data):.2f}', f'{np.mean(hqc256_data):.2f}', f'+{overhead_pct:.1f}%'],
        ['Desvio (ms)', f'{np.std(curve25519_data):.2f}', f'{np.std(hqc256_data):.2f}', ''],
        ['Mínimo (ms)', f'{np.min(curve25519_data):.2f}', f'{np.min(hqc256_data):.2f}', ''],
        ['Máximo (ms)', f'{np.max(curve25519_data):.2f}', f'{np.max(hqc256_data):.2f}', ''],
        ['P95 (ms)', f'{np.percentile(curve25519_data, 95):.2f}', f'{np.percentile(hqc256_data, 95):.2f}', '']
    ]
    
    table = ax4.table(cellText=stats_data, loc='center', cellLoc='center')
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 2)
    
    for i in range(4):
        table[(0, i)].set_facecolor('#4472C4')
        table[(0, i)].set_text_props(weight='bold', color='white')
    
    ax4.set_title('Estatísticas Comparativas', fontsize=12, fontweight='bold', pad=20)
    
    plt.tight_layout()
    plt.savefig('benchmark_results.png', dpi=300, bbox_inches='tight')
    print("\n✓ Gráfico salvo: benchmark_results.png")
    
except Exception as e:
    print(f"\n⚠ Erro ao gerar gráfico: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
EOF
else
    echo "⚠ Python3/matplotlib não disponível - pulando geração de gráfico"
    echo "Instale com: pip3 install matplotlib numpy"
fi

echo ""
echo "==================================="
echo "  Benchmark Concluído"
echo "==================================="
echo ""
echo "Arquivos gerados:"
echo "  📄 benchmark_results.csv"
echo "  📊 benchmark_results.png (se Python disponível)"
echo ""
echo "Logs do servidor disponíveis com:"
echo "  docker logs $CONTAINER_NAME"
echo ""
