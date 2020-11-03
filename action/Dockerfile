FROM python:alpine
COPY setup-qus.py /setup-qus.py
RUN apk --no-cache add ca-certificates curl \
 && curl -fsSL https://download.docker.com/linux/static/edge/x86_64/docker-18.06.3-ce.tgz | tar xvz --strip-components=1 docker/docker -C /usr/bin \
 && chmod +x /usr/bin/docker
ENTRYPOINT ["/setup-qus.py"]
