Guacamole
====

Docker container for Guacamole with embedded MariaDB (MySQL) and LDAP authentication

Guacamole is a clientless remote desktop gateway. It supports standard protocols like VNC and RDP.

---
The Build
===

Build from docker file:

```
git clone git@github.com:lsmithx2/docker-guacamole.git
docker build -t lsmithx2/guacamole .
```

You can also obtain it via:  

```
docker pull lsmithx2/guacamole
```

---
Running
===

Create your guacamole fsguac directory (which will contain both the properties file and the database).

To run using MariaDB for user authentication, launch with the following:

```
docker run -d -v /your-fsguac-location:/fsguac -p 8080:8080 -e OPT_MYSQL=Y lsmithx2/guacamole
```

Browse to ```http://server-ip:8080``` and login with user and password `guacadmin`

