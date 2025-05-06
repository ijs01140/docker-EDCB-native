FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        make gcc g++ \
        liblua5.2-dev lua-zlib \
        git ca-certificates wget

WORKDIR /tmp
# download EMWUI
RUN git clone https://github.com/EMWUI/EDCB_Material_WebUI.git

# build EDCB
RUN git clone https://github.com/xtne6f/EDCB.git && \
    cd EDCB/Document/Unix && \
    make -j$(nproc) && \
    make install

WORKDIR /tmp
# build BonDriver
RUN git clone https://github.com/matching/BonDriver_LinuxMirakc.git --recurse-submodules && \
    cd BonDriver_LinuxMirakc && \
    make -j$(nproc) 

# build lua
RUN cd /tmp && \
    wget -O - https://github.com/xtne6f/lua/archive/refs/heads/v5.2-luabinaries.tar.gz | tar xz && \
    cd lua-5.2-luabinaries && \
    make liblua5.2.so  && \
    # sudo cp liblua5.2.so /usr/local/lib/
    # sudo ldconfig
    cd /tmp && \
    wget -O - https://github.com/xtne6f/lua-zlib/archive/refs/heads/v0.5-lua52.tar.gz | tar xz  && \
    cd lua-zlib-0.5-lua52  && \
    make libzlib52.so
    # sudo mkdir -p /usr/local/lib/lua/5.2
    # sudo cp libzlib52.so /usr/local/lib/lua/5.2/

FROM ubuntu:24.04
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        lua-zlib && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# copy EDCB
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib/edcb /usr/local/lib/edcb

# copy EMWUI
COPY --from=builder /tmp/EDCB_Material_WebUI/HttpPublic /var/local/edcb/HttpPublic
COPY --from=builder /tmp/EDCB_Material_WebUI/Setting /var/local/edcb/Setting

# copy BonDriver
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so /var/local/edcb/
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so.ini_sample /var/local/edcb/BonDriver_LinuxMirakc.so.ini

# copy Lua
COPY --from=builder /tmp/lua-5.2-luabinaries/liblua5.2.so /usr/local/lib/
RUN ldconfig
COPY --from=builder /tmp/lua-zlib-0.5-lua52/libzlib52.so /usr/local/lib/lua/5.2/
