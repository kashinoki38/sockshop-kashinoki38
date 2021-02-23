FROM openjdk:8-jre-slim AS jmeter-env
ARG JMETER_VERSION=4.0
RUN apt-get clean && \
apt-get update && \
apt-get -qy install \
wget \
telnet \
iputils-ping \
unzip \
git
RUN   mkdir /jmeter \
&& cd /jmeter/ \
&& wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-$JMETER_VERSION.tgz \
&& tar -xzf apache-jmeter-$JMETER_VERSION.tgz \
&& rm apache-jmeter-$JMETER_VERSION.tgz

# RUN WRK_VERSION=4.0.2 && \
# cd /tmp && git clone -b ${WRK_VERSION} https://github.com/wg/wrk
# RUN cd /tmp/wrk && make

FROM weaveworks/flagger-loadtester:0.18.0 AS flagger-env


FROM openjdk:8-jre-slim 
# USER root
COPY --from=jmeter-env /usr/local/openjdk-8/ /usr/local/openjdk-8/
RUN   mkdir /jmeter
COPY --from=jmeter-env /jmeter /jmeter
# USER app
#### flagger loadtester config
RUN groupadd --system app && \
adduser --system -group app && \
apt-get clean && \
apt-get update && \
apt-get -qy install \
ca-certificates curl jq libgcc-8-dev wget



RUN chown -R app:app /usr/local/openjdk-8
RUN chown -R app:app /jmeter

WORKDIR /home/app

COPY --from=flagger-env /opt/bats/ /opt/bats/
RUN ln -s /opt/bats/bin/bats /usr/local/bin/

COPY --from=flagger-env /usr/local/bin/hey /usr/local/bin/
# COPY --from=jmeter-env /tmp/wrk/wrk /usr/local/bin/
COPY --from=flagger-env /usr/local/bin/helm /usr/local/bin/
COPY --from=flagger-env /usr/local/bin/tiller /usr/local/bin/
COPY --from=flagger-env /usr/local/bin/ghz /usr/local/bin/
COPY --from=flagger-env /usr/local/bin/helmv3 /usr/local/bin/
COPY --from=flagger-env /usr/local/bin/grpc_health_probe /usr/local/bin/
COPY --from=flagger-env /tmp/helm-tiller /tmp/helm-tiller
COPY --from=flagger-env /home/app/loadtester .
ADD https://raw.githubusercontent.com/grpc/grpc-proto/master/grpc/health/v1/health.proto /tmp/ghz/health.proto

RUN chown -R app:app ./
RUN chown -R app:app /tmp/ghz

USER app

ENV JAVA_HOME /usr/local/openjdk-8
ENV JAVA_VERSION 8u282
ENV JMETER_HOME /jmeter/apache-jmeter-$JMETER_VERSION/
ENV PATH $JMETER_HOME/bin:$PATH

# test load generator tools
RUN hey -n 1 -c 1 https://flagger.app > /dev/null && echo $? | grep 0
# RUN wrk -d 1s -c 1 -t 1 https://flagger.app > /dev/null && echo $? | grep 0

# install Helm v2 plugins
# RUN helm init --client-only && helm plugin install /tmp/helm-tiller

ENTRYPOINT ["./loadtester"]
####


