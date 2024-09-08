# Use the official Nginx base image
FROM nginx:latest

# Copy the static site files to the container
COPY src /usr/share/nginx/html

# Config Nginx website for Vue app
RUN echo 'server { listen 80 default_server; root /usr/share/nginx/html; autoindex off; location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf

# Expose port 80 for incoming traffic
EXPOSE 80

# The main command to run when the container starts
CMD ["nginx", "-g", "daemon off;"]

