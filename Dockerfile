ARG PYTHON_VERSION="3.7"

FROM docker.io/python:${PYTHON_VERSION}-slim as builder

RUN apt-get update -yqq \
 && apt-get install -y --no-install-recommends \
    gcc wget libffi-dev libjpeg62-turbo-dev libssl-dev libxslt1-dev libpq-dev zlib1g-dev

RUN pip install --upgrade pip \
 && pip install --prefix="/install" --no-warn-script-location \
        cryptography \
        msgpack-python \
        pillow \
        pynacl

RUN mkdir /synapse \
 && wget https://github.com/matrix-org/synapse/archive/v1.13.0.tar.gz -O synapse.tar.gz \
 && tar -xf synapse.tar.gz -C /synapse --strip-components=1

RUN pip install --prefix="/install" --no-warn-script-location \
        /synapse[all]

FROM docker.io/python:${PYTHON_VERSION}-slim

RUN apt-get update -yqq \
 && apt-get install -y --no-install-recommends \
    libjemalloc2 libjpeg62-turbo libxslt1.1 libpq5 zlib1g \
 && apt-get autoclean -y \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /synapse/config /synapse/data /synapse/keys /synapse/tls \
 && addgroup --system --gid 666 synapse \
 && adduser --system --uid 666 --ingroup synapse --home /synapse/config --disabled-password --no-create-home synapse

COPY --from=builder /install /usr/local
COPY --from=builder /synapse/docker/conf /conf

VOLUME /synapse/config /synapse/data /synapse/keys /synapse/tls

RUN chown -R synapse:synapse /synapse/config /synapse/data /synapse/keys /synapse/tls

ENV LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"

ENTRYPOINT ["python3", "-m", "synapse.app.homeserver"]
CMD ["-c", "/synapse/config/homeserver.yaml"]
