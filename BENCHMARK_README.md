# 📊 Benchmark HQC-256 vs Curve25519

Este diretório contém ferramentas para medir e comparar o desempenho do KEX pós-quântico HQC-256 com o algoritmo clássico Curve25519.

## 🎯 O que é medido

- **Latência do Handshake Completo**: Tempo total desde conexão até autenticação
- **Overhead de Rede**: Tamanho dos pacotes trocados
- **Estatísticas**: Média, desvio padrão, mínimo, máximo, percentis

## 🚀 Como Executar

### Pré-requisitos

1. **Servidor SSH rodando** (Docker ou local)
2. **libssh compilada** com suporte HQC-256
3. **Python 3** (opcional, para gráficos)

### Opção 1: Usar Servidor Existente (Recomendado)

```bash
# 1. Iniciar servidor (em outro terminal ou background)
./run_test_server.sh

# 2. Executar benchmark
./run_benchmark_simple.sh
```

### Opção 2: Benchmark com Docker Completo

```bash
# Cria container Docker e roda benchmark automaticamente
./run_benchmark_real.sh
```

### Configuração Personalizada

Use variáveis de ambiente para customizar:

```bash
# Servidor remoto
export SSH_BENCHMARK_HOST=192.168.1.100
export SSH_BENCHMARK_PORT=2222
export SSH_BENCHMARK_ITERATIONS=100

./run_benchmark_simple.sh
```

## 📈 Resultados

Após execução, são gerados:

### 1. **benchmark_results.csv**
Dados brutos de todas as iterações:
```csv
Algorithm,Iteration,Latency_ms
Curve25519,1,45.23
Curve25519,2,43.87
...
HQC-256,1,52.34
HQC-256,2,51.98
...
```

### 2. **benchmark_results.png** (se Python disponível)
Visualização com:
- Box plot comparativo
- Série temporal
- Histogramas
- Tabela de estatísticas
- Análise de overhead

### 3. Saída no Terminal
```
┌──────────────────────┬────────────────┬────────────────┐
│ Métrica              │ Curve25519     │ HQC-256        │
├──────────────────────┼────────────────┼────────────────┤
│ Latência Média       │      45.32 ms  │      52.18 ms  │
│ Desvio Padrão        │       2.14 ms  │       2.87 ms  │
│ Latência Mínima      │      42.11 ms  │      48.03 ms  │
│ Latência Máxima      │      51.22 ms  │      59.44 ms  │
│ Percentil 95         │      49.08 ms  │      57.12 ms  │
├──────────────────────┼────────────────┼────────────────┤
│ Dados Enviados       │        532 B   │      7745 B    │
│ Dados Recebidos      │        532 B   │     14921 B    │
│ Total por Handshake  │       1064 B   │     22666 B    │
└──────────────────────┴────────────────┴────────────────┘

Overhead PQC:
  Latência: +15.1% (+6.86 ms)
  Largura de Banda: +2029.5% (+21602 bytes)
```

## 🔬 Interpretação dos Resultados

### Latência
- **< 10% overhead**: Excelente - quase imperceptível
- **10-50% overhead**: Aceitável - impacto moderado
- **> 50% overhead**: Significativo - considerar trade-offs

### Largura de Banda
- HQC-256 usa **~21 KB** por handshake
- Curve25519 usa **~1 KB** por handshake
- **Overhead esperado: ~40-45x**

### Por que o overhead é tão grande?
- **HQC-256 Public Key**: 7.245 bytes (vs 32 bytes do Curve25519)
- **HQC-256 Ciphertext**: 14.421 bytes (vs nada no ECDH)
- **Trade-off**: Segurança pós-quântica vs eficiência

## 🛠 Troubleshooting

### Erro: "Servidor não está respondendo"
```bash
# Verificar se servidor está rodando
pgrep -f ssh_server_fork

# Verificar porta
ss -tlnp | grep 2222

# Iniciar servidor manualmente
cd libssh/build/examples
LD_LIBRARY_PATH=../lib ./ssh_server_fork 0.0.0.0 2222 /tmp/ssh_host_rsa_key
```

### Erro: "matplotlib not found"
```bash
# Instalar dependências Python
pip3 install matplotlib numpy

# Ou gerar apenas CSV (sem gráficos)
./benchmark_kex  # executa só o binário
```

### Compilação falha
```bash
# Verificar libssh compilada
ls libssh/build/lib/libssh.so

# Recompilar se necessário
cd libssh/build
make clean
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

## 📝 Uso Acadêmico (TCC)

Para incluir no TCC:

1. **Execute múltiplas vezes** para garantir consistência:
   ```bash
   for i in {1..5}; do
       ./run_benchmark_simple.sh
       mv benchmark_results.csv results_run_$i.csv
   done
   ```

2. **Documente o ambiente**:
   - SO e versão do kernel
   - CPU e RAM
   - Rede (local vs remota)
   - Versão da libssh
   - Versão da liboqs

3. **Análise Estatística**:
   - Média e desvio padrão
   - Intervalo de confiança
   - Teste de hipóteses (se aplicável)

4. **Gráficos para Relatório**:
   - Use `benchmark_results.png` (alta resolução 300 DPI)
   - Ou exporte para formato vetorial (modificar `plot_results.py`)

## 📚 Próximos Passos

Após coleta de métricas:
- [ ] Análise de resultados
- [ ] Comparação com literatura
- [ ] Implementação de Falcon-1024 (autenticação)
- [ ] Implementação de KEX híbrido
- [ ] Benchmark completo (KEX + Auth)

## 📖 Referências

- **Algoritmo**: HQC-256 (NIST PQC Round 4)
- **Biblioteca**: liboqs 0.15.0
- **Protocolo SSH**: RFC 4253
- **Metodologia**: Baseada em benchmarks OpenSSH-OQS
