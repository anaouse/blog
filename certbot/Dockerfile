# syntax=docker/dockerfile:1

FROM certbot/certbot:latest
COPY certbot/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
