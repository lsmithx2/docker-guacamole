#!/bin/bash

GUAC_VER="1.0.0"

MYSQL_SCHEMA=/opt/guacamole/mysql/schema
MYSQL_DATABASE=/fsguac/databases

sed -i -e 's#\(datadir.*=\).*#\1 /fsguac/databases#g' /etc/mysql/my.cnf
sed -i -e 's#\(bind-address.*=\).*#\1 127.0.0.1#g' /etc/mysql/my.cnf
sed -i -e '/log_warnings.*=.*/a log_error = /fsguac/databases/mysql_safe.log' /etc/mysql/my.cnf
sed -i -e 's/\(user.*=\).*/\1 nobody/g' /etc/mysql/my.cnf
echo '[mysqld]' > /etc/mysql/conf.d/innodb_file_per_table.cnf
echo 'innodb_file_per_table' >> /etc/mysql/conf.d/innodb_file_per_table.cnf
mkdir -p /var/run/mysqld
chown -R abc:abc /var/log/mysql /var/run/mysqld
chmod -R 777 /var/log/mysql /var/run/mysqld

start_mysql() {
  echo "Starting MariaDB...."
  /usr/bin/mysqld_safe > /dev/null 2>&1 &
  RET=1
  while [[ RET -ne 0 ]]; do
      mysql -uroot -e "status" > /dev/null 2>&1
      RET=$?
      sleep 1
  done
}

stop_mysqld() {
  echo "Stopping MariaDB...."
  mysqladmin -u root shutdown
  sleep 3
}

upgrade_database() {
  local UPG_VER="$1"
  start_mysql
  echo "Upgrading database pre-$UPG_VER...."
  echo "$GUAC_VER" > "$MYSQL_DATABASE"/guacamole/version
  mysql -uroot guacamole < ${MYSQL_SCHEMA}/upgrade/upgrade-pre-${UPG_VER}.sql
  stop_mysqld
  echo "Upgrade complete."
}

# If databases do not exist, create them
if [ -f "$MYSQL_DATABASE"/guacamole/guacamole_user.ibd ]; then
  echo "Database exists."
  if [ -f "$MYSQL_DATABASE"/guacamole/version ]; then
    OLD_GUAC_VER=$(cat $MYSQL_DATABASE/guacamole/version)
    IFS="."
    read -ra OLD_SPLIT <<< "$OLD_GUAC_VER"
    read -ra NEW_SPLIT <<< "$GUAC_VER"
    IFS=" "
    if (( NEW_SPLIT[2] > OLD_SPLIT[2] )) || (( NEW_SPLIT[1] > OLD_SPLIT[1] )) || (( NEW_SPLIT[0] > OLD_SPLIT[0] )); then
      echo "Database being upgraded."
      case $OLD_GUAC_VER in
      "0.9.13")
        upgrade_database "0.9.14"
        upgrade_database "1.0.0"
        ;;
      "0.9.14")
        upgrade_database "1.0.0"
        ;;
      esac
    elif (( OLD_SPLIT[2] > NEW_SPLIT[2] )) || (( OLD_SPLIT[1] > NEW_SPLIT[1] )) || (( OLD_SPLIT[0] > NEW_SPLIT[0] )); then
      echo "Database newer revision, no change needed."
      # revert 1.1.0 back to 1.0.0 to match database version rather than actual version since there have been no changes.
      echo "$GUAC_VER" > "$MYSQL_DATABASE"/guacamole/version
    else
      echo "Database upgrade not needed."
    fi
  else
    echo "Database being upgraded...."
    upgrade_database "0.9.13"
    upgrade_database "0.9.14"
    upgrade_database "1.0.0"
  fi
else
  if [ -f /fsguac/guacamole/guacamole.properties ]; then
    echo "Initializing Guacamole database."
    /usr/bin/mysql_install_db --datadir="$MYSQL_DATABASE" >/dev/null 2>&1
    echo "Database installation complete."
    start_mysql
    echo "Creating Guacamole database...."
    mysql -uroot -e "CREATE DATABASE guacamole"
    echo "Creating Guacamole database user...."
    PW=$(cat /fsguac/guacamole/guacamole.properties | grep -m 1 "mysql-password:\s" | sed 's/mysql-password:\s//')
    mysql -uroot -e "CREATE USER 'guacamole'@'localhost' IDENTIFIED BY '$PW'"
    echo "Database created. Granting access to 'guacamole' user for localhost."
    mysql -uroot -e "GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole.* TO 'guacamole'@'localhost'"
    mysql -uroot -e "FLUSH PRIVILEGES"
    echo "Creating Guacamole database schema and default admin user."
    mysql -uroot guacamole < ${MYSQL_SCHEMA}/001-create-schema.sql
    mysql -uroot guacamole < ${MYSQL_SCHEMA}/002-create-admin-user.sql
    echo "$GUAC_VER" > "$MYSQL_DATABASE"/guacamole/version
    stop_mysqld
    echo "Setting database permissions"
    chown -R abc:abc /fsguac/databases
    chmod -R 755 /fsguac/databases
    echo "Removing mysql-server logrotate directive"
    rm /etc/logrotate.d/mysql-server
    sleep 3
    echo "Initialization complete."
  else
    echo "Error! Unable to create database. guacamole.properties file does not exist."
    echo "If you get any error messages while you are installing this please put a post on the Docker Help Forum at https://www.fibreserv.net/forum/ "
  fi
fi
