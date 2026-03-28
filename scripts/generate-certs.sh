#!/bin/bash
# Generate self-signed TLS certificates for HAProxy and web servers
# This script creates certificates for educational purposes in the study-network lab

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_ROOT/certs"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== TLS Certificate Generation for Study Network Lab ===${NC}\n"

# Create certificates directory
mkdir -p "$CERTS_DIR"

# Certificate parameters
COUNTRY="US"
STATE="California"
CITY="San Francisco"
ORG="Study Network Lab"
OU="DevOps Learning"
DAYS_VALID=365

echo -e "${YELLOW}Certificate validity: $DAYS_VALID days${NC}\n"

#---------------------------------------------------------------------
# 1. Generate CA (Certificate Authority)
#---------------------------------------------------------------------
echo -e "${GREEN}[1/4] Generating Certificate Authority (CA)...${NC}"

openssl genrsa -out "$CERTS_DIR/ca-key.pem" 4096

openssl req -new -x509 -days $DAYS_VALID -key "$CERTS_DIR/ca-key.pem" \
    -out "$CERTS_DIR/ca-cert.pem" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=Study Network Lab CA"

echo -e "  ✓ CA certificate created: ca-cert.pem\n"

#---------------------------------------------------------------------
# 2. Generate HAProxy certificate (for SSL termination)
#---------------------------------------------------------------------
echo -e "${GREEN}[2/4] Generating HAProxy certificate...${NC}"

# Generate private key
openssl genrsa -out "$CERTS_DIR/haproxy-key.pem" 2048

# Create certificate signing request (CSR)
openssl req -new -key "$CERTS_DIR/haproxy-key.pem" \
    -out "$CERTS_DIR/haproxy.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=haproxy.netlab.local"

# Create SAN (Subject Alternative Names) configuration
cat > "$CERTS_DIR/haproxy-san.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = haproxy.netlab.local
DNS.2 = lb.netlab.local
DNS.3 = www.netlab.local
DNS.4 = api.netlab.local
DNS.5 = *.netlab.local
IP.1 = 10.0.3.10
IP.2 = 10.0.1.20
EOF

# Sign the certificate with our CA
openssl x509 -req -days $DAYS_VALID \
    -in "$CERTS_DIR/haproxy.csr" \
    -CA "$CERTS_DIR/ca-cert.pem" \
    -CAkey "$CERTS_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$CERTS_DIR/haproxy-cert.pem" \
    -extensions v3_req \
    -extfile "$CERTS_DIR/haproxy-san.cnf"

# HAProxy requires cert + key in single PEM file
cat "$CERTS_DIR/haproxy-cert.pem" "$CERTS_DIR/haproxy-key.pem" > "$CERTS_DIR/haproxy.pem"

echo -e "  ✓ HAProxy certificate created: haproxy.pem\n"

#---------------------------------------------------------------------
# 3. Generate web3 certificate (for end-to-end TLS)
#---------------------------------------------------------------------
echo -e "${GREEN}[3/4] Generating web3 HTTPS certificate...${NC}"

# Generate private key
openssl genrsa -out "$CERTS_DIR/web3-key.pem" 2048

# Create CSR
openssl req -new -key "$CERTS_DIR/web3-key.pem" \
    -out "$CERTS_DIR/web3.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=web3.netlab.local"

# Create SAN configuration
cat > "$CERTS_DIR/web3-san.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = web3.netlab.local
IP.1 = 10.0.1.12
EOF

# Sign the certificate with our CA
openssl x509 -req -days $DAYS_VALID \
    -in "$CERTS_DIR/web3.csr" \
    -CA "$CERTS_DIR/ca-cert.pem" \
    -CAkey "$CERTS_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$CERTS_DIR/web3-cert.pem" \
    -extensions v3_req \
    -extfile "$CERTS_DIR/web3-san.cnf"

echo -e "  ✓ web3 certificate created: web3-cert.pem, web3-key.pem\n"

#---------------------------------------------------------------------
# 4. Set proper permissions
#---------------------------------------------------------------------
echo -e "${GREEN}[4/4] Setting certificate permissions...${NC}"

chmod 600 "$CERTS_DIR"/*-key.pem
chmod 644 "$CERTS_DIR"/*-cert.pem
chmod 644 "$CERTS_DIR"/ca-cert.pem
chmod 600 "$CERTS_DIR"/haproxy.pem

echo -e "  ✓ Permissions set\n"

# Clean up temporary CSR and SAN config files
rm -f "$CERTS_DIR"/*.csr "$CERTS_DIR"/*-san.cnf

#---------------------------------------------------------------------
# Summary
#---------------------------------------------------------------------
echo -e "${BLUE}=== Certificate Generation Complete ===${NC}\n"
echo "Generated certificates:"
echo "  📁 Location: $CERTS_DIR"
echo ""
echo "  🔐 CA Certificate:"
echo "     - ca-cert.pem (public CA certificate)"
echo "     - ca-key.pem (private CA key)"
echo ""
echo "  🔐 HAProxy Certificate (SSL Termination):"
echo "     - haproxy.pem (combined cert + key for HAProxy)"
echo "     - Covers: *.netlab.local, haproxy.netlab.local, lb.netlab.local"
echo ""
echo "  🔐 web3 Certificate (HTTPS):"
echo "     - web3-cert.pem (public certificate)"
echo "     - web3-key.pem (private key)"
echo "     - Covers: web3.netlab.local"
echo ""
echo -e "${YELLOW}⚠️  These are self-signed certificates for educational purposes only!${NC}"
echo -e "${YELLOW}⚠️  Do NOT use in production environments.${NC}"
echo ""
echo "To verify certificates:"
echo "  openssl x509 -in $CERTS_DIR/haproxy-cert.pem -text -noout"
echo "  openssl x509 -in $CERTS_DIR/web3-cert.pem -text -noout"
echo ""
echo "To trust the CA certificate (optional, for testing):"
echo "  - macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CERTS_DIR/ca-cert.pem"
echo "  - Linux: sudo cp $CERTS_DIR/ca-cert.pem /usr/local/share/ca-certificates/netlab-ca.crt && sudo update-ca-certificates"
echo ""
