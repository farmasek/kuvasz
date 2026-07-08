# syntax=docker/dockerfile:1

# ---- Build stage: build the exploded application distribution ----
# A full JDK 25 is required (the project targets Java 25). jOOQ sources are
# committed under model/src/jooq/java, so NO database is needed at build time.
#
# NOTE: we build the `installDist` distribution (an exploded multi-jar classpath),
# NOT the shadow/fat jar. Micronaut discovers its beans — including the embedded
# Netty HTTP server — by reading META-INF/services/io.micronaut.inject.BeanDefinitionReference
# from every jar on the classpath. That is exactly how upstream's Jib image runs.
# A merged shadow jar drops the server here and the process exits right after
# startup, so the exploded layout is the reliable choice.
FROM eclipse-temurin:25-jdk AS build
WORKDIR /workspace

# rock8cloud builds from a BuildKit git source, which exports the source tree
# WITHOUT a .git directory. The palantir git-version plugin (`version = gitVersion()`)
# requires one, so install git and synthesize a throwaway repo + tag purely so the
# project version can be resolved during Gradle configuration.
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN git init -q \
    && git config user.email "deploy@rock8cloud.local" \
    && git config user.name "rock8cloud deploy" \
    && git add -A \
    && git commit -qm "rock8cloud build" \
    && git tag 0.0.0

RUN ./gradlew --no-daemon --stacktrace :app:installDist

# ---- Runtime stage: slim JRE image matching upstream's Jib base ----
FROM eclipse-temurin:25-jre-alpine-3.23
WORKDIR /app

# Copy the exploded classpath (the app jar + all dependency jars).
COPY --from=build /workspace/app/build/install/app/lib /app/lib

# Let the JVM size its heap from the container's memory limit.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"

EXPOSE 8080

# `/app/lib/*` is a JVM classpath wildcard (expanded by the JVM, not the shell),
# so it works in exec form without a shell.
ENTRYPOINT ["java", "-cp", "/app/lib/*", "com.kuvaszuptime.kuvasz.Application"]
