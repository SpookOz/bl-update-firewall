#!/bin/bash
# Adds a new rule to the top of the BL firewall rules.


# Enter BL API Token below
#APITOKEN=

# Get IP Address
PUBIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
echo "Public IP of server is: $PUBIP"

# Get IP for Firewall Rule
echo "Please enter IP address to add to Firewall Exception: "
read IPaddress

# Get ports for Firewall Rule
echo 'Please enter ports to add to Firewall Exception. Each port should be in inverted commas and seperated by a comma. EG: "30019","30020"'
read FirewallPorts

# Get description for Firewall Rule
echo "Please enter a description for the Firewall Exception."
read FirewallDescription

# Ask the user to confirm
read -p "IP address to add is $IPaddress. Ports are $FirewallPorts. Description is $FirewallDescription. Are you sure you want to proceed? (y/n): " answer

# Check the user's response
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Exiting..."
    exit 1
fi

# Retrieves Hostname
tmphostname=$(hostname --long)

# Installs jq if needed
. /etc/os-release
DIST=$ID
if [ $DIST = "centos" ]; then
	sudo yum install jq -y
elif [ $DIST = "rocky" ]; then
	sudo dnf install jq -y
elif [ $DIST = "ubuntu" ]; then
	sudo apt install jq -y
elif [ $DIST = "debian" ]; then
	sudo apt install jq -y
fi

# Gets BL server ID
echo "Retrieving ID for $tmphostname"
serverid=$(curl -X GET "https://api.binarylane.com.au/v2/servers?hostname=$tmphostname" -H "Authorization: Bearer $APITOKEN" | jq '.servers[0].id')
echo "The ID for $tmphostname is: $serverid"

# Gets Firewall Rules
curl -X GET "https://api.binarylane.com.au/v2/servers/$serverid/advanced_firewall_rules" -H "Authorization: Bearer $APITOKEN" > /tmp/firewall.json

# Copy Rules
sudo cp /tmp/firewall.json  /tmp/firewall-upload.json

# Define the new firewall rule
NEW_RULE='{"source_addresses":["'$IPaddress'"],"destination_addresses":["'$PUBIP'"],"destination_ports":['$FirewallPorts'],"protocol":"all","action":"accept","description":"'$FirewallDescription'"}'

# Ask the user to confirm
echo "New Rule will look like this: "
echo $NEW_RULE
read -p "Does that look right? (y/n): " answer2

# Check the user's response
if [ "$answer2" != "y" ] && [ "$answer2" != "Y" ]; then
    echo "Exiting..."
    exit 1
fi

# Read the JSON file into a variable
JSON=$(cat /tmp/firewall-upload.json)

# Use jq to insert the new rule at the beginning of the firewall_rules array
JSON=$(echo $JSON | jq --argjson new_rule "$NEW_RULE" '.firewall_rules |= [$new_rule] + .')

# Write the updated JSON back to the file
echo $JSON > /tmp/firewall-upload.json

# Modify to change json
jq -n --argjson fr "$(jq -c '.[]' /tmp/firewall-upload.json)" '{type: "change_advanced_firewall_rules", firewall_rules: $fr}' > /tmp/firewall-upload.json

# Upload new firewall rules to the server
curl -X POST "https://api.binarylane.com.au/v2/servers/$serverid/actions" -H "Authorization: Bearer $APITOKEN" -H "Content-Type: application/json" -d "@/tmp/firewall-upload.json"

# Check for errors
if [ $? -eq 0 ]
then
  echo "Firewall rules apparently uploaded."
else
  echo "Firewall rule upload may have failed."
fi

# Fetch new rule to check
curl -X GET "https://api.binarylane.com.au/v2/servers/$serverid/advanced_firewall_rules" -H "Authorization: Bearer $APITOKEN" > /tmp/firewall-new.json

# Check new rule
echo "The new rule has been applied. The rule is:"
echo "Source Address: $(cat /tmp/firewall-new.json | jq -r '.firewall_rules[0] | [.source_addresses[]] | @csv')"
echo "Destination Address: $(cat /tmp/firewall-new.json | jq -r '.firewall_rules[0] | [.destination_addresses[]] | @csv')"
echo "Ports: $(cat /tmp/firewall-new.json | jq -r '.firewall_rules[0] | [.destination_ports[]] | @csv')"
echo "Protocol: $(cat /tmp/firewall-new.json | jq -r '.firewall_rules[0] | [.protocol] | @csv')"
echo "Action: $(cat /tmp/firewall-new.json | jq -r '.firewall_rules[0] | [.action] | @csv')"
echo "Description: $(cat /tmp/firewall-new.json | jq -r '.firewall_rules[0] | [.description] | @csv')"

# Check other rules are still present:
echo "To confirm, the firewall rules now look like this. Note IPs and ports are tuncated:"
jq -r '.firewall_rules[] | [.source_addresses[0], .destination_addresses[0], .destination_ports[0], .protocol, .action, .description] | @tsv' /tmp/firewall-new.json | (printf "%-10s | %-10s | %-10s | %-10s | %-10s\n" "Source Address" "Destination Address" "Destination Port" "Protocol" "Action" "Description"; cat) | column -t -s $'\t'
