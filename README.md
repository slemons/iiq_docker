Sailpoint Identity IQ Dockerized
================================
# Prerequisites

IdentityIQ 8.0 has been provided in the src directory. The database creation scripts have been modified to work with MariaDB.
Do not upload this container outside of PwC.

# Description
Oracle JDK 8 and Tomcat 8 based docker container.
Inspired by dodorka/tomcat 
            steffensperling/sailpoint-iiq


Includes:

 - Oracle JDK 1.8
 - Tomcat 8.5
 - mariadb database
 
## Docker
Get started with docker for Windows here: https://docs.docker.com/engine/installation/windows/

## Ports
Two ports are exposed:

 - 8080: default Tomcat port.
 - 8009: default Tomcat debug port.
 - 3306: default MySQL port.


# How to run the container

## Using docker compose
Build with:
```
From a PowerShell or Command Prompt as Administrator

docker-compose build
```
Please do not upload this docker container to a public docker registry: Sailpoint IIQ is closed source and not publicly available.

```
docker-compose up

Note: The first time you execute the command, it will take a few minutes to complete as it initializes identityiq
```

# Usage
## Login
Go to http://localhost:8080/identityiq. 
User: spadmin
Password: admin

## A warning regarding admin user for tomcat management console
Please note that the image contains a `tomcat-users.xml` file, including an `admin` user (password `admin`). For the time being, should you wish to change that, fork this repo and modify the xml file accordingly.


MySQL
User: root
Password: password

User: identityiq
Password: identityiq

## Pusing IIQ image to Azure Container Registry

Push

az login
az acr login --name gxzu2appscr005

If the above command fails, 
	az acr check-health -n gxzu2appscr005 --yes
This may thrown an error
	ValidationError: An error occurred: CONNECTIVITY_SSL_ERROR
If so
	$Env:AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1
And run the command again.
Once the check-health command is successful, run the acr login command again.

docker tag iiq_iiq gxzu2appscr005.azurecr.io/iiq
docker push gxzu2appscr005.azurecr.io/iiq

