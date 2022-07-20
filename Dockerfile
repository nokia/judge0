FROM judge0/compilers:1.4.0 AS production

# ---- Installation of TPM libraries ----- #

RUN mkdir -p /tpm2

# ! tpm2-tools installation instructions here
RUN apt autoclean
RUN apt update
RUN apt -y install autoconf-archive \ 
    libcmocka0 libcmocka-dev procps \
    iproute2 build-essential git pkg-config gcc libtool automake libssl-dev \
    uthash-dev autoconf doxygen libglib2.0-dev libdbus-1-dev libcurl4-gnutls-dev \
    libgcrypt20-dev openssl \
    python-pip vim nano net-tools iputils-ping dnsutils libjson-c-dev && \
    apt autoclean

# RUN echo $(ls -l /dev/)
# RUN ls -l /dev/tpm0

# # Give permissions to access the TPM device
# RUN chmod 666 /dev/tpm0
# RUN chmod 666 /dev/tpmrm0

WORKDIR /tpm2
RUN git clone --branch 3.0.1 https://github.com/tpm2-software/tpm2-tss && \
    # * check if this abrmd is really needed or if the kernel RM is enough
    # git clone --branch 2.0.3 https://github.com/tpm2-software/tpm2-abrmd && \
    git clone --branch 5.0 https://github.com/tpm2-software/tpm2-tools

WORKDIR /tpm2/tpm2-tss
RUN ./bootstrap && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    ldconfig && \
    make clean

WORKDIR /tpm2/tpm2-tools
RUN ./bootstrap && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean
# ! End of tpm2-tools installation instructions

# ! ibmtss installation instructions here
# Installing and configuring IBM TSS
RUN curl -fSsL "https://sourceforge.net/projects/ibmtpm20tss/files/ibmtss1.5.0.tar.gz" -o /tmp/ibmtss1.5.0.tar.gz && \
    mkdir /tpm2/ibmtss1.5.0 && \
    tar -xf /tmp/ibmtss1.5.0.tar.gz -C /tpm2/ibmtss1.5.0/ && \
    rm -rf /tmp/*

WORKDIR /tpm2/ibmtss1.5.0/
RUN autoreconf -i && \
    ./configure --disable-tpm-1.2 && \
    make clean && \
    make && \
    make install
# ! End of ibmtss installation instructions

# ? Do I need this if the compilers docker image already has go?
# ! Go installation instructions here
# RUN curl -fSsL "https://golang.org/dl/go1.15.5.linux-amd64.tar.gz" -o /tmp/go1.15.5.tar.gz && \
#     mkdir /tpm2/go1.15.5 && \
#     tar -xzf /tmp/go1.15.5.tar.gz -C /usr/local/ && \
#     rm -rf /tmp/*
ENV PATH=$PATH:/usr/local/go-1.13.5/bin:$GOROOT/bin
# ! End of go installation instructions

# ! Go-tpm installation instructions here
RUN go get -v github.com/google/go-tpm/tpm2 && go get -v github.com/google/go-tpm-tools/tpm2tools && go get -v github.com/google/go-tpm-tools/cmd/gotpm
RUN echo "GOPATH: ${GOPATH}"
RUN echo "GOROOT: ${GOROOT}"
ENV PATH=$PATH:/root/go/bin
# ! End of go-tpm installation instructions

# ! WolfTPM installation instructions here
WORKDIR /tpm2
RUN git clone https://github.com/wolfSSL/wolfssl.git
WORKDIR /tpm2/wolfssl
RUN ./autogen.sh && \
    ./configure --enable-certgen --enable-certreq --enable-certext --enable-pkcs7 --enable-cryptocb --enable-aescfb --enable-devtpm --prefix=/usr && \
    make && \
    make install && \
    ldconfig && \
    make clean
WORKDIR /tpm2/
RUN git clone --branch v2.0.0 https://github.com/wolfSSL/wolfTPM.git
WORKDIR /tpm2/wolfTPM
RUN ./autogen.sh && \
    ./configure --prefix=/usr --enable-devtpm && \
    make install 
# ! End of WolfTPM installation instructions

ENV JUDGE0_HOMEPAGE "https://judge0.com"
LABEL homepage=$JUDGE0_HOMEPAGE

ENV JUDGE0_SOURCE_CODE "https://github.com/judge0/judge0"
LABEL source_code=$JUDGE0_SOURCE_CODE

ENV JUDGE0_MAINTAINER "Herman Zvonimir Došilović <hermanz.dosilovic@gmail.com>"
LABEL maintainer=$JUDGE0_MAINTAINER

ENV PATH "/usr/local/ruby-2.7.0/bin:/opt/.gem/bin:$PATH"
ENV GEM_HOME "/opt/.gem/"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      cron \
      libpq-dev \
      sudo && \
    rm -rf /var/lib/apt/lists/* && \
    echo "gem: --no-document" > /root/.gemrc && \
    gem install bundler:2.1.4 && \
    npm install -g --unsafe-perm aglio@2.3.0

ENV VIRTUAL_PORT 2358
EXPOSE $VIRTUAL_PORT

WORKDIR /api

COPY Gemfile* ./
RUN RAILS_ENV=production bundle

COPY cron /etc/cron.d
RUN cat /etc/cron.d/* | crontab -

COPY . .

# ---- Copy task files that we need in the runtime for participants ---- #
COPY ./task_files/ /task_files/
COPY ./task_files/ /task_files_run/

ENTRYPOINT ["/api/docker-entrypoint.sh"]
CMD ["/api/scripts/server"]

ENV JUDGE0_VERSION "1.13.0"
LABEL version=$JUDGE0_VERSION


# FROM production AS development
# 
# ARG DEV_USER=judge0
# ARG DEV_USER_ID=1000
# 
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#         tmux \
#         vim && \
#     useradd -u $DEV_USER_ID -m -r $DEV_USER && \
#     echo "$DEV_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers
# 
# USER $DEV_USER
# 
# CMD ["sleep", "infinity"]
