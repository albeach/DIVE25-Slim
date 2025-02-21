#!/bin/bash
set -e

# Wait for LDAP to be ready
until ldapwhoami -H ldap://localhost -x -D "cn=admin,dc=dive25,dc=local" -w ${LDAP_ADMIN_PASSWORD}; do
  echo "Waiting for LDAP to be ready..."
  sleep 2
done

# Apply initial LDIF
ldapadd -H ldap://localhost -x -D "cn=admin,dc=dive25,dc=local" -w ${LDAP_ADMIN_PASSWORD} -f /container/service/slapd/assets/config/initial.ldif || true 