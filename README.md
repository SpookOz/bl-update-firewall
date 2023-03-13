# bl-update-firewall

## Updates firewall rule for current VPS using BinaryLane API

### This must be run on a BinaryLane Linux VPS
### Tested on RockyLinux8, but should work on all versions of Centos, Debian, Rocky, Ubuntu.

To run
- Download BL-Modify-Firewall.sh
- Uncomment #APITOKEN=
- Add API token after APITOKEN=
  eg APITOKEN=43509845093745234060438765340567

This shell script will:
- Lookup the server Public IP
- Lookup the hostname of the server
- Install jq if required
- Fetch the server ID from BinaryLane using the hostname
- Fetch the current firewall config using the server hostname
- Request the user to input details for the new firewall rule, including IP address, port and description. It assumes protocol is "all".
- Modify the fetched firewall config by adding the new rule at the top
- Upload the new firewall rule to BinaryLane
- Fetches the new firewall rules from BinaryLane and displays them to the user to check

NB: there is almost no error-checking in the scripts, except for a confirmation for the user to make sure they inputted the correct details. 
NB: The process is destructive, in that it will overwrite the old firewall rules with the new ones. However, there are a few stopgaps in place to avoid irreparibly deleting firewall rules:
  1. A copy of the original unmodified rules can be found in /tmp/firewall.json. If something goes wrong, they can be easily uploaded.
  2. The BL API will not modify the firewall rules if the syntax is incorrect. So if something goes wrong when the script is creating the new rules, it probably won't update.
  
There is probably room for improvement. Happy for contributions to be made.
