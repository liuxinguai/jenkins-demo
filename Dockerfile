FROM ascdc/jdk8:latest
#在build镜像时可以通过 --build-args profile=xxx 进行修改
ARG profile
ENV SPRING_PROFILES_ACTIVE=${profile}
#项目的端口
EXPOSE 8080
WORKDIR /mnt

#修改时区
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk add --no-cache tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && apk del tzdata \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* $HOME/.cache

COPY ./target/jenkins-demo-0.0.1-SNAPSHOT.jar ./app.jar
ENTRYPOINT ["java", "-jar", "/mnt/app.jar"]