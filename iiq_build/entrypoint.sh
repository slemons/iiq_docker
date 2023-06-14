#!/bin/bash

#check environment variables and set some defaults
if [ -z "${MYSQL_HOST}" ]
then
	export MYSQL_HOST=db
fi
if [ -z "${MYSQL_USER}" ]
then
	export MYSQL_USER=identityiq
fi
if [ -z "${MYSQL_PASSWORD}" ]
then
	export MYSQL_PASSWORD=identityiq
fi

#wait for database to start
echo "waiting for database on ${MYSQL_HOST} to come up"
while ! mysqladmin ping -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent ; do
	echo -ne "."
	sleep 1
done


#check if database schema is already there
export DB_SCHEMA_VERSION=$(mysql -s -N -hdb -uroot -p${MYSQL_ROOT_PASSWORD} -e "select schema_version from identityiq.spt_database_version;")
if [ -z "$DB_SCHEMA_VERSION" ]
then
	echo "No schema present, creating IIQ schema in DB" 
	/opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq schema

	# create database schema
	#mysql -uroot -p${MYSQL_ROOT_PASSWORD} -hdb < /opt/tomcat/webapps/identityiq/WEB-INF/database/create_identityiq_tables-${IIQ_VERSION}.mysql
	sed -ri -e "s/WITH mysql_native_password//" /opt/tomcat/webapps/identityiq/WEB-INF/database/create_identityiq_tables.mysql
	mysql -uroot -p${MYSQL_ROOT_PASSWORD} -hdb < /opt/tomcat/webapps/identityiq/WEB-INF/database/create_identityiq_tables.mysql
	echo "=> Done creating database!"

else
	echo "=> Database already set up, version "$DB_SCHEMA_VERSION" found, starting IIQ directly";
fi

# set database host in properties
sed -ri -e "s/mysql:\/\/localhost/mysql:\/\/${MYSQL_HOST}/" /opt/tomcat/webapps/identityiq/WEB-INF/classes/iiq.properties
sed -ri -e "s/dataSource.username\=.*/dataSource.username=${MYSQL_USER}/" /opt/tomcat/webapps/identityiq/WEB-INF/classes/iiq.properties
sed -ri -e "s/dataSource.password\=.*/dataSource.password=${MYSQL_PASSWORD}/" /opt/tomcat/webapps/identityiq/WEB-INF/classes/iiq.properties
echo "=> Done configuring iiq.properties!"
export DB_SPADMIN_PRESENT=$(mysql -s -N -hdb -uroot -p${MYSQL_ROOT_PASSWORD} -e "select name from identityiq.spt_identity where name='spadmin';")

if [ -z $DB_SPADMIN_PRESENT ]
then
	echo "No spadmin user in database, setting up database connection in iiq.properties and importing init.xml, init-lcm.xml and sp.init-custom.xml"
	
	echo "import init.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	echo "import init-lcm.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	[ -f /opt/tomcat/webapps/identityiq/WEB-INF/config/sp.init-custom.xml ] &&  \
		echo "import sp.init-custom.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	echo "import Workflow-Importer.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	echo "=> Done loading init.xml via iiq console!"
	echo "Applying patch $IIQ_PATCH_VERSION"
	/opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq patch $IIQ_PATCH_VERSION
	echo "Done applying patch $IIQ_PATCH_VERSION"
fi

#wait for the directory server to start
echo "waiting for directory server to come up"
while ! ldapsearch -x -LLL -D "cn=Directory Manager" -w password -H ldap://ldap:1389 -s sub -b dc=example,dc=com > /dev/null 2>&1; 
do
	echo -ne "."
	sleep 1
done

# check if the DIT is already in ldap
export LDAP_DIT=$(ldapsearch -x -LLL -D "cn=Directory Manager" -w password -H ldap://ldap:1389 -s sub -b dc=example,dc=com '(ou=People)' ou;)
if [ -z "$LDAP_DIT" ] 
then
	echo "No DIT present, importing LDIF"
	ldapadd -c -x -D "cn=Directory Manager" -w password -H ldap://ldap:1389 -f /tmp/data.ldif
else
	echo "=> DIT already imported"
fi



export DB_IDENTITIES_EXIST=$(mysql -s -N -hdb -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'identities'";)
if [ -z "$DB_IDENTITIES_EXIST" ]
then
	echo "No identities database exists, create database and populating tables"
	mysql -uroot -p${MYSQL_ROOT_PASSWORD} -hdb < /tmp/data.sql

else
	echo "=> Database already set up, version "$DB_IDENTITIES_EXIST" found, skipping...."; 
fi

/opt/tomcat/bin/catalina.sh run

