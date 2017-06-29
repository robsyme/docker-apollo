#!/usr/bin/env bash
service postgresql start 



#!/bin/bash
until pg_isready; do
	echo -n "."
	sleep 1;
done

echo "Postgres is up, loading chado"

if [[ "${WEBAPOLLO_DB_HOST}" == "" ]]; then
	WEBAPOLLO_DB_HOST=127.0.0.1
fi
if [[ "${WEBAPOLLO_DB_NAME}" == "" ]]; then
	WEBAPOLLO_DB_NAME=apollo
fi
if [[ "${WEBAPOLLO_DB_USERNAME}" == "" ]]; then
	WEBAPOLLO_DB_USERNAME=apollo
fi
if [[ "${WEBAPOLLO_DB_PASSWORD}" == "" ]]; then
	WEBAPOLLO_DB_PASSWORD=apollo
fi
WEBAPOLLO_HOST_FLAG="-h ${WEBAPOLLO_DB_HOST}"


if [[ "${CHADO_DB_HOST}" == "" ]]; then
	CHADO_DB_HOST=127.0.0.1
fi
if [[ "${CHADO_DB_NAME}" == "" ]]; then
	CHADO_DB_NAME=chado
fi
if [[ "${CHADO_DB_USERNAME}" == "" ]]; then
	CHADO_DB_USERNAME=apollo
fi
if [[ "${CHADO_DB_PASSWORD}" == "" ]]; then
	CHADO_DB_PASSWORD=apollo
fi
CHADO_HOST_FLAG="-h ${CHADO_DB_HOST}"

su postgres -c 'psql -f /apollo/user.sql'

su postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw $WEBAPOLLO_DB_NAME"
if [[ "$?" == "1" ]]; then
	echo "Apollo database not found, creating..."
	su postgres -c "createdb $WEBAPOLLO_HOST_FLAG $WEBAPOLLO_DB_NAME"
	su postgres -c "psql $WEBAPOLLO_HOST_FLAG -c \"CREATE USER $WEBAPOLLO_DB_USERNAME WITH PASSWORD '$WEBAPOLLO_DB_PASSWORD';\""
	su postgres -c "psql $WEBAPOLLO_HOST_FLAG -c 'GRANT ALL PRIVILEGES ON DATABASE \"$WEBAPOLLO_DB_NAME\" to $WEBAPOLLO_DB_USERNAME;'"
fi

su postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw $CHADO_DB_NAME"
if [[ "$?" == "1" ]]; then
	echo "Chado database not found, creating..."
    su postgres -c "createdb $CHADO_DB_NAME"
	su postgres -c "createdb $CHADO_HOST_FLAG $CHADO_DB_NAME"
	su postgres -c "psql $CHADO_HOST_FLAG -c \"CREATE USER $CHADO_DB_USERNAME WITH PASSWORD '$CHADO_DB_PASSWORD';\""
	su postgres -c "psql $CHADO_HOST_FLAG -c 'GRANT ALL PRIVILEGES ON DATABASE \"$CHADO_DB_NAME\" to $CHADO_DB_USERNAME;'"
	su postgres -c "PGPASSWORD=apollo psql -U $CHADO_DB_USERNAME -h ${CHADO_DB_HOST} $CHADO_DB_NAME -f /chado.sql"
fi


# https://tomcat.apache.org/tomcat-8.0-doc/config/context.html#Naming
export CATALINA_HOME=/usr/local/tomcat/
FIXED_CTX=$(echo "${CONTEXT_PATH}" | sed 's|/|#|g')
WAR_FILE=${CATALINA_HOME}/webapps/${FIXED_CTX}.war

echo "Starting tomcat with $CATALINA_HOME"
$CATALINA_HOME/bin/shutdown.sh
$CATALINA_HOME/bin/startup.sh

cp ${CATALINA_HOME}/apollo.war ${WAR_FILE}

if [[ ! -f "${CATALINA_HOME}/logs/catalina.out" ]]; then
	touch ${CATALINA_HOME}/logs/catalina.out
fi

tail -f ${CATALINA_HOME}/logs/catalina.out 
