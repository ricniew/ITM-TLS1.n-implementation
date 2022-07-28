#!/bin/bash
#set -x
#
# Usage: 
#   # ./activate_teps-tlsv.sh { -h ITM home } [ -a arch ] [-b {no, yes[default]} ] { -r [no, yes] }
#
# Before execution the file ". .\init_tlsv1.2.ps1" must be sourced first
#
# 20.07.2022: Version 2.0      R. Niewolik EMEA AVP Team 
#             - Complete redesign of the script released on 20.04.2022.
#               Splitted inital script into a new script, function file and files to set
#               the required variables
# 28.07.2022: Version 2.2      R. Niewolik EMEA AVP Team
#             - changed modkcjparmstxt execution to modcjenvironment to support TEPD (CJ) TLSv1.n changes 
##
 
SECONDS=0
PROGNAME=$(basename $0)
USRCMD="$0 $*"
echo "INFO - Script Version 2.0"

usage()
{ # usage description
  echo "----"
  echo " Usage:"
  echo "  $PROGNAME { -h ITM home } [ -a arch ] [-b {no, yes[default]} ] { -r [no, yes] }"
  echo "    -h = Required. ITM home folder"
  echo "    -a = Arch folder name (e.g. lx8266)"
  echo "    -b = If backup should be performed or not, default is 'yes'. Please use that parameter carefully!!!!!!"
  echo "    -r = Required. If set to 'no' the ITM default cert will NOT be renewed. "
  echo ""
  echo " Sample executions:"
  echo "    $PROGNAME -h /opt/IBM/ITM -r yes  # A backup is performed and default keystore is renewed"
  echo "    $PROGNAME -h /opt/IBM/ITM -b no -r yes -a lx8266  # NO backup is performed, default keystore is renewed, arch folder is lx8266"
  echo "    $PROGNAME -h /opt/IBM/ITM -b no -r no  # NO backup is performed and default keystore is not renewed"
  echo "----"
  exit 1
}

check_param ()
{
  if  [ "$CERTRENEW" != ""  ] ; then
      if [ "$CERTRENEW" != "no" ] && [ "$CERTRENEW" != "yes"  ] ; then 
          echo "ERROR - check_param - Bad execution syntax. Option '-r' ("$CERTRENEW") value not correct (yes/no)"
          usage
      else
          echo "INFO - check_param - Option '-r' = '$CERTRENEW'"
      fi
  else
      echo "ERROR - check_param - Bad execution syntax. Option '-r' is mandatory (yes/no)"
      usage
  fi
  if [ "$BACKUP" != "" ] ; then
      if [ "$BACKUP" != "no" ] && [  "$BACKUP" !=  "yes"  ] ; then
          echo "ERROR - check_param - Bad execution syntax. Option '-b' value not correct (yes/no)"
          usage
      else
          echo "INFO - check_param - Option '-b' = '${BACKUP}'"
      fi
  fi

  if [ "$CITMHOME" != "" ] ; then 
      if [ -d  "$CITMHOME/bin" ] ;  then
          echo "INFO - check_param - Option '-h' = '${CITMHOME}'"
      else 
          echo "ERROR - check_param - Folder $CITMHOME is not an ITMHOME directory. Check ITM home '-h' option "
          usage
      fi 
  else
      echo "ERROR - check_param - Bad execution syntax. Option '-h' is mandatory (yes/no)"
      usage
  fi

  if [ "$CHARCH" == "" ] ; then
      echo "INFO - check_param - Option '-a' for ITM arch folder name was not set. Trying to evaluate ..."
      CHARCH=`${CITMHOME}/bin/cinfo -d cq|grep "cq.*Tivoli Enterprise Portal Server"|awk -F'","' '{print $3}'`
      if [ ! -d "${CITMHOME}/${CHARCH}/iw" ]; then
          echo "ERROR - check_param - ARCH folder cannot be evaluated. ITM directory ${CITMHOME}/${CHARCH}/iw is not existing"
          echo " You can find the rigth value by looking at the 'cinfo -t cq' output "
          echo " For example e.g. lx8266 for the 'cq' component. Then restart the procedure and add option '-a lx8266' "
          usage
      fi
  else
      if [ -d "${CITMHOME}/${CHARCH}/iw" ]; then
          echo "INFO - check_param - Option '-h' = '${CITMHOME}'"
      else
          echo "ERROR - check_param - Option '-a' set to '${CHARCH}' but folder '${CITMHOME}/${CHARCH}/iw' does not exists. Please check and restart."   
          usage
      fi 
  fi

}

# --------------------------------------------------------------
# MAIN ---------------------------------------------------------
# --------------------------------------------------------------

while getopts "a:h:b:r:" OPTS
do
  case $OPTS in
    h) CITMHOME=${OPTARG} ;;
    a) CHARCH=${OPTARG} ;;
    b) BACKUP=${OPTARG} ;;
    r) CERTRENEW=${OPTARG} ;;
    *) echo "ERROR - main - You have used a not valid switch"; usage ; exit ;;
  esac
done

check_param 

# initialize functions and global variables
if [ -f functions_sources.h ] ; then 
   source ./functions_sources.h $CITMHOME $CHARCH
   if [ $? -eq 1 ] ; then exit 1 ; fi
   
else 
  echo "ERROR - main - File functions_sources.h doesn't exists in the current directory"
  exit 1
fi

echo "INFO -------------------------------------------"
echo "INFO - main - Modifications for TLSVER=$TLSVER -"
#ver=`echo "${TLSVER,,}"` ; ifssave=$IFS; IFS=\n ; for i in `grep echo init_${ver}` ; do eval $i ; done ; IFS=$ifssave ;
echo "INFO -------------------------------------------"

# check if TEPS running and initialized
${ITMHOME}/bin/cinfo -r | grep " cq " | grep -i  "running" > /dev/null
if [ $? -eq 1 ]; then
    echo "ERROR - main - TEPS not running. Please start it and restart the procedure"
    exit 1
else
    grep 'Waiting for requests. Startup complete' $ITMHOME/logs/kfwservices.msg > /dev/null
    if [ $? -ne 0 ] ; then
        echo "ERROR - main - TEPS running but not connected to a TEMS"
        exit 1
    fi
fi

# check if TEPS and eWAS on required version  
tepsver=`${ITMHOME}/bin/cinfo -d cq | grep "cq.*Tivoli Enterprise Portal Server" | awk -F'","' '{print $4}'`
ewasver=`${ITMHOME}/bin/cinfo -d iw | grep "iw.*IBM Tivoli Enterprise Portal Server Extensions" | awk -F'","' '{print $4}'`
if [ $tepsver -lt 06300700 ] ; then
    echo "ERROR - main - TEPS Server must be at least at version 06.30.07.00. You must update your TEPS server to <= 06.30.07.00 ."
    exit 1
elif [ $ewasver -lt 08551600 ] ; then
    echo "ERROR - main - eWAS server must be at least at version 08.55.16.00. Please perform an eWAS and IHS uplift as described in the udpate readme files" 
    exit 1
fi
echo "INFO - main - TEPS = $tepsver eWAS = $ewasver"

# check if Default backup folder exists
if [ ! -d "${ITMHOME}/backup/" ]; then
    echo "ERROR - main - Default backup folder ${ITMHOME}/backup does not exists! Please check. "
    exit 1
fi

# check if backup should be made. And if yes, assure that the new backup folder doesn't exists already 
if [ "$BACKUP" != "no" ] ; then
    if [ -d "${BACKUPFOLDER}" ]; then
        echo "ERROR - main - This script was started already and the folder $BACKUPFOLDER exists! To avoid data loss, "
        echo "before executing this script again, you must restore the original content by using the '$BACKUPFOLDER/$RESTORESCRIPT' script and delete/rename the backup folder."
        exit 1
    else
        mkdir ${BACKUPFOLDER}
        echo "INFO - main - Backup directory is: ${BACKUPFOLDER}"
    fi
else
     echo "WARNING - main - Backup will not be done because option \"-b no\" was set !!!!. Press CTRL+C in the next 7 secs if it was a mistake."
     sleep 7
fi

checkIfFileExists
if [ $? -eq 1 ] ; then exit 1 ; fi
# enable ICSLite in eWAS
EnableICSLite "true"
if [ $? -eq 1 ] ; then exit 1 ; fi

if [ "$BACKUP" != "no" ] ; then
    backupewasAndKeyfiles ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["httpd.conf"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["cq.ini"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["tep.jnlpt"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["component.jnlpt"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["applet.html.updateparams"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    if [ $KCJ -ne 4 ] ; then
        backupfile "${AFILES["cj.environment"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    fi
    backupfile "${AFILES["java.security"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["trust.p12"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["key.p12"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["ssl.client.props"]}"  ; if [ $? -eq 1 ] ; then exit 1 ; fi
    backupfile "${AFILES["cacerts"]}" ; if [ $? -eq 1 ] ; then exit 1 ; fi
    # Create a script to restore the files before TLS1.2 was set using this script
    createRestoreScript  ; if [ $? -eq 1 ] ; then exit 1 ; fi
else
    echo "WARNING - main - Backup will not be done because option \"-b no\" was set !!!!. Press CTRL+C in the next 5 secs if it was a mistake."
    sleep 5
fi 

if [ "$CERTRENEW" != "no" ] ; then
    # Renew the default certificate
    renewCert
    rc=$?
    if [ $rc -eq 1 ] ; then exit 1 ; fi
    # restart TEPS
    if [ $rc -eq 4 ] ; then
        echo "INFO - main - No Changes. Tivoli Enterpise Portal Server restart not required yet."
    else
        restartTEPS
        if [ $? -eq 1 ] ; then exit 1 ; fi
        EnableICSLite "true"
        if [ $? -eq 1 ] ; then exit 1 ; fi
    fi
else
    echo "WARNING - main - Certificate will NOT be renewed because option \"-r no\" was set."
fi

# TLS v1.2 only configuration - TEPS/eWAS TEP, IHS, TEPS,  components
# TEPS/eWAS modify Quality of Protection (QoP)    
modQop
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=$rc

# eWAS Set custom property com.ibm.websphere.tls.disabledAlgorithms
disableAlgorithms
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=$(( $rc + $rcs ))

# eWAS sslclientprops modification
modsslclientprops "${AFILES["ssl.client.props"]}" 
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=$(( $rc + $rcs ))
# test openssl s_client -connect 172.16.11.4:15206 -tls1_2 doesn't work on windows by default. Needs to be installed first in PS (Install-Module -Name OpenSSL)

# TEPS
# cq.ini add/modify variables
modcqini "${AFILES["cq.ini"]}"
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=$(( $rc + $rcs ))

# IHS httpd.conf modification
modhttpconf "${AFILES["httpd.conf"]}" 
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=$(( $rc + $rcs ))

# restart TEPS
if  [ $rcs -eq 20 ] ; then
    echo "INFO - main - No Changes. Tivoli Enterpise Portal Server restart not required yet."
else 
    restartTEPS
    if [ $? -eq 1 ] ; then exit 1 ; fi
    EnableICSLite "true"
    if [ $? -eq 1 ] ; then exit 1 ; fi
fi

# JAVAHOME java.security modification
modjavasecurity "${AFILES["java.security"]}"
if [ $? -eq 1 ] ; then exit 1 ; fi

# JAVAHOME cacerts file modification
importSelfSignedToJREcacerts "${AFILES["cacerts"]}"
if [ $? -eq 1 ] ; then exit 1 ; fi

# Browser/WebStart client related
modtepjnlpt "${AFILES["tep.jnlpt"]}"
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=rc
modcompjnlpt "${AFILES["component.jnlpt"]}"
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=$(( $rc + $rcs ))
modapplethtmlupdateparams "${AFILES["applet.html.updateparams"]}"
rc=$?
if [ $rc -eq 1 ] ; then exit 1 ; fi
rcs=$(( $rc + $rcs ))
if [ $rcs -eq 12 ] ; then
    echo "INFO - main - No changes, hence no need to reconfigure TEP WebSstart/Browser client 'cw'"
else 
    echo "INFO - main - Reconfiguring TEP WebSstart/Browser client 'cw'"
    ${ITMHOME}/bin/itmcmd config -A cw
    if [ $? -ne 0 ] ; then
        echo "ERROR - main - Reconfigure of TEP WebSstart/Browser client '${ITMHOME}/bin/itmcmd config -A kcw' failed. Script ended!"
        exit 1
    fi
fi

# Desktop client related
if [ $KCJ -eq 4 ] ; then
    echo "WARNING - main - TEP Desktop client not installed and was not modified ('${ITMHOME}/${ARCH}/cj/bin' not existing)."
else
    modcjenvironment "${AFILES["cj.environment"]}"
    rc=$?
    if [ $rc -eq 1 ] ; then exit 1 ; fi
    if [ $rc -eq 4 ] ; then
        echo "INFO - main - No changes, hence no need to reconfigure TEP Desktop Client 'cj'"
    else
        echo  "INFO - main - Reconfiguring TEP Desktop Client 'cj'" 
        ${ITMHOME}/bin/itmcmd config -Ar cj
        if [ $? -ne 0 ] ; then
            echo "ERROR - main - Reconfigure of TEP Desktop Client '${ITMHOME}/bin/itmcmd config -Ar kcj' failed. Powershell script ended!"
            exit 1
        fi
    fi
fi

# Disable ICSLIte
#EnableICSLite "false"


echo ""
etm=$((SECONDS/60))
host=`hostname`
echo "------------------------------------------------------------------------------------------"
echo "INFO - main - Procedure successfully finished Elapsedtime: $etm min " 
if [ "$BACKUP" != "no" ] ; then
    echo " - Original files saved in folder $BACKUPFOLDER "
    echo " - To restore the level before update run '$BACKUPFOLDER/$RESTORESCRIPT' "
else
    echo "WARNING - main - Backup was NOT done because option \"-b $BACKUP\" was set" 
fi
echo "----- POST script execution steps ---" 
echo " - Reconfigure TEPS and verify connections for TEP, TEPS, HUB" 
echo " - To check eWAS settings use: https://${host}:15206/ibm/console"
echo " - To check TEP WebStart  use: https://${host}:$TEPSHTTPSPORT/tep.jnlp"
echo "------------------------------------------------------------------------------------------"

exit 0

