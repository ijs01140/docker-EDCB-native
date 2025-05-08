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
        apt-get install -y --no-install-recommends \
        ca-certificates \
        fonts-noto-cjk \
        ncdu \
        language-pack-ja \
        locales \
        python3 \
        sudo \
        supervisor \
        tar \
        tzdata \
        wget && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# copy EDCB
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib/edcb /usr/local/lib/edcb
COPY --from=builder --chmod=775 --chown=ubuntu:ubuntu /var/local/edcb /var/local/edcb
# legacy WEBUIからの設定変更を許可する
RUN sed -i -e 's/^ALLOW_SETTING=.*/ALLOW_SETTING=true/' /var/local/edcb/HttpPublic/legacy/util.lua

# copy EMWUI
COPY --from=builder /tmp/EDCB_Material_WebUI/HttpPublic /var/local/edcb/HttpPublic
COPY --from=builder /tmp/EDCB_Material_WebUI/Setting /var/local/edcb/Setting

# copy BonDriver
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so /var/local/edcb/
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so /var/local/edcb/BonDriver_LinuxMirakc_T.so
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so /var/local/edcb/BonDriver_LinuxMirakc_S.so
COPY --from=builder /tmp/BonDriver_LinuxMirakc/BonDriver_LinuxMirakc.so.ini_sample /var/local/edcb/BonDriver_LinuxMirakc.so.ini

# タイムゾーンを東京に設定
ENV TZ=Asia/Tokyo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# 日本語環境を設定
RUN locale-gen ja_JP.UTF-8
ENV LANG=ja_JP.UTF-8 \
    LANGUAGE=ja_JP:ja \
    LC_ALL=ja_JP.UTF-8

# 一般ユーザーを作成
RUN echo ubuntu:ubuntu | chpasswd && \
    echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R ubuntu:ubuntu /var/local/edcb
USER ubuntu
WORKDIR /home/ubuntu/

# Supervisor の設定ファイルをコピー
COPY ./supervisor.conf /etc/supervisor/conf.d/supervisor.conf

EXPOSE 4510 5510
USER root
CMD ["/usr/bin/supervisord"]
