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

	# Edit hiberate file for mysql.  Create schema files
	if [ -f /opt/tomcat/pwcid/iiq-web-1.0.0-webapp-files.zip ]
	then
		/usr/bin/unzip -oq /opt/tomcat/pwcid/iiq-web-1.0.0-webapp-files.zip -d /opt/tomcat/webapps/identityiq
		sed  -ri -e 's/length="450"/length="250"/'  /opt/tomcat/webapps/identityiq/WEB-INF/classes/sailpoint/object/IdentityExtended.hbm.xml
	fi
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
	
	# Extract xml config files.  Remove files not applicable to local instance
	if [ -f /opt/tomcat/pwcid/iiq-xml-config-1.0.0-config-files.zip ]
	then
		/usr/bin/unzip -oq /opt/tomcat/pwcid/iiq-xml-config-1.0.0-config-files.zip -d /opt/tomcat/webapps/identityiq/WEB-INF/config
		
		# Replace encrypted values with "Test"
		sed -i 's:\"[0-9]\:.*\"/>$:"Test"/>:' /opt/tomcat/webapps/identityiq/WEB-INF/config/custom/Application/*.xml
		
		# Some files don't/shouldn't be imported into a local instance
		rm /opt/tomcat/webapps/identityiq/WEB-INF/config/custom/TaskSchedule/*.xml
		rm /opt/tomcat/webapps/identityiq/WEB-INF/config/custom/Server/*.xml
		rm /opt/tomcat/webapps/identityiq/WEB-INF/config/custom/ServiceDefinition/SSB_PluginImporterService.xml
		rm /opt/tomcat/webapps/identityiq/WEB-INF/config/custom/Configuration/Configuration-SystemConfig-PasswordResetEntry.xml

		sed -ri -e "/custom\/TaskSchedule/d" /opt/tomcat/webapps/identityiq/WEB-INF/config/sp.init-custom.xml
		sed -ri -e "/custom\/Server/d" /opt/tomcat/webapps/identityiq/WEB-INF/config/sp.init-custom.xml
		sed -ri -e "/custom\/ServiceDefinition\/SSB_PluginImporterService/d" /opt/tomcat/webapps/identityiq/WEB-INF/config/sp.init-custom.xml
		sed -ri -e "/custom\/Configuration\/Configuration-SystemConfig-PasswordResetEntry/d" /opt/tomcat/webapps/identityiq/WEB-INF/config/sp.init-custom.xml
	fi

	echo "import init.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	echo "import init-lcm.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	[ -f /opt/tomcat/webapps/identityiq/WEB-INF/config/sp.init-custom.xml ] &&  \
		echo "import sp.init-custom.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	echo "import Workflow-Importer.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
	echo "=> Done loading init.xml via iiq console!"
	echo "Applying patch $IIQ_PATCH_VERSION"
	/opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq patch $IIQ_PATCH_VERSION
	echo "Done applying patch $IIQ_PATCH_VERSION"
else
	# Extract xml config files. Diff files and import only changes. Remove files not applicable to local instance
	if [ -f /opt/tomcat/pwcid/iiq-xml-config-1.0.0-config-files.zip ]
	then
		/usr/bin/unzip -oq /opt/tomcat/pwcid/iiq-xml-config-1.0.0-config-files.zip -d /tmp
		rm /tmp/custom/TaskSchedule/*.xml
		rm /tmp/custom/Server/*.xml
		rm /tmp/custom/ServiceDefinition/SSB_PluginImporterService.xml
		rm /tmp/custom/Configuration/Configuration-SystemConfig-PasswordResetEntry.xml
		# Replace encrypted values with "Test"
		sed -i 's:\"[0-9]\:.*\"/>$:"Test"/>:' /tmp/custom/Application/*.xml		

		export DELTA_CUSTOM_FILE=/opt/tomcat/webapps/identityiq/WEB-INF/config/sp.delta-custom.xml

		echo "<?xml version='1.0' encoding='UTF-8'?><!DOCTYPE sailpoint PUBLIC 'sailpoint.dtd' 'sailpoint.dtd'><sailpoint>" > $DELTA_CUSTOM_FILE

		diff -qr  /tmp/custom/ \
		/opt/tomcat/webapps/identityiq/WEB-INF/config/custom/ | \
		grep -v 'Only in /opt/tomcat/' | \
		sed "s/Files \([\_ a-zA-Z0-9\/\.\-]*\) and .*/  <ImportAction name='include' value='\\1'\/>/" | \
		sed "s/Only in \(\/tmp\/custom\/[a-zA-Z0-9]*\): \([\_ a-zA-Z0-9\/\.\-]*\)/  <ImportAction name='include' value='\\1\\/\\2'\/>/" \
		>> $DELTA_CUSTOM_FILE

		echo "</sailpoint>" >> $DELTA_CUSTOM_FILE

		cat $DELTA_CUSTOM_FILE
		
		if [ `wc -l $DELTA_CUSTOM_FILE | cut -d ' ' -f 1` -gt 2 ]
		then
			echo "import sp.delta-custom.xml" | /opt/tomcat/webapps/identityiq/WEB-INF/bin/iiq console
			cp -r /tmp/custom /opt/tomcat/webapps/identityiq/WEB-INF/config/
		fi

		# Clean up
		rm -rf /tmp/custom
		rm $DELTA_CUSTOM_FILE
	fi
fi
/opt/tomcat/bin/catalina.sh run

