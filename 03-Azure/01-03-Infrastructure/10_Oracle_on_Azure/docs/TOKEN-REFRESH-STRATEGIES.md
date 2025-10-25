# Token Refresh Strategies for Entra ID Authentication

## Overview

OAuth2 tokens from Entra ID typically expire after **60-90 minutes**. For production scenarios, you need an automated token refresh mechanism to maintain continuous database connectivity.

---

## Recommended Approaches

### ⭐ **Option 1: Sidecar Container with Token Refresh (RECOMMENDED for Production)**

Deploy a sidecar container in your Kubernetes pod that automatically refreshes the token before expiration.

#### Architecture
```
┌─────────────────────────────────────────┐
│           Kubernetes Pod                │
│                                         │
│  ┌──────────────┐   ┌───────────────┐ │
│  │ Application  │   │ Token Refresh │ │
│  │  Container   │   │   Sidecar     │ │
│  │              │   │               │ │
│  │ - Reads      │   │ - Refreshes   │ │
│  │   token      │   │   every 45min │ │
│  │ - Connects   │   │ - Uses MSI    │ │
│  │   to Oracle  │   │ - Writes to   │ │
│  │              │   │   shared vol  │ │
│  └──────────────┘   └───────────────┘ │
│         │                    │          │
│         └────────┬───────────┘          │
│                  │                      │
│         ┌────────▼────────┐            │
│         │  Shared Volume  │            │
│         │  /tmp/wallet/   │            │
│         │  token.txt      │            │
│         └─────────────────┘            │
└─────────────────────────────────────────┘
```

#### Implementation

**1. Create Token Refresh Script:**

```bash
#!/bin/bash
# refresh-token.sh
# Automatically refreshes Entra ID token using Azure Managed Identity

TENANT_ID="f71980b2-590a-4de9-90d5-6fbc867da951"
CLIENT_ID="7d22ece1-dd60-4279-a911-4b7b95934f2e"
SCOPE="https://cptazure.org/${CLIENT_ID}/.default"
TOKEN_FILE="/tmp/wallet/token.txt"
REFRESH_INTERVAL=2700  # 45 minutes (before 60-minute expiry)

while true; do
    echo "$(date): Refreshing token..."
    
    # Get token using Managed Identity
    TOKEN=$(curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=${SCOPE}" \
         -H "Metadata: true" \
         | jq -r .access_token)
    
    if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
        echo -n "$TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo "$(date): Token refreshed successfully"
    else
        echo "$(date): ERROR - Failed to refresh token"
    fi
    
    sleep $REFRESH_INTERVAL
done
```

**2. Create Sidecar Container Image:**

```dockerfile
# Dockerfile.token-refresh
FROM mcr.microsoft.com/azure-cli:latest

# Install jq for JSON parsing
RUN apk add --no-cache jq curl bash

# Copy refresh script
COPY refresh-token.sh /usr/local/bin/refresh-token.sh
RUN chmod +x /usr/local/bin/refresh-token.sh

# Run the refresh loop
CMD ["/usr/local/bin/refresh-token.sh"]
```

**3. Update Kubernetes Deployment:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oracle-client
  namespace: microhacks
spec:
  template:
    spec:
      serviceAccountName: oracle-client-sa  # With Azure Workload Identity
      containers:
      # Main application container
      - name: app
        image: your-oracle-client:latest
        volumeMounts:
        - name: wallet
          mountPath: /tmp/wallet
        env:
        - name: TNS_ADMIN
          value: "/tmp/wallet"
        - name: ORACLE_HOME
          value: "/opt/oracle/instantclient_23_4"
        - name: LD_LIBRARY_PATH
          value: "/opt/oracle/instantclient_23_4"
      
      # Token refresh sidecar
      - name: token-refresh
        image: your-registry/token-refresh:latest
        volumeMounts:
        - name: wallet
          mountPath: /tmp/wallet
        env:
        - name: AZURE_CLIENT_ID
          value: "7d22ece1-dd60-4279-a911-4b7b95934f2e"
        - name: AZURE_TENANT_ID
          value: "f71980b2-590a-4de9-90d5-6fbc867da951"
      
      volumes:
      - name: wallet
        emptyDir: {}
```

**4. Setup Azure Workload Identity:**

```bash
# Create Azure Managed Identity
az identity create \
  --name oracle-token-refresh \
  --resource-group odaa \
  --location germanywestcentral

# Get identity details
IDENTITY_CLIENT_ID=$(az identity show --name oracle-token-refresh --resource-group odaa --query clientId -o tsv)
IDENTITY_ID=$(az identity show --name oracle-token-refresh --resource-group odaa --query id -o tsv)

# Grant permissions to get tokens for the app registration
az ad app permission grant \
  --id 7d22ece1-dd60-4279-a911-4b7b95934f2e \
  --api 7d22ece1-dd60-4279-a911-4b7b95934f2e \
  --scope session:scope:connect

# Setup Workload Identity Federation
az identity federated-credential create \
  --name oracle-aks-federated \
  --identity-name oracle-token-refresh \
  --resource-group odaa \
  --issuer $(az aks show -n odaa -g odaa --query "oidcIssuerProfile.issuerUrl" -o tsv) \
  --subject "system:serviceaccount:microhacks:oracle-client-sa"

# Create Kubernetes Service Account
kubectl create serviceaccount oracle-client-sa -n microhacks
kubectl annotate serviceaccount oracle-client-sa -n microhacks \
  azure.workload.identity/client-id=$IDENTITY_CLIENT_ID
```

---

### ⭐ **Option 2: CronJob-based Token Refresh (Simpler, Good for Testing)**

Use Kubernetes CronJob to refresh the token periodically.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: refresh-oracle-token
  namespace: microhacks
spec:
  schedule: "*/45 * * * *"  # Every 45 minutes
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: oracle-client-sa
          containers:
          - name: token-refresh
            image: mcr.microsoft.com/azure-cli:latest
            command:
            - /bin/bash
            - -c
            - |
              # Get token
              TOKEN=$(az account get-access-token \
                --scope "https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e/.default" \
                --query accessToken -o tsv)
              
              # Update ConfigMap with new token
              kubectl create configmap oracle-token \
                --from-literal=token=$TOKEN \
                --dry-run=client -o yaml | kubectl apply -f -
              
              # Restart pods to pick up new token
              kubectl rollout restart deployment/oracle-client -n microhacks
          restartPolicy: OnFailure
```

Then mount the token from ConfigMap:

```yaml
volumes:
- name: token
  configMap:
    name: oracle-token
```

---

### ⭐ **Option 3: Application-Level Token Refresh (Best for Custom Apps)**

Implement token refresh logic directly in your application.

#### Python Example with Connection Pool

```python
# oracle_entraid_client.py
import os
import time
import subprocess
import threading
from datetime import datetime, timedelta
import oracledb

class EntraIDTokenManager:
    def __init__(self, tenant_id, client_id, scope, token_file):
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.scope = scope
        self.token_file = token_file
        self.token_expiry = None
        self.refresh_thread = None
        self.running = False
        
    def get_token(self):
        """Get new token from Entra ID using Azure CLI or Managed Identity"""
        try:
            # Try Managed Identity first
            import requests
            response = requests.get(
                "http://169.254.169.254/metadata/identity/oauth2/token",
                params={
                    "api-version": "2018-02-01",
                    "resource": self.scope
                },
                headers={"Metadata": "true"},
                timeout=5
            )
            if response.status_code == 200:
                data = response.json()
                return data['access_token'], data['expires_on']
        except:
            pass
        
        # Fallback to Azure CLI
        result = subprocess.run([
            'az', 'account', 'get-access-token',
            '--scope', self.scope,
            '--query', 'accessToken',
            '-o', 'tsv'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            token = result.stdout.strip()
            # Default expiry: 60 minutes
            expiry = int(time.time()) + 3600
            return token, expiry
        
        raise Exception("Failed to get token")
    
    def refresh_token(self):
        """Refresh token and write to file"""
        token, expiry = self.get_token()
        
        # Write token to file (single line, no newline)
        with open(self.token_file, 'w') as f:
            f.write(token)
        
        os.chmod(self.token_file, 0o600)
        self.token_expiry = datetime.fromtimestamp(int(expiry))
        
        print(f"Token refreshed. Expires at: {self.token_expiry}")
    
    def start_refresh_loop(self):
        """Start background thread to refresh token"""
        self.running = True
        self.refresh_thread = threading.Thread(target=self._refresh_loop, daemon=True)
        self.refresh_thread.start()
    
    def _refresh_loop(self):
        """Background loop to refresh token before expiry"""
        while self.running:
            try:
                # Refresh token
                self.refresh_token()
                
                # Calculate next refresh time (5 minutes before expiry)
                if self.token_expiry:
                    time_until_expiry = (self.token_expiry - datetime.now()).total_seconds()
                    sleep_time = max(60, time_until_expiry - 300)  # 5 min buffer
                else:
                    sleep_time = 2700  # 45 minutes default
                
                print(f"Next token refresh in {sleep_time/60:.1f} minutes")
                time.sleep(sleep_time)
                
            except Exception as e:
                print(f"Error refreshing token: {e}")
                time.sleep(60)  # Retry after 1 minute
    
    def stop(self):
        """Stop refresh loop"""
        self.running = False


class OracleEntraIDConnection:
    def __init__(self, dsn, token_manager):
        self.dsn = dsn
        self.token_manager = token_manager
        self.pool = None
    
    def create_pool(self, min_connections=2, max_connections=10):
        """Create connection pool"""
        # Set TNS_ADMIN for wallet location
        os.environ['TNS_ADMIN'] = '/tmp/wallet'
        
        # Create connection pool with external authentication
        self.pool = oracledb.create_pool(
            dsn=self.dsn,
            min=min_connections,
            max=max_connections,
            externalauth=True  # Use external authentication (token)
        )
        
        print(f"Connection pool created: {min_connections}-{max_connections} connections")
        return self.pool
    
    def get_connection(self):
        """Get connection from pool"""
        if not self.pool:
            raise Exception("Pool not created. Call create_pool() first.")
        return self.pool.acquire()


# Usage Example
if __name__ == "__main__":
    # Configuration
    TENANT_ID = "f71980b2-590a-4de9-90d5-6fbc867da951"
    CLIENT_ID = "7d22ece1-dd60-4279-a911-4b7b95934f2e"
    SCOPE = f"https://cptazure.org/{CLIENT_ID}/.default"
    TOKEN_FILE = "/tmp/wallet/token.txt"
    DSN = "adbger_high"
    
    # Initialize token manager
    token_mgr = EntraIDTokenManager(TENANT_ID, CLIENT_ID, SCOPE, TOKEN_FILE)
    
    # Get initial token
    token_mgr.refresh_token()
    
    # Start automatic refresh
    token_mgr.start_refresh_loop()
    
    # Create Oracle connection
    oracle_conn = OracleEntraIDConnection(DSN, token_mgr)
    pool = oracle_conn.create_pool(min_connections=2, max_connections=10)
    
    # Use connection
    try:
        conn = oracle_conn.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT USER, SYS_CONTEXT('USERENV', 'AUTHENTICATION_METHOD') FROM DUAL")
        result = cursor.fetchone()
        print(f"Connected as: {result[0]}, Auth method: {result[1]}")
        cursor.close()
        conn.close()
    finally:
        token_mgr.stop()
        pool.close()
```

---

### ⭐ **Option 4: Azure Key Vault with Periodic Sync (Enterprise)**

Store and automatically sync tokens via Azure Key Vault.

```bash
# Store token in Key Vault
az keyvault secret set \
  --vault-name your-keyvault \
  --name oracle-entraid-token \
  --value "$TOKEN"

# Use CSI driver to mount as volume
# The CSI driver can be configured to sync every X minutes
```

```yaml
apiVersion: v1
kind: SecretProviderClass
metadata:
  name: oracle-token-sync
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    keyvaultName: "your-keyvault"
    objects: |
      array:
        - |
          objectName: oracle-entraid-token
          objectType: secret
          objectVersion: ""
    tenantId: "f71980b2-590a-4de9-90d5-6fbc867da951"
  syncPeriod: "45m"  # Auto-refresh every 45 minutes
```

---

## Comparison Matrix

| Approach | Complexity | Reliability | Use Case | Token Refresh |
|----------|-----------|-------------|----------|---------------|
| **Sidecar Container** | Medium | ⭐⭐⭐⭐⭐ | Production apps in K8s | Automatic (45 min) |
| **CronJob** | Low | ⭐⭐⭐ | Testing, simple deployments | Every 45 min |
| **Application-Level** | Medium-High | ⭐⭐⭐⭐ | Custom applications | Application-controlled |
| **Key Vault + CSI** | High | ⭐⭐⭐⭐⭐ | Enterprise, multi-pod | CSI sync (configurable) |

---

## Quick Implementation for Your Environment

For your current AKS setup, I recommend **Option 1 (Sidecar Container)**. Here's a quick start:

### Step 1: Create the Token Refresh Script

Save this as `misc/refresh-token.sh`:

```bash
#!/bin/bash
set -e

TENANT_ID="${AZURE_TENANT_ID:-f71980b2-590a-4de9-90d5-6fbc867da951}"
CLIENT_ID="${AZURE_CLIENT_ID:-7d22ece1-dd60-4279-a911-4b7b95934f2e}"
SCOPE="https://cptazure.org/${CLIENT_ID}/.default"
TOKEN_FILE="/tmp/wallet/token.txt"
REFRESH_INTERVAL=${REFRESH_INTERVAL:-2700}  # 45 minutes

echo "Starting token refresh service..."
echo "Tenant: $TENANT_ID"
echo "Client: $CLIENT_ID"
echo "Refresh interval: $REFRESH_INTERVAL seconds"

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Refreshing token..."
    
    # Get token using Azure CLI with Managed Identity
    TOKEN=$(az account get-access-token \
        --tenant "$TENANT_ID" \
        --scope "$SCOPE" \
        --query accessToken \
        --output tsv 2>&1)
    
    if [ $? -eq 0 ] && [ -n "$TOKEN" ]; then
        # Write token without newline
        echo -n "$TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): ✅ Token refreshed successfully"
        
        # Decode and show expiry time
        EXP=$(echo "$TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | grep -o '"exp":[0-9]*' | cut -d':' -f2)
        if [ -n "$EXP" ]; then
            EXPIRY_DATE=$(date -d "@$EXP" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Token expires at: $EXPIRY_DATE"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S'): ❌ ERROR - Failed to refresh token: $TOKEN"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Sleeping for $REFRESH_INTERVAL seconds..."
    sleep $REFRESH_INTERVAL
done
```

### Step 2: Build and Push Sidecar Image

```dockerfile
# misc/Dockerfile.token-refresh
FROM mcr.microsoft.com/azure-cli:2.55.0

# Install required tools
RUN apk add --no-cache coreutils bash

# Copy refresh script
COPY refresh-token.sh /usr/local/bin/refresh-token.sh
RUN chmod +x /usr/local/bin/refresh-token.sh

# Health check
HEALTHCHECK --interval=5m --timeout=10s --retries=3 \
  CMD test -f /tmp/wallet/token.txt && \
      test $(find /tmp/wallet/token.txt -mmin -60) || exit 1

CMD ["/usr/local/bin/refresh-token.sh"]
```

```powershell
# Build and push
cd misc
docker build -f Dockerfile.token-refresh -t <your-acr>.azurecr.io/token-refresh:latest .
docker push <your-acr>.azurecr.io/token-refresh:latest
```

### Step 3: Update Your Deployment

Add the sidecar to your existing deployment - see the YAML example in Option 1 above.

---

## Monitoring & Alerts

Set up monitoring to alert when token refresh fails:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
data:
  alerts.yml: |
    groups:
    - name: oracle-token
      rules:
      - alert: TokenRefreshFailed
        expr: time() - oracle_token_last_refresh_timestamp > 3600
        for: 5m
        annotations:
          summary: "Oracle token hasn't been refreshed in 1 hour"
```

---

## Best Practices

1. ✅ **Refresh before expiry** - Refresh 15 minutes before token expiration
2. ✅ **Use Managed Identity** - Avoid storing credentials in code/config
3. ✅ **Monitor refresh status** - Set up alerts for failed refreshes
4. ✅ **Handle failures gracefully** - Retry with exponential backoff
5. ✅ **Log token events** - Track refresh times and failures
6. ✅ **Single line tokens** - Always write tokens without newlines
7. ✅ **Secure storage** - Set file permissions to 600 (read/write for owner only)

---

## Next Steps

1. Choose the approach that fits your architecture
2. Implement token refresh automation
3. Set up monitoring and alerts
4. Test token expiry scenarios
5. Document the solution for your team

Would you like help implementing any of these options?
