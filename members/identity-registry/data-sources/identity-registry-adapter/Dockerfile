# Builds the Identity Registry Adapter, the GraphQL service the Orchestration
# Engine queries. The Ballerina jar is platform independent, so it is compiled
# once on the build machine's platform and copied into each target platform's
# Java runtime image.
ARG BALLERINA_VERSION=2201.13.1

FROM --platform=$BUILDPLATFORM ballerina/ballerina:${BALLERINA_VERSION} AS build
WORKDIR /home/ballerina/src
COPY --chown=ballerina:troupe Ballerina.toml Dependencies.toml main.bal types.bal ./
# --sticky builds with the exact versions in Dependencies.toml instead of
# moving to the newest patch releases.
RUN bal build --sticky

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S ballerina && adduser -S -G ballerina -h /home/ballerina ballerina
WORKDIR /home/ballerina
COPY --from=build /home/ballerina/src/target/bin/identity_registry_adapter.jar app.jar
USER ballerina
EXPOSE 9091
# Config.toml is left out on purpose: its serviceURL is localhost, which inside
# a container is the container itself. members/run-member-services.sh sets the
# Identity Registry API's URL and key with BAL_CONFIG_VAR_SERVICEURL and
# BAL_CONFIG_VAR_CHOREOAPIKEY.
ENTRYPOINT ["java", "-XX:+ExitOnOutOfMemoryError", "-jar", "app.jar"]
