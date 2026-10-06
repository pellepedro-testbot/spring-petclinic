# Multi-stage build of spring-petclinic FROM SOURCE using the repo's own Maven wrapper,
# so the image always runs the code of the checked-out PR. Build context = repo root.
FROM eclipse-temurin:17-jdk AS build
WORKDIR /src
COPY . .
RUN ./mvnw -B -q -DskipTests package \
 && cp target/spring-petclinic-*.jar /app.jar

FROM eclipse-temurin:17-jre
COPY --from=build /app.jar /app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]
