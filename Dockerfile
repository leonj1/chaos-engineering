FROM nginx:alpine

# Create custom index.html with region information
RUN echo '<!DOCTYPE html>' > /usr/share/nginx/html/index.html && \
    echo '<html>' >> /usr/share/nginx/html/index.html && \
    echo '<head><title>Hello from Nginx</title></head>' >> /usr/share/nginx/html/index.html && \
    echo '<body>' >> /usr/share/nginx/html/index.html && \
    echo '<h1>Hello World from Nginx!</h1>' >> /usr/share/nginx/html/index.html && \
    echo '<p>Container ID: <span id="container-id"></span></p>' >> /usr/share/nginx/html/index.html && \
    echo '<p>Region: <span id="region">REGION_PLACEHOLDER</span></p>' >> /usr/share/nginx/html/index.html && \
    echo '<script>' >> /usr/share/nginx/html/index.html && \
    echo 'document.getElementById("container-id").textContent = window.location.hostname;' >> /usr/share/nginx/html/index.html && \
    echo '</script>' >> /usr/share/nginx/html/index.html && \
    echo '</body>' >> /usr/share/nginx/html/index.html && \
    echo '</html>' >> /usr/share/nginx/html/index.html

# Add health check endpoint
RUN echo 'OK' > /usr/share/nginx/html/health

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]