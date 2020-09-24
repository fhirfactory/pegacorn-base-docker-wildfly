FROM aethercontainerregistry.azurecr.io/pegacorn-base-docker-java:1.0.0-snapshot

# Default to UTF-8 file.encoding from https://github.com/woahbase/alpine-wildfly/blob/master/Dockerfile_x86_64
ENV LANG C.UTF-8

# START equivalent of https://github.com/jboss-dockerfiles/wildfly/blob/20.0.1.Final/Dockerfile

# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 20.0.1.Final
ENV WILDFLY_SHA1 95366b4a0c8f2e6e74e3e4000a98371046c83eeb
ENV JBOSS_HOME /opt/jboss/wildfly

# Switch back to root
USER root

# curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz
COPY wildfly-20.0.1.Final.tar.gz /opt/jboss

# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place
RUN cd $HOME \
    && sha1sum wildfly-$WILDFLY_VERSION.tar.gz | grep $WILDFLY_SHA1 \
    && tar xf wildfly-$WILDFLY_VERSION.tar.gz \
    && mv $HOME/wildfly-$WILDFLY_VERSION $JBOSS_HOME \
    && rm wildfly-$WILDFLY_VERSION.tar.gz \
    && chown -R jboss:0 ${JBOSS_HOME} \
    && chmod -R g+rw ${JBOSS_HOME}

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

