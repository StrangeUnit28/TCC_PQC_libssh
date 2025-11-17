#!/usr/bin/env python3
"""
plot_results.py - Gera visualizações dos resultados do benchmark
"""

import csv
import sys

try:
    import matplotlib.pyplot as plt
    import numpy as np
except ImportError:
    print("Erro: matplotlib e/ou numpy não instalados")
    print("Instale com: pip3 install matplotlib numpy")
    sys.exit(1)

def load_data(filename='benchmark_results.csv'):
    """Carrega dados do CSV"""
    curve25519_data = []
    hqc256_data = []
    
    try:
        with open(filename, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row['Algorithm'] == 'Curve25519':
                    curve25519_data.append(float(row['Latency_ms']))
                elif row['Algorithm'] == 'HQC-256':
                    hqc256_data.append(float(row['Latency_ms']))
    except FileNotFoundError:
        print(f"Erro: Arquivo {filename} não encontrado")
        sys.exit(1)
    except Exception as e:
        print(f"Erro ao ler CSV: {e}")
        sys.exit(1)
    
    if not curve25519_data or not hqc256_data:
        print("Erro: Dados insuficientes no CSV")
        sys.exit(1)
    
    return np.array(curve25519_data), np.array(hqc256_data)

def create_plots(curve25519_data, hqc256_data, output='benchmark_results.png'):
    """Cria visualizações dos resultados"""
    
    # Configurar estilo
    plt.style.use('seaborn-v0_8-darkgrid')
    
    # Criar figura com subplots
    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
    
    # Título principal
    fig.suptitle('SSH KEX Performance Benchmark: Curve25519 vs HQC-256', 
                 fontsize=18, fontweight='bold', y=0.98)
    
    # 1. Box Plot (grande)
    ax1 = fig.add_subplot(gs[0, :2])
    bp = ax1.boxplot([curve25519_data, hqc256_data], 
                      labels=['Curve25519\n(Clássico)', 'HQC-256\n(Pós-Quântico)'],
                      patch_artist=True,
                      widths=0.6)
    bp['boxes'][0].set_facecolor('#3498db')
    bp['boxes'][1].set_facecolor('#e74c3c')
    for box in bp['boxes']:
        box.set_alpha(0.7)
    ax1.set_ylabel('Latência (ms)', fontsize=13, fontweight='bold')
    ax1.set_title('Distribuição de Latência', fontsize=14, fontweight='bold', pad=10)
    ax1.grid(True, alpha=0.3, linestyle='--')
    ax1.set_facecolor('#f8f9fa')
    
    # 2. Estatísticas (tabela)
    ax2 = fig.add_subplot(gs[0, 2])
    ax2.axis('off')
    
    mean_c = np.mean(curve25519_data)
    mean_h = np.mean(hqc256_data)
    overhead_pct = ((mean_h - mean_c) / mean_c * 100)
    
    stats_data = [
        ['Métrica', 'Curve25519', 'HQC-256'],
        ['Média', f'{mean_c:.2f} ms', f'{mean_h:.2f} ms'],
        ['Desvio', f'{np.std(curve25519_data):.2f} ms', f'{np.std(hqc256_data):.2f} ms'],
        ['Mínimo', f'{np.min(curve25519_data):.2f} ms', f'{np.min(hqc256_data):.2f} ms'],
        ['Máximo', f'{np.max(curve25519_data):.2f} ms', f'{np.max(hqc256_data):.2f} ms'],
        ['P50', f'{np.percentile(curve25519_data, 50):.2f} ms', f'{np.percentile(hqc256_data, 50):.2f} ms'],
        ['P95', f'{np.percentile(curve25519_data, 95):.2f} ms', f'{np.percentile(hqc256_data, 95):.2f} ms'],
        ['P99', f'{np.percentile(curve25519_data, 99):.2f} ms', f'{np.percentile(hqc256_data, 99):.2f} ms'],
    ]
    
    table = ax2.table(cellText=stats_data, loc='center', cellLoc='left')
    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 2.2)
    
    # Estilizar cabeçalho
    for i in range(3):
        cell = table[(0, i)]
        cell.set_facecolor('#2c3e50')
        cell.set_text_props(weight='bold', color='white')
    
    # Cores alternadas nas linhas
    for i in range(1, len(stats_data)):
        for j in range(3):
            cell = table[(i, j)]
            if i % 2 == 0:
                cell.set_facecolor('#ecf0f1')
    
    ax2.set_title('Estatísticas', fontsize=14, fontweight='bold', pad=15)
    
    # 3. Série Temporal
    ax3 = fig.add_subplot(gs[1, :])
    iterations = np.arange(1, len(curve25519_data) + 1)
    ax3.plot(iterations, curve25519_data, 'o-', label='Curve25519', 
             color='#3498db', alpha=0.7, markersize=5, linewidth=1.5)
    ax3.plot(iterations, hqc256_data, 's-', label='HQC-256', 
             color='#e74c3c', alpha=0.7, markersize=5, linewidth=1.5)
    ax3.axhline(mean_c, color='#3498db', linestyle='--', alpha=0.5, linewidth=1)
    ax3.axhline(mean_h, color='#e74c3c', linestyle='--', alpha=0.5, linewidth=1)
    ax3.set_xlabel('Número da Iteração', fontsize=12, fontweight='bold')
    ax3.set_ylabel('Latência (ms)', fontsize=12, fontweight='bold')
    ax3.set_title('Latência por Iteração (linhas tracejadas = média)', 
                  fontsize=14, fontweight='bold', pad=10)
    ax3.legend(fontsize=11, loc='upper right')
    ax3.grid(True, alpha=0.3, linestyle='--')
    ax3.set_facecolor('#f8f9fa')
    
    # 4. Histograma Curve25519
    ax4 = fig.add_subplot(gs[2, 0])
    ax4.hist(curve25519_data, bins=20, alpha=0.7, color='#3498db', edgecolor='black', linewidth=0.5)
    ax4.axvline(mean_c, color='red', linestyle='--', linewidth=2, label=f'Média: {mean_c:.2f}ms')
    ax4.set_xlabel('Latência (ms)', fontsize=11)
    ax4.set_ylabel('Frequência', fontsize=11)
    ax4.set_title('Curve25519 - Distribuição', fontsize=12, fontweight='bold')
    ax4.legend(fontsize=9)
    ax4.grid(True, alpha=0.3, axis='y', linestyle='--')
    ax4.set_facecolor('#f8f9fa')
    
    # 5. Histograma HQC-256
    ax5 = fig.add_subplot(gs[2, 1])
    ax5.hist(hqc256_data, bins=20, alpha=0.7, color='#e74c3c', edgecolor='black', linewidth=0.5)
    ax5.axvline(mean_h, color='darkred', linestyle='--', linewidth=2, label=f'Média: {mean_h:.2f}ms')
    ax5.set_xlabel('Latência (ms)', fontsize=11)
    ax5.set_ylabel('Frequência', fontsize=11)
    ax5.set_title('HQC-256 - Distribuição', fontsize=12, fontweight='bold')
    ax5.legend(fontsize=9)
    ax5.grid(True, alpha=0.3, axis='y', linestyle='--')
    ax5.set_facecolor('#f8f9fa')
    
    # 6. Comparação de Overhead
    ax6 = fig.add_subplot(gs[2, 2])
    ax6.axis('off')
    
    # Calcular overhead
    overhead_ms = mean_h - mean_c
    overhead_data = [
        ['Overhead PQC', ''],
        ['', ''],
        ['Latência', f'+{overhead_ms:.2f} ms'],
        ['Percentual', f'+{overhead_pct:.1f}%'],
        ['', ''],
        ['Largura de Banda', ''],
        ['Clássico', '~532 bytes'],
        ['PQC', '~21,666 bytes'],
        ['Overhead', '~40.7x'],
    ]
    
    table2 = ax6.table(cellText=overhead_data, loc='center', cellLoc='left')
    table2.auto_set_font_size(False)
    table2.set_fontsize(10)
    table2.scale(1, 2.5)
    
    # Destacar células importantes
    table2[(0, 0)].set_facecolor('#e74c3c')
    table2[(0, 0)].set_text_props(weight='bold', color='white')
    table2[(0, 1)].set_facecolor('#e74c3c')
    
    table2[(5, 0)].set_facecolor('#3498db')
    table2[(5, 0)].set_text_props(weight='bold', color='white')
    table2[(5, 1)].set_facecolor('#3498db')
    
    for i in [2, 3, 8]:
        table2[(i, 0)].set_text_props(weight='bold')
        table2[(i, 1)].set_text_props(weight='bold', color='#e74c3c')
    
    ax6.set_title('Análise de Overhead', fontsize=14, fontweight='bold', pad=15)
    
    # Salvar figura
    plt.savefig(output, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"✓ Gráfico salvo: {output}")

def main():
    print("Gerando visualizações do benchmark...")
    
    try:
        # Carregar dados
        curve25519_data, hqc256_data = load_data()
        
        # Criar plots
        create_plots(curve25519_data, hqc256_data)
        
        # Estatísticas no terminal
        print("\n" + "="*50)
        print("RESUMO ESTATÍSTICO")
        print("="*50)
        print(f"\nCurve25519 (Clássico):")
        print(f"  Média:  {np.mean(curve25519_data):.2f} ms")
        print(f"  Desvio: {np.std(curve25519_data):.2f} ms")
        print(f"  Min:    {np.min(curve25519_data):.2f} ms")
        print(f"  Max:    {np.max(curve25519_data):.2f} ms")
        
        print(f"\nHQC-256 (Pós-Quântico):")
        print(f"  Média:  {np.mean(hqc256_data):.2f} ms")
        print(f"  Desvio: {np.std(hqc256_data):.2f} ms")
        print(f"  Min:    {np.min(hqc256_data):.2f} ms")
        print(f"  Max:    {np.max(hqc256_data):.2f} ms")
        
        overhead = ((np.mean(hqc256_data) - np.mean(curve25519_data)) / 
                    np.mean(curve25519_data) * 100)
        print(f"\nOverhead PQC:")
        print(f"  Latência: +{overhead:.1f}%")
        print(f"  Absoluto: +{np.mean(hqc256_data) - np.mean(curve25519_data):.2f} ms")
        print("="*50 + "\n")
        
    except Exception as e:
        print(f"Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
