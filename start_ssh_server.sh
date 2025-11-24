#!/bin/bash
# Script para iniciar o servidor SSH libssh com suporte PQC (Falcon-1024 + HQC-256)

echo "=== Iniciando servidor SSH libssh com PQC ==="

# Verificar se os binários existem
if [ ! -f /opt/libssh/build/examples/samplesshd-cb ]; then
    echo "ERRO: Servidor de exemplo não encontrado!"
    echo "Verifique se a compilação foi bem-sucedida."
    exit 1
fi

if [ ! -f /opt/libssh/build/examples/generate_falcon_hostkey ]; then
    echo "ERRO: generate_falcon_hostkey não encontrado!"
    echo "Verifique se a compilação foi bem-sucedida."
    exit 1
fi

# Criar diretório para chaves se não existir
mkdir -p /opt/libssh/server_keys
cd /opt/libssh/server_keys

# Gerar chave Falcon-1024 (PQC) se não existir
if [ ! -f /opt/libssh/server_keys/ssh_host_falcon1024_key ]; then
    echo "Gerando chave Falcon-1024 (PQC)..."
    /opt/libssh/build/examples/generate_falcon_hostkey /opt/libssh/server_keys/ssh_host_falcon1024_key || {
        echo "ERRO: Falha ao gerar chave Falcon-1024"
        exit 1
    }
fi

# Gerar chave RSA tradicional como fallback se não existir
if [ ! -f /opt/libssh/server_keys/ssh_host_rsa_key ]; then
    echo "Gerando chave RSA tradicional (fallback)..."
    ssh-keygen -t rsa -b 2048 -f /opt/libssh/server_keys/ssh_host_rsa_key -N '' || {
        echo "AVISO: Falha ao gerar chave RSA (não crítico)"
    }
fi

# Verificar se a chave foi gerada
if [ -f /opt/libssh/server_keys/ssh_host_falcon1024_key ]; then
    echo "Chave Falcon-1024 gerada com sucesso!"
    echo ""
    echo "Detalhes da chave:"
    ls -lh /opt/libssh/server_keys/ssh_host_falcon1024_key*
    echo ""
    KEY_FILE="/opt/libssh/server_keys/ssh_host_falcon1024_key"
    KEY_TYPE="Falcon-1024 (PQC)"
else
    echo "ERRO: Chave Falcon não foi gerada!"
    exit 1
fi

echo ""
echo "Servidor configurado com sucesso!"
echo "Tipo de chave: $KEY_TYPE"
echo "Arquivo da chave: $KEY_FILE"
echo ""
echo "Iniciando servidor SSH na porta 2222 (modo loop para testes)..."
echo ""

# Matar qualquer instância antiga do samplesshd-cb
pkill -9 samplesshd-cb 2>/dev/null || true
sleep 1

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Aguardando conexões..."
    # Usando samplesshd-cb com PQC completo:
    # - Hostkey: Falcon-1024 (assinatura, via -k)
    # - Key Exchange: HQC-256 (automático, compilado na libssh)
    # -v = verbosidade, -p = porta, -k = chave host
    /opt/libssh/build/examples/samplesshd-cb \
        -v \
        -p 2222 \
        -k /opt/libssh/server_keys/ssh_host_falcon1024_key \
        0.0.0.0
    EXIT_CODE=$?
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Servidor finalizou (exit: $EXIT_CODE)"
    
    # Se exit code > 1, pode ser erro crítico
    if [ $EXIT_CODE -gt 1 ]; then
        echo "ERRO: Servidor falhou com código $EXIT_CODE"
        sleep 2
    fi
    
    sleep 0.5
done

