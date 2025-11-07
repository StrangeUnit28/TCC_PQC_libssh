# Quick build & run guide for libssh server (Docker-based)

Este guia contém os passos e comandos utilizados para configurar, construir e executar o servidor libssh em um ambiente Docker isolado. O guia explica o que cada comando faz e fornece dicas de solução de problemas.

Este ambiente de servidor foi desenvolvido para testes acadêmicos de integração de algoritmos pós-quânticos (Falcon e HQC) na biblioteca libssh, servindo como contraparte do cliente local.

Todos os comandos assumem que você está usando um shell POSIX (zsh/bash) e que seu diretório de trabalho atual é a raiz do repositório.

## Pré-requisitos

- Docker instalado e em execução
- Permissões para executar comandos Docker (usuário no grupo `docker` ou uso de `sudo`)
- Git (para clonar a libssh, se necessário)
- Acesso à rede para baixar imagens Docker

Em sistemas Debian/Ubuntu, instale o Docker com:

```bash
sudo apt update
sudo apt install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
# Adicionar seu usuário ao grupo docker (logout/login necessário)
sudo usermod -aG docker $USER
```

Verifique a instalação do Docker:

```bash
docker --version
docker ps
```

## Estrutura da Solução

O servidor libssh será executado dentro de um container Docker com:
- Sistema operacional base (Debian/Ubuntu)
- Dependências de compilação instaladas
- libssh compilada com suporte aos algoritmos pós-quânticos
- Servidor SSH configurado e em execução
- Portas expostas para comunicação com o cliente local

## Comandos utilizados (com descrições)

### 1) Verificar o Dockerfile

O arquivo `Dockerfile` já está criado na raiz do repositório e contém toda a configuração necessária para:
- Usar Ubuntu 22.04 como base
- Instalar dependências de compilação (cmake, gcc, libssl-dev, zlib1g-dev)
- Compilar a libssh com suporte a exemplos e servidor
- Configurar o ambiente SSH básico
- Expor portas 22 e 2222 para comunicação

**Arquivo**: `Dockerfile` (consulte o arquivo para ver a configuração completa)

### 2) Verificar script de configuração do servidor

O script `start_ssh_server.sh` já está criado e configurado para:
- Verificar se os binários foram compilados corretamente
- Gerar chaves SSH necessárias para o servidor
- Fornecer instruções de como iniciar o servidor
- Manter o container ativo para testes

**Arquivo**: `start_ssh_server.sh` (consulte o arquivo para ver o script completo)

### 3) Verificar arquivo .dockerignore

O arquivo `.dockerignore` já está criado para otimizar o build do Docker, evitando copiar arquivos desnecessários (.git, build, *.md, etc.) para o container.

**Arquivo**: `.dockerignore` (consulte o arquivo para ver os padrões de exclusão)

### 4) Construir a imagem Docker

```bash
docker build -t libssh-server:latest .
```

O que faz: constrói a imagem Docker usando o `Dockerfile` criado. A tag `libssh-server:latest` identifica a imagem.

Observações:
- Este processo pode levar alguns minutos na primeira execução
- O Docker fará cache das camadas para builds subsequentes serem mais rápidos
- Se houver erros de compilação, verifique as dependências no Dockerfile

Solução de problemas:
- Se o build falhar por falta de memória, aumente os recursos do Docker
- Para rebuild completo sem cache: `docker build --no-cache -t libssh-server:latest .`

### 5) Verificar se a imagem foi criada

```bash
docker images | grep libssh-server
```

O que faz: lista as imagens Docker e filtra por "libssh-server" para confirmar que a imagem foi criada com sucesso.

### 6) Executar o container

#### Opção A: Modo interativo para testes

```bash
docker run -it --name libssh-server-test \
    -p 2222:2222 \
    -p 22:22 \
    libssh-server:latest /bin/bash
```

O que faz:
- `-it`: modo interativo com terminal
- `--name libssh-server-test`: nome do container
- `-p 2222:2222`: mapeia porta 2222 do host para porta 2222 do container
- `-p 22:22`: mapeia porta 22 do host para porta 22 do container
- `/bin/bash`: inicia shell bash interativo

#### Opção B: Modo daemon (background) com script de inicialização

```bash
docker run -d --name libssh-server-test \
    -p 2222:2222 \
    -p 22:22 \
    libssh-server:latest /opt/libssh/start_ssh_server.sh
```

O que faz: executa o container em background com o script de inicialização.

### 7) Verificar containers em execução

```bash
docker ps
```

O que faz: lista os containers ativos. Você deve ver `libssh-server-test` na lista.

### 8) Acessar o shell do container em execução

```bash
docker exec -it libssh-server-test /bin/bash
```

O que faz: abre um shell interativo dentro do container em execução, permitindo executar comandos e iniciar o servidor.

### 9) Iniciar o servidor SSH dentro do container

Dentro do container (após `docker exec`):

```bash
# Navegar para o diretório de exemplos
cd /opt/libssh/build/examples

# Listar os servidores de exemplo disponíveis
ls -la | grep sshd

# Iniciar o servidor de exemplo na porta 2222
./samplesshd-cb -p 2222 -r /opt/libssh/server_keys/ssh_host_rsa_key -v
```

O que faz:
- `samplesshd-cb`: servidor SSH de exemplo baseado em callbacks
- `-p 2222`: porta de escuta
- `-r /opt/libssh/server_keys/ssh_host_rsa_key`: chave privada do host
- `-v`: modo verbose (opcional, útil para debug)

Opções alternativas de servidores de exemplo:
- `samplesshd-cb`: servidor com callbacks (recomendado para testes)
- `samplesshd-kbdint`: servidor com autenticação keyboard-interactive

### 10) Testar conexão do cliente

Em outro terminal (no host, fora do container), teste a conexão:

```bash
# Usando o cliente libssh compilado localmente
./build/examples/ssh-client -l root -p 2222 localhost

# Ou usando o cliente SSH padrão do sistema
ssh -p 2222 root@localhost
```

Senha padrão configurada: `tccpassword`

O que faz: conecta ao servidor SSH rodando no container através da porta mapeada.

### 11) Visualizar logs do container

```bash
# Logs em tempo real
docker logs -f libssh-server-test

# Últimas 50 linhas de log
docker logs --tail 50 libssh-server-test
```

O que faz: exibe os logs do container, útil para debug e monitoramento.

## Gerenciamento do Container

### Parar o container

```bash
docker stop libssh-server-test
```

### Iniciar container parado

```bash
docker start libssh-server-test
```

### Reiniciar o container

```bash
docker restart libssh-server-test
```

### Remover o container

```bash
docker stop libssh-server-test
docker rm libssh-server-test
```

### Remover a imagem

```bash
docker rmi libssh-server:latest
```

## Configuração Avançada

### Persistir dados do servidor

Para manter chaves e configurações entre reinicios, use volumes:

```bash
docker run -d --name libssh-server-test \
    -p 2222:2222 \
    -v $(pwd)/server_data:/opt/libssh/server_keys \
    libssh-server:latest
```

### Compartilhar código fonte com o container

Para desenvolvimento ativo, monte o diretório de código:

```bash
docker run -it --name libssh-server-dev \
    -p 2222:2222 \
    -v $(pwd):/opt/libssh \
    libssh-server:latest /bin/bash
```

Após modificações no código, recompile dentro do container:

```bash
cd /opt/libssh/build
make -j$(nproc)
make install
ldconfig
```

### Usar docker-compose (opcional)

O arquivo `docker-compose.yml` já está criado e configurado para facilitar o gerenciamento do container.

**Arquivo**: `docker-compose.yml` (consulte o arquivo para ver a configuração completa)

Comandos docker-compose:

```bash
# Construir e iniciar
docker-compose up -d

# Parar
docker-compose down

# Ver logs
docker-compose logs -f

# Reconstruir
docker-compose up -d --build
```

## Problemas Comuns e Soluções

### Porta já em uso

Erro: `bind: address already in use`

Solução:
```bash
# Verificar qual processo está usando a porta
sudo lsof -i :2222
# ou
sudo netstat -tlnp | grep 2222

# Matar o processo ou usar porta diferente
docker run ... -p 3333:2222 ...
```

### Container não inicia

Verificar logs:
```bash
docker logs libssh-server-test
```

Executar em modo interativo para debug:
```bash
docker run -it --rm libssh-server:latest /bin/bash
```

### Servidor não aceita conexões

Dentro do container, verificar se o servidor está rodando:
```bash
ps aux | grep sshd
netstat -tlnp | grep 2222
```

Testar conexão localmente dentro do container:
```bash
ssh -p 2222 root@localhost
```

### Permissões de arquivo de chave

O servidor SSH pode rejeitar chaves com permissões incorretas:
```bash
chmod 600 /opt/libssh/server_keys/ssh_host_rsa_key
chmod 644 /opt/libssh/server_keys/ssh_host_rsa_key.pub
```

### Rebuild após modificações no código

Se você modificou o código fonte da libssh:

1. Reconstrua a imagem Docker:
```bash
docker build -t libssh-server:latest .
```

2. Remova o container antigo e crie um novo:
```bash
docker stop libssh-server-test
docker rm libssh-server-test
docker run -d --name libssh-server-test -p 2222:2222 libssh-server:latest
```

### Debug de compilação

Para ver erros de compilação detalhados, compile manualmente no container:

```bash
docker run -it libssh-server:latest /bin/bash
cd /opt/libssh/build
make VERBOSE=1
```

## Testes de Integração

### Testar autenticação por senha

```bash
# Do host
./build/examples/ssh-client -l root -p 2222 localhost
# Senha: tccpassword
```

### Testar execução de comando remoto

```bash
./build/examples/ssh-client -l root -p 2222 localhost "ls -la /opt/libssh"
```

### Verificar algoritmos criptográficos suportados

Dentro do container, verifique os logs verbose do servidor para ver os algoritmos negociados durante a conexão.

### Testar com algoritmos pós-quânticos

Após integrar Falcon e HQC, você pode especificar os algoritmos no cliente e verificar os logs do servidor para confirmar o uso:

```bash
# No cliente (exemplo conceitual, adapte conforme implementação)
./build/examples/ssh-client -l root -p 2222 localhost -o KexAlgorithms=hqc-kyber
```

## Estrutura de Diretórios no Container

```
/opt/libssh/               # Código fonte
/opt/libssh/build/         # Arquivos compilados
/opt/libssh/build/examples/    # Binários de exemplo
/opt/libssh/server_keys/       # Chaves do servidor SSH
/usr/local/lib/            # libssh instalada
/usr/local/include/libssh/ # Headers instalados
```

## Próximos Passos

1. ✅ Compilar e executar servidor em Docker
2. ✅ Testar conexão básica cliente-servidor
3. ⏳ Integrar bibliotecas de algoritmos pós-quânticos (Falcon, HQC)
4. ⏳ Modificar código da libssh para suportar os novos algoritmos
5. ⏳ Recompilar cliente e servidor com modificações
6. ⏳ Realizar testes de comunicação com algoritmos pós-quânticos
7. ⏳ Documentar resultados e métricas de desempenho

## Referências e Recursos

- Documentação oficial da libssh: https://api.libssh.org/
- Docker Documentation: https://docs.docker.com/
- Falcon (assinatura pós-quântica): https://falcon-sign.info/
- HQC (KEM pós-quântico): https://pqc-hqc.org/

---

**Nota acadêmica**: Este guia foi desenvolvido como parte do ambiente de testes para o TCC sobre integração de algoritmos pós-quânticos na libssh. O ambiente containerizado garante isolamento, reprodutibilidade e facilita testes de comunicação entre cliente e servidor.
