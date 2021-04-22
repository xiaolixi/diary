# docker build -t tomlixi:1.0.0 --build-arg APP=tomlixi .
FROM jdk:8

ARG APP=app

RUN mkidr -p /opt/${APP} && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo 'Asia/Shanghai' >/etc/timezone

WORKDIR /opt/${APP}

EXPOSE 8080

COPY ./*.jar /opt/${APP}/${APP}.jar

CMD java ${JAVA_OPTS} -jar ${APP}.jar
