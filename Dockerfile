# WebApollo
# VERSION 2.0
FROM tomcat:8-jre8
MAINTAINER Eric Rasche <esr@tamu.edu>, Anthony Bretaudeau <anthony.bretaudeau@inria.fr>, Nathan Dunn <nathandunn@lbl.gov>
ENV DEBIAN_FRONTEND noninteractive 

RUN apt-get -qq update --fix-missing && \
	apt-get --no-install-recommends -y install \
	git build-essential maven tomcat8 libpq-dev postgresql-common openjdk-8-jdk wget \
	xmlstarlet netcat libpng-dev \
	zlib1g-dev libexpat1-dev ant curl ssl-cert zip unzip

RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get -qq update --fix-missing && \
	apt-get --no-install-recommends -y install nodejs && \
	apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN npm i -g yarn

RUN cp /usr/lib/jvm/java-8-openjdk-amd64/lib/tools.jar /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/ext/tools.jar && \
	useradd -ms /bin/bash -d /apollo apollo

ENV WEBAPOLLO_VERSION 37b4063baeaf24021445ca581701f230b3b5df41
RUN curl -L https://github.com/GMOD/Apollo/archive/${WEBAPOLLO_VERSION}.tar.gz | tar xzf - --strip-components=1 -C /apollo

# install grails
COPY build.sh /bin/build.sh
ADD apollo-config.groovy /apollo/apollo-config.groovy

RUN chown -R apollo:apollo /apollo
RUN curl -s "http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/blat/blat" -o /usr/local/bin/blat
RUN chmod +x /usr/local/bin/blat

USER apollo
RUN curl -s get.sdkman.io | bash
RUN /bin/bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && yes | sdk install grails 2.5.5"
RUN /bin/bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && yes | sdk install gradle 3.2.1"


RUN /bin/bash -c "source $HOME/.profile && source $HOME/.sdkman/bin/sdkman-init.sh && /bin/bash /bin/build.sh"

USER root
ENV CATALINA_HOME=/usr/local/tomcat/
RUN rm -rf ${CATALINA_HOME}/webapps/* && \
	cp /apollo/apollo*.war ${CATALINA_HOME}/apollo.war

ENV CONTEXT_PATH ROOT

ADD launch.sh /launch.sh
CMD "/launch.sh"



