# syntax=docker/dockerfile:1

# ---- Build stage: compile the Micronaut app into a fat (shadow) jar ----
# A full JDK 25 is required (the project targets Java 25). jOOQ sources are
# committed under model/src/jooq/java, so NO database is needed at build time.
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

RUN ./gradlew --no-daemon --stacktrace :app:shadowJar

# ---- Runtime stage: slim JRE image matching upstream's Jib base ----
FROM eclipse-temurin:25-jre-alpine-3.23
WORKDIR /app

COPY --from=build /workspace/app/build/libs/*-all.jar /app/kuvasz.jar

# Let the JVM size its heap from the container's memory limit.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/kuvasz.jar"]
