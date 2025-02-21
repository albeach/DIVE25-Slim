FROM alpine:latest

RUN apk add --no-cache openldap-clients curl

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 9330

ENTRYPOINT ["/entrypoint.sh"] 