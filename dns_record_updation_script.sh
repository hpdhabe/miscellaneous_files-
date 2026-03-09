#!/bin/bash

# Configuration
CLOUDFLARE_EMAIL="EMAIL_HERE"
API_TOKEN="CLOUDFLARE_API_TOKEN"
ZONE_ID=""
RECORD_ID=""
API_URL_BASE="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
DOMAIN_NAME="d1.example.com"
DOMAIN_NAME_2="d2.example.com"
DOMAIN_NAME_3="d3.example.com"

# Check if the website returns 301
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DOMAIN_NAME")
# Get the IP address that is currently set in DNS records
DNS_CONTENT_UNNORMALIZED=$(curl "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=AAAA&name=$DOMAIN_NAME" -H "X-Auth-Email: $CLOUDFLARE_EMAIL" -H "X-Auth-Key: $API_TOKEN" | jq '.result[0].content')
# Get the server's IPv6 address
IPV6_ADDRESS_DATA=$(curl -6 icanhazip.com)
IPV6_ADDRESS_UNNORMALIZED="\"$IPV6_ADDRESS_DATA\""

# Normalize IPv6 addresses (using a Python one liner)
normalize_ipv6() {
  python3 -c "import ipaddress; print(ipaddress.ip_address($1))" 2>/dev/null
}

# --- Function to get the Record ID and then PATCH the record ---
update_cloudflare_record() {
    local DOMAIN_TO_UPDATE="$1"
    local RECORD_COMMENT="[$(date '+%Y-%m-%d %H:%M:%S')] $2"
    local RECORD_ID

    echo "--- Checking Record ID for $DOMAIN_TO_UPDATE ---"

    # 1. FIND THE RECORD ID using the name and type filters
    RECORD_ID=$(curl -s "$API_URL_BASE?type=AAAA&name=$DOMAIN_TO_UPDATE" \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $API_TOKEN" | \
        jq -r '.result[] | select(.type=="AAAA") | .id')

    # Check if a record ID was found
    if [ -z "$RECORD_ID" ]; then
        echo "Error: AAAA record not found for $DOMAIN_TO_UPDATE. Cannot update."
        exit 1
    fi
    echo "Found Record ID: $RECORD_ID"

    # 2. PERFORM THE PATCH (Update) using the specific Record ID
    local PATCH_URL="$API_URL_BASE/$RECORD_ID"
    local RESPONSE

    RESPONSE=$(curl -s -X PATCH \
        -H "Content-Type: application/json" \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $API_TOKEN" \
        --data '
        {
            "comment": "'"$RECORD_COMMENT"'",
            "type": "AAAA",
            "name": "'"$DOMAIN_TO_UPDATE"'",
            "content": "'"$IPV6_ADDRESS"'",
            "ttl": 3600,
            "proxied": true
        }' \
        "$PATCH_URL")

    # 3. CHECK THE RESPONSE
    if echo "$RESPONSE" | jq -r '.success' | grep -q true; then
        echo "✅ Successfully updated Cloudflare DNS record for $DOMAIN_TO_UPDATE."
    else
        echo "❌ Error updating Cloudflare DNS record $DOMAIN_TO_UPDATE."
        echo "Response details:"
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

IPV6_ADDRESS=$(normalize_ipv6 $IPV6_ADDRESS_UNNORMALIZED)
DNS_CONTENT=$(normalize_ipv6 "$DNS_CONTENT_UNNORMALIZED")

if [ -z "$IPV6_ADDRESS" ]; then
	echo "Error: Could not retrieve IPv6 address."
	exit 1
fi

if [[ "$IPV6_ADDRESS" != "$DNS_CONTENT" ]]; then
	echo "IPs do not match"
	echo "Remote:	$DNS_CONTENT"
	echo "Local:	$IPV6_ADDRESS"

	echo "Detected IPv6 address: $IPV6_ADDRESS"
	# Construct the Cloudflare API request
	API_URL="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID"

  # --- Execute the updates ---
  update_cloudflare_record "$DOMAIN_NAME" "a server"
  echo " "
  update_cloudflare_record "$DOMAIN_NAME_2" "b server"
  echo " "
  update_cloudflare_record "$DOMAIN_NAME_3" "c server"
  echo " "

else
	echo "Simillar IPs detected, Skipping IPv6 update."
	echo "Remote:	$DNS_CONTENT"
	echo "Local:	$IPV6_ADDRESS"
fi

exit 0
