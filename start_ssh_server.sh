#!/bin/bash
# Script para iniciar o servidor SSH libssh

echo "=== Iniciando servidor SSH libssh ==="

# Verificar se os binários de exemplo existem
if [ ! -f /opt/libssh/build/examples/samplesshd-cb ]; then
    echo "ERRO: Servidor de exemplo não encontrado!"
    echo "Verifique se a compilação foi bem-sucedida."
    exit 1
fi

# Criar diretório para chaves se não existir
mkdir -p /opt/libssh/server_keys

# Gerar chave do servidor se não existir
if [ ! -f /opt/libssh/server_keys/ssh_host_rsa_key ]; then
    echo "Gerando chave RSA do servidor..."
    ssh-keygen -t rsa -f /opt/libssh/server_keys/ssh_host_rsa_key -N '' -q
fi

echo "Servidor configurado com sucesso!"
echo "Chaves do servidor em: /opt/libssh/server_keys/"
echo ""
echo "Para iniciar o servidor de exemplo, execute:"
echo "  /opt/libssh/build/examples/samplesshd-cb -p 2222 -r /opt/libssh/server_keys/ssh_host_rsa_key"
echo ""
echo "Ou para manter o container ativo para testes:"
echo "  tail -f /dev/null"

# Manter container ativo
exec tail -f /dev/null
