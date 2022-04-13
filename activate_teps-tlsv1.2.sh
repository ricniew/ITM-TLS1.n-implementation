#!/bin/bash
#set -x
###################################################################
# R. Niewolik IBM AVP
# This script  performs configuration steps to implement a TLSv1.2 only configuration
# 16.03.2022: Initial version by R. Niewolik EMEA AVP Team
# 30.03.2022: Version 1.4     by R. Niewolik EMEA AVP Team
# 30.03.2022: Version 1.41    by R. Niewolik EMEA AVP Team
#             - Add check if TEPS and eWas are at the required Level
#             - Backupfolder now created in ITMHOME/backup/.. directory                
## 
SECONDS=0

usage()
{ # usage description
echo ""
echo " Usage:"
echo "  $PROGNAME { -h ITM home } [ -a arch ]"
echo " Sample executions:"
echo "  Create a silent response file only without execution unconfiguration step for all servers"
echo "    $PROGNAME -h /opt/IBM/ITM "
echo ""
}

backupfile () 
{
  # this function als check if the files to backup exists, if not, scripts exists with error.
  filen=$1
  if [ -f $filen  ] ; then 
      echo "INFO - backupfile - Saving $filen in $BACKUPFOLDER "
      cp -p $filen $BACKUPFOLDER/.
  else
      if [[ $filen =~ "kcjparms" ]] ; then
          echo "WARNING - backupfile - file $filen does NOT exists and not saved. KCJ componenent probably not installed. Continue..."
          return 4
      else
          echo "ERROR - backupfile - file $filen does NOT exists. Please check."
          exit 1
      fi
  fi

  return 0
}  
  
backupewasAndKeyfiles() 
{
  echo "INFO - backup - Saving Directory $CANDLEHOME/$ARCH/iw in $BACKUPFOLDER. This can take a while..." 
  cp -pR $CANDLEHOME/$ARCH/iw  $BACKUPFOLDER/ 
  if [ $? -ne 0 ]; then
      echo "ERROR - backup - Could not backup  $CANDLEHOME/$ARCH/iw to folder $BACKUPFOLDER. Check permissions and space."
      exit 1
  fi 
  echo "INFO - backup - Saving Directory $CANDLEHOME/$ARCH/iw in $BACKUPFOLDER. This can take a while..." 
  cp -pR  $CANDLEHOME/keyfiles/ $BACKUPFOLDER/ 
  if [ $? -ne 0 ]; then
      echo "ERROR - backup - Could not backup  $CANDLEHOME/keyfiles/ to folder $BACKUPFOLDER. Check permissions and space."
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
  echo "cp -pR iw $CANDLEHOME/$ARCH/." >> $restorebatfull
  echo "cp -pR keyfiles $CANDLEHOME/." >> $restorebatfull
  echo "" >>  $restorebatfull 
  for filename in "${!AFILES[@]}"; do
      if [[ $filename =~ "kcjparms" ]] && [[ $KCJ -eq 4 ]] ; then
          echo "WARNING - createRestoreScript - TEP Desktop Client apparently not installed. File 'kcjparms.txt' not added to restore script"
          continue
      fi
      echo "cp -p $filename ${AFILES[$filename]} " >> $restorebatfull   
      echo "rm -f ${AFILES[$filename]}.beforetls12" >> $restorebatfull   
      echo "rm -f ${AFILES[$filename]}.tls12" >> $restorebatfull  
      echo "" >>   $restorebatfull      
  done
  echo "" >>  $restorebatfull      
  echo "${CANDLEHOME}/bin/itmcmd config -A cw" >> $restorebatfull
  if [[ $KCJ -eq 4 ]] ; then
      :
  else
      echo "${CANDLEHOME}/bin/itmcmd config -Ar cj" >> $restorebatfull 
  fi  

  echo "INFO - createRestoreScript - Restore bat file created $restorebatfull"
  echo "" >>  $restorebatfull      
  sleep 4
  return 0
}

EnableICSLite () 
{
  echo "INFO - EnableICSLite - Set ISCLite to '$1' "
  ${CANDLEHOME}/$ARCH/iw/scripts/enableISCLite.sh $1
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
  $CANDLEHOME/bin/itmcmd agent stop cq 
  $CANDLEHOME/bin/itmcmd agent start cq
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
          grep 'Waiting for requests. Startup complete' $CANDLEHOME/logs/kfwservices.msg > /dev/null
          if [ $? -eq 0 ] ; then
              echo ""
              echo "INFO - restartTEPS - TEPS restarted successfully."
              wait=0 
          else 
              echo -n ".."
              c=$(( $c + 1 ))
              sleep 3  
          fi
	  #if [ $c -gt 150 ] ; then
          #    echo "ERROR - restartTEPS - TEPS restart takes too long (over 2,5) min. Something went wrong. Powershell script ended!"
          #    exit 1
          #fi
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
  NEWORGFILE="$orgfile.tls12"
  echo "INFO - saveorgcreatenew - $NEWORGFILE will be the modified file"
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
  echo "INFO - modhttpconf - Start $httpdfile creation "
  saveorgcreatenew $httpdfile
  if [ $? -eq 1 ] ; then
       echo "WARNING - modhttpconf - IHS component apparently not installed. File $httpdfile not modified !"
       return 1 
  fi
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
              temp="  DocumentRoot \"${CANDLEHOME}/$ARCH/cw\""
              echo $temp >> $newhttpdfile
              echo "  SSLEnable" >> $newhttpdfile
              echo "  SSLProtocolDisable SSLv2" >> $newhttpdfile
              echo "  SSLProtocolDisable SSLv3" >> $newhttpdfile
              echo "  SSLProtocolDisable TLSv10" >> $newhttpdfile
              echo "  SSLProtocolDisable TLSv11" >> $newhttpdfile
              echo "  SSLProtocolEnable TLSv12" >> $newhttpdfile
              echo "  SSLCipherSpec ALL -SSL_RSA_WITH_3DES_EDE_CBC_SHA" >> $newhttpdfile
              echo "  ErrorLog \"${CANDLEHOME}/$ARCH/iu/ihs/HTTPServer/logs/sslerror.log\"" >> $newhttpdfile
              echo "  TransferLog \"${CANDLEHOME}/$ARCH/iu/ihs/HTTPServer/logs/sslaccess.log\"" >> $newhttpdfile
              echo "  KeyFile \"${CANDLEHOME}/keyfiles/keyfile.kdb\"" >> $newhttpdfile
              echo "  SSLStashfile \"${CANDLEHOME}/keyfiles/keyfile.sth\"" >> $newhttpdfile
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
  echo  "INFO - modcqini - Start $cqini creation "
  saveorgcreatenew $cqini
  if [ $? -eq 1 ] ; then
       echo "WARNING - modcqini - TEPS component apparently not installed. File $cqini not modified !"
       return 1
  fi
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
  echo "INFO - modtepjnlpt - Start $tepjnlpt creation "
  tepjnlpt=$1
  saveorgcreatenew $tepjnlpt
  if [ $? -eq 1 ] ; then
       echo "WARNING - modtepjnlpt - TEPS component apparently not installed. File $tepjnlpt not modified !"
       return 1
  fi
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
  echo "INFO - modcompjnlpt - Start modcompjnlpt creation "
  compjnlpt=$1
  saveorgcreatenew $compjnlpt
  if [ $? -eq 1 ] ; then
       echo "WARNING - modcompjnlpt - TEPS component apparently not installed. File $compjnlpt not modified !"
       return 1
  fi
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
  echo "INFO - modapplethtmlupdateparams - Start $applethtmlupdateparams creation "
  saveorgcreatenew $applethtmlupdateparams
  if [ $? -eq 1 ] ; then
       echo "WARNING - modapplethtmlupdateparams - TEPS component apparently not installed. File $applethtmlupdateparams not modified !"
       return 1
  fi
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
  echo  "INFO - modkcjparmstxt - Start $kcjparmstxt creation "
  saveorgcreatenew $kcjparmstxt
  if [ $? -eq 1 ] ; then
      echo "WARNING - modkcjparmstxt - CNP Destop Client apparently not installed. File $kcjparmstxt not modified !"
      return 1
  fi
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

modsslclientprops () 
{
  sslclientprops=$1
  echo "INFO - modsslclientprops - Start $sslclientprops modification "
  saveorgcreatenew $sslclientprops
  if [ $? -eq 1 ] ; then
       echo "WARNING - modsslclientprops -  $sslclientprops not installed. File $sslclientprops not modified !"
       return 1
  fi
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
              echo  "INFO - modsslclientprops - $sslclientprops contains already 'com.ibm.ssl.protocol=TLSv1.2'"
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

modjavasecurity () 
{
  javasecurity=$1
  echo "INFO - modjavasecurity - Start $javasecurity creation "
  saveorgcreatenew $javasecurity
  if [ $? -eq 1 ] ; then
       echo "WARNING - modjavasecurity - ITHOME/CNPSJ/JAVA component apparently not installed. File $javasecurity not modified !"
       return 1
  fi
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

renewCert () 
{
  cmd1="AdminTask.renewCertificate('-keyStoreName NodeDefaultKeyStore -certificateAlias  default')"
  cmd2="AdminConfig.save()"
  echo " $WSADMIN -lang jython -c \"${cmd1}\" -c \"${cmd2}\""
  $WSADMIN -lang jython -c "${cmd1}" -c "${cmd2}"
  if  [ $? -ne 0 ] ; then
      echo "ERROR - renewCert - Error during renewing Certificate. Script ended!"
  else
      cmd="AdminTask.getCertificateChain('[-certificateAlias default -keyStoreName NodeDefaultKeyStore -keyStoreScope (cell):ITMCell:(node):ITMNode ]')"
      $WSADMIN -lang jython -c "${cmd}"
      echo "INFO - renewCert - Successfully renewed Certificate" 
  fi

  echo "INFO - renewCert - Running GSKitcmd.sh commands" 
  CH=$CANDLEHOME
  IWDIR=$(ls -d $CH/[al]*/iw 2> /dev/null)
  KEYKDB=$CANDLEHOME/keyfiles/keyfile.kdb
  KEYP12=$IWDIR/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12
  TRUSTP12=$IWDIR/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12
  CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -delete -db $KEYKDB -stashed -label default
  CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -delete -db $KEYKDB -stashed -label root
  CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -import -db $KEYP12 -pw WebAS -target $KEYKDB -target_stashed -label default -new_label default
  CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -import -db $TRUSTP12 -pw WebAS -target $KEYKDB -target_stashed -label root -new_label root
  if [ $? -ne 0 ]; then
      echo "ERROR - renewCert - Error during GSKitcmd.sh execution. Script ended!"
      exit 1
  else
      echo "INFO - renewCert - GSKitcmd.sh commands finished. See label and issuer info below..." 
      echo ""
      echo "CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -list -db $KEYKDB -stashed -label default "
      CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -list -db $KEYKDB -stashed -label default
      echo ""
      echo "CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYKDB -stashed -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'"
      CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYKDB -stashed -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      echo ""
      echo "CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYP12 -pw WebAS -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'"
      CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYP12 -pw WebAS -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      echo ""
      echo "CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYKDB -stashed -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'"
      CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $KEYKDB -stashed -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      echo ""
      echo "CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $TRUSTP12 -pw WebAS -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'"
      CANDLEHOME=$CH $CH/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db $TRUSTP12 -pw WebAS -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
      return 0
  fi

}

modQop () 
{    
cmd1="AdminTask.modifySSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode -keyStoreName NodeDefaultKeyStore -keyStoreScopeName (cell):ITMCell:(node):ITMNode -trustStoreName NodeDefaultTrustStore -trustStoreScopeName (cell):ITMCell:(node):ITMNode -jsseProvider IBMJSSE2 -sslProtocol TLSv1.2 -clientAuthentication false -clientAuthenticationSupported false -securityLevel HIGH -enabledCiphers ]')"
cmd2="AdminConfig.save()"
echo "$WSADMIN -lang jython -c  \"${cmd1}\" -c  \"${cmd2}\""
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
jython="$CANDLEHOME/tmp/org.jy"
touch $jython 
echo "sec = AdminConfig.getid('/Security:/')" > $jython 
echo "prop = AdminConfig.getid('/Security:/Property:com.ibm.websphere.tls.disabledAlgorithms/' )"  >> $jython 
echo "if prop:"  >> $jython 
echo "  AdminConfig.modify(prop, [['value', 'none'],['required', \"false\"]])"  >> $jython 
echo "else: "  >> $jython 
echo " AdminConfig.create('Property',sec,'[[name \"com.ibm.websphere.tls.disabledAlgorithms\"] [description \"Added due ITM TSLv1.2 usage\"] [value \"none\"][required \"false\"]]') "  >> $jython 
echo "AdminConfig.save()" >> $jython
echo "$WSADMIN -lang jython -f $jython"
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

# --------------------------------------------------------------
# MAIN ---------------------------------------------------------
# --------------------------------------------------------------

while getopts "a:h:" OPTS
do
  case $OPTS in
    h) CANDLEHOME=${OPTARG} ;;
    a) ARCH=${OPTARG} ;;
    *) echo "$OPTARG is not a valid switch"; usage ; exit ;;
  esac
done

if [ -d "${CANDLEHOME}" ]; then
    echo "INFO - main - ITM home directory is: ${CANDLEHOME}"
else
    echo "ERROR - main - ITM home directory ${CANDLEHOME} is not existing!"
    usage
    exit 1
fi

${CANDLEHOME}/bin/cinfo -r | grep " cq " | grep -i  "running" > /dev/null
if [ $? -eq 1 ]; then
    echo "ERROR - main - TEPS not running. Please start it and restart the procedure"
    exit
else
    grep 'Waiting for requests. Startup complete' $CANDLEHOME/logs/kfwservices.msg > /dev/null
    if [ $? -ne 0 ] ; then
        echo "ERROR - main - TEPS running but not connected to a TEMS"
        exit
    fi
fi 

if [ "$ARCH" = "" ] ; then
      ARCH=`${CANDLEHOME}/bin/cinfo -t cq|grep "cq.*Tivoli Enterprise Portal Server"|awk '{print $6}'`
fi
if [ -d "${CANDLEHOME}/${ARCH}/iw" ]; then
    echo "INFO - main - ITM arch directory is: ${CANDLEHOME}/${ARCH}"
else
    echo "ERROR - main - TEPS not installed on this host because ITM directory ${CANDLEHOME}/${ARCH}/iw is not existing"
    echo " or the arch '$ARCH' folder is not correct. You can find the rigth value by looking at the 'cinfo -t cq' output (e.g. lx8266 for the 'cq' component)"
    usage
    exit 1
fi

tepsver=`${CANDLEHOME}/bin/cinfo -t cq| grep "^cq"|awk '{print $7}'|sed 's/\.//g'`
ewasver=`${CANDLEHOME}/bin/cinfo -t iw| grep "^iw"|awk '{print $9}'|sed 's/\.//g'`
if [ $tepsver -lt 06300700 ] ; then
    echo "ERROR - main - TEPS Server must be at least at version 06.30.07.00. You must update your TEPS server to <= 06.30.07.00 ."
    exit
elif [ $ewasver -lt 08551600 ] ; then
    echo "ERROR - main - eWAS server must be at least at version 08.55.16.00. Please perform an eWAS and IHS uplift as described in the udpate readme files" 
    exit
fi
echo "INFO - main - TEPS = $tepsver eWAS = $ewasver"


PROGNAME=$(basename $0)
USRCMD="$0 $*"
BACKUPFOLDER="${CANDLEHOME}/backup/backup_before_TLS1.2"
RESTORESCRIPT="SCRIPTrestore.sh"
WSADMIN="$CANDLEHOME/$ARCH/iw/bin/wsadmin.sh"

if [ ! -d "${CANDLEHOME}/backup/" ]; then
    echo "ERROR - main - Default backup folder ${CANDLEHOME}/backup does not exists! Please check. "
    exit 1
fi
if [ -d "${BACKUPFOLDER}" ]; then
    echo "ERROR - main - This script was started already and the folder $BACKUPFOLDER exists already! To avoid data loss, "
    echo "before executing this script again, you must restore the original content by using the '$BACKUPFOLDER/$RESTORESCRIPT' script and delete/rename the backup folder."
    exit 1
else
    mkdir ${BACKUPFOLDER}
    echo "INFO - main - Backup directory is: ${BACKUPFOLDER}"
fi

declare -A AFILES=( 
  ["httpd.conf"]="${CANDLEHOME}/$ARCH/iu/ihs/HTTPServer/conf/httpd.conf"  \
  ["cq.ini"]="${CANDLEHOME}/config/cq.ini" \
  ["tep.jnlpt"]="${CANDLEHOME}/config/tep.jnlpt" \
  ["component.jnlpt"]="${CANDLEHOME}/config/component.jnlpt" \
  ["applet.html.updateparams"]="${CANDLEHOME}/$ARCH/cw/applet.html.updateparams" \
  ["kcjparms.txt"]="${CANDLEHOME}/$ARCH/cj/kcjparms.txt" \
  ["java.security"]="${CANDLEHOME}/$ARCH/iw/java/jre/lib/security/java.security" \
  ["trust.p12"]="${CANDLEHOME}/$ARCH/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12" \
  ["key.p12"]="${CANDLEHOME}/$ARCH/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12" \
  ["ssl.client.props"]="${CANDLEHOME}/$ARCH/iw/profiles/ITMProfile/properties/ssl.client.props" \
)


# enable ICSLite in eWAS
EnableICSLite "true"

backupewasAndKeyfiles
backupfile "${AFILES["httpd.conf"]}" 
HTTPD=$?
backupfile "${AFILES["cq.ini"]}"
CQINI=$?
backupfile "${AFILES["tep.jnlpt"]}"
TEPT=$?
backupfile "${AFILES["component.jnlpt"]}"
COMPONENTT=$?
backupfile "${AFILES["applet.html.updateparams"]}"
APPLET=$?
backupfile "${AFILES["kcjparms.txt"]}"
KCJ=$?
backupfile "${AFILES["java.security"]}"
JAVASEC=$?
backupfile "${AFILES["trust.p12"]}"
TRUSTP12=$?
backupfile "${AFILES["key.p12"]}"
KEYP12=$?
backupfile "${AFILES["ssl.client.props"]}"
SSLPROPS=$?

# Create a script to restore the files before TLS1.2 was set using this script
createRestoreScript

# Renew the default certificate
renewCert

# restart TEPS
restartTEPS
EnableICSLite "true"

# TLS v1.2 only configuration - TEPS/eWAS TEP, IHS, TEPS,  components
# TEPS/eWAS modify Quality of Protection (QoP)    
modQop

# eWAS Set custom property com.ibm.websphere.tls.disabledAlgorithms
disableAlgorithms

# eWAS sslclientprops modification
modsslclientprops "${AFILES["ssl.client.props"]}" 
# test openssl s_client -connect 172.16.11.4:15206 -tls1_2 doesn't work on windows by default. Needs to be installed first in PS (Install-Module -Name OpenSSL)

# IHS httpd.conf modification
modhttpconf "${AFILES["httpd.conf"]}" 

# TEPS
# kwfenv add/modify variables
modcqini "${AFILES["cq.ini"]}"

# TEPS JAVA java.security modification
modjavasecurity "${AFILES["java.security"]}"

# restart TEPS
restartTEPS

# Browser/WebStart client related
modtepjnlpt "${AFILES["tep.jnlpt"]}"
modcompjnlpt "${AFILES["component.jnlpt"]}"
modapplethtmlupdateparams "${AFILES["applet.html.updateparams"]}"
echo "INFO - main - Reconfiguring TEP WebSstart/Broswer client 'cw'"
${CANDLEHOME}/bin/itmcmd config -A cw
if [ $? -ne 0 ] ; then
    echo "ERROR - main - Reconfigure of TEP WebSstart/Broswer client '${CANDLEHOME}/bin/itmcmd config -A kcw' failed. Script ended!"
    exit 1
fi
#sleep 10

# Desktop client related
if [ $KCJ -eq 0 ] ; then
    modkcjparmstxt "${AFILES["kcjparms.txt"]}"
    echo  "INFO - main - Reconfiguring TEP Desktop Client 'cj'"
    ${CANDLEHOME}/bin/itmcmd config -Ar cj
    if [ $? -ne ] ; then
        error "ERROR - main - Reconfigure of TEP Desktop Client '${CANDLEHOME}/bin/itmcmd config -Ar kcj' failed. Powershell script ended!"
        exit 1
    fi
    #sleep 10
else 
    echo "WARNING - main - TEP Desktop client not installed and was not modified ('kcjparms.txt' not existing) "
fi

# Disable ICSLIte
EnableICSLite "false"

echo ""
etm=$((SECONDS/60))
host=`hostname`
echo "------------------------------------------------------------------------------------------"
echo "INFO - main - Procedure successfully finished Elapsedtime: $etm min " 
echo " - Original files saved in folder $BACKUPFOLDER "
echo " - To restore the level before update run '$BACKUPFOLDER/$RESTORESCRIPT' "
echo "----- POST script execution steps ---" 
echo " - Reconfigure TEPS and verify connections for TEP, TEPS, HUB" 
echo " - To check eWAS settings use: https://${host}:15206/ibm/console/login"
echo " - To check TEP WebStart  use: https://${host}:15201/tep.jnlp"
echo "------------------------------------------------------------------------------------------"

exit 0
