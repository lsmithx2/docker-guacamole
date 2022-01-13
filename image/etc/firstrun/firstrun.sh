#!/bin/bash

EXT_STORE="/opt/guacamole"
GUAC_EXT="/fsguac/guacamole/extensions"
TOMCAT_LOG="/fsguac/log/tomcat9"
CHANGES=false

# Create user
PUID=${PUID:-99}
PGID=${PGID:-100}

groupmod -o -g "$PGID" fsguac
usermod -o -u "$PUID" fsguac

echo "----------------------"
echo "User UID: $(id -u fsguac)"
echo "User GID: $(id -g fsguac)"
echo "----------------------"

chown -R fsguac:fsguac /fsguac
chown -R fsguac:fsguac /var/run/tomcat /var/lib/tomcat9 /usr/share/tomcat9 /etc/tomcat9
chown fsguac:fsguac /var/run/tomcat

OPTMYSQL=${OPT_MYSQL:-N}

# Check if properties file exists. If not, copy in the starter database
if [ -f /fsguac/guacamole/guacamole.properties ]; then
  echo "Using existing properties file."
  if [ ! -d "$TOMCAT_LOG" ]; then
    echo "Creating log directory."
    mkdir -p "$TOMCAT_LOG"
    chown -R fsguac:fsguac "$TOMCAT_LOG"
  fi
else
  echo "Creating properties from template."
  mkdir -p "$GUAC_EXT" /fsguac/guacamole/lib "$TOMCAT_LOG"
  cp /etc/firstrun/templates/* /fsguac/guacamole
  chown -R fsguac:fsguac /fsguac/guacamole "$TOMCAT_LOG"
  if [ "$OPTMYSQL" = "Y" ] && [ -f /etc/firstrun/mariadb.sh ]; then
    echo "Creating Database folders"
    mkdir -p /fsguac/databases
    chown fsguac:fsguac /fsguac/databases
  fi
  PW=$(pwgen -1snc 32)
  sed -i -e 's/some_password/'$PW'/g' /fsguac/guacamole/guacamole.properties
  CHANGES=true
fi

# Check if extensions files exists. Copy or upgrade if necessary.
OPTMYSQLEXT=${OPT_MYSQL_EXTENSION:-N}
if [ "$OPTMYSQL" = "Y" ] || [ "$OPTMYSQLEXT" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*jdbc-mysql*.jar ]; then
    oldMysqlFiles=( "$GUAC_EXT"/*jdbc-mysql*.jar )
    newMysqlFiles=( "$EXT_STORE"/mysql/*jdbc-mysql*.jar )

    if diff ${oldMysqlFiles[0]} ${newMysqlFiles[0]} >/dev/null ; then
      echo "Using existing MySQL extension."
      if [ ! -d /fsguac/mysql-schema ]; then
        mkdir /fsguac/mysql-schema
        cp -R /root/mysql/* /fsguac/mysql-schema
        CHANGES=true
      fi
    else
      echo "Upgrading MySQL extension."
      rm "$GUAC_EXT"/*jdbc-mysql*.jar
      cd /fsguac/guacamole/lib
      rm mysql-connector*.jar
      cp "$EXT_STORE"/mysql/*jdbc-mysql*.jar "$GUAC_EXT"
      cp "$EXT_STORE"/mysql/mysql-connector* /fsguac/guacamole/lib
      rm -R /fsguac/mysql-schema/*
      cp -R "$EXT_STORE"/mysql/schema/* /fsguac/mysql-schema
      CHANGES=true
    fi
  else
    echo "Copying MySQL extension."
    cp "$EXT_STORE"/mysql/*jdbc-mysql*.jar "$GUAC_EXT"
    cp "$EXT_STORE"/mysql/mysql-connector* /fsguac/guacamole/lib
    mkdir /fsguac/mysql-schema
    cp -R "$EXT_STORE"/mysql/schema/* /fsguac/mysql-schema
    CHANGES=true
  fi
elif [ "$OPTMYSQL" = "N" ] || [ "$OPTMYSQLEXT" = "N" ]; then
  if [ -f "$GUAC_EXT"/*jdbc-mysql*.jar ]; then
    echo "Removing MySQL extension."
    rm "$GUAC_EXT"/*jdbc-mysql*.jar
    cd /fsguac/guacamole/lib
    rm mysql-connector*.jar
    rm -R /fsguac/mysql-schema
  fi
fi

OPTSQLSERVER=${OPT_SQLSERVER:-N}
if [ "$OPTSQLSERVER" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*sqlserver*.jar ]; then
    oldSqlServerFiles=( "$GUAC_EXT"/*sqlserver*.jar )
    newSqlServerFiles=( "$EXT_STORE"/sqlserver/*sqlserver*.jar )

    if diff ${oldSqlServerFiles[0]} ${newSqlServerFiles[0]} >/dev/null ; then
    	echo "Using existing SQL Server extension."
    else
    	echo "Upgrading SQL Server extension."
    	rm "$GUAC_EXT"/*sqlserver*.jar
    	cp "$EXT_STORE"/sqlserver/*sqlserver*.jar "$GUAC_EXT"
      rm -R /fsguac/sqlserver-schema/*
      cp -R "$EXT_STORE"/sqlserver/schema/* /fsguac/sqlserver-schema
      CHANGES=true
    fi
  else
    echo "Copying SQL Server extension."
    cp "$EXT_STORE"/sqlserver/*sqlserver*.jar "$GUAC_EXT"
    mkdir /fsguac/sqlserver-schema
    cp -R "$EXT_STORE"/sqlserver/schema/* /fsguac/sqlserver-schema
    CHANGES=true
  fi
elif [ "$OPTSQLSERVER" = "N" ]; then
  if [ -f "$GUAC_EXT"/*sqlserver*.jar ]; then
    echo "Removing SQL Server extension."
    rm "$GUAC_EXT"/*sqlserver*.jar
    rm -R /fsguac/sqlserver-schema
  fi
fi

OPTLDAP=${OPT_LDAP:-N}
if [ "$OPTLDAP" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*ldap*.jar ]; then
    oldLDAPFiles=( "$GUAC_EXT"/*ldap*.jar )
    newLDAPFiles=( "$EXT_STORE"/ldap/*ldap*.jar )

    if diff ${oldLDAPFiles[0]} ${newLDAPFiles[0]} >/dev/null ; then
    	echo "Using existing LDAP extension."
    else
    	echo "Upgrading LDAP extension."
    	rm "$GUAC_EXT"/*ldap*.jar
    	rm -R /fsguac/ldap-schema/*
    	cp "$EXT_STORE"/ldap/*ldap*.jar "$GUAC_EXT"
    	cp -R "$EXT_STORE"/ldap/*.ldif /fsguac/ldap-schema
      CHANGES=true
    fi
  else
    echo "Copying LDAP extension."
    cp "$EXT_STORE"/ldap/*ldap*.jar "$GUAC_EXT"
    mkdir /fsguac/ldap-schema
    cp -R "$EXT_STORE"/ldap/*.ldif /fsguac/ldap-schema
    CHANGES=true
  fi
elif [ "$OPTLDAP" = "N" ]; then
  if [ -f "$GUAC_EXT"/*ldap*.jar ]; then
    echo "Removing LDAP extension."
    rm "$GUAC_EXT"/*ldap*.jar
    rm -R /fsguac/ldap-schema
  fi
fi

OPTDUO=${OPT_DUO:-N}
if [ "$OPTDUO" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*duo*.jar ]; then
    oldDuoFiles=( "$GUAC_EXT"/*duo*.jar )
    newDuoFiles=( "$EXT_STORE"/duo/*duo*.jar )

    if diff ${oldDuoFiles[0]} ${newDuoFiles[0]} >/dev/null ; then
      echo "Using existing Duo extension."
    else
      echo "Upgrading Duo extension."
      rm "$GUAC_EXT"/*duo*.jar
      cp "$EXT_STORE"/duo/*duo*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying Duo extension."
    cp "$EXT_STORE"/duo/*duo*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTDUO" = "N" ]; then
  if [ -f "$GUAC_EXT"/*duo*.jar ]; then
    echo "Removing Duo extension."
    rm "$GUAC_EXT"/*duo*.jar
  fi
fi

OPTCAS=${OPT_CAS:-N}
if [ "$OPTCAS" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*cas*.jar ]; then
    oldCasFiles=( "$GUAC_EXT"/*cas*.jar )
    newCasFiles=( "$EXT_STORE"/cas/*cas*.jar )

    if diff ${oldCasFiles[0]} ${newCasFiles[0]} >/dev/null ; then
      echo "Using existing CAS extension."
    else
      echo "Upgrading CAS extension."
      rm "$GUAC_EXT"/*cas*.jar
      cp "$EXT_STORE"/cas/*cas*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying CAS extension."
    cp "$EXT_STORE"/cas/*cas*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTCAS" = "N" ]; then
  if [ -f "$GUAC_EXT"/*cas*.jar ]; then
    echo "Removing CAS extension."
    rm "$GUAC_EXT"/*cas*.jar
  fi
fi

OPTOPENID=${OPT_OPENID:-N}
if [ "$OPTOPENID" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*openid*.jar ]; then
    oldOpenidFiles=( "$GUAC_EXT"/*openid*.jar )
    newOpenidFiles=( "$EXT_STORE"/openid/*openid*.jar )

    if diff ${oldOpenidFiles[0]} ${newOpenidFiles[0]} >/dev/null ; then
      echo "Using existing OpenID extension."
    else
      echo "Upgrading OpenID extension."
      rm "$GUAC_EXT"/*openid*.jar
      find ${EXT_STORE}/openid/ -name "*.jar" | awk -F/ '{print $NF}' | xargs -I '{}' cp "${EXT_STORE}/openid/{}" "${GUAC_EXT}/1-{}"
      CHANGES=true
    fi
  else
    echo "Copying OpenID extension."
    find ${EXT_STORE}/openid/ -name "*.jar" | awk -F/ '{print $NF}' | xargs -I '{}' cp "${EXT_STORE}/openid/{}" "${GUAC_EXT}/1-{}"
    CHANGES=true
  fi
elif [ "$OPTOPENID" = "N" ]; then
  if [ -f "$GUAC_EXT"/*openid*.jar ]; then
    echo "Removing OpenID extension."
    rm "$GUAC_EXT"/*openid*.jar
  fi
fi

OPTTOTP=${OPT_TOTP:-N}
if [ "$OPTTOTP" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*totp*.jar ]; then
    oldTotpFiles=( "$GUAC_EXT"/*totp*.jar )
    newTotpFiles=( "$EXT_STORE"/totp/*totp*.jar )

    if diff ${oldTotpFiles[0]} ${newTotpFiles[0]} >/dev/null ; then
      echo "Using existing TOTP extension."
    else
      echo "Upgrading TOTP extension."
      rm "$GUAC_EXT"/*totp*.jar
      cp "$EXT_STORE"/totp/*totp*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying TOTP extension."
    cp "$EXT_STORE"/totp/*totp*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTTOTP" = "N" ]; then
  if [ -f "$GUAC_EXT"/*totp*.jar ]; then
    echo "Removing TOTP extension."
    rm "$GUAC_EXT"/*totp*.jar
  fi
fi

OPTQUICKCONNECT=${OPT_QUICKCONNECT:-N}
if [ "$OPTQUICKCONNECT" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*quickconnect*.jar ]; then
    oldQCFiles=( "$GUAC_EXT"/*quickconnect*.jar )
    newQCFiles=( "$EXT_STORE"/quickconnect/*quickconnect*.jar )

    if diff ${oldQCFiles[0]} ${newQCFiles[0]} >/dev/null ; then
      echo "Using existing Quick Connect extension."
    else
      echo "Upgrading Quick Connect extension."
      rm "$GUAC_EXT"/*quickconnect*.jar
      cp "$EXT_STORE"/quickconnect/*quickconnect*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying Quick Connect extension."
    cp "$EXT_STORE"/quickconnect/*quickconnect*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTQUICKCONNECT" = "N" ]; then
  if [ -f "$GUAC_EXT"/*quickconnect*.jar ]; then
    echo "Removing Quick Connect extension."
    rm "$GUAC_EXT"/*quickconnect*.jar
  fi
fi

OPTHEADER=${OPT_HEADER:-N}
if [ "$OPTHEADER" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*header*.jar ]; then
    oldQCFiles=( "$GUAC_EXT"/*header*.jar )
    newQCFiles=( "$EXT_STORE"/header/*header*.jar )

    if diff ${oldQCFiles[0]} ${newQCFiles[0]} >/dev/null ; then
      echo "Using existing Header extension."
    else
      echo "Upgrading Header extension."
      rm "$GUAC_EXT"/*header*.jar
      cp "$EXT_STORE"/header/*header*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying Header extension."
    cp "$EXT_STORE"/header/*header*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTHEADER" = "N" ]; then
  if [ -f "$GUAC_EXT"/*header*.jar ]; then
    echo "Removing Header extension."
    rm "$GUAC_EXT"/*header*.jar
  fi
fi

OPTSAML=${OPT_SAML:-N}
if [ "$OPTSAML" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*saml*.jar ]; then
    oldQCFiles=( "$GUAC_EXT"/*saml*.jar )
    newQCFiles=( "$EXT_STORE"/saml/*saml*.jar )

    if diff ${oldQCFiles[0]} ${newQCFiles[0]} >/dev/null ; then
      echo "Using existing SAML extension."
    else
      echo "Upgrading SAML extension."
      rm "$GUAC_EXT"/*saml*.jar
      cp "$EXT_STORE"/saml/*saml*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying SAML extension."
    cp "$EXT_STORE"/saml/*saml*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTSAML" = "N" ]; then
  if [ -f "$GUAC_EXT"/*saml*.jar ]; then
    echo "Removing SAML extension."
    rm "$GUAC_EXT"/*saml*.jar
  fi
fi

if [ "$CHANGES" = true ]; then
  echo "Updating user permissions."
  chown fsguac:fsguac -R /fsguac/guacamole
  chmod 755 -R /fsguac/guacamole
else
  echo "No permissions changes needed."
fi

# exec /bin/tini -s -- /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf

if [ "$OPTMYSQL" = "Y" ] && [ -f /etc/firstrun/mariadb.sh ]; then
  /etc/firstrun/mariadb.sh
  exec /bin/tini -s -- /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord-mariadb.conf
else
  exec /bin/tini -s -- /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
fi
