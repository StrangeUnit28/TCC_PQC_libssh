# TCC: Integração de Algoritmos Pós-Quânticos na libssh

## Sobre este Repositório

Este repositório faz parte do Trabalho de Conclusão de Curso (TCC) sobre a integração de algoritmos de criptografia pós-quântica na biblioteca libssh.

### Objetivo

O objetivo deste projeto é a integração dos seguintes algoritmos pós-quânticos:
- **Falcon**: Para assinatura digital
- **HQC (Hamming Quasi-Cyclic)**: Para encapsulamento de chaves (KEM)

### Estrutura do Ambiente

Este repositório contém a configuração necessária para o ambiente de testes da libssh modificada:

- **Cliente**: A libssh clonada e modificada roda localmente 
- **Servidor**: Um container Docker executando o servidor libssh para testes de comunicação

### Ambiente de Desenvolvimento

O ambiente foi configurado para permitir testes completos da comunicação SSH com os algoritmos pós-quânticos integrados, utilizando:
- Cliente SSH local com as modificações implementadas
- Servidor SSH em container Docker para isolamento e facilidade de testes

**Nota**: A parte teórica do TCC foi desenvolvida separadamente e não está incluída neste repositório, que foca exclusivamente na implementação prática e no ambiente de testes.
