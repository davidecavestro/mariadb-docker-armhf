FROM arm32v7/debian:stretch-slim AS builder

COPY qemu-arm-static /usr/bin

ARG DEBIAN_FRONTEND=noninteractive

RUN \
  echo "deb-src http://deb.debian.org/debian stretch main" >> /etc/apt/sources.list && \
  apt-get update && \
  apt-get -y --no-install-recommends install apt-utils git ca-certificates libneon27-gnutls-dev ninja-build && \
  apt-get -y --no-install-recommends build-dep mariadb-server

ARG MARIADB_VERSION=10.3
RUN git clone --branch $MARIADB_VERSION --single-branch --depth=1 https://github.com/MariaDB/server.git /src

WORKDIR /src

#RUN cmake . -DBUILD_CONFIG=mysql_release && make
RUN cmake . \
#  -DBUILD_CONFIG=mysql_release \
  -DENABLE_DEBUG_SYNC=OFF \
  -DINSTALL_MYSQLTESTDIR= \
  -DCONC_WITH_{UNITTEST,SSL}=OFF \
  -DWITH_EMBEDDED_SERVER=OFF \
  -DWITH_UNIT_TESTS=OFF \
#  -DCMAKE_BUILD_TYPE=Release \
  -DPLUGIN_{TOKUDB,MROONGA,OQGRAPH,ROCKSDB,CONNECT,PERFSCHEMA,SPIDER}=OFF \  
  -DWITH_EXAMPLE_STORAGE_ENGINE=0 \
  -DWITH_FEDERATED_STORAGE_ENGINE=0 \
  -DWITH_ARCHIVE_STORAGE_ENGINE=0 \
  -DWITH_BLACKHOLE_STORAGE_ENGINE=0 \
  -DWITH_NDB_STORAGE_ENGINE=0 \
  -DWITH_PARTITION_STORAGE_ENGINE=0 \
  -DWITH_TOKUDB_STORAGE_ENGINE=0 \
  -DWITH_MROONGA_STORAGE_ENGINE=0 \
  -DWITHOUT_MROONGA_SE_STORAGE_ENGINE=1 \
  -DWITH_OQGRAPH_STORAGE_ENGINE=0 \
  -DWITH_ROCKSDB_STORAGE_ENGINE=0 \
  -DWITHOUT_ROCKSDB_SE_STORAGE_ENGINE=1 \
  -DWITH_SPIDER_STORAGE_ENGINE=0 \
  -DWITH_SAFEMALLOC=OFF \
  -DWITH_SSL=bundled 
#  -G Ninja

RUN make -j4
#RUN ninja -j4

WORKDIR /src

RUN make install
#RUN ninja install

FROM arm32v7/debian:stretch-slim AS release
ARG DEBIAN_FRONTEND=noninteractive
COPY qemu-arm-static /usr/bin

RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends apt-utils && \
  apt-get install -y --no-install-recommends libaio1

WORKDIR /usr/local/mysql

COPY --from=builder /usr/local/mysql /usr/local/mysql

RUN \
  useradd -r mysql && \
  echo <<MYCNF >> /home/mysql/my.cnf \
[mariadb] \
datadir=/var/lib/mysql \
tmpdir=/tmp \
\
lc_messages_dir=/usr/local/mysql/share \
max-connections=20 \
lc-messages=en_us \
MYCNF && \
  mkdir -p /var/lib/mysql && \
  chown -R mysql /usr/local/mysql/ /var/lib/mysql && \
  /usr/local/mysql/scripts/mysql_install_db --datadir=/var/lib/mysql --user=mysql

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/docker-entrypoint.sh / # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]
