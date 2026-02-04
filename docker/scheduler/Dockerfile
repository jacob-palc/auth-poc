#
# BUILD STAGE
#
FROM maven:3.6.0-jdk-11-slim AS build
COPY src /usr/src/app/src
COPY pom.xml /usr/src/app
COPY libraries/netconf-java.zip /usr/src/app
#COPY netconf-java /usr/src/app/netconf-java
RUN unzip /usr/src/app/netconf-java.zip -d /usr/src/app && \
    rm /usr/src/app/netconf-java.zip
WORKDIR /usr/src/app/
RUN mvn install:install-file -Dfile=/usr/src/app/netconf-java/target/netconf-java-2.1.1.7.jar -DgroupId=net.juniper.netconf -DartifactId=netconf-java -Dversion=2.1.1.7 -Dpackaging=jar
#RUN mvn clean install
RUN mvn -f /usr/src/app/pom.xml clean package -DskipTests
 
#
# PACKAGE STAGE
#
FROM openjdk:11
COPY --from=build /usr/src/app/target/scheduler-0.0.1-SNAPSHOT.jar /usr/app/scheduler-0.0.1-SNAPSHOT.jar
EXPOSE 8082:8082
CMD ["java","-jar","/usr/app/scheduler-0.0.1-SNAPSHOT.jar"]
