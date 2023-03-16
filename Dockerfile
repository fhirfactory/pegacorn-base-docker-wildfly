FROM fhirfactory/pegacorn-base-docker-java:1.0.0

# Default to UTF-8 file.encoding from https://github.com/woahbase/alpine-wildfly/blob/master/Dockerfile_x86_64
ENV LANG C.UTF-8

# START equivalent of https://github.com/jboss-dockerfiles/wildfly/blob/20.0.1.Final/Dockerfile

# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 24.0.1.Final
ENV WILDFLY_SHA1 751e3ff9128a6fbe72016552a9b864f729a710cc
ENV JBOSS_HOME=${HOME}/wildfly

# Switch back to root
USER root

# Fix for wget: server returned error: HTTP/1.1 500 handshakefailed
RUN apk --no-cache add ca-certificates wget \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place
RUN cd $HOME \
    && wget --no-check-certificate -O wildfly-$WILDFLY_VERSION.tar.gz https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
    && sha1sum wildfly-$WILDFLY_VERSION.tar.gz | grep $WILDFLY_SHA1 \
    && tar xf wildfly-$WILDFLY_VERSION.tar.gz \
    && mv $HOME/wildfly-$WILDFLY_VERSION $JBOSS_HOME \
    && rm wildfly-$WILDFLY_VERSION.tar.gz \
    && chown -R jboss:0 ${HOME} \
    && chmod -R g+rw ${HOME}
# Changing the permissions on $HOME instead of the sub folder $JBOSS_HOME to fix the error "Unable to create index directory: target/lucenefiles"

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

# Switch to jboss user
USER jboss

# Expose the ports we're interested in
EXPOSE 8080

# END equivalent of https://github.com/jboss-dockerfiles/wildfly/blob/20.0.1.Final/Dockerfile

# From https://forums.docker.com/t/how-can-i-view-the-dockerfile-in-an-image/5687/3
# the ConatinerConfig.Cmd in the output of the command > docker inspect wildflyext/wildfly-camel was
# CMD ["/usr/libexec/s2i/run"], but to use the embedded ActiveMQ Artemis and to 
# support jBPM/KIE Server we need to start in full mode as mentioned on:
# https://www.codelikethewind.org/2017/08/08/how-to-embed-a-jbpm-process-in-a-java-ee-application/
# http://www.mastertheboss.com/jboss-jbpm/jbpm6/running-rules-on-wildfly-with-kie-server
# https://github.com/jboss-dockerfiles/drools/blob/master/kie-server/showcase/etc/start_kie-server.sh
# so followed the example of https://github.com/jemella/microbpm-fabric8/blob/master/microbpm-kie-server/src/main/docker/Dockerfile
# and swapped the config files, so if the server is manually restarted from the command line the default
# configuration is for the full-ha mode:
RUN mv $JBOSS_HOME/standalone/configuration/standalone.xml $JBOSS_HOME/standalone/configuration/standalone.xml.orig && \
    cp $JBOSS_HOME/standalone/configuration/standalone-full-ha.xml $JBOSS_HOME/standalone/configuration/standalone.xml

# Copy and run cli to modify the standalone.xml configuration.
COPY cli/ssl-configuration.cli $JBOSS_HOME/bin/ssl-configuration.cli

# After running each command the content of the "$JBOSS_HOME/standalone/configuration/standalone_xml_history/current" directory
# needs to be deleted as each steps expects it to be empty.  Maybe there is another way??
RUN $JBOSS_HOME/bin/jboss-cli.sh --file=$JBOSS_HOME/bin/ssl-configuration.cli && \
    rm -rf $JBOSS_HOME/standalone/configuration/standalone_xml_history/current/*

# Remove vulnerable jars that exist only in Wildfly
# These jars are not in the Aether projects
RUN rm $JBOSS_HOME/modules/system/layers/base/com/fasterxml/jackson/core/jackson-databind/main/jackson-databind-2.12.3.jar
RUN rm $JBOSS_HOME/modules/system/layers/base/org/apache/sshd/main/sshd-core-2.6.0.jar
RUN rm $JBOSS_HOME/modules/system/layers/base/org/apache/santuario/xmlsec/main/xmlsec-2.1.6.jar
RUN rm $JBOSS_HOME/modules/system/layers/base/org/apache/thrift/main/libthrift-0.13.0.jar
RUN rm $JBOSS_HOME/modules/system/layers/base/org/picketlink/common/main/picketlink-common-2.5.5.SP12-redhat-00009.jar
RUN rm $JBOSS_HOME/modules/system/layers/base/org/jsoup/main/jsoup-1.8.3.jar
RUN rm $JBOSS_HOME/modules/system/layers/base/io/jaegertracing/jaeger/main/jaeger-core-1.5.0.jar
RUN rm $JBOSS_HOME/modules/system/layers/base/io/jaegertracing/jaeger/main/jaeger-thrift-1.5.0.jar

# Copy jar versions that are not vulnerable as @ 14/04/2022
COPY jar_files/jackson-databind-2.12.6.1.jar $JBOSS_HOME/modules/system/layers/base/com/fasterxml/jackson/core/jackson-databind/main/jackson-databind-2.12.6.1.jar
COPY jar_files/sshd-core-2.7.0.jar $JBOSS_HOME/modules/system/layers/base/org/apache/sshd/main/sshd-core-2.7.0.jar
COPY jar_files/xmlsec-2.2.3.jar $JBOSS_HOME/modules/system/layers/base/org/apache/santuario/xmlsec/main/xmlsec-2.2.3.jar
COPY jar_files/libthrift-0.14.0.jar $JBOSS_HOME/modules/system/layers/base/org/apache/thrift/main/libthrift-0.14.0.jar
COPY jar_files/picketlink-common-2.6.1.Final.jar $JBOSS_HOME/modules/system/layers/base/org/picketlink/common/main/picketlink-common-2.6.1.Final.jar
COPY jar_files/jsoup-1.14.3.jar $JBOSS_HOME/modules/system/layers/base/org/jsoup/main/jsoup-1.14.3.jar
COPY jar_files/jaeger-core-1.6.0.jar $JBOSS_HOME/modules/system/layers/base/io/jaegertracing/jaeger/main/jaeger-core-1.6.0.jar
COPY jar_files/jaeger-thrift-1.6.0.jar $JBOSS_HOME/modules/system/layers/base/io/jaegertracing/jaeger/main/jaeger-thrift-1.6.0.jar