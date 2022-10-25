#!/bin/bash
# For remote connections it is better to use the IP instead of hostname. Hostname may not work sometimes
# export HUBHOST=9.20.199.88  
export HUBHOST=localhost
export ITMHOME=/opt/IBM/ITM
export SQLLIB=.
kdstsns=`find $ITMHOME -name kdstsns|grep "ms"`
echo "SELECT NODE, HOSTADDR FROM O4SRV.INODESTS;" > itm_get_node_address.sql

# for ip.pipe use port 1918
#export KDC_PORTS="(2 135 3661)"

# for ip.pipe use IP.PIPE and change hostname if running remotely
# if running remotely change hostname "localhost" to your HUB hostname 
if [[ $HUBHOST =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ; then
    echo ip.spipe:#$HUBHOST >  runCMSsql_site.txt 
    echo ip.pipe:#$HUBHOST >> runCMSsql_site.txt

else
    echo ip.spipe:$HUBHOST >  runCMSsql_site.txt 
    echo ip.pipe:$HUBHOST >> runCMSsql_site.txt
fi
export KDC_GLBSITES=runCMSsql_site.txt

$kdstsns  itm_get_node_address.sql *HUB |grep "/NM"| awk -F'<' '{print $1} '

