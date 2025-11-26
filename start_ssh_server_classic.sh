#!/bin/bash
# Script para iniciar o servidor SSH libssh com criptografia CLÁSSICA (para comparação)

echo "=== Iniciando servidor SSH libssh CLÁSSICO ==="

# Verificar se os binários existem
if [ ! -f /opt/libssh/build/examples/samplesshd-cb ]; then
    echo "ERRO: Servidor de exemplo não encontrado!"
    echo "Verifique se a compilação foi bem-sucedida."
    exit 1
fi

# Criar diretório para chaves se não existir
mkdir -p /opt/libssh/server_keys
cd /opt/libssh/server_keys

# Gerar chave RSA tradicional se não existir
if [ ! -f /opt/libssh/server_keys/ssh_host_rsa_key ]; then
    echo "Gerando chave RSA tradicional..."
    ssh-keygen -t rsa -b 2048 -f /opt/libssh/server_keys/ssh_host_rsa_key -N '' || {
        echo "ERRO: Falha ao gerar chave RSA"
        exit 1
    }
fi

# Verificar se a chave foi gerada
if [ -f /opt/libssh/server_keys/ssh_host_rsa_key ]; then
    echo "Chave RSA gerada com sucesso!"
    echo ""
    echo "Detalhes da chave:"
    ls -lh /opt/libssh/server_keys/ssh_host_rsa_key*
    echo ""
    KEY_FILE="/opt/libssh/server_keys/ssh_host_rsa_key"
    KEY_TYPE="RSA-2048 (Clássico)"
else
    echo "ERRO: Chave RSA não foi gerada!"
    exit 1
fi

echo ""
echo "Servidor CLÁSSICO configurado com sucesso!"
echo "Tipo de chave: $KEY_TYPE"
echo "Arquivo da chave: $KEY_FILE"
echo ""
echo "Iniciando servidor SSH na porta 2223 (modo daemon)..."
echo "Algoritmos: ECDH-SHA2-NISTP256 (KEX) + RSA-SHA2-512 (HostKey)"
echo ""

# Matar qualquer instância antiga do samplesshd-cb
pkill -9 samplesshd-cb 2>/dev/null || true
sleep 1

# Iniciar servidor em background como daemon
while true; do
    if ! pgrep -f "samplesshd-cb.*2223" > /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando servidor CLÁSSICO..."
        /opt/libssh/build/examples/samplesshd-cb \
            -v \
            -p 2223 \
            -k /opt/libssh/server_keys/ssh_host_rsa_key \
            0.0.0.0 &
        SERVER_PID=$!
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Servidor CLÁSSICO rodando com PID: $SERVER_PID"
    fi
    sleep 1
done
