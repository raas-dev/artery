ARG JDK_VERSION=20
FROM openjdk:$JDK_VERSION-jdk-slim-bullseye

ARG UNAME="app"
ARG GNAME="app"
ARG UHOME="/home/app"
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG SHELL="/bin/bash"

RUN addgroup --system \
  --gid ${HOST_GID} \
  ${GNAME}

RUN adduser --system \
  --uid ${HOST_UID} \
  --ingroup ${GNAME} \
  --disabled-password \
  --home ${UHOME} \
  --shell ${SHELL} \
  ${UNAME}

RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER ${UNAME}
WORKDIR ${UHOME}

ARG CATS_VERSION=8.2.0
RUN curl -fsSL https://github.com/Endava/cats/releases/download/cats-$CATS_VERSION/cats_uberjar_$CATS_VERSION.tar.gz -o cats.tar.gz
RUN tar xvfz cats.tar.gz

ENTRYPOINT ["java", "-jar", "cats.jar"]
CMD ["--help"]
