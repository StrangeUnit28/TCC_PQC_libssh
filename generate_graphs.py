#!/usr/bin/env python3
import sys
import glob
from pathlib import Path

try:
    import pandas as pd
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')
except ImportError:
    print("Erro: pip install pandas matplotlib")
    sys.exit(1)

RESULTS_DIR = Path("./benchmark_results")
OUTPUT_DIR = RESULTS_DIR / "graficos"
OUTPUT_DIR.mkdir(exist_ok=True)

latency_files = list(RESULTS_DIR.glob("latency_*.csv"))
if latency_files:
    df = pd.read_csv(latency_files[-1])
    df_success = df[df['total_time_ms'] != 'FAIL']
    df_success['total_time_ms'] = df_success['total_time_ms'].astype(float)
    
    plt.figure(figsize=(10, 6))
    plt.plot(df_success['iteration'], df_success['total_time_ms'], 
             marker='o', linewidth=2, color='#2E86AB')
    mean_time = df_success['total_time_ms'].mean()
    plt.axhline(y=mean_time, color='red', linestyle='--', 
                label=f'Média: {mean_time:.1f}ms')
    plt.xlabel('Iteração')
    plt.ylabel('Tempo (ms)')
    plt.title('Latência Handshake SSH PQC')
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "latencia.png", dpi=300)
    plt.close()

throughput_files = list(RESULTS_DIR.glob("throughput_*.csv"))
if throughput_files:
    df = pd.read_csv(throughput_files[-1])
    summary = df.groupby(['file_size', 'direction'])['throughput_mbps'].mean().unstack()
    
    fig, ax = plt.subplots(figsize=(10, 6))
    summary.plot(kind='bar', ax=ax, color=['#F18F01', '#048A81'])
    ax.set_xlabel('Tamanho')
    ax.set_ylabel('Throughput (Mbps)')
    ax.set_title('Throughput SSH PQC')
    ax.legend(['Upload', 'Download'])
    ax.grid(True, alpha=0.3, axis='y')
    plt.setp(ax.xaxis.get_majorticklabels(), rotation=0)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "throughput.png", dpi=300)
    plt.close()

print("Gráficos salvos em:", OUTPUT_DIR)

# ============================================================================
# GRÁFICO 3: Dashboard Consolidado
# ============================================================================

print("\n[3/3] Gerando dashboard consolidado...")

if latency_files:
    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)
    
    # Subplot 1: Latência ao longo do tempo
    ax1 = fig.add_subplot(gs[0, 0])
    df_latency = pd.read_csv(latency_files[-1])
    df_success = df_latency[df_latency['total_time_ms'] != 'FAIL']
    df_success['total_time_ms'] = df_success['total_time_ms'].astype(float)
    
    ax1.plot(df_success['iteration'], df_success['total_time_ms'], 
             marker='o', linewidth=2, color='#2E86AB')
    mean_time = df_success['total_time_ms'].mean()
    ax1.axhline(y=mean_time, color='red', linestyle='--', linewidth=1.5, 
                label=f'Média: {mean_time:.1f}ms')
    ax1.set_xlabel('Iteração', fontsize=10, fontweight='bold')
    ax1.set_ylabel('Tempo (ms)', fontsize=10, fontweight='bold')
    ax1.set_title('Latência do Handshake PQC', fontsize=12, fontweight='bold')
    ax1.grid(True, alpha=0.3)
    ax1.legend(fontsize=9)
    
    # Subplot 2: Distribuição temporal das operações
    ax2 = fig.add_subplot(gs[0, 1])
    operations = ['Geração de\nChaves', 'Processamento\nServidor', 'Verificação\nAssinatura', 'Overhead\nI/O']
    durations = [40, 135, 1, 177]
    colors_ops = ['#C73E1D', '#F18F01', '#048A81', '#457B9D']
    
    bars = ax2.bar(operations, durations, color=colors_ops, alpha=0.8)
    for bar in bars:
        height = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2., height,
                f'{int(height)}ms', ha='center', va='bottom', fontsize=9)
    ax2.set_ylabel('Tempo (ms)', fontsize=10, fontweight='bold')
    ax2.set_title('Decomposição Temporal do Handshake', fontsize=12, fontweight='bold')
    ax2.grid(True, alpha=0.3, axis='y')
    plt.setp(ax2.xaxis.get_majorticklabels(), rotation=0, fontsize=8)
    
    # Subplot 3: Throughput
    if throughput_files:
        ax3 = fig.add_subplot(gs[1, 0])
        df_throughput = pd.read_csv(throughput_files[-1])
        summary_thr = df_throughput.groupby(['file_size', 'direction'])['throughput_mbps'].mean().unstack()
        
        summary_thr.plot(kind='bar', ax=ax3, color=['#F18F01', '#048A81'], alpha=0.8)
        ax3.set_xlabel('Tamanho do Arquivo', fontsize=10, fontweight='bold')
        ax3.set_ylabel('Throughput (Mbps)', fontsize=10, fontweight='bold')
        ax3.set_title('Taxa de Transferência', fontsize=12, fontweight='bold')
        ax3.legend(['Upload', 'Download'], fontsize=9)
        ax3.grid(True, alpha=0.3, axis='y')
        plt.setp(ax3.xaxis.get_majorticklabels(), rotation=0)
    
    # Subplot 4: Tamanho dos pacotes
    ax4 = fig.add_subplot(gs[1, 1])
    categories = ['Chave\nPública\nHQC-256', 'Ciphertext\nHQC-256', 'Assinatura\nFalcon-1024', 
                  'Pacote\nKEX_REPLY\nTotal']
    sizes = [7245, 14421, 1280, 17608]
    colors_bar = ['#A8DADC', '#457B9D', '#1D3557', '#C73E1D']
    
    bars = ax4.bar(categories, sizes, color=colors_bar, alpha=0.8)
    for bar in bars:
        height = bar.get_height()
        ax4.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:,}',
                ha='center', va='bottom', fontsize=8)
    ax4.set_ylabel('Tamanho (bytes)', fontsize=10, fontweight='bold')
    ax4.set_title('Tamanhos dos Componentes PQC', fontsize=12, fontweight='bold')
    ax4.grid(True, alpha=0.3, axis='y')
    plt.setp(ax4.xaxis.get_majorticklabels(), rotation=0, fontsize=8)
    
    # Título geral
    fig.suptitle('Dashboard de Performance - SSH com Criptografia Pós-Quântica', 
                 fontsize=16, fontweight='bold', y=0.98)
    
    output_file = OUTPUT_DIR / "dashboard_completo.png"
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"  ✓ Gerado: {output_file}")
    plt.close()
else:
    print("  ⚠ Dados insuficientes para dashboard")

# ============================================================================
# RESUMO FINAL
# ============================================================================

print("\n" + "=" * 70)
print("  RESUMO")
print("=" * 70)
print()
print(f"📁 Gráficos salvos em: {OUTPUT_DIR}/")
print()
print("Arquivos gerados:")
for png_file in sorted(OUTPUT_DIR.glob("*.png")):
    file_size = png_file.stat().st_size / 1024  # KB
    print(f"  ✓ {png_file.name} ({file_size:.1f} KB)")

print()
print("=" * 70)
print("✅ Geração de gráficos concluída!")
print("=" * 70)
print()
print("💡 Dica: Para incluir no LaTeX:")
print()
print(r"  \begin{figure}[h]")
print(r"  \centering")
print(r"  \includegraphics[width=0.8\textwidth]{imagens/latencia_handshake.png}")
print(r"  \caption{Latência do handshake SSH com PQC}")
print(r"  \label{fig:latencia}")
print(r"  \end{figure}")
print()
