FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        make gcc g++ \
        liblua5.2-dev lua-zlib \
        git ca-certificates

WORKDIR /tmp
# download EMWUI
RUN git clone https://github.com/EMWUI/EDCB_Material_WebUI.git && \
    rm -rf EDCB_Material_WebUI/.git && \
    rm -rf EDCB_Material_WebUI/LICENSE && \
    rm -f EDCB_Material_WebUI/README.md

# build EDCB
RUN git clone https://github.com/xtne6f/EDCB.git && \
    cd EDCB/Document/Unix && \
    make -j$(nproc) && \
    make install && \
    mkdir /var/local/edcb && \
    make setup_ini

WORKDIR /tmp
# build BonDriver
RUN git clone https://github.com/matching/BonDriver_LinuxMirakc.git --recurse-submodules && \
    cd BonDriver_LinuxMirakc && \
    make -j$(nproc) 


FROM ubuntu:24.04
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        liblua5.2-0 lua-zlib && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# copy EDCB
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib/edcb /usr/local/lib/edcb
# legacy WEBUIからの設定変更を許可する
RUN sed -i -e 's/^ALLOW_SETTING=.*/ALLOW_SETTING=true/' /var/local/edcb/HttpPublic/legacy/util.lua

# copy EMWUI
COPY --from=builder /tmp/EDCB_Material_WebUI/HttpPublic /var/local/edcb/HttpPublic
COPY --from=builder /tmp/EDCB_Material_WebUI/Setting /var/local/edcb/Setting

# copy BonDriver
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so /var/local/edcb/
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so.ini_sample /var/local/edcb/BonDriver_LinuxMirakc.so.ini
