FROM tomcat:9.0.52-jdk8-adoptopenjdk-hotspot

ENV TOMCAT_VERSION 8.5.29
ENV IIQ_VERSION 8.1
ENV IIQ_PATCH_VERSION=8.1p3

# Fix sh
# RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install dependencies
RUN apt-get update && \
apt-get install -y apt-utils wget unzip tar mysql-client

# Define commonly used JAVA_HOME variable
# ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# Move the default image location to the one this is expecting
RUN mv /usr/local/tomcat /opt/tomcat

# Add debug page to ui
RUN echo 'JAVA_OPTS="$JAVA_OPTS -Dsailpoint.debugPages=true"' > /opt/tomcat/bin/setenv.sh

# Add admin/admin user
#ADD tomcat-users.xml /opt/tomcat/conf/
#run mkdir -p /opt/tomcat/conf/Catalina/localhost
#ADD manager.xml /opt/tomcat/conf/Catalina/localhost

# add IIQ
COPY src/identityiq.war /tmp
RUN mkdir /opt/tomcat/webapps/identityiq && \
unzip /tmp/identityiq.war -d /opt/tomcat/webapps/identityiq && \
chmod +x /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq && \
rm /tmp/identityiq.war

# add PATCH
COPY src/identityiq-${IIQ_PATCH_VERSION}.jar /tmp
RUN unzip -qo -d /opt/tomcat/webapps/identityiq /tmp/identityiq-${IIQ_PATCH_VERSION}.jar 

COPY index.html /opt/tomcat/webapps/ROOT

COPY Workflow-Importer.xml /opt/tomcat/webapps/identityiq/WEB-INF/config

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV CATALINA_HOME /opt/tomcat
ENV PATH $PATH:$CATALINA_HOME/bin

EXPOSE 8080
EXPOSE 8009
#VOLUME "/opt/tomcat/webapps/identityiq/"
VOLUME "/opt/tomcat/logs"
WORKDIR /opt/tomcat

# Launch IIQ
CMD ["/entrypoint.sh", "run"]
#CMD ["/opt/tomcat/bin/catalina.sh", "run"]
