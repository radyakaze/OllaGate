FROM openresty/openresty:1.25.3.2-0-alpine

COPY src/ /usr/local/openresty/nginx/conf/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

EXPOSE 80

CMD ["/usr/local/bin/entrypoint.sh"]