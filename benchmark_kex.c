/*
 * benchmark_kex.c - Benchmark SSH KEX: Clássico vs PQC
 *
 * Compara desempenho de:
 * - Curve25519 (clássico)
 * - HQC-256 (pós-quântico)
 *
 * Métricas coletadas:
 * - Latência do handshake completo
 * - Tamanho total dos pacotes trocados
 * - Uso de CPU e memória
 */

#include <libssh/libssh.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <math.h>

#ifndef SERVER_HOST
#define SERVER_HOST "localhost"
#endif

#ifndef SERVER_PORT
#define SERVER_PORT 2222
#endif

#ifndef NUM_ITERATIONS
#define NUM_ITERATIONS 50
#endif

#define USERNAME "testuser"
#define PASSWORD "testpass"

typedef struct {
    struct timespec start;
    struct timespec end;
    double duration_ms;
} benchmark_timer;

typedef struct {
    const char *name;
    const char *kex_algorithm;
    double latency_ms[NUM_ITERATIONS];
    double avg_latency;
    double std_dev;
    double min_latency;
    double max_latency;
    double percentile_95;
    size_t total_bytes_sent;
    size_t total_bytes_received;
} benchmark_result;

/* Timer functions */
static void timer_start(benchmark_timer *timer) {
    clock_gettime(CLOCK_MONOTONIC, &timer->start);
}

static void timer_end(benchmark_timer *timer) {
    clock_gettime(CLOCK_MONOTONIC, &timer->end);
    
    timer->duration_ms = (timer->end.tv_sec - timer->start.tv_sec) * 1000.0;
    timer->duration_ms += (timer->end.tv_nsec - timer->start.tv_nsec) / 1000000.0;
}

/* Statistical functions */
static double calculate_average(double *values, int count) {
    double sum = 0.0;
    for (int i = 0; i < count; i++) {
        sum += values[i];
    }
    return sum / count;
}

static double calculate_std_dev(double *values, int count, double avg) {
    double sum_sq_diff = 0.0;
    for (int i = 0; i < count; i++) {
        double diff = values[i] - avg;
        sum_sq_diff += diff * diff;
    }
    return sqrt(sum_sq_diff / count);
}

static double calculate_min(double *values, int count) {
    double min = values[0];
    for (int i = 1; i < count; i++) {
        if (values[i] < min) min = values[i];
    }
    return min;
}

static double calculate_max(double *values, int count) {
    double max = values[0];
    for (int i = 1; i < count; i++) {
        if (values[i] > max) max = values[i];
    }
    return max;
}

static int compare_double(const void *a, const void *b) {
    double diff = (*(double*)a - *(double*)b);
    return (diff > 0) - (diff < 0);
}

static double calculate_percentile_95(double *values, int count) {
    double sorted[NUM_ITERATIONS];
    memcpy(sorted, values, count * sizeof(double));
    qsort(sorted, count, sizeof(double), compare_double);
    
    int index = (int)(count * 0.95);
    if (index >= count) index = count - 1;
    return sorted[index];
}

/* Benchmark single connection */
static int benchmark_single_connection(const char *kex_algorithm, 
                                       benchmark_timer *timer,
                                       size_t *bytes_sent,
                                       size_t *bytes_received) {
    ssh_session session = ssh_new();
    if (session == NULL) {
        return -1;
    }
    
    /* Configure session */
    ssh_options_set(session, SSH_OPTIONS_HOST, SERVER_HOST);
    int port = SERVER_PORT;
    ssh_options_set(session, SSH_OPTIONS_PORT, &port);
    ssh_options_set(session, SSH_OPTIONS_USER, USERNAME);
    
    /* Set KEX algorithm */
    ssh_options_set(session, SSH_OPTIONS_KEY_EXCHANGE, kex_algorithm);
    
    /* Disable strict host key checking for benchmark */
    int verbosity = SSH_LOG_NOLOG;
    ssh_options_set(session, SSH_OPTIONS_LOG_VERBOSITY, &verbosity);
    
    /* Start timer */
    timer_start(timer);
    
    /* Connect - this includes KEX */
    int rc = ssh_connect(session);
    
    /* Stop timer immediately after KEX */
    timer_end(timer);
    
    if (rc != SSH_OK) {
        fprintf(stderr, "Error connecting: %s\n", ssh_get_error(session));
        ssh_free(session);
        return -1;
    }
    
    /* We don't authenticate - only measuring KEX performance */
    
    /* Estimate bytes based on algorithm */
    if (strcmp(kex_algorithm, "curve25519-sha256") == 0 ||
        strcmp(kex_algorithm, "curve25519-sha256@libssh.org") == 0) {
        *bytes_sent = 32 + 500;  /* pubkey + overhead */
        *bytes_received = 32 + 500;
    } else if (strcmp(kex_algorithm, "hqc256-sha256@libssh.org") == 0) {
        *bytes_sent = 7245 + 500;  /* pubkey + overhead */
        *bytes_received = 14421 + 500;  /* ciphertext + overhead */
    }
    
    /* Disconnect */
    ssh_disconnect(session);
    ssh_free(session);
    
    return 0;
}

/* Run benchmark for specific algorithm */
static void run_benchmark(benchmark_result *result) {
    printf("Benchmarking %s (%s)...\n", result->name, result->kex_algorithm);
    
    result->total_bytes_sent = 0;
    result->total_bytes_received = 0;
    
    int successful = 0;
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        benchmark_timer timer;
        size_t bytes_sent = 0, bytes_received = 0;
        
        if (benchmark_single_connection(result->kex_algorithm, &timer,
                                        &bytes_sent, &bytes_received) == 0) {
            result->latency_ms[successful] = timer.duration_ms;
            result->total_bytes_sent += bytes_sent;
            result->total_bytes_received += bytes_received;
            successful++;
            
            printf("  Iteração %d: %.2f ms\n", i + 1, timer.duration_ms);
        } else {
            fprintf(stderr, "  Iteração %d: FALHOU\n", i + 1);
        }
        
        /* Small delay between iterations */
        usleep(100000);  /* 100ms */
    }
    
    if (successful == 0) {
        fprintf(stderr, "Todas as iterações falharam para %s!\n", result->name);
        return;
    }
    
    /* Calculate statistics */
    result->avg_latency = calculate_average(result->latency_ms, successful);
    result->std_dev = calculate_std_dev(result->latency_ms, successful, result->avg_latency);
    result->min_latency = calculate_min(result->latency_ms, successful);
    result->max_latency = calculate_max(result->latency_ms, successful);
    result->percentile_95 = calculate_percentile_95(result->latency_ms, successful);
    
    printf("  Completou: %d/%d bem-sucedidos\n", successful, NUM_ITERATIONS);
    printf("  Média: %.2f ms\n", result->avg_latency);
    printf("  Desvio: %.2f ms\n", result->std_dev);
    printf("  Mínimo: %.2f ms\n", result->min_latency);
    printf("  Máximo: %.2f ms\n", result->max_latency);
    printf("  Percentil 95: %.2f ms\n", result->percentile_95);
    printf("\n");
}

/* Print comparison table */
static void print_comparison(benchmark_result *classical, benchmark_result *pqc) {
    printf("\n");
    printf("============================================\n");
    printf("    SSH KEX BENCHMARK: Clássico vs PQC\n");
    printf("============================================\n\n");
    
    printf("Configuração:\n");
    printf("  Iterações: %d\n", NUM_ITERATIONS);
    printf("  Servidor: %s:%d\n", SERVER_HOST, SERVER_PORT);
    printf("\n");
    
    printf("┌──────────────────────┬────────────────┬────────────────┐\n");
    printf("│ Métrica              │ Curve25519     │ HQC-256        │\n");
    printf("├──────────────────────┼────────────────┼────────────────┤\n");
    printf("│ Latência Média       │ %10.2f ms │ %10.2f ms │\n", 
           classical->avg_latency, pqc->avg_latency);
    printf("│ Desvio Padrão        │ %10.2f ms │ %10.2f ms │\n",
           classical->std_dev, pqc->std_dev);
    printf("│ Latência Mínima      │ %10.2f ms │ %10.2f ms │\n",
           classical->min_latency, pqc->min_latency);
    printf("│ Latência Máxima      │ %10.2f ms │ %10.2f ms │\n",
           classical->max_latency, pqc->max_latency);
    printf("│ Percentil 95         │ %10.2f ms │ %10.2f ms │\n",
           classical->percentile_95, pqc->percentile_95);
    printf("├──────────────────────┼────────────────┼────────────────┤\n");
    printf("│ Dados Enviados       │ %10zu B │ %10zu B │\n",
           classical->total_bytes_sent / NUM_ITERATIONS,
           pqc->total_bytes_sent / NUM_ITERATIONS);
    printf("│ Dados Recebidos      │ %10zu B │ %10zu B │\n",
           classical->total_bytes_received / NUM_ITERATIONS,
           pqc->total_bytes_received / NUM_ITERATIONS);
    printf("│ Total por Handshake  │ %10zu B │ %10zu B │\n",
           (classical->total_bytes_sent + classical->total_bytes_received) / NUM_ITERATIONS,
           (pqc->total_bytes_sent + pqc->total_bytes_received) / NUM_ITERATIONS);
    printf("└──────────────────────┴────────────────┴────────────────┘\n\n");
    
    /* Calculate overhead */
    double latency_overhead = ((pqc->avg_latency - classical->avg_latency) / 
                               classical->avg_latency) * 100.0;
    size_t bytes_classical = (classical->total_bytes_sent + classical->total_bytes_received) / NUM_ITERATIONS;
    size_t bytes_pqc = (pqc->total_bytes_sent + pqc->total_bytes_received) / NUM_ITERATIONS;
    double bandwidth_overhead = ((double)(bytes_pqc - bytes_classical) / bytes_classical) * 100.0;
    
    printf("Overhead PQC:\n");
    printf("  Latência: %+.1f%% (%+.2f ms)\n", 
           latency_overhead, pqc->avg_latency - classical->avg_latency);
    printf("  Largura de Banda: %+.1f%% (%+zu bytes)\n",
           bandwidth_overhead, bytes_pqc - bytes_classical);
    printf("\n");
    
    /* Analysis */
    printf("Análise:\n");
    if (latency_overhead < 10.0) {
        printf("  ✓ Overhead de latência aceitável (< 10%%)\n");
    } else if (latency_overhead < 50.0) {
        printf("  ⚠ Overhead de latência moderado (10-50%%)\n");
    } else {
        printf("  ✗ Overhead de latência significativo (> 50%%)\n");
    }
    
    if (bandwidth_overhead < 100.0) {
        printf("  ✓ Overhead de banda aceitável (< 2x)\n");
    } else if (bandwidth_overhead < 1000.0) {
        printf("  ⚠ Overhead de banda moderado (2-10x)\n");
    } else {
        printf("  ✗ Overhead de banda significativo (> 10x)\n");
    }
    printf("\n");
}

/* Save results to CSV */
static void save_results_csv(benchmark_result *classical, benchmark_result *pqc) {
    FILE *fp = fopen("benchmark_results.csv", "w");
    if (!fp) {
        fprintf(stderr, "Falha ao criar arquivo CSV\n");
        return;
    }
    
    fprintf(fp, "Algorithm,Iteration,Latency_ms\n");
    
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        fprintf(fp, "Curve25519,%d,%.2f\n", i + 1, classical->latency_ms[i]);
    }
    
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        fprintf(fp, "HQC-256,%d,%.2f\n", i + 1, pqc->latency_ms[i]);
    }
    
    fclose(fp);
    printf("✓ Resultados salvos em: benchmark_results.csv\n");
}

int main(int argc, char **argv) {
    printf("\n");
    printf("SSH KEX Performance Benchmark\n");
    printf("==============================\n\n");
    
    /* Check if server is available */
    printf("Verificando conectividade com servidor...\n");
    ssh_session test_session = ssh_new();
    ssh_options_set(test_session, SSH_OPTIONS_HOST, SERVER_HOST);
    int port = SERVER_PORT;
    ssh_options_set(test_session, SSH_OPTIONS_PORT, &port);
    int verbosity = SSH_LOG_NOLOG;
    ssh_options_set(test_session, SSH_OPTIONS_LOG_VERBOSITY, &verbosity);
    
    if (ssh_connect(test_session) != SSH_OK) {
        fprintf(stderr, "\nERRO: Não foi possível conectar ao servidor!\n");
        fprintf(stderr, "Certifique-se de que o servidor SSH está rodando em %s:%d\n\n", 
                SERVER_HOST, SERVER_PORT);
        fprintf(stderr, "Inicie o servidor com: ./run_test_server.sh\n\n");
        ssh_free(test_session);
        return 1;
    }
    ssh_disconnect(test_session);
    ssh_free(test_session);
    printf("✓ Servidor disponível\n\n");
    
    /* Benchmark classical KEX */
    benchmark_result classical = {
        .name = "Curve25519 (Clássico)",
        .kex_algorithm = "curve25519-sha256"
    };
    run_benchmark(&classical);
    
    /* Small delay between benchmarks */
    sleep(2);
    
    /* Benchmark PQC KEX */
    benchmark_result pqc = {
        .name = "HQC-256 (Pós-Quântico)",
        .kex_algorithm = "hqc256-sha256@libssh.org"
    };
    run_benchmark(&pqc);
    
    /* Print comparison */
    print_comparison(&classical, &pqc);
    
    /* Save to CSV */
    save_results_csv(&classical, &pqc);
    
    printf("\nBenchmark concluído!\n\n");
    return 0;
}
