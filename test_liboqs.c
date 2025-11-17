#include <stdio.h>
#include <stdlib.h>
#include <oqs/oqs.h>

int main() {
    printf("=== Teste liboqs 0.15.0 ===\n\n");
    
    // Testar HQC-256
    printf("Testando HQC-256 (KEM)...\n");
    OQS_KEM *kem = OQS_KEM_new("HQC-256");
    if (kem == NULL) {
        printf("❌ ERRO: HQC-256 não disponível!\n");
        return 1;
    }
    
    printf("✅ HQC-256 disponível!\n");
    printf("   - Chave pública: %zu bytes\n", kem->length_public_key);
    printf("   - Ciphertext: %zu bytes\n", kem->length_ciphertext);
    printf("   - Shared secret: %zu bytes\n\n", kem->length_shared_secret);
    
    // Testar keypair generation
    uint8_t *public_key = malloc(kem->length_public_key);
    uint8_t *secret_key = malloc(kem->length_secret_key);
    
    if (OQS_KEM_keypair(kem, public_key, secret_key) != OQS_SUCCESS) {
        printf("❌ ERRO: Falha ao gerar keypair HQC-256!\n");
        return 1;
    }
    printf("✅ Keypair HQC-256 gerado com sucesso!\n\n");
    
    free(public_key);
    free(secret_key);
    OQS_KEM_free(kem);
    
    // Testar Falcon-1024
    printf("Testando Falcon-1024 (Assinatura)...\n");
    OQS_SIG *sig = OQS_SIG_new("Falcon-1024");
    if (sig == NULL) {
        printf("❌ ERRO: Falcon-1024 não disponível!\n");
        return 1;
    }
    
    printf("✅ Falcon-1024 disponível!\n");
    printf("   - Chave pública: %zu bytes\n", sig->length_public_key);
    printf("   - Chave privada: %zu bytes\n", sig->length_secret_key);
    printf("   - Assinatura: %zu bytes\n\n", sig->length_signature);
    
    // Testar keypair generation
    uint8_t *sig_public_key = malloc(sig->length_public_key);
    uint8_t *sig_secret_key = malloc(sig->length_secret_key);
    
    if (OQS_SIG_keypair(sig, sig_public_key, sig_secret_key) != OQS_SUCCESS) {
        printf("❌ ERRO: Falha ao gerar keypair Falcon-1024!\n");
        return 1;
    }
    printf("✅ Keypair Falcon-1024 gerado com sucesso!\n\n");
    
    free(sig_public_key);
    free(sig_secret_key);
    OQS_SIG_free(sig);
    
    printf("🎉 Todos os testes passaram! liboqs 0.15.0 está pronta para uso.\n");
    return 0;
}
