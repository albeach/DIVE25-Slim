#!/bin/bash
set -e

# Wait for LDAP to be ready
until ldapsearch -x -H ldap://localhost -D "cn=admin,dc=dive25,dc=local" -w $LDAP_ADMIN_PASSWORD -b "dc=dive25,dc=local" &>/dev/null; do
    echo "Waiting for LDAP to be ready..."
    sleep 2
done

# Add NATO schema
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/nato.ldif

# Add base structure
ldapadd -x -H ldap://localhost -D "cn=admin,dc=dive25,dc=local" -w $LDAP_ADMIN_PASSWORD -f /bootstrap/structure.ldif

# Add sample users
ldapadd -x -H ldap://localhost -D "cn=admin,dc=dive25,dc=local" -w $LDAP_ADMIN_PASSWORD -f /bootstrap/users.ldif