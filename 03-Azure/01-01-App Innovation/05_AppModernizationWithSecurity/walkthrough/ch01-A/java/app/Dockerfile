FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml ./
COPY src/ src/
RUN mvn -B -ntp -Dmaven.test.skip=true package

FROM eclipse-temurin:21-jre-jammy AS runtime
RUN groupadd --gid 10001 catalog \
    && useradd --uid 10001 --gid catalog --create-home catalog
WORKDIR /app
COPY --from=build --chown=catalog:catalog /workspace/target/catalog-java-1.0.0.jar app.jar
ENV SERVER_PORT=8080 \
    CATALOG_SEED_PATH=/data/catalog.json \
    CATALOG_IMAGES_PATH=/data/images
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
