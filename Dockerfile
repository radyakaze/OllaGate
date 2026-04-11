FROM openresty/openresty:alpine

COPY src/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY config.lua /app/config.lua
COPY src/proxy.lua /usr/local/openresty/nginx/conf/proxy.lua

EXPOSE 80

CMD ["openresty", "-g", "daemon off;"]
