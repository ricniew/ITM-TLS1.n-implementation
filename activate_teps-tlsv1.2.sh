#!/bin/bash
#set -x
###################################################################
# R. Niewolik IBM AVP
# This script  performs configuration steps to implement a TLSv1.2 only configuration
# 16.03.2022: Initial version by R. Niewolik EMEA AVP Team
# 30.03.2022: Version 1.3     by R. Niewolik EMEA AVP Team
# 13.04.2022: Version 1.31    by R. Niewolik EMEA AVP Team
#             - Add check if TEPS and eWas are at the required Level
#             - Backupfolder now created in ITMHOME/backup/.. directory 
# 20.04.2022: Version 1.32    by R. Niewolik EMEA AVP Team
#             - New function to check for file existance
#             - Added checks to functions if TLSv1.2 related variables were set already 
# 21.04.2022: Version 1.33     R. Niewolik EMEA AVP Team
#             - Improved checks if TLSv1.2 configured already
# 22.04.2022: Version 1.34     R. Niewolik EMEA AVP Team
#             - added "-n" option to allow a run without performing a backup
# 27.05.2022: Version 1.4      R. Niewolik EMEA AVP Team
#             - Delete -n switch and added -b instead
#             - Added new -r parameter to allow a run without cert renew
#             - Added functions for syntax display (syntax) and parameter check (check_param)      
##            
 
SECONDS=0
PROGNAME=$(basename $0)
USRCMD="$0 $*"
echo "INFO - Script Version 1.4"

usage()
{ # usage description
  echo ""
  echo " Usage:"
  echo "  $PROGNAME { -h ITM home } [ -a arch ] [-b {no, yes[default]} ] [-r {no, yes[default]} ]"
  echo "    -h = ITM home folder"
  echo "    -a = Arch folder name (e.g. lx8266)"
  echo "    -b = If backup should be performed or not, default is 'yes'. Please use that parameter carefully!!!!!!"
  echo "    -r = If set to 'no' the ITM default cert will NOT be renewed. Default is 'yes'"
  echo ""
  echo " Sample executions:"
  echo "    $PROGNAME -h /opt/IBM/ITM              # ITM home set, a backup is performed"
  echo "    $PROGNAME -h /opt/IBM/ITM -r no        # ITM home set, a backup is performed and default keystore is not renewed"
  echo "    $PROGNAME -h /opt/IBM/ITM -b no        # ITM home set, a NO backup is performed"
  echo "    $PROGNAME -h /opt/IBM/ITM -b no -r no  # ITM home set, NO backup is performed and default keystore is not renewed"
  echo ""
}

checkIfFileExists () # not used yet
{
  # this function als check if the files to backup exists
  if [ -d "$ITMHOME/$ARCH/iw" ]; then
      echo "INFO - checkIfFileExists - Directory $ITMHOME/$ARCH/iw  OK."
  else
      echo "ERROR - checkIfFileExists - Directory $ITMHOME/$ARCH/iw  does NOT exists. Please check."
  fi
  if [ -d "$ITMHOME/keyfiles" ]; then
      echo "INFO - checkIfFileExists - Directory $ITMHOME/keyfiles  OK."
  else
      echo "ERROR - checkIfFileExists - Directory $ITMHOME/keyfiles  does NOT exists. Please check."
  fi
  
  for filename in "${!AFILES[@]}"; do
      if [ -f ${AFILES[$filename]}  ] ; then 
          echo "INFO - checkIfFileExists - File ${AFILES[$filename]} OK."
          continue
      else
          if [[ $filename =~ "kcjparms" ]] ; then
              echo "WARNING - checkIfFileExists - File ${AFILES[$filename]} does NOT exists. KCJ component probably not installed. Continue..."
              KCJ=4 # will be used later in main and createRestoreScript
              continue
          else
              echo "ERROR - checkIfFileExists - file ${AFILES[$filename]} does NOT exists. Please check."
              exit 1
          fi
      fi      
  done
  
  return 0
}  

backupfile () 
{
  # this function als check if the files to backup exists, if not, scripts exists with error.
  filen=$1
  if [ -f $filen  ] ; then 
      echo "INFO - backupfile - Saving $filen in $BACKUPFOLDER "
      cp -p $filen $BACKUPFOLDER/.
      if [ $? -ne 0 ] ; then
          echo "ERROR - backupfile - Error during copy of file $filen to $BACKUPFOLDER. Check permissions and space available."
          exit 1
      fi
  fi

  return 0
}  
  
backupewasAndKeyfiles() 
{
  echo "INFO - backup - Saving Directory $ITMHOME/$ARCH/iw in $BACKUPFOLDER. This can take a while..." 
  cp -pR $ITMHOME/$ARCH/iw  $BACKUPFOLDER/ 
  if [ $? -ne 0 ]; then
      echo "ERROR - backup - Could not backup  $ITMHOME/$ARCH/iw to folder $BACKUPFOLDER. Check permissions and space."
      exit 1
  fi 
  echo "INFO - backup - $ITMHOME/keyfiles/ in $BACKUPFOLDER..." 
  cp -pR  $ITMHOME/keyfiles/ $BACKUPFOLDER/ 
  if [ $? -ne 0 ]; then
      echo "ERROR - backup - Could not backup  $ITMHOME/keyfiles/ to folder $BACKUPFOLDER. Check permissions and space."
      exit 1
  fi 
  return 0
}

createRestoreScript () 
{
  restorebatfull="$BACKUPFOLDER/$RESTORESCRIPT"
  if [ -f  $restorebatfull ] ; then
       echo "WARNING - createRestoreScript - Script $restorebatfull exists already and will be deleted"
       rm -f $restorebatfull
  fi
  touch $restorebatfull 
  chmod 755 $restorebatfull
  echo "set -x" >>  $restorebatfull 
  echo "cd $BACKUPFOLDER" >> $restorebatfull
  echo "" >>  $restorebatfull 
  echo "cp -pR iw $ITMHOME/$ARCH/." >> $restorebatfull
  echo "cp -pR keyfiles $ITMHOME/." >> $restorebatfull
  echo "" >>  $restorebatfull 
  for filename in "${!AFILES[@]}"; do
      if [[ $filename =~ "kcjparms" ]] && [[ $KCJ -eq 4 ]] ; then
          #echo "WARNING - createRestoreScript - TEP Desktop Client apparently not installed. File 'kcjparms.txt' not added to restore script"
          continue
      fi
      echo "cp -p $filename ${AFILES[$filename]} " >> $restorebatfull   
      echo "rm -f ${AFILES[$filename]}.beforetls12" >> $restorebatfull   
      echo "rm -f ${AFILES[$filename]}.tls12" >> $restorebatfull  
      echo "" >>   $restorebatfull      
  done
  echo "" >>  $restorebatfull      
  echo "${ITMHOME}/bin/itmcmd config -A cw" >> $restorebatfull
  if [[ $KCJ -eq 4 ]] ; then
      :
  else
      echo "${ITMHOME}/bin/itmcmd config -Ar cj" >> $restorebatfull 
  fi  

  echo "INFO - createRestoreScript - Restore script created: $restorebatfull"
  echo "" >>  $restorebatfull      
  sleep 4
  return 0
}

EnableICSLite () 
{
  echo "INFO - EnableICSLite - Set ISCLite to '$1' "
  ${ITMHOME}/$ARCH/iw/scripts/enableISCLite.sh $1
  if  [ $? -ne 0 ] ; then
      echo "ERROR - EnableICSLite - Enable ISCLite command $cmd failed. Possibly you did not set a eWAS user password. "
      echo " Try to set a password as descirbed here https://www.ibm.com/docs/en/tivoli-monitoring/6.3.0?topic=administration-define-wasadmin-password" 
      echo " Script ended!"
      exit 1
  fi
}

restartTEPS () 
 {
  echo  "INFO - restartTEPS - Restarting TEPS ..." 
  $ITMHOME/bin/itmcmd agent stop cq 
  $ITMHOME/bin/itmcmd agent start cq
  if [ $? -ne 0 ]; then
      echo "ERROR - restartTEPS - TEPS restart failed. Powershell script ended!"
      exit 1
  else
      echo "INFO - restartTEPS - Waiting for TEPS to initialize...."
      sleep 5
      wait=1
      c=0
      while [ $wait -eq 1 ] 
      do
          c=$(( $c + 1 ))
          grep 'Waiting for requests. Startup complete' $ITMHOME/logs/kfwservices.msg > /dev/null
          if [ $? -eq 0 ] ; then
              echo ""
              echo "INFO - restartTEPS - TEPS restarted successfully."
              wait=0 
          else 
              echo -n ".."
              c=$(( $c + 1 ))
              sleep 3  
          fi
	        if [ $c -gt 150 ] ; then
              echo "ERROR - restartTEPS - TEPS restart takes too long (over 2,5) min. Something went wrong. Powershell script ended!"
              exit 1
          fi
      done
      sleep 5
  fi
}

saveorgcreatenew () 
{
  orgfile=$1
  NEWORGFILE="${orgfile}.tls12"
  SAVEORGFILE="${orgfile}.beforetls12"

  if [ -f $SAVEORGFILE ] ; then # should not happen testing anyway
      echo "WARNING - saveorgcreatenew - $SAVEORGFILE exists and will be reused (contains original content)"
  else
      echo "INFO - saveorgcreatenew - $SAVEORGFILE created to save original content" 
      cp -p  $orgfile $SAVEORGFILE
  fi
  if [ -f $NEWORGFILE ] ; then
      echo "INFO - saveorgcreatenew - $NEWORGFILE exists already and will be deleted"
      rm $NEWORGFILE 
  fi
  touch $NEWORGFILE; chmod 755 $NEWORGFILE
  return 0
}

modhttpconf () 
{
  httpdfile=$1
  grep "^\s*SSLProtocolDisable\s*TLSv11"  $httpdfile > /dev/null
  if [ $? -eq 0 ] ; then
      grep "^\s*SSLProtocolEnable\s*TLSv12"  $httpdfile > /dev/null
      if [  $? -eq 0  ] ; then
          echo "WARNING - modhttpconf - $httpdfile contains 'SSLProtocolEnable TLSv12' + TLS11,10 disabled and will not be modified"
          return 4
      fi
  fi
  echo "INFO - modhttpconf - Modifying $httpdfile"
  
  saveorgcreatenew $httpdfile
  newhttpdfile=$NEWORGFILE
  savehttpdfile=$SAVEORGFILE
  foundsslcfg=1
  #echo "DEBUG - modhttpconf - $NEWORGFILE $SAVEORGFILE " ; exit
  while IFS= read -r line || [[ -n "$line" ]]
  do
      #echo -- $foundsslcfg
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newhttpdfile   
          #echo  "$line"
	        continue 
      fi
      tregex='ServerName (.*):15200'
      if [[ $line =~ $tregex ]] ; then 
          temp="ServerName ${BASH_REMATCH[1]}:15201"
          echo "$temp" >> $newhttpdfile
          echo "#${line}" >> $newhttpdfile
          continue
      fi
      tregex='^Listen[[:space:]]*15200'
      if [[ $line =~ $tregex ]] ; then
          echo "Listen 127.0.0.1:15200" >> $newhttpdfile
          #echo "${line}" >> $newhttpdfile
          continue
      fi
      if [ $foundsslcfg -eq 1 ] ; then  
          if [ "$line" = "<VirtualHost *:15201>" ] ; then
              #echo Debug -modhttpconf-----line= $line -- foundsslcfg= $foundsslcfg 
              foundsslcfg=0
              echo "$line" >> $newhttpdfile
              temp="  DocumentRoot \"${ITMHOME}/$ARCH/cw\""
              echo $temp >> $newhttpdfile
              echo "  SSLEnable" >> $newhttpdfile
              echo "  SSLProtocolDisable SSLv2" >> $newhttpdfile
              echo "  SSLProtocolDisable SSLv3" >> $newhttpdfile
              echo "  SSLProtocolDisable TLSv10" >> $newhttpdfile
              echo "  SSLProtocolDisable TLSv11" >> $newhttpdfile
              echo "  SSLProtocolEnable TLSv12" >> $newhttpdfile
              echo "  SSLCipherSpec ALL -SSL_RSA_WITH_3DES_EDE_CBC_SHA" >> $newhttpdfile
              echo "  ErrorLog \"${ITMHOME}/$ARCH/iu/ihs/HTTPServer/logs/sslerror.log\"" >> $newhttpdfile
              echo "  TransferLog \"${ITMHOME}/$ARCH/iu/ihs/HTTPServer/logs/sslaccess.log\"" >> $newhttpdfile
              echo "  KeyFile \"${ITMHOME}/keyfiles/keyfile.kdb\"" >> $newhttpdfile
              echo "  SSLStashfile \"${ITMHOME}/keyfiles/keyfile.sth\"" >> $newhttpdfile
              echo "  SSLServerCert IBM_Tivoli_Monitoring_Certificate" >> $newhttpdfile
          else
              echo "$line" >>  $newhttpdfile
          fi
    elif [ $foundsslcfg -eq 0 ]; then
        tregex="</VirtualHost>" 
        if [[ $line =~ $tregex ]] ; then
            echo "</VirtualHost>" >> $newhttpdfile
            foundsslcfg=2 
            continue
        fi
    else
        echo "$line" >> $newhttpdfile
    fi
  done < $savehttpdfile
  cp -p $newhttpdfile $httpdfile
  echo "INFO - modhttpconf - $newhttpdfile created and copied on $httpdfile"  

  #echo Debug ------line= $line -- foundsslcfg= $foundsslcfg
}

modcqini () 
{
  cqini=$1
  grep "KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only" $cqini > /dev/null
  if [  $? -eq 0  ] ; then
      grep "KDEBE_TLS11_ON=NO" $cqini > /dev/null
      if [  $? -eq 0  ] ; then
          echo "WARNING - modcqini - $cqini contains 'KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only' and will not be modified"
          return 4
      fi
  fi
  echo "INFO - modcqini - Modifying $cqini"
  
  saveorgcreatenew $cqini
  newcqini=$NEWORGFILE
  savecqini=$SAVEORGFILE
  foundKFWORB=1
  foundTLS10=1
  foundTLS11=1
  foundTLS12=1
  while IFS= read -r line || [[ -n "$line" ]]
  do
      #echo "$line"
      if [ ${line:0:1} = '#' ] ; then
          echo  "$line"  >> $newcqini 
          #echo  "$line"
	        continue 
      fi    
      if [[ $line =~ *KFW_ORB_ENABLED_PROTOCOLS* ]] ; then 
          echo "KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only" >> $newcqini 
          foundKFWORB=0 ; continue
      elif [[ $line =~ *KDEBE_TLS10_ON* ]]; then
          echo "KDEBE_TLS10_ON=NO" >> $newcqini 
          foundTLS10=0 ; continue
          continue
      elif [[ $line =~ *KDEBE_TLS11_ON* ]]; then
          echo "KDEBE_TLS11_ON=NO" >> $newcqini 
          foundTLS11=0 ; continue
      elif [[ $line =~ *KDEBE_TLSV12_CIPHER_SPECS* ]]; then
          echo "KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256" >> $newcqini 
          foundTLS12=0 ; continue
      else 
          echo "${line}" >> $newcqini  
      fi
  done < $SAVEORGFILE
  
  if [ $foundKFWORB -eq 1 ] ; then echo 'KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only' >> $newcqini ; fi  
  if [ $foundTLS10 -eq 1 ]  ; then echo 'KDEBE_TLS10_ON=NO' >> $newcqini ; fi
  if [ $foundTLS11 -eq 1 ]  ; then echo 'KDEBE_TLS11_ON=NO' >> $newcqini ; fi
  if [ $foundTLS12 -eq 1 ]  ; then echo 'KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256'>> $newcqini ; fi
  cp -p $newcqini $cqini 
  echo  "INFO - modcqini - $newcqini created and copied on $cqini"  
  return 0
}

modtepjnlpt () 
{
  tepjnlpt=$1
  grep "\s*<property name=\"jnlp.tep.sslcontext.protocol.*TLSv1.2" $tepjnlpt > /dev/null
  if [ $? -eq 0 ] ; then
      grep "codebase=\"https.*:15201" $tepjnlpt > /dev/null
      if [ $? -eq 0 ] ; then
          echo "WARNING - modtepjnlpt - $tepjnlpt contains 'jnlp.tep.sslcontext.protocol value=\"TLSv1.2\"' and will not be modified"
          return 4
      fi
  fi
  echo  "INFO - modtepjnlpt - Modifying $tepjnlpt"
  saveorgcreatenew $tepjnlpt
  newtepjnlpt=$NEWORGFILE
  savetepjnlpt=$SAVEORGFILE
  foundprotocol=1
  foundport=1
  foundTLS12=1
  while IFS= read -r line || [[ -n "$line" ]]
  do
      #echo "$line"
      if [[ $line =~ codebase.*http://\$HOST\$:\$PORT\$ ]] ; then
          echo '  codebase="https://$HOST$:15201/"> ' >> $newtepjnlpt 
      elif [[ $line =~ ^[[:space:]]*property.name=\"jnlp.tep.connection.protocol\".*value=  ]] ; then
          echo '    <property name="jnlp.tep.connection.protocol" value="https"/> '  >> $newtepjnlpt 
          foundprotocol=0
      elif [[ $line =~ ^[[:space:]]*property.name=\"jnlp.tep.connection.protocol.url.port\".*value= ]] ; then
          echo '    <property name="jnlp.tep.connection.protocol.url.port" value="15201"/> '  >> $newtepjnlpt 
          foundport=0
      elif [[ $line =~ ^[[:space:]]*property.name=\"jnlp.tep.sslcontext.protocol\".*value ]] ; then
          echo '    <property name="jnlp.tep.sslcontext.protocol" value="TLSv1.2"/> '  >> $newtepjnlpt 
          foundTLS12=0
      else 
          echo "${line}" >> $newtepjnlpt 
      fi
  done < $savetepjnlpt
  
  count=$(( foundprotocol+foundport+foundTLS12 ))
  if [ $count -gt 0 ] ; then
      #echo  "-DEBUG-modtepjnlpt----- c=$count --$foundprotocol = $foundport = $foundTLS12"
      tempfile="$newtepjnlpt.temporaryfile" 
      while IFS= read -r line || [[ -n "$line" ]]
      do
          if [[ $line =~ \<\!--.Custom.parameters.*--\> ]] ; then
              echo "$line" >> $tempfile
              #echo "    <Custom parameters>" >> $tempfile
              if [ $foundprotocol -eq 1 ] ; then echo '    <property name="jnlp.tep.connection.protocol" value="https"/> ' >> $tempfile ; fi
              if [ $foundport -eq 1 ] ;     then echo '    <property name="jnlp.tep.connection.protocol.url.port" value="15201"/> '  >> $tempfile ; fi
              if [ $foundTLS12 -eq 1 ] ;    then echo '    <property name="jnlp.tep.sslcontext.protocol" value="TLSv1.2"/> ' >> $tempfile ; fi
              #echo "    </Custom parameters>" >> $tempfile
          else 
               echo "${line}"  >> $tempfile 
          fi
      done < $newtepjnlpt
      cp $tempfile $newtepjnlpt
      rm -f $tempfile
  fi
  cp -p $newtepjnlpt $tepjnlpt
  echo  "INFO - modtepjnlpt - $newtepjnlpt created and copied on $tepjnlpt"
  return 0
}

modcompjnlpt () 
{
  compjnlpt=$1
  grep "codebase=\"https.*:15201" $compjnlpt > /dev/null
  if [  $? -eq 0  ] ; then
      echo "WARNING - modcompjnlpt - $compjnlpt contains 'codebase=https..:15201' and will not be modified"
      return 4
  else
      echo "INFO - modcompjnlpt - Modifying $compjnlpt"
  fi
  
  saveorgcreatenew $compjnlpt
  newcompjnlpt=$NEWORGFILE
  savecompjnlpt=$SAVEORGFILE
  cp $savecompjnlpt $newcompjnlpt
  sed -i -e 's/http:\/\/\$HOST\$:\$PORT\$/https:\/\/\$HOST\$:15201/g' $newcompjnlpt
  
  cp -p $newcompjnlpt $compjnlpt
  echo  "INFO - modcompjnlpt - $newcompjnlpt created and copied on $compjnlpt"
  return 0
}

modapplethtmlupdateparams () 
{
  applethtmlupdateparams=$1
  grep -i "tep.sslcontext.protocol.*verride.*TLSv1.2" $applethtmlupdateparams > /dev/null
  if [  $? -eq 0  ] ; then
      grep -i "tep.connection.protocol.*verride.*https" $applethtmlupdateparams > /dev/null
      if [  $? -eq 0  ] ; then
          echo "WARNING - modapplethtmlupdateparams - $applethtmlupdateparams contains \"tep.sslcontext.protocol|override|'TLSv1.2'\" and will not be modified"
          return 4
      fi  
  fi
  echo "INFO - modapplethtmlupdateparams - Modifying $applethtmlupdateparams"
  
  saveorgcreatenew $applethtmlupdateparams
  newapplethtmlupdateparams=$NEWORGFILE
  saveapplethtmlupdateparams=$SAVEORGFILE
  foundprotocol=1
  foundport=1
  foundTLS12=1
  while IFS= read -r line || [[ -n "$line" ]]
  do
      if [ "${line:0:1}" = "#" ] ; then
          echo "$line"  >> $newapplethtmlupdateparams
	  continue 
      elif [[ $line =~ tep.connection.protocol\|.* ]]; then
          echo "tep.connection.protocol|override|'https'" >> $newapplethtmlupdateparams
          foundprotocol=0
          continue
      elif [[ $line =~ tep.connection.protocol.url.port.* ]]; then
          echo "tep.connection.protocol.url.port|override|'15201'" >> $newapplethtmlupdateparams
          foundport=0
          continue
      elif [[ $line =~ tep.sslcontext.protocol\|.* ]]; then
          echo "tep.sslcontext.protocol|override|'TLSv1.2'" >> $newapplethtmlupdateparams
          foundTLS12=0
          continue
      else 
          echo  "${line}" >> $newapplethtmlupdateparams
      fi
  done < $saveapplethtmlupdateparams
  
  count=$(( foundprotocol+foundport+foundTLS12))
  if [ $count -gt 0 ] ; then
      #echo "-DEBUG-modapplethtmlupdateparams----- c=$count --foundprotocol=$foundprotocol foundport=$foundport foundTLS12=$foundTLS12"
      if [ $foundprotocol -eq 1 ] ; then echo "tep.connection.protocol|override|'https'" >> $newapplethtmlupdateparams ;fi
      if [ $foundport -eq 1  ] ;    then echo "tep.connection.protocol.url.port|override|'15201'" >> $newapplethtmlupdateparams ;fi
      if [ $foundTLS12 -eq 1 ] ;    then echo "tep.sslcontext.protocol|override|'TLSv1.2'" >> $newapplethtmlupdateparams; fi
  fi
  cp -p $newapplethtmlupdateparams $applethtmlupdateparams
  echo "INFO - modapplethtmlupdateparams - $newapplethtmlupdateparams created and copied on $applethtmlupdateparams"
  return 0
}

modkcjparmstxt () 
{
  kcjparmstxt=$1
  grep -i "tep.sslcontext.protocol.*TLSv1.2" $kcjparmstxt > /dev/null
  if [  $? -eq 0  ] ; then
      grep -i "tep.connection.protocol.*https" $kcjparmstxt > /dev/null
      if [  $? -eq 0  ] ; then
          echo "WARNING - modkcjparmstxt - $kcjparmstxt contains\"tep.sslcontext.protocol|override|'TLSv1.2'\" and will not be modified"
          return 4 
      fi
  fi      
  echo "INFO - modkcjparmstxt - Modifying $kcjparmstxt"
  
  saveorgcreatenew $kcjparmstxt
  newkcjparmstxt=$NEWORGFILE
  savekcjparmstxt=$SAVEORGFILE 
  foundprotocol=1
  foundport=1
  foundTLS12=1
  while IFS= read -r line || [[ -n "$line" ]]
  do
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newkcjparmstxt   
	  continue 
      elif [[ $line =~ tep.connection.protocol[[:space:]] ]] ; then
          #echo  "${line}" >>  $newkcjparmstxt
          echo "tep.connection.protocol | string | https | Communication protocol used between TEP/TEPS (iiop,http,https)" >>  $newkcjparmstxt
          foundproto=0
          continue
      elif [[ $line =~ tep.connection.protocol.url.port[[:space:]] ]] ; then
          echo "tep.connection.protocol.url.port | int | 15201 | Port used by the TEP to connect with the TEPS" >>  $newkcjparmstxt
          foundport=0
          continue
      elif [[ $line =~ tep.sslcontext.protocol[[:space:]]  ]] ; then
          echo "tep.sslcontext.protocol | string | TLSv1.2 | TLS used TEP to connect with the TEPS" >>  $newkcjparmstxt
          foundTLS12=0
          continue
      else 
          echo  "${line}" >>  $newkcjparmstxt
      fi 
  done < $savekcjparmstxt
  if [ $foundprotocol -eq 1 ] ; then echo "tep.connection.protocol | string | https | Communication protocol used between TEP/TEPS (iiop,http,https)" >> $newkcjparmstxt ; fi
  if [ $foundport -eq 1 ] ;     then echo "tep.connection.protocol.url.port | int | 15201 | Port used by the TEP to connect with the TEPS" >> $newkcjparmstxt ; fi
  if [ $foundTLS12 -eq 1 ] ;    then echo "tep.sslcontext.protocol | string | TLSv1.2 | TLS used TEP to connect with the TEPS" >> $newkcjparmstxt ; fi

  cp $newkcjparmstxt $kcjparmstxt 
  echo "INFO - modkcjparmstxt - $newkcjparmstxt created and copied on $kcjparmstxt"
  return 0
}

modjavasecurity () 
{
  javasecurity=$1
  grep "jdk.tls.disabledAlgorithms=MD5.*SSLv3.*DSA.*DESede.*DES.*RSA.*keySize\s*<\s*2048" $javasecurity > /dev/null
  if [  $? -eq 0  ] ; then
      echo "WARNING - modjavasecurity - $javasecurity contains \"jdk.tls.disabledAlgorithms=MD5, SSLv3, DSA, DESede, DES, RSA keySize < 2048\" and will not be modified"
      return 4
  else
     echo "INFO - modjavasecurity - Modifying $javasecurity"
  fi
  
  saveorgcreatenew $javasecurity
  newjavasecurity=$NEWORGFILE
  savejavasecurity=$SAVEORGFILE
  nextline=1
  foundAlgo=1
  while IFS= read -r line || [[ -n "$line" ]]
  do  
      #echo "DEBUG - modjavasecurity - after copy "
      tline=`echo $line | awk '{$1=$1};1'` # trim leadin and trailing white spaces 
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newjavasecurity   
          #echo  "$line"
	        continue 
      fi
      if [ $nextline -eq 0 ]; then
          if [[ $tline == *\\ ]]; then
              echo "${line}" >> $newjavasecurity  
              continue
          else
              echo "${line}" >> $newjavasecurity  
              echo "jdk.tls.disabledAlgorithms=MD5, SSLv3, DSA, DESede, DES, RSA keySize < 2048"  >> $newjavasecurity  
              foundAlgo=0
              nextline=1
              continue
          fi
      elif [[ $line =~ jdk.tls.disabledAlgorithms ]] && [[ $tline == *\\ ]] ; then
          echo "${line}" >> $newjavasecurity 
          nextline=0
          continue 
      else          
          echo "${line}" >> $newjavasecurity 
      fi
  done < $savejavasecurity
  
  if [ $foundAlgo -eq 1 ]; then
      echo "jdk.tls.disabledAlgorithms=MD5, SSLv3, DSA, DESede, DES, RSA keySize < 2048" >> $newjavasecurity  
  fi
  cp $newjavasecurity $javasecurity
  echo "INFO - modjavasecurity - $newjavasecurity created and copied on $javasecurity"
}

modsslclientprops () 
{
  sslclientprops=$1
  grep "^\s*com.ibm.ssl.protocol.*TLSv1.2" $sslclientprops > /dev/null
  if [  $? -eq 0  ] ; then
      echo "WARNING - modsslclientprops - $sslclientprops contains \"com.ibm.ssl.protocol=TLSv1.2\" and will not be modified"
      return 4
  else 
     echo "INFO - modsslclientprops - Modifying $sslclientprops"
  fi

  saveorgcreatenew $sslclientprops
  newsslclientprops=$NEWORGFILE
  savesslclientprops=$SAVEORGFILE
  foundproto=1
  while IFS= read -r line || [[ -n "$line" ]]
  do  
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newsslclientprops   
          continue 
      elif [[ $line =~ com.ibm.ssl.protocol ]] ; then
          if [[ $line =~ com.ibm.ssl.protocol=TLSv1.2 ]] ; then
              echo  "INFO - modsslclientprops - $sslclientprops contains 'com.ibm.ssl.protocol=TLSv1.2'"
              echo "${line}" >> $newsslclientprops 
          else
              echo "com.ibm.ssl.protocol=TLSv1.2" >> $newsslclientprops 
              echo "#${line}" >> $newsslclientprops 
          fi
          foundproto=0 
      else 
          echo  "${line}" >> $newsslclientprops
      fi
  done < $savesslclientprops
  
  if [ $foundproto -eq 1 ] ; then
      echo "INFO - modsslclientprops - 'com.ibm.ssl.protocol' set TLSv1.2 at the end of props file"
      echo  "com.ibm.ssl.protocol=TLSv1.2" >> $newsslclientprops 
  fi
  cp $newsslclientprops $sslclientprops
  echo  "INFO - modsslclientprops - $newsslclientprops created and copied on $sslclientprops"
  return 0
}

renewCert () 
{
  CH=$ITMHOME
  IWDIR=$(ls -d $CH/[al]*/iw 2> /dev/null)
  KEYKDB=$ITMHOME/keyfiles/keyfile.kdb
  KEYP12=$IWDIR/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12
  TRUSTP12=$IWDIR/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12
  
  keydate=`ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYKDB -stashed -label default | grep 'Not Before'|awk -F' : ' '{print $2}'`
  now=$(date)
  date_one=$(date -d "$keydate" +%s)
  date_two=$(date -d "$now" +%s)
  ts=$(( (date_two - date_one) / 86400 ))
  if [ $ts -lt 10 ] ; then
      echo "WARNING - renewCert - Default certificate was renewed recently ($ts days ago) and will not be renewed again"
      return 4
  else 
      echo "INFO - renewCert -  Default certificate will be renewed again ($ts)"
  fi
  
  cmd1="AdminTask.renewCertificate('-keyStoreName NodeDefaultKeyStore -certificateAlias  default')"
  cmd2="AdminConfig.save()"
  #echo " $WSADMIN -lang jython -c \"${cmd1}\" -c \"${cmd2}\""
  $WSADMIN -lang jython -c "${cmd1}" -c "${cmd2}"
  if  [ $? -ne 0 ] ; then
      echo "ERROR - renewCert - Error during renewing Certificate. Script ended!"
  else
      #cmd="AdminTask.getCertificateChain('[-certificateAlias default -keyStoreName NodeDefaultKeyStore -keyStoreScope (cell):ITMCell:(node):ITMNode ]')"
      #$WSADMIN -lang jython -c "${cmd}"
      echo "INFO - renewCert - Successfully renewed Certificate" 
  fi

  echo "INFO - renewCert - Running GSKitcmd.sh commands" 
  ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -delete -db $KEYKDB -stashed -label default
  ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -delete -db $KEYKDB -stashed -label root
  ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -import -db $KEYP12 -pw WebAS -target $KEYKDB -target_stashed -label default -new_label default
  ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -import -db $TRUSTP12 -pw WebAS -target $KEYKDB -target_stashed -label root -new_label root
  if [ $? -ne 0 ]; then
      echo "ERROR - renewCert - Error during GSKitcmd.sh execution. Script ended!"
      exit 1
  else
      echo "INFO - renewCert - GSKitcmd.sh commands finished successfully." 
      #echo "" ; ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -list -db $KEYKDB -stashed -label default
      #echo "" ; ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYKDB -stashed -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      #echo "" ; ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYP12 -pw WebAS -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      #echo "" ; ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYKDB -stashed -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      #echo "" ; ITMHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $TRUSTP12 -pw WebAS -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      return 0
  fi
  
}

modQop () 
{    
  # check if "[ sslProtocol SSL_TLSv2 ]" already set
  $WSADMIN  -lang jython -c "AdminTask.getSSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode ]')" | grep "sslProtocol SSL_TLSv2" > /dev/null 
  if [ $? -eq 0 ] ; then
      echo "WARNING - modQop - Quality of Protection (QoP) is already set to 'sslProtocol SSL_TLSv2' and will not be modified again." 
      return 4
  else
      echo "INFO - modQop - Quality of Protection (QoP) not set yet. Modifying..."
  fi
  
  cmd1="AdminTask.modifySSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode -keyStoreName NodeDefaultKeyStore -keyStoreScopeName (cell):ITMCell:(node):ITMNode -trustStoreName NodeDefaultTrustStore -trustStoreScopeName (cell):ITMCell:(node):ITMNode -jsseProvider IBMJSSE2 -sslProtocol TLSv1.2 -clientAuthentication false -clientAuthenticationSupported false -securityLevel HIGH -enabledCiphers ]')"
  cmd2="AdminConfig.save()"
  #echo "$WSADMIN -lang jython -c  \"${cmd1}\" -c  \"${cmd2}\""
  $WSADMIN -lang jython -c "${cmd1}" -c "${cmd2}"
  if [ $? -ne 0 ]; then
      echo "ERROR - modQop - Error setting TLSv1.2 for Quality of Protection (QoP). Script ended!"
      exit 1
  else
      echo "INFO - modQop - Successfully set TLSv1.2 for Quality of Protection (QoP)" 
      return 0
  fi
}

disableAlgorithms () 
{
  secxml="$ITMHOME/$ARCH/iw/profiles/ITMProfile/config/cells/ITMCell/security.xml"
  grep "com.ibm.websphere.tls.disabledAlgorithms.* value=.*none"  $secxml > /dev/null
   if [ $? -eq 0 ] ; then
      echo "WARNING - disableAlgorithms - Custom property 'com.ibm.websphere.tls.disabledAlgorithms... value=none' is already set and will not be set again"
      return 4
  else 
     echo "INFO - disableAlgorithms - Modifying $secxml"
  fi
  
  jython="$ITMHOME/tmp/org.jy"
  touch $jython 
  echo "sec = AdminConfig.getid('/Security:/')" > $jython 
  echo "prop = AdminConfig.getid('/Security:/Property:com.ibm.websphere.tls.disabledAlgorithms/' )"  >> $jython 
  echo "if prop:"  >> $jython 
  echo "  AdminConfig.modify(prop, [['value', 'none'],['required', \"false\"]])"  >> $jython 
  echo "else: "  >> $jython 
  echo " AdminConfig.create('Property',sec,'[[name \"com.ibm.websphere.tls.disabledAlgorithms\"] [description \"Added due ITM TSLv1.2 usage\"] [value \"none\"][required \"false\"]]') "  >> $jython 
  echo "AdminConfig.save()" >> $jython
  #echo "$WSADMIN -lang jython -f $jython"
  $WSADMIN -lang jython -f $jython
  if [ $? -ne 0 ]; then
      echo "ERROR - disableAlgorithms - Error setting Custom Property ( com.ibm.websphere.tls.disabledAlgorithms ). Script ended!"
      exit 1
  else
      #rm -f $jython
      echo "INFO - disableAlgorithms - Successfully set com.ibm.websphere.tls.disabledAlgorithms to none" 
      return 0
  fi
}

check_param ()
{

  if  [ "$CERTRENEW" != ""  ] ; then
      if [ "$CERTRENEW" != "no"  -a  "$CERTRENEW" != "yes"  ] ; then 
          echo "ERROR - check_param - Bad execution syntax. Parameter '-r' value not correct (yes/no)"
          usage
          exit 1
      else
          if [ "$CERTRENEW" == "yes" ] ; then
              echo "INFO - check_param - Parameter '-r' = '$CERTRENEW' (default)"
          else   
              echo "INFO - check_param - Parameter '-r' = '$CERTRENEW'  OK."
          fi
      fi
  fi
  if [ "$BACKUP" != "" ] ; then
      if [ "$BACKUP" != "no"  -a  "$BACKUP" !=  "yes"  ] ; then
          echo "ERROR - check_param - Bad execution syntax. Parameter '-b' value not correct (yes/no)"
          usage
          exit 1
       else
          if [ "$BACKUP" == "yes" ] ; then
              echo "INFO - check_param - Parameter '-b' = '$BACKUP' (default)"
          else
              echo "INFO - check_param - Parameter '-b' = '$BACKUP'  OK."
          fi
      fi
  fi

  if [ "$ITMHOME" != "" ] ; then 
      if [ -d  "$ITMHOME" ] ;  then
          echo "INFO - check_param - ITM home directory is: ${ITMHOME}"
      else 
          echo "ERROR - check_param - ITM home $ITMHOME set in '-h' option does not exists."
          usage
          exit 1
      fi 
  else
      echo "INFO - check_param - ITMHOME Parameter '-h' was not set. Procedure tries to use \$CANDLEHOME"
      if [ -z $CANDLEHOME ] ; then
          echo "ERROR - check_param - Variable CANDLEHOME=\$CANDLEHOME is not set. Please use option '-h'."
          usage
          exit 1
      else
          if [ -d  "$CANDLEHOME" ] ;  then
              ITMHOME=${CANDLEHOME}
              echo "INFO - check_param - ITM home directory is: ${ITMHOME}"
          else 
              echo "ERROR - check_param - ITM home $CANDLEHOME does not exists."
              usage
              exit 1
          fi 
      fi 
  fi

  if [ "$ARCH" = "" ] ; then
      echo "INFO - check_param - Option '-a' for ITM arch folder name was not set. Procedure tries to find it."
      ARCH=`${ITMHOME}/bin/cinfo -t cq|grep "cq.*Tivoli Enterprise Portal Server"|awk '{print $6}'`
      if [ -d "${ITMHOME}/${ARCH}/iw" ]; then
          echo "INFO - check_param - ITM arch directory is: ${ITMHOME}/${ARCH}"
      else
          echo "ERROR - check_param - TEPS apparently not installed on this host because ITM directory ${ITMHOME}/${ARCH}/iw is not existing"
          echo " or the arch '$ARCH' folder is not correct. You can find the rigth value by looking at the 'cinfo -t cq' output "
          echo " For example e.g. lx8266 for the 'cq' component. The restart the procedure ane add option '-a lx8266' "
          usage
          exit 1
      fi
  else
      if [ -d "${ITMHOME}/${ARCH}/iw" ]; then
           echo "INFO - check_param - ITM arch directory is: ${ITMHOME}/${ARCH}"
      else
         echo "ERROR - check_param - Option '-a' set to '${ARCH}' but folder '${ITMHOME}/${ARCH}/iw' does not exists. Please check and restart."   
         usage
         exit 1
      fi 
  fi

}

# --------------------------------------------------------------
# MAIN ---------------------------------------------------------
# --------------------------------------------------------------

while getopts "a:h:b:r:" OPTS
do
  case $OPTS in
    h) ITMHOME=${OPTARG} ;;
    a) ARCH=${OPTARG} ;;
    b) BACKUP=${OPTARG} ;;
    r) CERTRENEW=${OPTARG} ;;
    *) echo "ERROR - main - You have used a not valid switch"; usage ; exit ;;
  esac
done

check_param 

${ITMHOME}/bin/cinfo -r | grep " cq " | grep -i  "running" > /dev/null
if [ $? -eq 1 ]; then
    echo "ERROR - main - TEPS not running. Please start it and restart the procedure"
    exit
else
    grep 'Waiting for requests. Startup complete' $ITMHOME/logs/kfwservices.msg > /dev/null
    if [ $? -ne 0 ] ; then
        echo "ERROR - main - TEPS running but not connected to a TEMS"
        exit
    fi
fi 

tepsver=`${ITMHOME}/bin/cinfo -t cq| grep "^cq"|awk '{print $7}'|sed 's/\.//g'`
ewasver=`${ITMHOME}/bin/cinfo -t iw| grep "^iw"|awk '{print $9}'|sed 's/\.//g'`
if [ $tepsver -lt 06300700 ] ; then
    echo "ERROR - main - TEPS Server must be at least at version 06.30.07.00. You must update your TEPS server to <= 06.30.07.00 ."
    exit
elif [ $ewasver -lt 08551600 ] ; then
    echo "ERROR - main - eWAS server must be at least at version 08.55.16.00. Please perform an eWAS and IHS uplift as described in the udpate readme files" 
    exit
fi
echo "INFO - main - TEPS = $tepsver eWAS = $ewasver"

BACKUPFOLDER="${ITMHOME}/backup/backup_before_TLS1.2"
RESTORESCRIPT="SCRIPTrestore.sh"
WSADMIN="$ITMHOME/$ARCH/iw/bin/wsadmin.sh"

if [ ! -d "${ITMHOME}/backup/" ]; then
    echo "ERROR - main - Default backup folder ${ITMHOME}/backup does not exists! Please check. "
    exit 1
fi

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

declare -A AFILES=( 
  ["httpd.conf"]="${ITMHOME}/$ARCH/iu/ihs/HTTPServer/conf/httpd.conf"  \
  ["cq.ini"]="${ITMHOME}/config/cq.ini" \
  ["tep.jnlpt"]="${ITMHOME}/config/tep.jnlpt" \
  ["component.jnlpt"]="${ITMHOME}/config/component.jnlpt" \
  ["applet.html.updateparams"]="${ITMHOME}/$ARCH/cw/applet.html.updateparams" \
  ["kcjparms.txt"]="${ITMHOME}/$ARCH/cj/kcjparms.txt" \
  ["java.security"]="${ITMHOME}/$ARCH/iw/java/jre/lib/security/java.security" \
  ["trust.p12"]="${ITMHOME}/$ARCH/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12" \
  ["key.p12"]="${ITMHOME}/$ARCH/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12" \
  ["ssl.client.props"]="${ITMHOME}/$ARCH/iw/profiles/ITMProfile/properties/ssl.client.props" \
)
checkIfFileExists

# enable ICSLite in eWAS
EnableICSLite "true"

if [ "$BACKUP" != "no" ] ; then
    backupewasAndKeyfiles
    backupfile "${AFILES["httpd.conf"]}" 
    backupfile "${AFILES["cq.ini"]}"
    backupfile "${AFILES["tep.jnlpt"]}"
    backupfile "${AFILES["component.jnlpt"]}"
    backupfile "${AFILES["applet.html.updateparams"]}"
    if [ $KCJ -ne 4 ] ; then
         backupfile "${AFILES["kcjparms.txt"]}"
    fi
    backupfile "${AFILES["java.security"]}"
    backupfile "${AFILES["trust.p12"]}"
    backupfile "${AFILES["key.p12"]}"
    backupfile "${AFILES["ssl.client.props"]}"
    # Create a script to restore the files before TLS1.2 was set using this script
    createRestoreScript
else
    echo "WARNING - main - Backup will not be done because option \"-b no\" was set !!!!. Press CTRL+C in the next 5 secs if it was a mistake."
    sleep 7
fi 

if [ "$CERTRENEW" != "no" ] ; then
  # Renew the default certificate
  renewCert
  rc=$?
  # restart TEPS
  if [ $rc -eq 4 ] ; then
      echo "INFO - main - Tivoli Enterpise Portal Server restart not required yet."
  else
      restartTEPS
      EnableICSLite "true"
  fi
else
    echo "WARNING - main - Certificate will NOT be renewed because option \"-r no\" was set."
fi
# TLS v1.2 only configuration - TEPS/eWAS TEP, IHS, TEPS,  components
# TEPS/eWAS modify Quality of Protection (QoP)    
modQop
rc=$?
rcs=$rc

# eWAS Set custom property com.ibm.websphere.tls.disabledAlgorithms
disableAlgorithms
rc=$?
rcs=$(( $rc + $rcs ))

# eWAS sslclientprops modification
modsslclientprops "${AFILES["ssl.client.props"]}" 
rc=$?
rcs=$(( $rc + $rcs ))
# test openssl s_client -connect 172.16.11.4:15206 -tls1_2 doesn't work on windows by default. Needs to be installed first in PS (Install-Module -Name OpenSSL)

# TEPS
# cq.ini add/modify variables
modcqini "${AFILES["cq.ini"]}"
rc=$?
rcs=$(( $rc + $rcs ))

# IHS httpd.conf modification
modhttpconf "${AFILES["httpd.conf"]}" 
rc=$?
rcs=$(( $rc + $rcs ))

# restart TEPS
if  [ $rcs -eq 20 ] ; then
    echo "INFO - main - No changes, hence Tivoli Enterpise Portal Server restart not required yet."
else 
    restartTEPS
    EnableICSLite "true"
fi

# TEPS JAVA java.security modification
modjavasecurity "${AFILES["java.security"]}"
rc=$?

# Browser/WebStart client related
modtepjnlpt "${AFILES["tep.jnlpt"]}"
rc=$?
rcs=rc
modcompjnlpt "${AFILES["component.jnlpt"]}"
rc=$?
rcs=$(( $rc + $rcs ))
modapplethtmlupdateparams "${AFILES["applet.html.updateparams"]}"
rc=$?
rcs=$(( $rc + $rcs ))
if [ $rcs -eq 12 ] ; then
    echo "INFO - main - No changes hence no need to reconfigure CW"
else 
    echo "INFO - main - Reconfiguring CW"
    ${ITMHOME}/bin/itmcmd config -A cw
    if [ $? -ne 0 ] ; then
        echo "ERROR - main - Reconfigure of TEP WebSstart/Broswer client '${ITMHOME}/bin/itmcmd config -A kcw' failed. Script ended!"
        exit 1
    fi
fi

# Desktop client related
if [ $KCJ -eq 4 ] ; then
    echo "WARNING - main - TEP Desktop client not installed and was not modified ('kcjparms.txt' not existing)."
else
    modkcjparmstxt "${AFILES["kcjparms.txt"]}"
    rc=$?
    if [ $rc -eq 4 ] ; then
        echo "INFO - main - No changes hence no need to reconfigure KCJ"
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
if [ "$BACKUP" == "yes" ] ; then
    echo " - Original files saved in folder $BACKUPFOLDER "
    echo " - To restore the level before update run '$BACKUPFOLDER/$RESTORESCRIPT' "
else
    echo "WARNING - main - Backup was NOT done because option \"-b no\" was set"
fi
echo "----- POST script execution steps ---" 
echo " - Reconfigure TEPS and verify connections for TEP, TEPS, HUB" 
echo " - To check eWAS settings use: https://${host}:15206/ibm/console/login"
echo " - To check TEP WebStart  use: https://${host}:15201/tep.jnlp"
echo "------------------------------------------------------------------------------------------"

exit 0
