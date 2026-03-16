# Сборка приложения
FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /app

COPY . .

# Сборка frontend и копирование в static
RUN apt-get update && apt-get install -y --no-install-recommends nodejs npm \
    && rm -rf /var/lib/apt/lists/*
RUN cd frontend && npm ci && npm run build
RUN mkdir -p src/main/resources/static && cp -r frontend/dist/* src/main/resources/static/

# Даём права на gradlew под Linux
RUN chmod +x ./gradlew

# Собираем JAR с тестами
RUN ./gradlew clean test bootJar --no-daemon


# Финальный образ — только JRE, без JDK
FROM eclipse-temurin:21-jre-jammy AS runtime
WORKDIR /app

# Профиль по умолчанию — dev с H2
ENV SPRING_PROFILES_ACTIVE=dev

COPY --from=build /app/build/libs/project-devops-deploy-0.0.1-SNAPSHOT.jar /app/app.jar

EXPOSE 8080 9090

# Поддержка JAVA_OPTS из переменных окружения
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
