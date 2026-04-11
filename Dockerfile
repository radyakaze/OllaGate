FROM openresty/openresty:alpine

COPY src/ /usr/local/openresty/nginx/conf/

EXPOSE 80

CMD ["openresty", "-g", "daemon off;"]
