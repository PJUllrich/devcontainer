#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# Squid transparent firewall
#
# Uses Squid as a transparent proxy for all outbound HTTP/HTTPS traffic.
# iptables REDIRECT rules send ports 80/443 to Squid, which filters by
# domain using the allowed-domains.txt allowlist. Unlike an HTTP_PROXY-based
# approach, this catches ALL traffic regardless of whether the process
# respects proxy environment variables.
#
# - Port 80  (HTTP)  → Squid intercept port 3129 (reads Host header)
# - Port 443 (HTTPS) → Squid intercept port 3130 (reads SNI via peek-and-splice)
# ============================================================================

# --- Fix localhost IPv6 resolution ---
# Some tools (e.g. Tidewave CLI) resolve localhost to ::1 (IPv6) first,
# but services like Phoenix bind to 0.0.0.0 (IPv4 only). Ensure localhost
# resolves to 127.0.0.1 by commenting out the IPv6 entry in /etc/hosts.
if grep -q "^::1.*localhost" /etc/hosts 2>/dev/null; then
    sed 's/^::1\(.*localhost\)/#::1\1/' /etc/hosts > /tmp/hosts.tmp && cp /tmp/hosts.tmp /etc/hosts && rm /tmp/hosts.tmp
    echo "Disabled IPv6 localhost in /etc/hosts"
fi

# --- Preserve Docker internal DNS before flushing ---
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# --- Flush all existing rules ---
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# --- Restore Docker DNS ---
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# --- Generate regex domain list for ssl_bump filtering ---
# Squid's ssl::server_name with .domain.com only matches subdomains, not the
# bare domain. And it rejects having both forms in one ACL. So we convert to
# regex patterns:
#   .github.com  -> (^|\.)github\.com$   (domain + subdomains)
#   google.com   -> ^google\.com$         (exact match only)
SSL_REGEX="/etc/squid/allowed-ssl-domains.regex"
> "$SSL_REGEX"
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    if [[ "$line" == .* ]]; then
        # Leading dot: match domain and all subdomains
        bare="${line#.}"
        escaped="${bare//./\\.}"
        echo "(^|\\.)${escaped}$" >> "$SSL_REGEX"
    else
        # No leading dot: exact domain match only
        escaped="${line//./\\.}"
        echo "^${escaped}$" >> "$SSL_REGEX"
    fi
done < /etc/squid/allowed-domains.txt
echo "Generated $(wc -l < "$SSL_REGEX") SSL regex rules"

# --- Start Squid ---
echo "Starting Squid..."
squid
sleep 2

if ! pgrep -x squid >/dev/null 2>&1; then
    echo "ERROR: Squid failed to start. Check /var/log/squid/cache.log"
    cat /var/log/squid/cache.log 2>/dev/null | tail -20 || true
    exit 1
fi
echo "Squid started"
chmod 644 /var/log/squid/access.log 2>/dev/null || true

# --- Base allow rules ---

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow DNS (needed for Squid to resolve domains)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT

# Allow established/related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow host network (VS Code, Docker comms)
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi
HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network: $HOST_NETWORK"
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Allow host.docker.internal (resolves to a different subnet on Docker Desktop)
DOCKER_HOST_IP=$(getent hosts host.docker.internal | awk '{print $1}')
if [ -n "$DOCKER_HOST_IP" ]; then
    echo "host.docker.internal: $DOCKER_HOST_IP"
    iptables -A INPUT -s "$DOCKER_HOST_IP" -j ACCEPT
    iptables -A OUTPUT -d "$DOCKER_HOST_IP" -j ACCEPT
fi

# --- Squid transparent redirect rules ---

# Allow Squid (proxy user) to make direct outbound connections
# Without this, Squid's own outbound traffic would be redirected back to itself
iptables -A OUTPUT -p tcp --dport 80 -m owner --uid-owner proxy -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -m owner --uid-owner proxy -j ACCEPT

# Allow redirected traffic to reach Squid's local ports
iptables -A OUTPUT -p tcp --dport 3129 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 3130 -j ACCEPT

# Redirect all other outbound HTTP/HTTPS to Squid
iptables -t nat -A OUTPUT -p tcp --dport 80 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3129
iptables -t nat -A OUTPUT -p tcp --dport 443 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3130

# --- Set default DROP policy ---
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Explicit reject for clear error messages on non-allowed traffic
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# --- Verification ---
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "PASS: example.com blocked"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "PASS: api.github.com reachable"
fi

if ! curl --connect-timeout 5 https://claude.ai >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://claude.ai"
    exit 1
else
    echo "PASS: claude.ai reachable"
fi

if ! curl --connect-timeout 5 https://google.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://google.com"
    exit 1
else
    echo "PASS: google.com reachable (exact match)"
fi

if curl --connect-timeout 5 https://foo.google.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://foo.google.com"
    exit 1
else
    echo "PASS: foo.google.com blocked (subdomain of exact match)"
fi

echo "Firewall configuration complete"
