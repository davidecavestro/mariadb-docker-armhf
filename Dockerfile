ARG CODE_VERSION=latest
FROM davidecavestro/mariadb-arm-stretch-builder:${CODE_VERSION}

COPY qemu-arm-static /usr/bin

ARG DEBIAN_FRONTEND=noninteractive

#RUN make -j4
RUN ninja

WORKDIR /src

#RUN make install
RUN ninja install

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
  echo <<MYCNF >> /my.cnf \
[mariadb] \
datadir=/var/lib/mysql \
tmpdir=/tmp \
\
lc_messages_dir=/usr/local/mysql/share \
max-connections=20 \
lc-messages=en_us \
innodb_use_native_aio = 0 \
MYCNF && \
  mkdir -p /var/lib/mysql && \
  chown -R mysql /usr/local/mysql/ /var/lib/mysql /my.cnf

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/docker-entrypoint.sh / # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]
