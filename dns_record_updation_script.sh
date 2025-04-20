#!/bin/bash

# Configuration
CLOUDFLARE_EMAIL="EMAIL_HERE"
API_TOKEN="CLOUDFLARE_API_TOKEN"
ZONE_ID=""
RECORD_ID=""
DOMAIN_NAME="data.hrudaynath.com"

# Check if the website returns 301
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DOMAIN_NAME")
# Get the IP address that is currently set in DNS records
DNS_CONTENT_UNNORMALIZED=$(curl https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records     -H "X-Auth-Email: $CLOUDFLARE_EMAIL"     -H "X-Auth-Key: $API_TOKEN" | jq '.result | map(select(.type == "AAAA")) | .[].content')
# Get the server's IPv6 address
IPV6_ADDRESS_DATA=$(curl -6 icanhazip.com)
IPV6_ADDRESS_UNNORMALIZED="\"$IPV6_ADDRESS_DATA\""

# Normalize IPv6 addresses (using a Python one liner)
normalize_ipv6() {
  python3 -c "import ipaddress; print(ipaddress.ip_address($1))" 2>/dev/null
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

	# Make the API call
	RESPONSE=$(curl -s -X PATCH \
	-H "Content-Type: application/json" \
	-H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
	-H "X-Auth-Key: $API_TOKEN" \
	--data '
	{
		"comment": "Domain verification record",
		"type": "AAAA",
		"name": "'$DOMAIN_NAME'",
		"content": "'$IPV6_ADDRESS'",
		"ttl": 3600,
		"proxied": true
	}
	'	\
	"$API_URL")

	# Check the response
	if echo "$RESPONSE" | jq -r '.success' | grep -q true; then
	        echo "Successfully updated Cloudflare DNS record."
	        echo "$RESPONSE" | jq .
	else
	        echo "Error updating Cloudflare DNS record."
	        echo "$RESPONSE" | jq .
	        exit 1
	fi
else
	echo "Simillar IPs detected, Skipping IPv6 update."
	echo "Remote:	$DNS_CONTENT"
	echo "Local:	$IPV6_ADDRESS"
fi

exit 0
