#!/bin/bash
# Remove todas as linhas de debug fprintf

echo "🧹 Removendo debug output do código..."

# Backup dos arquivos
cp libssh/src/kex.c libssh/src/kex.c.bak
cp libssh/src/kex_hqc256.c libssh/src/kex_hqc256.c.bak

# Remove linhas com fprintf DEBUG de kex.c
sed -i '/fprintf.*DEBUG/d' libssh/src/kex.c
sed -i '/fflush(stderr);$/d' libssh/src/kex.c

# Remove linhas com fprintf DEBUG de kex_hqc256.c
sed -i '/fprintf.*DEBUG/d' libssh/src/kex_hqc256.c
sed -i '/fflush(stderr);$/d' libssh/src/kex_hqc256.c

echo "✓ Debug output removido"
echo "  Backups salvos em: *.bak"
echo ""
echo "Arquivos modificados:"
echo "  - libssh/src/kex.c"
echo "  - libssh/src/kex_hqc256.c"
