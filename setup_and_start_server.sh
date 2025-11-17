#!/bin/bash

echo "========================================="
echo "  Configurando Servidor SSH libssh"
echo "========================================="
echo ""

# Criar diretório para chaves
echo "[1/3] Criando diretório para chaves..."
mkdir -p /opt/libssh/server_keys

# Gerar chave RSA se não existir
if [ ! -f /opt/libssh/server_keys/ssh_host_rsa_key ]; then
    echo "[2/3] Gerando chave RSA do servidor..."
    ssh-keygen -t rsa -f /opt/libssh/server_keys/ssh_host_rsa_key -N '' -q
    echo "✓ Chave RSA gerada com sucesso!"
else
    echo "[2/3] Chave RSA já existe, pulando geração..."
fi

# Ajustar permissões
chmod 600 /opt/libssh/server_keys/ssh_host_rsa_key
chmod 644 /opt/libssh/server_keys/ssh_host_rsa_key.pub

echo ""
echo "========================================="
echo "[3/3] Iniciando servidor SSH..."
echo "========================================="
echo "Porta: 2222"
echo "Host Key: /opt/libssh/server_keys/ssh_host_rsa_key"
echo "Endereço: 0.0.0.0 (todas as interfaces)"
echo ""
echo "Servidor rodando! Aguardando conexões..."
echo "========================================="
echo ""

# Navegar para o diretório de exemplos e iniciar servidor
cd /opt/libssh/build/examples
./samplesshd-kbdint -p 2222 -r /opt/libssh/server_keys/ssh_host_rsa_key 0.0.0.0
