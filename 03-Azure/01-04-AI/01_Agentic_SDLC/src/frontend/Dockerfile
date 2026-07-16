FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist/ /usr/share/nginx/html/
COPY --from=builder /app/public/* /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh

# Set proper permissions for the nginx html directory and entrypoint script
RUN chmod -R 755 /usr/share/nginx/html && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chmod +x /entrypoint.sh

# Set default environment variables
ENV API_HOST=api
ENV API_PORT=3000

EXPOSE 80

# Use ENTRYPOINT instead of CMD for better handling in App Service
ENTRYPOINT ["/entrypoint.sh"]
