# Builds the mock Identity Registry API. The Ballerina jar is platform
# independent, so it is compiled once on the build machine's platform and
# copied into each target platform's Java runtime image.
ARG BALLERINA_VERSION=2201.13.1

FROM --platform=$BUILDPLATFORM ballerina/ballerina:${BALLERINA_VERSION} AS build
WORKDIR /home/ballerina/src
COPY --chown=ballerina:troupe Ballerina.toml Dependencies.toml main.bal ./
# --sticky builds with the exact versions in Dependencies.toml instead of
# moving to the newest patch releases.
RUN bal build --sticky

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S ballerina && adduser -S -G ballerina -h /home/ballerina ballerina
WORKDIR /home/ballerina
COPY --from=build /home/ballerina/src/target/bin/identity_registry_api.jar app.jar
# Demo records; members/run-member-services.sh mounts the repository's copy over it.
COPY mock_data.json ./
USER ballerina
EXPOSE 9090
# PORT and MOCK_API_KEY are read from Config.toml in the working directory.
# members/run-member-services.sh mounts it at /home/ballerina/Config.toml.
ENTRYPOINT ["java", "-XX:+ExitOnOutOfMemoryError", "-jar", "app.jar"]
