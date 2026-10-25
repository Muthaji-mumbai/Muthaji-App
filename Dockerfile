# Lightweight production web server for Flutter Web
FROM nginx:alpine

# Copy the pre-built Flutter web bundle
COPY build/web /usr/share/nginx/html

# Copy custom Nginx configuration with Single Page Application (SPA) routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
