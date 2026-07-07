# syntax=docker/dockerfile:1

# ---- Build stage: compile the Micronaut app into a fat (shadow) jar ----
# A full JDK 25 is required (the project targets Java 25). The whole repo is
# copied in — including .git, which the palantir git-version plugin reads to
# compute the project version. jOOQ sources are committed under
# model/src/jooq/java, so NO database is needed at build time.
FROM eclipse-temurin:25-jdk AS build
WORKDIR /workspace

COPY . .
RUN ./gradlew --no-daemon --stacktrace :app:shadowJar

# ---- Runtime stage: slim JRE image matching upstream's Jib base ----
FROM eclipse-temurin:25-jre-alpine-3.23
WORKDIR /app

COPY --from=build /workspace/app/build/libs/*-all.jar /app/kuvasz.jar

# Let the JVM size its heap from the container's memory limit.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/kuvasz.jar"]
