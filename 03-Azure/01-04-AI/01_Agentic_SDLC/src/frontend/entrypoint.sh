#!/bin/sh

# Debug: Print the initial values received from the environment
echo "Initial API_HOST: $API_HOST"
echo "Initial API_PORT: $API_PORT"
echo "Intial API_PROTOCOL: $API_PROTOCOL"

# Use environment variables provided by App Service, otherwise use defaults
# The ':=' syntax assigns the default value if the variable is unset or null.
EFFECTIVE_API_HOST=${API_HOST:=api}
EFFECTIVE_API_PORT=${API_PORT:=3000}
EFFECTIVE_API_PROTOCOL=${API_PROTOCOL:=https}

# Check for Azure App Settings format (APPSETTING_API_HOST)
if [ ! -z "$APPSETTING_API_HOST" ]; then
  echo "Found APPSETTING_API_HOST: $APPSETTING_API_HOST"
  EFFECTIVE_API_HOST=$APPSETTING_API_HOST
fi

if [ ! -z "$APPSETTING_API_PORT" ]; then
  echo "Found APPSETTING_API_PORT: $APPSETTING_API_PORT"
  EFFECTIVE_API_PORT=$APPSETTING_API_PORT
fi

if [ ! -z "$APPSETTING_API_PROTOCOL" ]; then
  echo "Found APPSETTING_API_PROTOCOL: $APPSETTING_API_PROTOCOL"
  EFFECTIVE_API_PROTOCOL=$APPSETTING_API_PROTOCOL
fi

echo "Using API_HOST: $EFFECTIVE_API_HOST"
echo "Using API_PORT: $EFFECTIVE_API_PORT"
echo "Using API_PROTOCOL: $EFFECTIVE_API_PROTOCOL"

# Export the effective variables so envsubst can use them
export API_HOST=$EFFECTIVE_API_HOST
export API_PORT=$EFFECTIVE_API_PORT
export API_PROTOCOL=$EFFECTIVE_API_PROTOCOL

# Create runtime config JS file with the current API URL
# Default ports: 80,443
PORT_SECTION=""
if [ "$EFFECTIVE_API_PORT" != "80" ] && [ "$EFFECTIVE_API_PORT" != "443" ]; then
  PORT_SECTION=":${EFFECTIVE_API_PORT}"
fi

cat > /usr/share/nginx/html/runtime-config.js << EOF
window.RUNTIME_CONFIG = {
  API_URL: "${API_PROTOCOL}://${API_HOST}${PORT_SECTION}"
};
console.log("Runtime config loaded:", window.RUNTIME_CONFIG);
EOF

# Debug: Show the generated runtime config
echo "Generated runtime config:"
cat /usr/share/nginx/html/runtime-config.js
echo ""

# Start nginx
echo "Starting nginx..."
exec nginx -g "daemon off;"