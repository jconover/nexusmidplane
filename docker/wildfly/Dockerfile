FROM eclipse-temurin:17-jdk

ENV WILDFLY_VERSION=30.0.1.Final \
    WILDFLY_HOME=/opt/wildfly

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/wildfly/wildfly/releases/download/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.tar.gz \
    | tar -xz -C /opt \
    && ln -s /opt/wildfly-${WILDFLY_VERSION} ${WILDFLY_HOME}

# Create non-root user for security
RUN groupadd -r wildfly && useradd -r -g wildfly -d ${WILDFLY_HOME} -s /sbin/nologin wildfly \
    && chown -R wildfly:wildfly /opt/wildfly-${WILDFLY_VERSION} ${WILDFLY_HOME}

EXPOSE 8080 8443 9990

USER wildfly

CMD ["/opt/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
