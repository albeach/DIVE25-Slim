#!/bin/sh

while true; do
    # Check LDAP connectivity
    ldapsearch -x -H ldap://openldap:389 \
        -D "cn=admin,dc=dive25,dc=local" \
        -w "${LDAP_ADMIN_PASSWORD}" \
        -b "dc=dive25,dc=local" \
        -s base > /dev/null 2>&1
    
    LDAP_STATUS=$?

    # Create metrics output
    echo "# HELP ldap_up LDAP server up/down status" > /tmp/metrics
    echo "# TYPE ldap_up gauge" >> /tmp/metrics
    echo "ldap_up ${LDAP_STATUS}" >> /tmp/metrics

    # Serve metrics
    nc -l -p 9330 < /tmp/metrics

    sleep 15
done 