#!/usr/bin/env bash

WEBAPOLLO_DB_DATA="/var/lib/postgresql/9.6/main"

if [ ! -e ${WEBAPOLLO_DB_DATA} ]; then
	mkdir -p ${WEBAPOLLO_DB_DATA}
	chown -R postgres:postgres ${WEBAPOLLO_DB_DATA}
fi

if [ ! -e "${WEBAPOLLO_DB_DATA}/PG_VERSION" ];then
	su -c "/usr/lib/postgresql/9.6/bin/initdb -D ${WEBAPOLLO_DB_DATA}" postgres
fi

service postgresql start


WEBAPOLLO_DB_HOST="${WEBAPOLLO_DB_HOST:-127.0.0.1}"
WEBAPOLLO_DB_NAME="${WEBAPOLLO_DB_NAME:-apollo}"
WEBAPOLLO_DB_USERNAME="${WEBAPOLLO_DB_USERNAME:-apollo}"
WEBAPOLLO_DB_PASSWORD="${WEBAPOLLO_DB_PASSWORD:-apollo}"


# TODO: use variable throughout
#USE_CHADO="${USE_CHADO:true}"

CHADO_DB_HOST="${CHADO_DB_HOST:-127.0.0.1}"
CHADO_DB_NAME="${CHADO_DB_NAME:-chado}"
CHADO_DB_USERNAME="${CHADO_DB_USERNAME:-apollo}"
CHADO_DB_PASSWORD="${CHADO_DB_PASSWORD:-apollo}"

if [[ "${WEBAPOLLO_DB_HOST}" != "127.0.0.1" ]]; then
    WEBAPOLLO_HOST_FLAG="-h ${WEBAPOLLO_DB_HOST}"
fi
if [[ "${CHADO_DB_HOST}" != "127.0.0.1" ]]; then
    CHADO_HOST_FLAG="-h ${CHADO_DB_HOST}"
fi

echo "WEBAPOLLO_HOST_FLAG: $WEBAPOLLO_HOST_FLAG"
echo "CHADO_HOST_FLAG: $CHADO_HOST_FLAG"

echo "Waiting for DB"
until pg_isready $WEBAPOLLO_HOST_FLAG; do
	echo -n "."
	sleep 1;
done

echo "Postgres is up, configuring database"

su postgres -c "PGPASSWORD=$WEBAPOLLO_DB_PASSWORD psql $WEBAPOLLO_HOST_FLAG -U $WEBAPOLLO_DB_USERNAME -lqt | cut -d \| -f 1 | grep -qw $WEBAPOLLO_DB_NAME"
if [[ "$?" == "1" ]]; then
	echo "Apollo database not found, creating..."
	su postgres -c "createdb $WEBAPOLLO_HOST_FLAG $WEBAPOLLO_DB_NAME"
	su postgres -c "psql $WEBAPOLLO_HOST_FLAG -c \"CREATE USER $WEBAPOLLO_DB_USERNAME WITH PASSWORD '$WEBAPOLLO_DB_PASSWORD';\""
	su postgres -c "psql $WEBAPOLLO_HOST_FLAG -c \"GRANT ALL PRIVILEGES ON DATABASE $WEBAPOLLO_DB_NAME to $WEBAPOLLO_DB_USERNAME;\""
fi

echo "Configuring Chado"
su postgres -c "PGPASSWORD=$CHADO_DB_PASSWORD psql $CHADO_HOST_FLAG -U $CHADO_DB_USERNAME -lqt | cut -d \| -f 1 | grep -qw $CHADO_DB_NAME"
if [[ "$?" == "1" ]]; then
	echo "Chado database not found, creating..."
	su postgres -c "createdb $CHADO_HOST_FLAG $CHADO_DB_NAME"
	su postgres -c "psql $CHADO_HOST_FLAG -c \"CREATE USER $CHADO_DB_USERNAME WITH PASSWORD '$CHADO_DB_PASSWORD';\""
	su postgres -c "psql $CHADO_HOST_FLAG -c 'GRANT ALL PRIVILEGES ON DATABASE \"$CHADO_DB_NAME\" to $CHADO_DB_USERNAME;'"
	echo "Loading Chado"
	su postgres -c "PGPASSWORD=$CHADO_DB_PASSWORD psql -U $CHADO_DB_USERNAME -h $CHADO_DB_HOST $CHADO_DB_NAME -f /chado.sql"
    echo "Loaded Chado"
fi

# https://tomcat.apache.org/tomcat-8.0-doc/config/context.html#Naming
export CATALINA_HOME="${CATALINA_HOME:-/usr/local/tomcat/}"
FIXED_CTX=$(echo "${CONTEXT_PATH}" | sed 's|/|#|g')
WAR_FILE=${CATALINA_HOME}/webapps/${FIXED_CTX}.war

echo "Restarting tomcat with $CATALINA_HOME"
service tomcat8 restart

cp ${CATALINA_HOME}/apollo.war ${WAR_FILE}

if [[ ! -f "${CATALINA_HOME}/logs/catalina.out" ]]; then
	touch ${CATALINA_HOME}/logs/catalina.out
fi

tail -f ${CATALINA_HOME}/logs/catalina.out 
