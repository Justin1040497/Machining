FROM node:22-alpine AS admin-web
WORKDIR /app/admin-web
COPY admin-web/package.json ./
RUN npm install --no-audit --no-fund
COPY admin-web ./
RUN npm run build:prod

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY . .
COPY --from=admin-web /app/admin-web/dist ./ruoyi-admin/src/main/resources/static
RUN mvn -Pprod -pl ruoyi-admin -am clean package -DskipTests -B

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/ruoyi-admin/target/ruoyi-admin.jar app.jar
EXPOSE 4918
ENTRYPOINT ["java", "-jar", "app.jar"]
