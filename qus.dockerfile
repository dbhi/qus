ARG HOST_LIB
ARG TARGET_PLATFORM

FROM scratch AS pkg
COPY ./bin-static/* /usr/bin/

FROM ${HOST_LIB}busybox AS register
ENV QEMU_BIN_DIR=/qus/bin
COPY ./register.sh /qus/register
ADD https://raw.githubusercontent.com/umarcor/qemu/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh /qus/qemu-binfmt-conf.sh
RUN chmod +x /qus/qemu-binfmt-conf.sh
ENTRYPOINT ["/qus/register"]

FROM register AS final
COPY --from=pkg /usr/bin/qemu-* /qus/bin/
VOLUME /qus