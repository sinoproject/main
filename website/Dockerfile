FROM busybox
COPY src /www
CMD ["httpd", "-f", "-p", "80", "-h", "/www"]
EXPOSE 80

