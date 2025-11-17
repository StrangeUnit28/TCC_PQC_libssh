#!/bin/bash
# Script para testar conexão SSH cliente-servidor

echo "========================================="
echo "  Teste de Conexão SSH"
echo "========================================="
echo ""

# Verificar se servidor está rodando
echo "🔍 Verificando servidor..."
SERVER_PID=$(docker exec libssh-server-test ps aux | grep "samplesshd-kbdint" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$SERVER_PID" ]; then
    echo "⚠️  Servidor não está rodando. Iniciando..."
    docker exec -d libssh-server-test /bin/bash -c "cd /opt/libssh/build/examples && ./samplesshd-kbdint -p 2222 -r /opt/libssh/server_keys/ssh_host_rsa_key 0.0.0.0"
    sleep 2
    echo "✅ Servidor iniciado!"
else
    echo "✅ Servidor rodando (PID: $SERVER_PID)"
fi

echo ""
echo "========================================="
echo "  Conectando ao servidor..."
echo "========================================="
echo ""
echo "Credenciais:"
echo "  Usuário: libssh"
echo "  Senha: libssh"
echo ""
echo "Pressione Ctrl+C para sair"
echo "========================================="
echo ""

cd /home/rafa_bosi/Documentos/TCC/TCC_PQC_libssh/libssh/build/examples
./ssh-client libssh@localhost -p 2222
