#!/bin/bash
# NetBird AKS Health Check and Validation Script

set -e

NAMESPACE="netbird"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

echo "========================================"
echo "NetBird AKS Health Check"
echo "========================================"
echo ""

# Check 1: Verify namespace exists
echo "1. Checking Namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    print_status 0 "Namespace '$NAMESPACE' exists"
else
    print_status 1 "Namespace '$NAMESPACE' not found"
    exit 1
fi
echo ""

# Check 2: Verify all pods are running
echo "2. Checking Pod Status..."
PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null)
ALL_RUNNING=true

while IFS= read -r line; do
    POD_NAME=$(echo $line | awk '{print $1}')
    STATUS=$(echo $line | awk '{print $3}')
    
    if [ "$STATUS" = "Running" ]; then
        print_status 0 "Pod $POD_NAME is running"
    else
        print_status 1 "Pod $POD_NAME is $STATUS"
        ALL_RUNNING=false
    fi
done <<< "$PODS"
echo ""

# Check 3: Verify PVCs are bound
echo "3. Checking Persistent Volumes..."
PVCS=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null)

while IFS= read -r line; do
    PVC_NAME=$(echo $line | awk '{print $1}')
    STATUS=$(echo $line | awk '{print $2}')
    SIZE=$(echo $line | awk '{print $4}')
    
    if [ "$STATUS" = "Bound" ]; then
        print_status 0 "PVC $PVC_NAME is bound ($SIZE)"
    else
        print_status 1 "PVC $PVC_NAME is $STATUS"
    fi
done <<< "$PVCS"
echo ""

# Check 4: Verify services
echo "4. Checking Services..."
SERVICES=$(kubectl get svc -n $NAMESPACE --no-headers 2>/dev/null)

while IFS= read -r line; do
    SVC_NAME=$(echo $line | awk '{print $1}')
    TYPE=$(echo $line | awk '{print $2}')
    CLUSTER_IP=$(echo $line | awk '{print $3}')
    
    if [ ! -z "$CLUSTER_IP" ] || [ "$TYPE" = "ExternalName" ]; then
        print_status 0 "Service $SVC_NAME ($TYPE) is available"
    else
        print_status 1 "Service $SVC_NAME appears misconfigured"
    fi
done <<< "$SERVICES"
echo ""

# Check 5: Check reverse proxy certificate storage
echo "5. Checking Reverse Proxy Certificate Storage..."
PROXY_POD=$(kubectl get pod -n $NAMESPACE -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$PROXY_POD" ]; then
    # Check if certs directory exists and is writable
    if kubectl exec -n $NAMESPACE $PROXY_POD -- test -d /certs 2>/dev/null; then
        print_status 0 "Proxy certificate directory exists (/certs)"
        
        # Check for certificate files
        CERT_COUNT=$(kubectl exec -n $NAMESPACE $PROXY_POD -- find /certs -type f 2>/dev/null | wc -l || echo 0)
        if [ "$CERT_COUNT" -gt 0 ]; then
            print_status 0 "Found $CERT_COUNT certificate files in /certs"
        else
            print_info "No certificate files yet (will be generated on first request)"
        fi
    else
        print_status 1 "Proxy certificate directory not accessible"
    fi
else
    print_status 1 "Reverse proxy pod not found"
fi
echo ""

# Check 6: Verify server database
echo "6. Checking Server Database..."
SERVER_POD=$(kubectl get pod -n $NAMESPACE -l app=netbird-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$SERVER_POD" ]; then
    if kubectl exec -n $NAMESPACE $SERVER_POD -- test -d /var/lib/netbird 2>/dev/null; then
        print_status 0 "Server data directory exists (/var/lib/netbird)"
        
        # Check database size
        DB_SIZE=$(kubectl exec -n $NAMESPACE $SERVER_POD -- du -sh /var/lib/netbird 2>/dev/null | awk '{print $1}' || echo "unknown")
        print_info "Database size: $DB_SIZE"
    else
        print_status 1 "Server data directory not accessible"
    fi
else
    print_status 1 "Server pod not found"
fi
echo ""

# Check 7: Check reverse proxy connectivity
echo "7. Checking Reverse Proxy Health..."
PROXY_POD=$(kubectl get pod -n $NAMESPACE -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$PROXY_POD" ]; then
    # Check if listening on expected ports
    if kubectl exec -n $NAMESPACE $PROXY_POD -- netstat -tlnp 2>/dev/null | grep -E ':80|:443' > /dev/null; then
        print_status 0 "Reverse proxy is listening on port 80/443"
    else
        print_status 1 "Reverse proxy not listening on expected ports"
    fi
else
    print_status 1 "Reverse proxy pod not found"
fi
echo ""

# Check 8: Check server connectivity
echo "8. Checking Server API Health..."
SERVER_POD=$(kubectl get pod -n $NAMESPACE -l app=netbird-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$SERVER_POD" ]; then
    if kubectl exec -n $NAMESPACE $SERVER_POD -- netstat -tlnp 2>/dev/null | grep ':80' > /dev/null; then
        print_status 0 "Server is listening on port 80"
    else
        print_status 1 "Server not listening on port 80"
    fi
else
    print_status 1 "Server pod not found"
fi
echo ""

# Check 9: Check recent errors in logs
echo "9. Checking for Recent Errors in Logs..."
PROXY_ERRORS=$(kubectl logs -n $NAMESPACE -l app=netbird-reverse-proxy --tail=500 2>/dev/null | grep -iE "error|fail|fatal|panic" | wc -l || echo 0)
SERVER_ERRORS=$(kubectl logs -n $NAMESPACE -l app=netbird-server --tail=500 2>/dev/null | grep -iE "error|fail|fatal|panic" | wc -l || echo 0)

print_info "Proxy errors in last 500 lines: $PROXY_ERRORS"
print_info "Server errors in last 500 lines: $SERVER_ERRORS"

if [ "$PROXY_ERRORS" -lt 5 ] && [ "$SERVER_ERRORS" -lt 5 ]; then
    print_status 0 "Low error count in logs (expected)"
else
    print_status 1 "High error count - review logs"
fi
echo ""

# Check 10: Check ACME certificate status
echo "10. Checking ACME Certificate Status..."
if kubectl logs -n $NAMESPACE -l app=netbird-reverse-proxy --tail=200 2>/dev/null | grep -i "rate limit\|acme" > /dev/null; then
    print_info "ACME activity detected in logs"
    
    if kubectl logs -n $NAMESPACE -l app=netbird-reverse-proxy --tail=200 2>/dev/null | grep -i "rate.limit" > /dev/null; then
        print_status 1 "Rate limiting detected - wait before retrying"
    else
        print_status 0 "ACME certificates being managed"
    fi
else
    print_info "No recent ACME activity"
fi
echo ""

# Summary
echo "========================================"
echo "Health Check Summary"
echo "========================================"

if [ "$ALL_RUNNING" = true ] && [ "$PROXY_ERRORS" -lt 5 ] && [ "$SERVER_ERRORS" -lt 5 ]; then
    print_status 0 "NetBird cluster appears to be healthy"
    exit 0
else
    print_status 1 "Some issues detected - see above for details"
    exit 1
fi
