FROM openjdk:17.0.2-jdk-slim

ARG JMETER_VERSION=5.5
ARG JMETER_INSTALLATION_PATH="/opt/jmeter/apache-jmeter-${JMETER_VERSION}" 
ARG CURL_OPTS="--connect-timeout 10 --retry 5 --retry-delay 1 --retry-max-time 60" 
ARG JMETER_CMD_RUNNER_PATH="${JMETER_INSTALLATION_PATH}/lib/cmdrunner-2.3.jar" 
ARG JMETER_CMD_RUNNER_URL="http://search.maven.org/remotecontent?filepath=kg/apc/cmdrunner/2.3/cmdrunner-2.3.jar"
ARG JMETER_PLUGIN_URL="https://jmeter-plugins.org/get/" 
ARG JMETER_PLUGIN_PATH="${JMETER_INSTALLATION_PATH}/lib/ext/jmeter-plugins-manager.jar"

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget coreutils unzip bash curl apt-utils

# Adding the package path to local
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

RUN apt-get install -y python3-pip
RUN curl -sSL https://sdk.cloud.google.com > /tmp/gcl && bash /tmp/gcl --install-dir=~/gcloud --disable-prompts
# Downloading gcloud package
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz

# Installing the package
RUN mkdir -p /usr/local/gcloud \
  && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
  && /usr/local/gcloud/google-cloud-sdk/install.sh


# Installing jmeter clean and link
RUN mkdir /opt/jmeter && \
    cd /opt/jmeter && \
    wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz && \
    tar --extract --gzip --file apache-jmeter-${JMETER_VERSION}.tgz && \
    rm apache-jmeter-${JMETER_VERSION}.tgz && \
    rm --recursive --force /var/cache/apk/* && \
    rm --recursive --force  ${JMETER_INSTALLATION_PATH}/docs

RUN ln --symbolic ${JMETER_INSTALLATION_PATH} /opt/jmeter/apache-jmeter && \
    ln --symbolic /proc/1/fd/1 ${JMETER_INSTALLATION_PATH}/bin/jmeter-master.out && \
    ln --symbolic /proc/1/fd/1 ${JMETER_INSTALLATION_PATH}/bin/jmeter-master.err && \
    ln --symbolic /proc/1/fd/1 ${JMETER_INSTALLATION_PATH}/bin/jmeter-injector.out && \
    ln --symbolic /proc/1/fd/1 ${JMETER_INSTALLATION_PATH}/bin/jmeter-injector.err && \
    ln --symbolic /proc/1/fd/1 ${JMETER_INSTALLATION_PATH}/bin/jmeter.log && \
    ln --symbolic /proc/1/fd/1 ${JMETER_INSTALLATION_PATH}/bin/jmeter-server.log && \
    echo "client.tries=3" >> ${JMETER_INSTALLATION_PATH}/bin/jmeter.properties && \
    echo "client.retries_delay=20" >> ${JMETER_INSTALLATION_PATH}/bin/jmeter.properties

# Install Plugin cmd runner and jmeter plugin
RUN curl ${CURL_OPTS} --location --output "${JMETER_PLUGIN_PATH}" "${JMETER_PLUGIN_URL}"  && \
    curl ${CURL_OPTS} --location --output "${JMETER_CMD_RUNNER_PATH}" "${JMETER_CMD_RUNNER_URL}" && \
    java -classpath "${JMETER_PLUGIN_PATH}" org.jmeterplugins.repository.PluginManagerCMDInstaller 

RUN curl ${CURL_OPTS} --location --output "${JMETER_INSTALLATION_PATH}/lib/jolokia-java-agent.jar"  "https://repo1.maven.org/maven2/org/jolokia/jolokia-jvm/1.7.2/jolokia-jvm-1.7.2.jar"
                                                                                                     
## Setting users &&  directory and right
RUN mkdir /report &&  \
    addgroup jmeter && \
    adduser --disabled-password --gecos '' --home /jmeter --ingroup jmeter jmeter && \
    chown --recursive jmeter:jmeter /opt/jmeter && \
    chown --recursive jmeter:jmeter /report

ENV JMETER_HOME ${JMETER_INSTALLATION_PATH}
ENV PATH $JMETER_HOME/bin:$PATH

# Uncomment required lines below to add JMeter plugins for spcecific jmeter scripts if needed. 
# Provide the PATH to the the jmx scritps 
# 
RUN mkdir /home/scenarios
RUN chown -R jmeter /opt/jmeter/apache-jmeter/
RUN chown -R jmeter /home/scenarios/
     
# just for dummy test      
ADD ./scenarios/dummy-gke-jmeter-tests/dummy-test/dummy-test.jmx  /home/scenarios/dummy-test.jmx
RUN java  -jar ${JMETER_INSTALLATION_PATH}/lib/cmdrunner-2.3.jar --tool org.jmeterplugins.repository.PluginManagerCMD install-for-jmx /home/scenarios/dummy-test.jmx

# uncomment and modify to plugins to the JMeter image  
#ADD ./scenarios/<category-of-tests>/<test-name>/<test-name>.jmx  /home/scenarios/<test-name>.jmx
#RUN java  -jar ${JMETER_INSTALLATION_PATH}/lib/cmdrunner-2.3.jar --tool org.jmeterplugins.repository.PluginManagerCMD install-for-jmx /home/scenarios/<test-name>.jmx

# uncomment and modify to plugins to the JMeter image test-name-1
#ADD ./scenarios/<category-of-tests>/<test-name-1>/<test-name-1>.jmx  /home/scenarios/<test-name-1>.jmx
#RUN java  -jar ${JMETER_INSTALLATION_PATH}/lib/cmdrunner-2.3.jar --tool org.jmeterplugins.repository.PluginManagerCMD install-for-jmx /home/scenarios/<test-name-1>.jmx


ADD jmeter-lib/PluginsManagerCMD.sh /opt/jmeter/apache-jmeter/bin/
RUN chmod -R ug+rwx /opt/jmeter/apache-jmeter/bin/PluginsManagerCMD.sh
RUN chmod -R a+rw /tmp/

ENV CLASSPATH $CLASSPATH:/opt/jmeter/apache-jmeter/lib
RUN mkdir /opt/jmeter/apache-jmeter/bin/report
RUN chown jmeter /opt/jmeter/apache-jmeter/bin/report
RUN chgrp jmeter /opt/jmeter/apache-jmeter/bin/report

RUN chmod -R  a+rw /opt/jmeter/apache-jmeter/

# Add no-split files and certificate for PreProd
# uncomment to add certificate file and reference to certificate file defiend in the jmeter system.properties.  
#ADD ./scenarios/common-files/<certificate-file>.jks    /opt/jmeter/apache-jmeter/bin/
#ADD ./scenarios/common-files/system.properties  /opt/jmeter/apache-jmeter/bin/
ADD ./scenarios/common-no-split-dataset/*.csv   /opt/jmeter/apache-jmeter/bin/

USER jmeter