#!/bin/bash

# Adicionar libssh ao LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/libssh/build/lib:/opt/third_party/liboqs/build/lib:$LD_LIBRARY_PATH

# Iniciar servidor SSH padrão na porta 22
/usr/sbin/sshd -D &

# Aguardar SSH padrão iniciar
sleep 2

# Iniciar servidor libssh customizado na porta 2222
cd /opt/libssh/build/examples
./ssh_server_fork \
    --port=2222 \
    --hostkey=/etc/ssh/ssh_host_rsa_key \
    --user=testuser \
    --pass=testpass \
    0.0.0.0 &

echo "Servidores iniciados:"
echo "  - OpenSSH padrão: porta 22"
echo "  - libssh PQC: porta 2222 (testuser/testpass)"

# Manter container rodando
tail -f /dev/null
