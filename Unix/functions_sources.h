#!/bin/bash
# This functions are sourced and used by the "activate_teps-tlvs.sh" procedure.
# You can also source and used it one by one in the command line but it is required
# to source the init_tlsv[n.n] first and then init_global_vars.h before 
# execution.
# 
# 20.07.2022: Version 2.0      R. Niewolik EMEA AVP Team 
#             - Complete redesign of the script released on 20.04.2022. 
#               Splittet main script into this function file and two 
#               files to set variables
#             - Added new function importSelfSignedToJREcacerts to allow https tepslogin 
#             - Modified saveorgcreatenew
# 22.07.2022: Version 2.1      R. Niewolik EMEA AVP Team
#             - Modified modjavasecurity to support "\" in jdk.tls.disabledAlgorithms value (set in init_tlsvn.n)
# 28.07.2022: Version 2.2      R. Niewolik EMEA AVP Team
#             - removed modkcjparmstxt, add modcjenvironment to support TEPD (CJ) TLSv1.n changes
#             - made grep and match case insensitive
# 27.09.2022: Version 2.3 R. Niewolik EMEA AVP Team
#             - Function modhttpconf was modified to evaluate new variable HTTPD_DISABLE_15200 
#               Now it will be exeuted:  modhttpconf [httpd.conf file] [yes,no].
#               It was done to control if the HTTP port 15200 should be still allowed to be accessed outside of the localhost. 
#             - Function modkfwenv was modfied to support KFW_ORBPARM for TEPS version >= 6.3 fp7 sp8
#             - Modified function importSelfSignedToJREcacerts to check if label "IBM_Tivoli_Monitoring_Certificate" exists in $KEYKDB.
#               If not function returns rc=5 and Self Signed Cert is not copied from $KEYKDB To JRE cacerts 
##
##

if [ $1 ] ; then
    if [ -d "$1/logs" ] ; then
         export ITMHOME="$1"
    else 
        echo "ERROR - functions_sources - ITMHOME=$1 set by argument is not an ITMHOME folder"  
        return 1      
    fi
else
    if [ -z $CANDLEHOME ] ; then
        echo "ERROR - functions_sources - Variable CANDLEHOME doesn't exists. ITMHOME cannot be evaluated"
        sourcefilename=$0
        echo  "Please use \". ./init_global_vars [path to ITMHOME]\" (e.g. . ./init_global_vars /opt/IBM/ITM) to set the correct path"
        return 1
    else
        if [ -d  "$CANDLEHOME" ] ; then
            export ITMHOME=$CANDLEHOME
        else
            echo "ERROR - functions_sources - ITM home folder cannot be evaluated, CANDLEHOME=$CANDLEHOME doesn't exists"
            echo "Please set the correct path \". ./init_global_vars [path to ITMHOME]\" (e.g. . ./init_global_vars /opt/IBM/ITM)"
            return 1
        fi
    fi
fi

if [ ! $2 ] ; then
    ARCH=`${ITMHOME}/bin/cinfo -d cq|grep "cq.*Tivoli Enterprise Portal Server"|awk -F'","' '{print $3}'`
    if [ -d "${ITMHOME}/${ARCH}/iw" ]; then
        export ARCH=$ARCH
    else
        echo "ERROR - functions_sources - ARCH folder cannot be evaluated (TEPS apparently not installed: ${ITMHOME}/${ARCH}/iw is not existing"
        echo "Please set the correct path \". ./init_global_vars [path to ITMHOME]\" (e.g. . ./init_global_vars /opt/IBM/ITM lx8266)"
        return 1
    fi
else
    if [ -d "${ITMHOME}/$2/iw" ]; then
        export ARCH=$2
    else
        echo "ERROR - functions_sources  - The ARCH folder name $2 is not correct: '${ITMHOME}/$2/iw'. Please check and restart."  
        return 
    fi 
fi

# initialize global variables
if [ -f init_global_vars ] ; then 
   source ./init_global_vars $ITMHOME $ARCH
   if [ $? -ne 0 ] ; then 
       return 1
   fi 
else 
  echo "ERROR - functions_sources - File init_global_vars doesn't exists in the current directory"
  return 1
fi

# ---------
# Functions
# ---------
backupfile ()  # e.g backupfile "${AFILES["httpd.conf"]}" 
{ 
  # this function saves files which will be modified
  filen=$1
  if [ -f $filen  ] ; then 
      echo "INFO - backupfile - Saving $filen in $BACKUPFOLDER "
      \cp -p $filen $BACKUPFOLDER/.
      if [ $? -ne 0 ] ; then
          echo "ERROR - backupfile - Error during copy of file $filen to $BACKUPFOLDER. Check permissions and space available."
          return 1
      fi
  else
      echo "ERROR - backupfile - File $filen does not exists."
      return 1
  fi

  return 0
}  
  
backupewasAndKeyfiles() #  backupewasAndKeyfiles
{
  echo "INFO - backup - Saving Directory $ITMHOME/$ARCH/iw in $BACKUPFOLDER. This can take a while..." 
  \cp -pR $ITMHOME/$ARCH/iw  $BACKUPFOLDER/ 
  if [ $? -ne 0 ]; then
      echo "ERROR - backup - Could not backup  $ITMHOME/$ARCH/iw to folder $BACKUPFOLDER. Check permissions and space."
      return 1
  fi 
  echo "INFO - backup - Saving $ITMHOME/keyfiles/ in $BACKUPFOLDER..." 
  \cp -pR  $ITMHOME/keyfiles/ $BACKUPFOLDER/ 
  if [ $? -ne 0 ]; then
      echo "ERROR - backup - Could not backup  $ITMHOME/keyfiles/ to folder $BACKUPFOLDER. Check permissions and space."
      return 1
  fi 
  return 0
}

createRestoreScript () # createRestoreScript
{
  restorebatfull="$BACKUPFOLDER/$RESTORESCRIPT"
  if [ -f  $restorebatfull ] ; then 
      echo "INFO - createRestoreScript - Script $restorebatfull exists already and will be deleted"
      rm -f $restorebatfull
  fi
  touch $restorebatfull 
  chmod 755 $restorebatfull
  echo "set -x" >>  $restorebatfull 
  echo "cd $BACKUPFOLDER" >> $restorebatfull
  echo "" >>  $restorebatfull 
  echo "\cp -pR iw $ITMHOME/$ARCH/." >> $restorebatfull
  echo "\cp -pR keyfiles $ITMHOME/." >> $restorebatfull
  echo "" >>  $restorebatfull 
  for filename in "${!AFILES[@]}"; do
      if [[ $filename =~ "cj\.environment" ]] && [[ $KCJ -eq 4 ]] ; then
          #echo "WARNING - createRestoreScript - TEP Desktop Client apparently not installed. File 'cj.environment' not added to restore script"
          continue
      fi
      echo "\cp -p $filename ${AFILES[$filename]} " >> $restorebatfull   
      echo "rm -f ${AFILES[$filename]}.before${TLSVER}" >> $restorebatfull   
      echo "rm -f ${AFILES[$filename]}.${TLSVER}" >> $restorebatfull  
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

EnableICSLite () # EnableICSLite "true" (or "false")
{
  echo "INFO - EnableICSLite - Set ISCLite to '$1' "
  ${ITMHOME}/$ARCH/iw/scripts/enableISCLite.sh $1
  if  [ $? -ne 0 ] ; then
      echo "ERROR - EnableICSLite - Enable ISCLite command $cmd failed. Possibly you did not set a eWAS user password. "
      echo " Try to set a password as descirbed here https://www.ibm.com/docs/en/tivoli-monitoring/6.3.0?topic=administration-define-wasadmin-password" 
      echo " Script ended!"
      return 1
  fi
}

restartTEPS () # restartTEPS
 {
  echo  "INFO - restartTEPS - Restarting TEPS ..." 
  $ITMHOME/bin/itmcmd agent stop cq 
  $ITMHOME/bin/itmcmd agent start cq
  if [ $? -ne 0 ]; then
      echo "ERROR - restartTEPS - TEPS restart failed. Powershell script ended!"
      return 1
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
              return 1
          fi
      done
      sleep 5
  fi
}

checkIfFileExists () # checkIfFileExists
{
  # this function checks if the files to backup exists
  if [ -d "$ITMHOME/$ARCH/iw" ]; then
      echo "INFO - checkIfFileExists - Directory $ITMHOME/$ARCH/iw  OK."
  else
      echo "ERROR - checkIfFileExists - Directory $ITMHOME/$ARCH/iw  does NOT exists. Please check."
      return 1
  fi
  if [ -d "$ITMHOME/keyfiles" ]; then
      echo "INFO - checkIfFileExists - Directory $ITMHOME/keyfiles  OK."
  else
      echo "ERROR - checkIfFileExists - Directory $ITMHOME/keyfiles  does NOT exists. Please check."
      return 1
  fi
  
  for filename in "${!AFILES[@]}"; do
      if [ -f ${AFILES[$filename]}  ] ; then 
          echo "INFO - checkIfFileExists - File ${AFILES[$filename]} OK."
          if [[ $filename =~ "cj.environment" ]] ; then KCJ=0 ; fi
      else
          if [[ $filename =~ "cj.environment" ]] ; then
              if [ -d ${ITMHOME}/${ARCH}/cj/bin ] ; then
                  echo "INFO - checkIfFileExists - File ${AFILES[$filename]} does not exists but CJ installed. File will be created "
                  touch ${AFILES[$filename]}
                  chmod 755 ${AFILES[$filename]}
                  echo "# cj env file" > ${AFILES[$filename]}
                  KCJ=0
              else
                  echo "WARNING - checkIfFileExists - File ${AFILES[$filename]} does NOT exists. KCJ component probably not installed. Continue..."
                  KCJ=4 # will be used later in activate_teps-tlsv.sh and function createRestoreScript
              fi             
          else
              echo "ERROR - checkIfFileExists - file ${AFILES[$filename]} does NOT exists. Please check."
              return 1
          fi
      fi      
  done
  
  return 0
}  

saveorgcreatenew () 
{
  orgfile=$1
  NEWORGFILE="${orgfile}.${TLSVER}"
  SAVEORGFILE="${orgfile}.before${TLSVER}"

  if [ -f $SAVEORGFILE ] ; then 
      echo "INFO - saveorgcreatenew - $SAVEORGFILE exists and will be deleted"
      rm -f $SAVEORGFILE
  fi 
  \cp -p $orgfile $SAVEORGFILE
  
  if [ -f $NEWORGFILE ] ; then
      echo "INFO - saveorgcreatenew - $NEWORGFILE exists already and will be deleted"
      rm -f $NEWORGFILE 
  fi
  touch $NEWORGFILE; chmod 755 $NEWORGFILE
  
  return 0
}

modhttpconf () # modhttpconf [path to httpd.conf]
{ 
  # returns rc=4 if file already modified 
  httpdfile=$1
  HTTPD_DISABLE_15200=$2
  if [ "$2" = "" ] ; then
      echo "ERROR - modhttpconf - You must provide a second parameter to control whether external TEPS login on port 15200 should be disabled or not"
      echo "ERROR - modhttpconf - For example 'modhttpconf [path to httpd.conf] yes' to disable or 'modhttpconf [path to httpd.conf] no' to not disable"
      return 1
  elif [ "$2" != "no" ] && [ "$2" != "yes"  ] ; then
      echo "ERROR - modhttpconf - Bad execution syntax. 'modhttpconf [path to httpd.conf] [yes/no]' "
      return 1
  fi
  ver=`echo $TLSVER| sed 's/\.//g'` # change TLSvn.n to TLSvnn
  tlsvdis=`echo $KDEBE_TLS_DISABLE| sed 's/,/ /g'` # change "," to  " " if there 
  #grep -i "^\s*SSLProtocolDisable\s*TLSv11"  $httpdfile | grep "^[^#].*" > /dev/null
  i1=0
  i2=0
  for p in $tlsvdis ; do
      pn=`echo $p | sed 's/TLS/TLSv/'` # change TLSnn to TLSvnn
      grep -i "^\s*SSLProtocolDisable\s*$pn"  $httpdfile | grep "^[^#].*" > /dev/null
      it=$?
      i1=$(( i1+it ))
  done
  if [ $i1 -eq 0 ] ; then
      grep -i "^\s*SSLProtocolEnable\s*$ver"  $httpdfile | grep "^[^#].*" > /dev/null
      it=$?
      if [  $? -eq 0  ] ; then
          echo "INFO - modhttpconf - $httpdfile contains 'SSLProtocolEnable $ver' + TLS10,11,.. disabled and will not be modified"
          return 4
      else
         i2=$(( i2+it  ))
      fi
  fi
  echo "INFO - modhttpconf - Modifying $httpdfile ($i1,$i2)"
  echo "INFO - modhttpconf - TEPS port 15200 control set to 'HTTPD_DISABLE_15200=$HTTPD_DISABLE_15200'"
  
  saveorgcreatenew $httpdfile
  newhttpdfile=$NEWORGFILE
  savehttpdfile=$SAVEORGFILE
  
  foundsslcfg=1
  #echo "DEBUG - modhttpconf - $NEWORGFILE $SAVEORGFILE " ; 
  shopt -s nocasematch
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
          temp="ServerName ${BASH_REMATCH[1]}:$TEPSHTTPSPORT"
          grep "^\s*$temp" $savehttpdfile > /dev/null
          if [ $? -eq 0 ] ; then 
              echo "INFO - modhttpconf - '$temp' exists already"
          else
              echo "INFO - modhttpconf - adding $temp"
              echo "$temp" >> $newhttpdfile
          fi
          if [ "$HTTPD_DISABLE_15200" = "yes" ] ; then
              echo "#${line}" >> $newhttpdfile
          else
              echo "${line}" >> $newhttpdfile
          fi
          continue
      fi
      tregex='^Listen[[:space:]]*15200'
      if [[ $line =~ $tregex ]] ; then
          if [ "$HTTPD_DISABLE_15200" =  "yes" ] ; then
              echo "Listen 127.0.0.1:15200" >> $newhttpdfile
              echo "#${line}" >> $newhttpdfile
          else
              echo "${line}" >> $newhttpdfile
          fi
          continue
      fi
      if [ $foundsslcfg -eq 1 ] ; then  
          if [ "$line" = "<VirtualHost *:$TEPSHTTPSPORT>" ] ; then
              #echo Debug -modhttpconf-----line= $line -- foundsslcfg= $foundsslcfg 
              foundsslcfg=0
              echo "$line" >> $newhttpdfile
              temp="  DocumentRoot \"${ITMHOME}/$ARCH/cw\""
              echo $temp >> $newhttpdfile
              echo "  SSLEnable" >> $newhttpdfile
              echo "  SSLProtocolDisable SSLv2" >> $newhttpdfile
              echo "  SSLProtocolDisable SSLv3" >> $newhttpdfile
              for p in $tlsvdis ; do
                  pn=`echo $p | sed 's/TLS/TLSv/'` # change TLSnn to TLSvnn  
                  echo "  SSLProtocolDisable $pn" >> $newhttpdfile
              done               
              echo "  SSLProtocolEnable $ver" >> $newhttpdfile
              echo "  SSLCipherSpec ${HTTP_SSLCIPHERSPEC}" >> $newhttpdfile
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
  shopt -u nocasematch 
  \cp -p $newhttpdfile $httpdfile
  echo "INFO - modhttpconf - $newhttpdfile created and copied on $httpdfile"  

  #echo Debug ------line= $line -- foundsslcfg= $foundsslcfg
}

modcqini () # modcqini [path to cq.ini]
{ 
  # returns rc=4 if file already modified 
  cqini=$1
  tepsver_sp8=06300710
  tepsver_current=`${ITMHOME}/bin/cinfo -d cq | grep "cq.*Tivoli Enterprise Portal Server" | awk -F'","' '{print $4}'`
  ver=`echo ${TLSVER^^} | sed 's/\.//g'` # change e.g. from TLSvn.n to TLSVnn
  # KFW_ORB_ENABLED_PROTOCOLS used for TEPS vers < 6.3 FP7 SP8 
  vtmp=`echo $TLSVER | cut -d'v' -f2| sed 's/\./_/'` # will be e.g. "1_2"
  KFW_ORB_ENABLED_PROTOCOLS="TLS_Version_${vtmp}_Only" 
  # KFW_ORBPARM used for TEPS vers >= 6.3 FP7 SP8
  vtmp2=`echo $TLSVER | sed 's/TLSv/TLS/' | sed 's/\./_/'` # change from TLSvn.n to TLSn_n
  KFW_ORBPARM="-Dvbroker.security.server.socket.minTLSProtocol=$vtmp2 -Dvbroker.security.server.socket.maxTLSProtocol=TLS_MAX" 

  i1=0
  if [ $tepsver_current -lt $tepsver_sp8 ] ; then
      grep -i "KFW_ORB_ENABLED_PROTOCOLS=$KFW_ORB_ENABLED_PROTOCOLS" $cqini | grep "^[^#].*"  > /dev/null
      i1=$?
      if  [ $i1 -eq 0 ] ; then message="contains 'KFW_ORB_ENABLED_PROTOCOLS=$KFW_ORB_ENABLED_PROTOCOLS'" ; fi
  else
      grep -i "KFW_ORBPARM=" $cqini | grep "^[^#].*"  > /dev/null
      if [ $? -eq 0 ] ; then 
          for p in $KFW_ORBPARM 
          do
              temp=`echo $p | sed 's/-//g'`
              grep -i "$temp" $cqini | grep "^[^#].*"  > /dev/null
              it=$?
              i1=$(( i1+it ))
          done 
          if  [ $i1 -eq 0 ] ; then message="contains 'KFW_ORBPARM=$KFW_ORBPARM'" ; fi
      else
          i1=4    
      fi
  fi
  if [ $i1 -eq 0 ] ; then
      grep -i "KDEBE_${ver}_CIPHER_SPECS=$KDEBE_TLSVNN_CIPHER_SPECS" $cqini | grep "^[^#].*" > /dev/null
      if [  $? -eq 0  ] ; then
          echo "INFO - modcqini - $message  and the '$KDEBE_TLSVNN_CIPHER_SPECS' and will not be modified"
          return 4
      fi
  fi
  echo "INFO - modcqini - Modifying $cqini"
  
  saveorgcreatenew $cqini
  newcqini=$NEWORGFILE
  savecqini=$SAVEORGFILE
  
  tlsvdis=`echo $KDEBE_TLS_DISABLE| sed 's/,/ /g'`
  ver=`echo ${TLSVER^^} | sed 's/\.//g'` # change from TLSvn.n to TLSVnn
  foundORBENABLED=1
  foundORBPARM=1
  foundTLSdisable=1
  foundTLSn=1
  shopt -s nocasematch
  while IFS= read -r line || [[ -n "$line" ]]
  do
      #echo "DEBUG - modcqini : $line"
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newcqini 
          #echo  "DEBUG - modcqini - line=$line"
	        continue 
      fi    
      if [[ $line =~ .*KFW_ORB_ENABLED_PROTOCOLS.* ]] ; then 
          if [ $tepsver_current -lt $tepsver_sp8 ] ; then
              #vtmp=`echo $TLSVER | cut -d'v' -f2| sed 's/\./_/'` # will be e.g. "1_2" 
              echo "KFW_ORB_ENABLED_PROTOCOLS=$KFW_ORB_ENABLED_PROTOCOLS" >> $newcqini 
              foundORBENABLED=0
          else 
              echo "#$line" >> $newcqini         
          fi
      elif [[ $line =~ .*KFW_ORBPARM.* ]] ; then
          if [ $tepsver_current -lt $tepsver_sp8 ] ; then
              echo "$line" >> $newcqini
          else 
              #echo "#$line" >> $newcqini
              echo "$line $KFW_ORBPARM" >> $newcqini
              foundORBPARM=0
          fi
      elif [[ $line =~ .*KDEBE_(TLS[0-9]{2})_ON.* ]] ; then
          if [ $foundTLSdisable -eq 1 ] ; then
              for p in $tlsvdis ; do  echo "KDEBE_${p}_ON=NO" >> $newcqini ; done
              foundTLSdisable=0 
          fi    
      elif [[ $line =~ .*KDEBE_.*_CIPHER_SPECS.* ]]; then
          echo "KDEBE_${ver}_CIPHER_SPECS=$KDEBE_TLSVNN_CIPHER_SPECS" >> $newcqini 
          foundTLSn=0 
      else 
          echo "${line}" >> $newcqini  
      fi
  done < $SAVEORGFILE
  shopt -u nocasematch
  
  #echo "DEBUG - modcqini - foundORBENABLED=$foundKFWORB foundORBPARM=$foundORBPARM foundTLSdisable=$foundTLSdisable foundTLSn=$foundTLSn"
  if [ $tepsver_current -lt $tepsver_sp8 ] ; then
      if [ $foundORBENABLED -eq 1 ] ; then echo "KFW_ORB_ENABLED_PROTOCOLS=$KFW_ORB_ENABLED_PROTOCOLS" >> $newcqini ; fi  
  else
      if [ $foundORBPARM -eq 1 ]    ; then echo "KFW_ORBPARM=$KFW_ORBPARM" >> $newcqini ; fi  
  fi
  if [ $foundTLSdisable -eq 1 ] ; then for p in $tlsvdis ; do  echo "KDEBE_${p}_ON=NO" >> $newcqini ; done ; fi
  if [ $foundTLSn -eq 1 ]       ; then echo "KDEBE_${ver}_CIPHER_SPECS=$KDEBE_TLSVNN_CIPHER_SPECS">> $newcqini ; fi
  \cp -p $newcqini $cqini 
  echo  "INFO - modcqini - $newcqini created and copied on $cqini"  
  return 0
}

modtepjnlpt () # modtepjnlpt [path to tep.jnlpt]
{ 
  # returns rc=4 if file already modified 
  tepjnlpt=$1
  grep -i "^\s*<property name=\"jnlp.tep.sslcontext.protocol.*$TLSVER" $tepjnlpt > /dev/null
  if [ $? -eq 0 ] ; then
      grep -i "\s*codebase=\"https.*:$TEPSHTTPSPORT" $tepjnlpt > /dev/null
      if [ $? -eq 0 ] ; then
          echo "INFO - modtepjnlpt - $tepjnlpt contains 'jnlp.tep.sslcontext.protocol value=\"$TLSVER\"' and will not be modified"
          return 4
      fi
  fi
  echo  "INFO - modtepjnlpt - Modifying $tepjnlpt"
  
  saveorgcreatenew $tepjnlpt
  newtepjnlpt=$NEWORGFILE
  savetepjnlpt=$SAVEORGFILE
  
  foundprotocol=1
  foundport=1
  foundTLSn=1
  shopt -s nocasematch
  while IFS= read -r line || [[ -n "$line" ]]
  do
      echo $line | grep '\s*<!--' > /dev/null
      if [ $? -eq 0 ] ; then
          echo "${line}" >> $newtepjnlpt
      elif [[ $line =~ Codebase.*http://\$HOST\$:\$PORT\$ ]] ; then
          #echo "DEBUG - modtepjnlpt - codebase found $TEPSHTTPSPORT "
          echo "  codebase=\"https://\$HOST\$:$TEPSHTTPSPORT/\"> " >> $newtepjnlpt 
      elif [[ $line =~ \s*\<property.name\=.*jnlp.tep.connection.protocol[^\.].*value  ]] ; then
          #echo "DEBUG - modtepjnlpt - protocol found \"$line\" "; 
          echo "    <property name=\"jnlp.tep.connection.protocol\" value=\"https\"/> "  >> $newtepjnlpt 
          foundprotocol=0
      elif [[ $line =~ \s*\<property.name\=.jnlp.tep.connection.protocol.url.port.*value ]] ; then
          #echo "DEBUG - modtepjnlpt - port found \"$line\" "; 
          echo "    <property name=\"jnlp.tep.connection.protocol.url.port\" value=\"$TEPSHTTPSPORT\"/> "  >> $newtepjnlpt 
          foundport=0
      elif [[ $line =~ \s*\<property.name\=.jnlp.tep.sslcontext.protocol.*value ]] ; then
          #echo "DEBUG - modtepjnlpt - TLS found \"$line\" "; 
          echo "    <property name=\"jnlp.tep.sslcontext.protocol\" value=\"$TLSVER\"/> "  >> $newtepjnlpt 
          foundTLSn=0
      else 
          echo "${line}" >> $newtepjnlpt 
      fi
  done < $savetepjnlpt
  shopt -u nocasematch

  count=$(( foundprotocol+foundport+foundTLSn ))
  #echo "DEBUG - modtepjnlpt - c=$count foundprotocol=$foundprotocol foundport=$foundport foundTLSn=$foundTLSn"

  if [ $count -gt 0 ] ; then
      tempfile="$newtepjnlpt.temporaryfile"
      touch $tempfile
      chmod 755 $tempfile
      while IFS= read -r line || [[ -n "$line" ]]
      do
          if [[ $line =~ .*\ Custom.parameters.*\> ]] ; then
              #echo "DEBUG - Custom parameters found"
              echo "$line" >> $tempfile           
              if [ $foundprotocol -eq 1 ] ; then echo "    <property name=\"jnlp.tep.connection.protocol\" value=\"https\"/> " >> $tempfile ; fi
              if [ $foundport -eq 1 ] ;     then echo "    <property name=\"jnlp.tep.connection.protocol.url.port\" value=\"$TEPSHTTPSPORT\"/> "  >> $tempfile ; fi
              if [ $foundTLSn -eq 1 ] ;     then echo "    <property name=\"jnlp.tep.sslcontext.protocol\" value=\"$TLSVER\"/> " >> $tempfile ; fi
              #echo '    <!-- /Custom parameters -->' >> $tempfile
          else 
              #echo "DEBUG - modtepjnlpt -  ${line}" 
              echo "${line}"  >> $tempfile 
          fi
      done < $newtepjnlpt
      \cp $tempfile $newtepjnlpt
      rm -f $tempfile
  fi
  
  \cp -p $newtepjnlpt $tepjnlpt
  echo  "INFO - modtepjnlpt - $newtepjnlpt created and copied on $tepjnlpt"
  return 0
}

modcompjnlpt () #  modcompjnlpt [path to component.jnlpt]
{ 
  # returns rc=4 if file already modified 
  compjnlpt=$1
  grep -i "\s*codebase=\"https.*:$TEPSHTTPSPORT" $compjnlpt > /dev/null
  if [  $? -eq 0  ] ; then
      echo "INFO - modcompjnlpt - $compjnlpt contains 'codebase=https..:$TEPSHTTPSPORT' and will not be modified"
      return 4
  else
      echo "INFO - modcompjnlpt - Modifying $compjnlpt"
  fi
  
  saveorgcreatenew $compjnlpt
  newcompjnlpt=$NEWORGFILE
  savecompjnlpt=$SAVEORGFILE
  
  \cp $savecompjnlpt $newcompjnlpt
  sed -i -e "s/\\\$PORT\\$/$TEPSHTTPSPORT/g"  $newcompjnlpt
  sed -i -e "s/http:/https:/g"  $newcompjnlpt
  
  \cp -p $newcompjnlpt $compjnlpt
  echo  "INFO - modcompjnlpt - $newcompjnlpt created and copied on $compjnlpt"
  return 0
}

modapplethtmlupdateparams () #  modapplethtmlupdateparams [path to applet.html.updateparams]
{ 
  # returns rc=4 if file already modified 
  applethtmlupdateparams=$1
  grep -i "tep.sslcontext.protocol.*verride.*$TLSVER" $applethtmlupdateparams | grep "^[^#].*" > /dev/null
  if [  $? -eq 0  ] ; then
      grep -i "tep.connection.protocol.*verride.*https" $applethtmlupdateparams | grep "^[^#].*" > /dev/null
      if [  $? -eq 0  ] ; then
          echo "INFO - modapplethtmlupdateparams - $applethtmlupdateparams contains \"tep.sslcontext.protocol|override|'$TLSVER'\" and will not be modified"
          return 4
      fi  
  fi
  echo "INFO - modapplethtmlupdateparams - Modifying $applethtmlupdateparams"
  
  saveorgcreatenew $applethtmlupdateparams
  newapplethtmlupdateparams=$NEWORGFILE
  saveapplethtmlupdateparams=$SAVEORGFILE
  foundprotocol=1
  foundport=1
  foundTLSn=1
  shopt -s nocasematch
  while IFS= read -r line || [[ -n "$line" ]]
  do
      if [ "${line:0:1}" = "#" ] ; then
          echo "$line"  >> $newapplethtmlupdateparams 
      elif [[ $line =~ tep.connection.protocol\|.* ]]; then
          echo "tep.connection.protocol|override|'https'" >> $newapplethtmlupdateparams
          foundprotocol=0
      elif [[ $line =~ tep.connection.protocol.url.port.* ]]; then
          echo "tep.connection.protocol.url.port|override|'$TEPSHTTPSPORT'" >> $newapplethtmlupdateparams
          foundport=0
      elif [[ $line =~ tep.sslcontext.protocol\|.* ]]; then
          echo "tep.sslcontext.protocol|override|'$TLSVER'" >> $newapplethtmlupdateparams
          foundTLSn=0
      else 
          echo  "${line}" >> $newapplethtmlupdateparams
      fi
  done < $saveapplethtmlupdateparams
  shopt -u nocasematch
  
  count=$(( foundprotocol+foundport+foundTLSn))
  if [ $count -gt 0 ] ; then
      #echo "-DEBUG-modapplethtmlupdateparams----- c=$count --foundprotocol=$foundprotocol foundport=$foundport foundTLSn=$foundTLSn"
      if [ $foundprotocol -eq 1 ] ; then echo "tep.connection.protocol|override|'https'" >> $newapplethtmlupdateparams ;fi
      if [ $foundport -eq 1  ] ;    then echo "tep.connection.protocol.url.port|override|'$TEPSHTTPSPORT'" >> $newapplethtmlupdateparams ;fi
      if [ $foundTLSn -eq 1 ] ;     then echo "tep.sslcontext.protocol|override|'$TLSVER'" >> $newapplethtmlupdateparams; fi
  fi
  \cp -p $newapplethtmlupdateparams $applethtmlupdateparams
  echo "INFO - modapplethtmlupdateparams - $newapplethtmlupdateparams created and copied on $applethtmlupdateparams"
  return 0
}

modcjenvironment () # modcjenvironment [path to cj.environment]
{ 
  # returns rc=4 if file already modified 
  cjenvironment=$1
  grep -i "\-Dtep.sslcontext.protocol=$TLSVER" $cjenvironment | grep "^[^#].*" > /dev/null
  if [  $? -eq 0  ] ; then
      grep -i "\-Dtep.connection.protocol=https" $cjenvironment | grep "^[^#].*" > /dev/null
      if [  $? -eq 0  ] ; then
          echo "INFO - modcjenvironment - $cjenvironment contains\"-Dtep.sslcontext.protocol=$TLSVER\" and will not be modified"
          return 4 
      fi
  fi      
  echo "INFO - modcjenvironment - Modifying $cjenvironment"
  
  saveorgcreatenew $cjenvironment
  newcjenvironment=$NEWORGFILE
  savecjenvironment=$SAVEORGFILE 
  
  foundjavaargs=1
  foundtepjavahome=1
  shopt -s nocasematch
  while IFS= read -r line || [[ -n "$line" ]]
  do
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newcjenvironment   
      elif [[ $line =~ IBM_JVM_ARGS ]] ; then
          echo  "#${line}" >>  $newcjenvironment
          echo "IBM_JVM_ARGS=\"-Xgcpolicy:gencon -Xquickstart -Dtep.connection.protocol=https -Dtep.connection.protocol.url.port=$TEPSHTTPSPORT -Dtep.sslcontext.protocol=$TLSVER\"" >> $newcjenvironment
          foundjavaargs=0
      elif [[ $line =~ TEP_JAVA_HOME ]] ; then
          echo  "#${line}" >>  $newcjenvironment
          echo "${line}" >> $newcjenvironment
          foundtepjavahome=0
      else 
          echo  "${line}" >>  $newcjenvironment
      fi 
  done < $savecjenvironment
  shopt -u nocasematch
  #echo "DEBUG - modcjenvironment - foundjavaargs=$foundjavaargs foundtepjavahome=$foundtepjavahome"
  if [ $foundjavaargs -eq 1 ] ; then 
      echo "IBM_JVM_ARGS=\"-Xgcpolicy:gencon -Xquickstart -Dtep.connection.protocol=https -Dtep.connection.protocol.url.port=$TEPSHTTPSPORT -Dtep.sslcontext.protocol=$TLSVER\"" >> $newcjenvironment ;fi
  if [ $foundtepjavahome -eq 1 ] ; then 
      # TEP_JAVA_HOME is required, otherwise IBM_JAVA_ARGUMENTS is overwritten by the "itmcmd agent start cj" command
      echo "TEP_JAVA_HOME=$JAVAHOME" >> $newcjenvironment 
  fi

  \cp $newcjenvironment $cjenvironment 
  echo "INFO - modcjenvironment - $newcjenvironment created and copied on $cjenvironment"
  return 0
}

modjavasecurity () # modjavasecurity [path to java.security]
{ 
  # returns rc=4 if file already modified 
  javasecurity=$1
  tempvarset=".temp#variable_set.txt"
  tempvarval=".temporary#variable_values.txt"
  echo "${JAVASEC_DISABLED_ALGORITHMS}" |  
   awk '{ n = split($0, t, "\\")
     for (i = 0; ++i <= n;)
        print t[i]
     }' > $tempvarval
     
  varlines=`cat $tempvarval| wc -l`
  slash=`echo "${JAVASEC_DISABLED_ALGORITHMS}" | grep '\\\'`
  if [ $? -eq 0 ] ; then
      c=0
      f=0 # counts value matches
      #echo "DEBUG - f=$f varlines=$varlines"
      while IFS= read -r tl || [[ -n "$tl" ]]
      do
         c=$(( $c + 1 ))
         part=`echo "${tl}" | cut -d'\' -f1 | sed 's/ /\.*/g'`
         if [ $c -eq 1 ] ; then
             #echo "DEBUG - first=$tl"             
             grep -i "jdk.tls.disabledAlgorithms=${part}" $javasecurity | grep "^[^#].*" > /dev/null
             if [ $? -eq 0  ] ; then f=$(( $f + 1 )) ; fi        
         else
             #echo "DEBUG - following=$tl"
             grep -i "${part}" $javasecurity | grep "^[^#].*" > /dev/null
             if [ $? -eq 0  ] ; then f=$(( $f + 1 )) ; fi
         fi
      done < $tempvarval
      #echo "DEBUG - f=$f varlines=$varlines"
      if [ $f -eq $varlines ] ; then
          echo "INFO - modjavasecurity - $javasecurity contains \"jdk.tls.disabledAlgorithms=${JAVASEC_DISABLED_ALGORITHMS}\" and will not be modified."
          rm -f $tempvarval
          return 4     
      fi
  else
      tempalg=`echo ${JAVASEC_DISABLED_ALGORITHMS} | sed 's/ /\.*/g'`
      grep -i "jdk.tls.disabledAlgorithms=${tempalg}" $javasecurity | grep "^[^#].*" > /dev/null
      if [  $? -eq 0  ] ; then
          echo "INFO - modjavasecurity - $javasecurity contains \"jdk.tls.disabledAlgorithms=${JAVASEC_DISABLED_ALGORITHMS}\" and will not be modified"
          return 4
      fi
  fi
  
  echo "INFO - modjavasecurity - Modifying $javasecurity"

  saveorgcreatenew $javasecurity
  newjavasecurity=$NEWORGFILE
  savejavasecurity=$SAVEORGFILE

  c=0
  while IFS= read -r tl || [[ -n "$tl" ]]
  do
      c=$(( $c + 1 ))
      if [ $varlines -eq 1 ] ; then
          echo "jdk.tls.disabledAlgorithms=$tl"  > $tempvarset
      elif [ $c -eq 1 ] ; then
          echo "jdk.tls.disabledAlgorithms=$tl \\"  > $tempvarset
      elif [ $c -eq $varlines ] ; then
          echo "$tl"     >> $tempvarset
      else
          echo "$tl \\"  >> $tempvarset
      fi   
  done < $tempvarval
  
  nextline=1
  foundAlgo=2
  while IFS= read -r line || [[ -n "$line" ]]
  do  
      tline=`echo $line | awk '{$1=$1};1'` # trim leadin and trailing white spaces 
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newjavasecurity   
          continue 
      fi
      #echo "DEBUG- nextline=$nextline foundAlgo=$foundAlgo"
      if [ $foundAlgo -eq 0 ] ; then
          if [ $nextline -eq 0 ]  ; then
              if [[ $tline == *\\ ]]; then
                  #echo "DEBUG- write - $nextline $foundAlgo - with back #"
                  echo "#${line}" >> $newjavasecurity
              else
                  #echo "DEBUG- write - $nextline  $foundAlgo - $line"
                  echo "#${line}" >> $newjavasecurity # current line = line after var
                  cat $tempvarset >> $newjavasecurity
                  foundAlgo=1
                  nextline=1
              fi
          else
              foundAlgo=1
              #echo "DEBUG- write - $nextline $foundAlgo - $line "
              cat $tempvarset >> $newjavasecurity
              echo "${line}" >> $newjavasecurity # current line = line after var
          fi
      elif [[ $line =~ jdk.tls.disabledAlgorithms ]] ; then
          #echo "DEBUG found jdk.tls.disabledAlgorithms in = $tline"
          foundAlgo=0
          if [[ $tline == *\\ ]] ; then
              #echo "DEBUG write backslash in = $tline"
              echo "#${line}" >> $newjavasecurity
              nextline=0
          else
              #echo "DEBUG NO backslas in = $tline"
              echo "#${line}" >> $newjavasecurity
          fi
      else
          #echo "DEBUG not found jdk.tls.disabledAlgorithms in = $tline"
          echo "${line}" >> $newjavasecurity
      fi
  done < $savejavasecurity
  
  if [ $foundAlgo -eq 2 ]; then
      cat $tempvarset >> $newjavasecurity
      #echo "jdk.tls.disabledAlgorithms=${JAVASEC_DISABLED_ALGORITHMS}" >> $newjavasecurity  
  fi
  
  rm -f $tempvarset $tempvarval
  \cp $newjavasecurity $javasecurity
  echo "INFO - modjavasecurity - $newjavasecurity created and copied on $javasecurity"
}

modsslclientprops () # modsslclientprops [path to ssl.client.props]
{ 
  # returns rc=4 if file already modified 
  sslclientprops=$1
  grep -i "^\s*com.ibm.ssl.protocol.*$TLSVER" $sslclientprops > /dev/null
  if [  $? -eq 0  ] ; then
      echo "INFO - modsslclientprops - $sslclientprops contains \"com.ibm.ssl.protocol=$TLSVER\" and will not be modified"
      return 4
  else 
     echo "INFO - modsslclientprops - Modifying $sslclientprops"
  fi

  saveorgcreatenew $sslclientprops
  newsslclientprops=$NEWORGFILE
  savesslclientprops=$SAVEORGFILE
  
  foundproto=1
  shopt -s nocasematch
  while IFS= read -r line || [[ -n "$line" ]]
  do  
      if [ "${line:0:1}" = "#" ] ; then
          echo  "$line"  >> $newsslclientprops    
      elif [[ $line =~ com.ibm.ssl.protocol ]] ; then
          if [[ $line =~ com.ibm.ssl.protocol=$TLSVER ]] ; then
              echo  "INFO - modsslclientprops - $sslclientprops contains 'com.ibm.ssl.protocol=$TLSVER'"
              echo "${line}" >> $newsslclientprops 
          else
              echo "com.ibm.ssl.protocol=$TLSVER" >> $newsslclientprops 
              echo "#${line}" >> $newsslclientprops 
          fi
          foundproto=0 
      else 
          echo  "${line}" >> $newsslclientprops
      fi
  done < $savesslclientprops
  shopt -u nocasematch
  
  if [ $foundproto -eq 1 ] ; then
      echo "INFO - modsslclientprops - 'com.ibm.ssl.protocol' set $TLSVER at the end of props file"
      echo  "com.ibm.ssl.protocol=$TLSVER" >> $newsslclientprops 
  fi
  \cp $newsslclientprops $sslclientprops
  echo  "INFO - modsslclientprops - $newsslclientprops created and copied on $sslclientprops"
  return 0
}

importSelfSignedToJREcacerts ()
{ 
  # returns rc=4 if file already modified and rc=5 if KEYKDB does not contain ITM selfsigned certs
  # required otherwise tacmd https tesplogin may not work
  cacerts=$1
  $GSKCAPI -cert -details -stashed -db $KEYKDB -label "IBM_Tivoli_Monitoring_Certificate"| grep "does not contain"
  if [  $? -eq 0  ] ; then
      echo "INFO - importSelfSignedToJREcacerts - $KEYKDB does not contain label 'IBM_Tivoli_Monitoring_Certificate'. Hence the self seigned certs cannot be copied to the $cacerts file. Continue..."
      return 5
  fi
  certsca=`$KEYTOOL -list -v -keystore ${cacerts}  -storepass changeit|grep -i "IBM Tivoli Monitoring Self-Signed Certificate"`
  if [ -n "$certsca" ] ; then # Checks if the length of the string is nonzero
      serialkeyfile=`$GSKCAPI -cert -details -stashed -db $KEYKDB -label "IBM_Tivoli_Monitoring_Certificate"| grep "Serial "| sed 's/ //g'| cut -d':' -f2`
      serialcacerts=`$KEYTOOL -list -v -keystore ${cacerts}  -storepass changeit |grep -i -A1 "Issuer: CN=IBM Tivoli Monitoring"| grep -i "serial" | sed 's/ //g' | cut -d':' -f2`
      if [ "$serialkeyfile" == "$serialcacerts" ] ; then 
          echo "INFO - importSelfSignedToJREcacerts - Self signed certs were alreday imported into the JRE cacerts (serial number is equal) and will not be modified"
          return 4
      else
          saveorgcreatenew $cacerts
          echo "INFO - importSelfSignedToJREcacerts - Self signed cert is different in $KEYKDB and $cacerts (serial number is different)"
          echo "INFO - importSelfSignedToJREcacerts - This new cert will be added to cacerts again (old will be deleted)"
          cacertsalias=`$KEYTOOL -list -v -keystore ${cacerts}  -storepass changeit | grep -B7 "Issuer: CN=IBM Tivoli Monitoring" | grep -i "alias"  | sed 's/ //g' | cut -d':' -f2`
          $KEYTOOL -delete -v -keystore ${cacerts}  -storepass changeit -alias "$cacertsalias"
      fi
  else
      saveorgcreatenew $cacerts
  fi
  newcacert=$NEWORGFILE
  
  echo "INFO - importSelfSignedToJREcacerts - Modifying $cacerts"
 
  rm -f $SIGNERSP12
  $GSKCAPI -cert -import -stashed -db $KEYKDB -target $SIGNERSP12 -target_pw changeit -label "IBM_Tivoli_Monitoring_Certificate" -new_label ibm_tivoli_monitoring_certificate
  $KEYTOOL -importkeystore -srckeystore $SIGNERSP12 -srcstoretype pkcs12 -srcstorepass changeit -destkeystore $cacerts -deststoretype jks -deststorepass changeit
  if [ $? -ne 0 ]; then
      echo "ERROR - importSelfSignedToJREcacerts - Error during $GSKCAPI execution. Script ended!"
      return 1
  fi
  
  \cp -p $cacerts $newcacert
  echo  "INFO - importSelfSignedToJREcacerts - Imported self signed certs into JRE cacerts"
  return 0
}

renewCert () 
{ 
  # returns rc=4 if cert not renewed because it was done recently
  keydate=`$GSKCAPI -cert -details -db $KEYKDB -stashed -label default | grep -i 'Not Before'|awk -F' : ' '{print $2}'`
  now=$(date)
  date_one=$(date -d "$keydate" +%s)
  date_two=$(date -d "$now" +%s)
  ts=$(( (date_two - date_one) / 86400 ))
  if [ $ts -lt 100 ] ; then
      echo "INFO - renewCert - Default certificate was renewed recently ($ts days ago) and will not be renewed again"
      return 4
  fi
  
  echo "INFO - renewCert - Renewing default certificate" 
  cmd1="AdminTask.renewCertificate('-keyStoreName NodeDefaultKeyStore -certificateAlias  default')"
  cmd2="AdminConfig.save()"
  #echo " $WSADMIN -lang jython -c \"${cmd1}\" -c \"${cmd2}\""
  $WSADMIN -lang jython -c "${cmd1}" -c "${cmd2}"
  if  [ $? -ne 0 ] ; then
      echo "ERROR - renewCert - Error during renewing Certificate. Script ended!"
  fi
  #cmd="AdminTask.getCertificateChain('[-certificateAlias default -keyStoreName NodeDefaultKeyStore -keyStoreScope (cell):ITMCell:(node):ITMNode ]')"
  #$WSADMIN -lang jython -c "${cmd}"

  echo "INFO - renewCert - Running ${GSKCAPI} commands" 
  $GSKCAPI -cert -delete -db $KEYKDB -stashed -label default
  $GSKCAPI -cert -delete -db $KEYKDB -stashed -label root
  $GSKCAPI -cert -import -db $KEYP12 -pw WebAS -target $KEYKDB -target_stashed -label default -new_label default
  $GSKCAPI -cert -import -db $TRUSTP12 -pw WebAS -target $KEYKDB -target_stashed -label root -new_label root
  if [ $? -ne 0 ]; then
      echo "ERROR - renewCert - Error during $GSKCAPI execution. Script ended!"
      return 1
  fi
  #echo "" ; $GSKCAPI -cert -list -db $KEYKDB -stashed -label default
  #echo "" ; $GSKCAPI -cert -details -db $KEYKDB -stashed -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
  #echo "" ; $GSKCAPI -cert -details -db $KEYP12 -pw WebAS -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
  #echo "" ; $GSKCAPI -cert -details -db $KEYKDB -stashed -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
  #echo "" ; $GSKCAPI -cert -details -db $TRUSTP12 -pw WebAS -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
  
  echo "INFO - renewCert - Successfully renewed Certificate (previous renew was $ts days ago)" 
  return 0
}

modQop () 
{    
  # returns rc=4 if already QOP set already
  tver=`echo $TLSVER | sed 's/TLSv[0-9].\([0-9]\)/SSL_TLSv\1/'`
  $WSADMIN  -lang jython -c "AdminTask.getSSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode ]')" | grep "sslProtocol $TLSVER" > /dev/null 
  if [ $? -eq 0 ] ; then
      echo "INFO - modQop - Quality of Protection (QoP) is already set to 'sslProtocol $TLSVER' and will not be modified again." 
      return 4
  else
      echo "INFO - modQop - Quality of Protection (QoP) not set yet. Modifying..."
  fi
  
  cmd1="AdminTask.modifySSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode -keyStoreName NodeDefaultKeyStore -keyStoreScopeName (cell):ITMCell:(node):ITMNode -trustStoreName NodeDefaultTrustStore -trustStoreScopeName (cell):ITMCell:(node):ITMNode -jsseProvider IBMJSSE2 -sslProtocol $TLSVER -clientAuthentication false -clientAuthenticationSupported false -securityLevel HIGH -enabledCiphers ]')"
  cmd2="AdminConfig.save()"
  #  echo "$WSADMIN -lang jython -c  \"${cmd1}\" -c  \"${cmd2}\""
  $WSADMIN -lang jython -c "${cmd1}" -c "${cmd2}"
  if [ $? -ne 0 ]; then
      echo "ERROR - modQop - Error setting $TLSVER for Quality of Protection (QoP). Script ended!"
      return 1
  else
      echo "INFO - modQop - Successfully set $TLSVER for Quality of Protection (QoP)" 
      return 0
  fi
}

disableAlgorithms () 
{ 
  # returns rc=4 if property already set 
  secxml="$ITMHOME/$ARCH/iw/profiles/ITMProfile/config/cells/ITMCell/security.xml"
  grep -i "com.ibm.websphere.tls.disabledAlgorithms.* value=.*none"  $secxml | grep -v "<\!\-\-" > /dev/null
  if [ $? -eq 0 ] ; then
      echo "INFO - disableAlgorithms - Custom property 'com.ibm.websphere.tls.disabledAlgorithms... value=none' is already set and will not be set again"
      return 4
  else 
     echo "INFO - disableAlgorithms - Modifying com.ibm.websphere.tls.disabledAlgorithms"
  fi
  
  jython="$ITMHOME/tmp/org.jy"
  touch $jython 
  echo "sec = AdminConfig.getid('/Security:/')" > $jython 
  echo "prop = AdminConfig.getid('/Security:/Property:com.ibm.websphere.tls.disabledAlgorithms/' )"  >> $jython 
  echo "if prop:"  >> $jython 
  echo "  AdminConfig.modify(prop, [['value', 'none'],['required', \"false\"]])"  >> $jython 
  echo "else: "  >> $jython 
  echo " AdminConfig.create('Property',sec,'[[name \"com.ibm.websphere.tls.disabledAlgorithms\"] [description \"Added due ITM $TLSVER usage\"] [value \"none\"][required \"false\"]]') "  >> $jython 
  echo "AdminConfig.save()" >> $jython
  #echo "$WSADMIN -lang jython -f $jython"
  $WSADMIN -lang jython -f $jython
  if [ $? -ne 0 ]; then
      echo "ERROR - disableAlgorithms - Error setting Custom Property ( com.ibm.websphere.tls.disabledAlgorithms ). Script ended!"
      return 1
  else
      #rm -f $jython
      echo "INFO - disableAlgorithms - Successfully set com.ibm.websphere.tls.disabledAlgorithms to none" 
      return 0
  fi
}
