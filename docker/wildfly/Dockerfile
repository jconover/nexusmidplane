# Stage 1: Build the WAR artifact
FROM eclipse-temurin:17-jdk AS builder

RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY app/java-app/ .
RUN chmod +x mvnw && ./mvnw clean package -DskipTests --no-transfer-progress

# Stage 2: WildFly runtime with deployed WAR
FROM eclipse-temurin:17-jdk

ENV WILDFLY_VERSION=30.0.1.Final \
    WILDFLY_HOME=/opt/wildfly

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/wildfly/wildfly/releases/download/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.tar.gz \
    | tar -xz -C /opt \
    && ln -s /opt/wildfly-${WILDFLY_VERSION} ${WILDFLY_HOME}

# Deploy the WAR into WildFly
COPY --from=builder /build/target/java-app.war ${WILDFLY_HOME}/standalone/deployments/java-app.war

# Create non-root user for security
RUN groupadd -r wildfly && useradd -r -g wildfly -d ${WILDFLY_HOME} -s /sbin/nologin wildfly \
    && chown -R wildfly:wildfly /opt/wildfly-${WILDFLY_VERSION} ${WILDFLY_HOME}

EXPOSE 8080 8443 9990

USER wildfly

CMD ["/opt/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
