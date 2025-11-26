# Dockerfile para servidor libssh com suporte a algoritmos pós-quânticos
FROM ubuntu:22.04

# Evitar prompts durante instalação de pacotes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências de compilação e runtime
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    zlib1g-dev \
    git \
    openssh-client \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório de trabalho
WORKDIR /opt/libssh

# Copiar código fonte da libssh do submódulo para o container
COPY libssh/ /opt/libssh/

# Copiar third_party (liboqs) necessário para PQC
COPY third_party/ /opt/third_party/

# Copiar script de inicialização do servidor PQC
COPY start_ssh_server.sh /opt/libssh/start_ssh_server.sh
RUN chmod +x /opt/libssh/start_ssh_server.sh

# Criar diretório de build
RUN mkdir -p build

# Configurar o projeto com CMake
# Habilita exemplos e servidor
WORKDIR /opt/libssh/build
RUN cmake \
    -DWITH_EXAMPLES=ON \
    -DWITH_SERVER=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    ..

# Compilar o projeto
RUN make -j$(nproc)

# Instalar a biblioteca no sistema
RUN make install

# Atualizar cache de bibliotecas compartilhadas
RUN ldconfig

# Criar diretórios necessários para o servidor SSH
RUN mkdir -p /var/run/sshd /root/.ssh /etc/ssh

# Nota: Chaves Falcon-1024 serão geradas pelo start_ssh_server.sh
# Não geramos chaves tradicionais (RSA, ECDSA, Ed25519) aqui

# Configurar senha root para testes (APENAS PARA AMBIENTE DE DESENVOLVIMENTO)
RUN echo 'root:tccpassword' | chpasswd

# Expor porta SSH padrão
EXPOSE 22

# Expor porta para servidor PQC
EXPOSE 2222

# Diretório de trabalho para exemplos
WORKDIR /opt/libssh/build/examples

# Comando padrão: manter container ativo para testes
CMD ["/bin/bash"]
