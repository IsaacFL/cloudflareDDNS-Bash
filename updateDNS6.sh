#!/usr/bin/env bash
export PATH=/sbin:/opt/bin:/usr/local/bin:/usr/contrib/bin:/bin:/usr/bin:/usr/sbin:/usr/bin/X11

## A bash script to update a Cloudflare DNS AAAA record with the Internal IP of the source machine ##
## DNS record MUST pre-creating on Cloudflare

##### Config Params
what_ip="internal"              ##### Which IP should be used for the record: usually internal for ipv6
what_interface="eth0"           ##### For internal IP, provide interface name
dns_record="ddns.example.com"   ##### DNS A record which will be updated
zoneid="ChangeMe"               ##### Cloudflare's Zone ID
proxied="false"                 ##### Use Cloudflare proxy on dns record true/false
ttl=1                           ##### 120-7200 in seconds or 1 for Auto
cloudflare_api_token="ChangeMe" ##### Cloudflare API Token keep it private!!!!

##### Get the current IP addresss
if [ "${what_ip}" == "external" ]; then
    ip=$(curl -s -6 -X GET https://icanhazip.com)
else
    if [ "${what_ip}" == "internal" ]; then
        if which ip >/dev/null; then
            ip=$(ip -o -6 addr show ${what_interface} scope global | awk '{print $4;}' | cut -d/ -f 1)
        else
            ip=$(ifconfig ${what_interface} | grep 'inet6 ' | awk '{print $2}')
        fi
    else
        echo "missing or incorrect what_ip/what_interface parameter"
    fi
fi

logger -s -t $(basename $0) -p user.info "==> Current Local IP is $ip"

##### get the dns record id and current ip from cloudflare's api
dns_record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=AAAA&name=$dns_record" \
    -H "Authorization: Bearer $cloudflare_api_token" \
    -H "Content-Type: application/json")

dns_record_id=$(echo ${dns_record_info} | grep -o '"id":"[^"]*' | cut -d'"' -f4)
dns_record_ip=$(echo ${dns_record_info} | grep -o '"content":"[^"]*' | cut -d'"' -f4)

logger -s -t $(basename $0) -p user.info "==> DNS Record currently is set to $dns_record_ip"

if [ ${dns_record_ip} == ${ip} ]; then
    logger -s -t $(basename $0) -p user.info "==> No changes needed!"
    exit
else
    logger -s -t $(basename $0) -p user.info "==> Updating!!!"
fi

##### updates the dns record
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dns_record_id" \
    -H "Authorization: Bearer $cloudflare_api_token" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"AAAA\",\"name\":\"$dns_record\",\"content\":\"$ip\",\"ttl\":$ttl,\"proxied\":$proxied}")

if [[ $update == *"\"success\":false"* ]]; then
    logger -s -t $(basename $0) -p user.warn "==> FAILED:\n$update"
    exit 1
else
    logger -s -t $(basename $0) -p user.info "==> $dns_record DNS Record Updated To: $ip"
fi
