# This functions are sourced and used by the activate_teps-tlvs.ps1 procedure.
# You can also source and used it one by one in the command line but it is required
# to source the init_tlsv[n.n].ps1 first and then init_global_vars.ps1 before 
# execution.
#
# Note: all match or select string powershell commands are case sensitive by default
#
# 20.07.2022: Version 2.0      R. Niewolik EMEA AVP Team 
#             - Complete redesign of the script released on 20.04.2022. 
#               Splittet main script into this function file and two 
#               files to set variables
#             - Added new function importSelfSignedToJREcacerts to allow https tepslogin 
#             - Modified saveorgcreatenew 
# 22.07.2022: Version 2.1      R. Niewolik EMEA AVP Team
#             - Modfied modjavasecurity to support "\" in jdk.tls.disabledAlgorithms value (set in init_tlsvn.n)
# 27.09.2022: Version 2.3 R. Niewolik EMEA AVp Team
#             - Function modhttpconf was modified to evaluate new variable HTTPD_DISABLE_15200 introduced
#               Now it will be exeuted like: modhttpconf [httpd.conf file] [yes,no].
#               It was done to control if the HTTP port 15200 should be still allowed to be accessed outside of the localhost.
#             - Function modkfwenv was modfied to support KFW_ORBPARM FOR TEPS VERSION >= 6.3 fp7 sp8
#             - Modified function importSelfSignedToJREcacerts to check if label "IBM_Tivoli_Monitoring_Certificate" exists in $KEYKDB.
#               If not function returns rc=5 and Self Signed Cert is not copied from $KEYKDB To JRE cacerts 
# 13.10.2022: Version 2.31 R. Niewolik EMEA AVp Team
#             - removed test statement in modkfwenv
##

if (  $Args ) {
    if ( Test-Path -Path "$Args\logs" ) {
        $global:ITMHOME="$Args"
    } else { 
        write-host "INFO - functions_sources - ITMHOME='$Args' set by argument is not an ITMHOME folder or does not exists."
        return 1  
    }
} else {
    $cdh = Get-WmiObject -query "select * from Win32_environment where username='<system>' and name='CANDLE_HOME'" | ft -hide | out-string;
    if ( !$cdh  ) {
        write-host "ERROR - functions_sources - Variable %CANDLE_HOME% doesn't exists. ITMHOME cannot be evaluated"
        $sourcefilename= $MyInvocation.MyCommand.Name
        write-host "Please use '. .\$sourcefilename [path to ITMHOME]' (e.g. c:\ibm\itm) to set the correct path"
        return 1
    } else {
        $candlehome = $cdh.Split(" ")[0].trim()
        write-host "INFO - functions_sources -ITM home directory by %CANDLE_HOME% is: $candlehome"
        if (Test-Path -Path "$candlehome" ) {
            $global:ITMHOME = $candlehome
        } else {
            write-host "ERROR - functions_sources - ITM home folder cannot be evaluated, CANDLE_HOME=$candlehome doesn't exists"
            write-host "Please set the correct path '. .\$sourcefilename [path to ITMHOME]' (e.g. c:\ibm\itm)"
            return 1
        }
    }
}


# initialize global variables
if ( test-path .\init_global_vars.ps1 ) {
    $rc= . .\init_global_vars.ps1 $ITMHOME
    if ( $rc -eq 1 ) { return 1 }
} else { 
    write-host "ERROR - functions_sources - File init_global_vars doesn't exists in the current directory"
    return 1
}

# ---------
# Functions
#----------

function backupfile ($file) 
{
  #write-host "DEBUG - backupfile- $file"
  if ( test-path "$file" ) {
      write-host "INFO - backupfile - Saving $file in $BACKUPFOLDER "
      Copy-Item -Path "$file" -Destination "$BACKUPFOLDER"
      if ( -not $? ) {
          write-host "ERROR - backupfile - Error during copy of file $filen to $BACKUPFOLDER !! Check permissions and space available."
          return 1
      } else { 
          return 0 
      }
  } else {
      write-host "ERROR - backupfile - File $filen does not exists."
  }
}

function backupewasAndkeys ($backupfolder) 
{
  write-host "INFO - backupewasAndkeys - Directory $ITMHOME\CNPSJ saving in $BACKUPFOLDER. This can take a while..."
  Copy-Item -Path "$ITMHOME\CNPSJ" -Destination "$BACKUPFOLDER" -Recurse -erroraction stop
  if ( -not $? ) {
      write-host "ERROR - backupewasAndkeys - Could not copy $ITMHOME/CNPSJ folder to $BACKUPFOLDER !! Check permissions and available space."
      return 1
  }
  write-host "INFO - backupewasAndkeys - Directory $ITMHOME\keyfiles saving in $BACKUPFOLDER"
  Copy-Item -Path "$ITMHOME\keyfiles" -Destination "$BACKUPFOLDER" -Recurse -erroraction stop
  write-host "INFO - backupewasAndkeys - Files successfully saved in folder $BACKUPFOLDER."
  if ( -not $? ) {
      write-host "ERROR - backupewasAndkeys - Could not copy $ITMHOME/keyfiles folder to $BACKUPFOLDER !! Check permissions and available space."
      return 1
  }
}

function createRestoreScript ($restorebat) 
{
  $restorebatfull = "$BACKUPFOLDER\$restorebat"
  if ( test-path "$restorebatfull" ) { 
       write-host "WARNING - createRestoreScript - Script $restorebatfull exists already and will be deleted"
       remove-item $restorebatfull
  }

  $rc = New-Item -Path "$BACKUPFOLDER" -Name "$restorebat" -ItemType "file"
  Add-Content $restorebatfull "cd `"$BACKUPFOLDER`""
  Add-Content $restorebatfull "xcopy /y/s CNPSJ `"$ITMHOME\CNPSJ`""
  Add-Content $restorebatfull "xcopy /y/s keyfiles `"$ITMHOME\keyfiles`""
  Add-Content $restorebatfull " "

  foreach ( $h in $HFILES.Keys ) {
      $string="copy $h  `"$($HFILES.$h)`""
      if ( ( $file -like '*kcjparms*')  -and ( $KCJ = 4 ) ) {
          #write-host "WARNING - createRestoreScript - TEP Desktop Client apparently not installed. File 'kcjparms.txt' not added to restore script"
          continue 
      } 
      Add-Content $restorebatfull $string
      Add-Content $restorebatfull "if exist `"$($HFILES.$h).$TLSVER`" del `"$($HFILES.$h).before$TLSVER`""
      Add-Content $restorebatfull "if exist `"$($HFILES.$h).$TLSVER`" del `"$($HFILES.$h).$TLSVER`""
      Add-Content $restorebatfull " "
  }
  Add-Content $restorebatfull " "
  Add-Content $restorebatfull "kinconfg -n -rKCB"
  Add-Content $restorebatfull "kinconfg -n -rKCJ"
  Add-Content $restorebatfull "cd .."

  write-host "INFO - createRestoreScript - Restore bat file created $restorebatfull"
  Start-Sleep -seconds 4
}

function checkIfFileExists () # checkIfFileExists
{
  $global:KCJ=0
  # Checking if the files to modify exist
  if ( Test-Path -Path "$ITMHOME/CNPSJ" ) {
      write-host "INFO - checkIfFileExists - Directory $ITMHOME/CNPSJ  OK."
  } else {
      write-host "ERROR - checkIfFileExists - Directory $ITMHOME/CNPSJ  does NOT exists. Please check."
  }
  if ( Test-Path -Path "$ITMHOME\keyfiles" ) {
      write-host "INFO - checkIfFileExists - Directory $ITMHOME\keyfiles  OK."
  } else {
      write-host "ERROR - checkIfFileExists - Directory $ITMHOME\keyfiles  does NOT exists. Please check."
  }
  
  foreach ( $h in $HFILES.Keys ) {
      if ( test-path "$($HFILES.$h)" ) { 
          write-host "INFO - checkIfFileExists - File $($HFILES.$h) OK."
          continue
      } else {
          if ( $h -like '*kcjparms*') {
              write-host "WARNING - checkIfFileExists - File $($HFILES.$h) does NOT exists. KCJ component probably not installed. Continue..."
              $global:KCJ=4 # will be used later in main and createRestoreScript
              continue
          } else {
              write-host "ERROR - checkIfFileExists - file $($HFILES.$h) does NOT exists. Please check."
              return 1
          }
      }      
  }

  return 0
}  

function EnableICSLIte ($action) # EnableICSLIte "true" (or "false")
{
  write-host "INFO - EnableICSLIte - ISCLite set enabled=$action."
  $cmd="& '$ITMHOME\CNPSJ\bin\wsadmin' -conntype SOAP -lang jacl -f '$ITMHOME\CNPSJ\scripts\enableISCLite.jacl' $action"
  $cmd += '; $Success=$?'
  #write-host "$cmd"
  $out = Invoke-Expression $cmd
  if ( $Success ) { write-host "INFO - EnableICSLIte - Successfully set ISCLite to '$action'." }
  else {
      write-host "$success"
      write-host "ERROR - EnableICSLIte - Enable ISCLite command $cmd failed. Possibly you did not set a eWAS user password. "
      write-host " Try to set a password as described here https://www.ibm.com/docs/en/tivoli-monitoring/6.3.0?topic=administration-define-wasadmin-password" 
      write-host " Powershell script ended!"
      return 1
  }
  
}

function restartTEPS () # restartTEPS
{
  write-host "INFO - restartTEPS - Restarting TEPS ..." -ForegroundColor Yellow
  net stop KFWSRV 
  net start KFWSRV
  if ( -not $? ) {
      write-host "ERROR - restartTEPS - TEPS restart failed. Powershell script ended!"
      return 1
  } else {
      write-host "INFO - restartTEPS - Waiting for TEPS to initialize...."
      Start-Sleep -seconds 7
      $wait = 1
      $c=0
      while($wait -eq 1) {
          If (Select-String -Path "$ITMHOME\logs\kfwservices.msg" -Pattern 'Waiting for requests. Startup complete' -SimpleMatch) {
              write-host ""
              write-host 'INFO - restartTEPS - TEPS started successfully' -ForegroundColor Green
              $wait = 0 
          } Else {
              write-host -NoNewline ".."
              $c = $c + 3
              Start-Sleep -seconds 3  
          }
          if ( $c -gt 200 ) {
              write-host "ERROR - restartTEPS - TEPS restart takes too long (over 3 min). Something went wrong. Powershell script ended!"
              return 1
          }
              
      }
      Start-Sleep -seconds 5
      return 0
  }
}

function saveorgcreatenew ($orgfile) # saveorgcreatenew [path to filename] 
{
  # Only used in functions

  [hashtable]$return = @{}
  $saveorgfile = "$orgfile.before$TLSVER"
  $neworgfile = "$orgfile.$TLSVER"

  if ( test-path "$saveorgfile" ) { 
      write-host "INFO - saveorgcreatenew - $saveorgfile exists and will be deleted"
      remove-item $saveorgfile
  }
  Copy-Item -Path "$orgfile" -Destination "$saveorgfile"

  if ( test-path "$neworgfile" ) {
      write-host "INFO - saveorgcreatenew - $neworgfile exists already and will be deleted"
      remove-item $neworgfile
  }
  $dir = Split-Path $neworgfile -Parent
  $file = Split-Path $neworgfile -Leaf 
  $null = New-Item -path "$dir" -name "$file" -ItemType "file"

  #write-host "DEBUG - saveorgcreatenew - new= $neworgfile save= $saveorgfile org= $orgfile"
  $return.new = "$neworgfile"
  $return.save =  "$saveorgfile"
  return $return
}


function modhttpconf ($httpdfile,$httpd_disable_15200) # modhttpconf $HFILES["httpd.conf"]
{
  # returns rc=4 if file already modified
  # !! modification for versions > TLSV1.2 may be required
  if ( $httpd_disable_15200 -eq "" ) { 
      write-host "ERROR - modhttpconf - You must provide a second parameter to control whether external TEPS login on port 15200 should be disabled or not"
      write-host "ERROR - modhttpconf - For example 'modhttpconf [path to httpd.conf] yes' to disable or 'modhttpconf [path to httpd.conf] no' to not disable"
      return 1
  } elseif ( ( $httpd_disable_15200  -ne "no" ) -and ( $httpd_disable_15200  -ne "yes" ) ) { 
      write-host "ERROR - modhttpconf - Bad execution syntax. 'modhttpconf [path to httpd.conf] [yes/no]' "
      return 1
  }
  $ver = $TLSVER -replace "\.","" # TLSVn.n to TLSvnn
  $disArray =$KDEBE_TLS_DISABLE.Split(",")
  $i1=0
  $i2=0
  foreach ($item in $disArray) { 
      $pn=$item.ToUpper() ; $pn = $item -replace "TLS","TLSv" # change TLSnn to TLSvnn
      $pattern = "^\s*SSLProtocolDisable\s*$pn" 
      if (select-string -Path "$httpdfile" -Pattern $pattern) { } 
      else { $i1=$i1+1 }
  }
  if ( $i1 -eq 0 ) {
      $pattern = "^\s*SSLProtocolEnable\s*$ver" 
      if (select-string -Path "$httpdfile" -Pattern $pattern) {
          write-host "INFO - modhttpconf - $httpdfile contains 'SSLProtocolEnable $ver' + TLS10,11, ... disabled and will not be modified"
          return 4
      }
      $i2=$i2+1
  }

  write-host "INFO - modhttpconf - Modifying $httpdfile ($i1,$i2) "
  
  $rc = saveorgcreatenew $httpdfile 
  $newhttpdfile = $rc.new
  $savehttpdfile = $rc.save

  $foundsslcfg = 1
  foreach( $line in Get-Content $savehttpdfile ) {
      #write-host -- $foundsslcfg
      if ( $line.StartsWith("#") ) { Add-Content $newhttpdfile "${line}" ; continue }
      if ( "$line" -match "ServerName\s*(.*):15200" ) {
          $temp = "ServerName " + $matches[1] + ":${TEPSHTTPSPORT}"
          if ( select-string -Path "$httpdfile" -Pattern "^\s*$temp") {
              write-host "INFO - modhttpconf - '$temp' exists already"
          } else { 
              Add-Content $newhttpdfile $temp 
          }
          if ( $httpd_disable_15200  -eq "yes" ) { 
              Add-Content $newhttpdfile "#${line}"
          } else { 
              Add-Content $newhttpdfile "${line}"
          }
          continue
      }
      if ( "$line" -match "Listen\s*0.0.0.0:15200" ) {
          if ( $httpd_disable_15200  -eq "yes" ) { 
              Add-Content $newhttpdfile "Listen 127.0.0.1:15200" # local HTTP usage allowed
              Add-Content $newhttpdfile "#${line}"
          } else { 
              Add-Content $newhttpdfile "${line}"
          }
          continue
      }
      if ( $foundsslcfg -eq 1 ) {  
          if ( $line -eq "<VirtualHost *:${TEPSHTTPSPORT}>") {
              #write-host Debug -modhttpconf-----line= $line -- foundsslcfg= $foundsslcfg 
              $ch = $ITMHOME -replace "\\", '/'
              $foundsslcfg = 0
              Add-Content $newhttpdfile $line
              $temp = '  DocumentRoot "' + ${ch} + '/CNB"'
              Add-Content $newhttpdfile $temp
              Add-Content $newhttpdfile "  SSLEnable"
              Add-Content $newhttpdfile "  SSLProtocolDisable SSLv2"
              Add-Content $newhttpdfile "  SSLProtocolDisable SSLv3"
              foreach ($item in $disArray) { 
                  $pn=$item.ToUpper() ; $pn = $item -replace "TLS","TLSv" # change TLSnn to TLSvnn
                  Add-Content $newhttpdfile "  SSLProtocolDisable $pn"
              }
              Add-Content $newhttpdfile "  SSLProtocolEnable $ver"
              Add-Content $newhttpdfile "  SSLCipherSpec ALL -SSL_RSA_WITH_3DES_EDE_CBC_SHA"
              Add-Content $newhttpdfile "  ErrorLog `"${ch}/IHS/logs/sslerror.log`"" 
              Add-Content $newhttpdfile "  TransferLog `"${ch}/IHS/logs/sslaccess.loclsg`""
              Add-Content $newhttpdfile "  KeyFile `"${ch}/keyfiles/keyfile.kdb`""
              Add-Content $newhttpdfile "  SSLStashfile `"${ch}/keyfiles/keyfile.sth`""
              Add-Content $newhttpdfile "  SSLServerCert IBM_Tivoli_Monitoring_Certificate"
          } else {
              Add-Content $newhttpdfile $line
          }
    } elseif ( $foundsslcfg -eq 0 ) {  
        if ( $line -like '</VirtualHost>' ) {
            Add-Content $newhttpdfile '</VirtualHost>'
            $foundsslcfg = 2 
            continue
        }
    } else {
        Add-Content $newhttpdfile $line
    }
  }

  copy-item -Path "$newhttpdfile" -Destination "$httpdfile"
  write-host "INFO - modhttpconf - $newhttpdfile created and copied on $httpdfile"  
  return 0
}


function modkfwenv ($kfwenv) # modkfwenv $HFILES["kfwenv"]
{
  # returns rc=4 if file already modified
  # !! modification for > TLSV1.2 may be required
  $tepsver_sp8 = 06300710
  $cmd = 'kincinfo -t cq|find "CQ  TEPS"'
  $tmp = Invoke-Expression $cmd
  $tmparray = $($tmp -replace '\s+',' ').Split(" ")
  $tepsver_current = [int]$($tmparray[8] -replace '\.', '')
  #$tepsver_current = 06300704

  $ver=$TLSVER.ToUpper() ; $ver = $ver -replace "\.","" # change e.g. from TLSvn.n to TLSVnn
  # KFW_ORB_ENABLED_PROTOCOLS used for TEPS vers < 6.3 FP7 SP8
  $vtmp=$($TLSVER -replace '\.','_').Split("v")[1].trim() # will be e.g. "n_n"
  $KFW_ORB_ENABLED_PROTOCOLS="TLS_Version_${vtmp}_Only" 
  # KFW_ORBPARM used for TEPS vers >= 6.3 FP7 SP8
  $vtmp=$($TLSVER -replace 'TLSv','TLS')  # will be e.g. "TLSn.n"
  $vtmp2=$($vtmp -replace '\.','_')  # will be e.g. "TLSn_n"
  $KFW_ORBPARM="-Dvbroker.security.server.socket.minTLSProtocol=$vtmp2 -Dvbroker.security.server.socket.maxTLSProtocol=TLS_MAX"
  $i1 = 0
  if ( $tepsver_current -lt $tepsver_sp8 ) {
      $pattern="^[^#]*KFW_ORB_ENABLED_PROTOCOLS=${KFW_ORB_ENABLED_PROTOCOLS}" 
      if ( select-string -Path "$kfwenv" -Pattern $pattern ) {
          $message = "contains 'KFW_ORB_ENABLED_PROTOCOLS=$KFW_ORB_ENABLED_PROTOCOLS'"
      } else { 
          $i1 = 1 
      }
  } else {
      $pattern = "^[^#]*KFW_ORBPARM="
      if ( select-string -Path "$kfwenv" -Pattern $pattern ) {
          $tmpa = $($KFW_ORBPARM).Split(" ")
          foreach ( $item in $tmpa ) { 
              $pattern="^[^#]*$item"
              if ( select-string -Path "$kfwenv" -Pattern $pattern ) { }
              else {  $i1= $i1 + 1 }
          }
          if ( $i1 -eq 0 ) { $message = "contains 'KFW_ORBPARM=$KFW_ORBPARM'" }
      } else { 
          $i1=4 
      }
  }
  if ( $i1 -eq 0 ) {
      $pattern="^[^#]*KDEBE_${ver}_CIPHER_SPECS=$KDEBE_TLSVNN_CIPHER_SPECS"
      if ( select-string -Path "$kfwenv" -Pattern $pattern ) {
          write-host "INFO - modcqini - $message  and the '$KDEBE_TLSVNN_CIPHER_SPECS' and will not be modified"
          return 4
      }
  }

  write-host "INFO - modkfwenv - Modifying $kfwenv"

  $rc = saveorgcreatenew $kfwenv
  $newkfwenv = $rc.new
  $savekfwenv = $rc.save

  $foundKFWORB = $foundORBPARM = $foundTLSDisable = $foundTLSn = 1

  $disArray =$KDEBE_TLS_DISABLE.Split(",")
  foreach( $line in Get-Content $savekfwenv ) {
      if ( $line.StartsWith("#") ) { Add-Content $newkfwenv "${line}" ; continue }

      if ( "$line" -match "KFW_ORB_ENABLED_PROTOCOLS" ) {
          if ( $tepsver_current -lt $tepsver_sp8 ) { 
              Add-Content $newkfwenv "KFW_ORB_ENABLED_PROTOCOLS=${KFW_ORB_ENABLED_PROTOCOLS}" 
              $foundKFWORB = 0 
          } else {
              Add-Content $newkfwenv "#${line}"
          } 
      } elseif ( "$line" -match "KFW_ORBPARM" ) {
          if ( $tepsver_current -lt $tepsver_sp8 ) {
              Add-Content $newkfwenv "#${line}" 
          } else {
              Add-Content $newkfwenv "${line} $KFW_ORBPARM" 
              $foundORBPARM=0 
          } 
      } elseif ( "$line" -match "KDEBE_TLS[0-9][0-9]_ON" ) {
          if ( $foundTLSDisable -eq 0 ) { 
          } else {
              foreach ($item in $disArray) { 
                  Add-Content $newkfwenv "KDEBE_${item}_ON=NO"
              }
              $foundTLSDisable = 0 
          }
      } elseif ( "$line" -match "KDEBE_.*_CIPHER_SPECS" ) {
          Add-Content $newkfwenv "KDEBE_${ver}_CIPHER_SPECS=${KDEBE_TLSVNN_CIPHER_SPECS}"
          $foundTLSn = 0 ; continue
      } else { Add-Content $newkfwenv "${line}" }
  }

  if ( $tepsver_current -lt $tepsver_sp8 ) {
      if ( $foundKFWORB -eq 1 ) { Add-Content $newkfwenv "KFW_ORB_ENABLED_PROTOCOLS=${KFW_ORB_ENABLED_PROTOCOLS}" } 
  } else {
      if ( $foundORBPARM -eq 1 ) { Add-Content $newkfwenv "KFW_ORBPARM=$KFW_ORBPARM" } 
  } 
  if ( $foundTLSDisable -eq 1 )  { 
      Foreach ($item in $disArray) { 
          Add-Content $newkfwenv "KDEBE_${item}_ON=NO"
      }
  }
  if ( $foundTLSn -eq 1 )   { Add-Content $newkfwenv "KDEBE_${ver}_CIPHER_SPECS=${KDEBE_TLSVNN_CIPHER_SPECS}" }

  copy-item -Path "$newkfwenv" -Destination "$kfwenv"
  write-host "INFO - modkfwenv - $newkfwenv created and copied on $kfwenv"  
  return 0
}

function modtepjnlpt ($tepjnlpt) # modtepjnlpt $HFILES["tep.jnlpt"] 
{
  # returns rc=4 if file already modified
  $pattern="\s*<property name=`"jnlp.tep.sslcontext.protocol`.*$TLSVER" 
  If (select-string -Path "$tepjnlpt" -Pattern $pattern) {
      $pattern="codebase=`"https.*:${TEPSHTTPSPORT}"
      If (select-string -Path "$tepjnlpt" -Pattern $pattern) { 
          write-host "INFO - modtepjnlpt - $tepjnlpt contains 'jnlp.tep.sslcontext.protocol value=`"$TLSVER`"' and will not be modified"
          return 4
      }
  }

  write-host "INFO - modtepjnlpt - Modifying $tepjnlpt"

  $rc = saveorgcreatenew $tepjnlpt
  $newtepjnlpt = $rc.new
  $savetepjnlpt = $rc.save

  $foundprotocol = $foundport = $foundTLSn = 1
  foreach( $line in Get-Content $savetepjnlpt ) {
      if ( "$line" -match 'codebase="http://\$HOST\$:(.*)/' ) {
          Add-Content $newtepjnlpt "  codebase=`"https://`$HOST`$:${TEPSHTTPSPORT}/`"> "
      } elseif ( "$line" -match '\s*<property name="jnlp.tep.connection.protocol"\s*value=.*' ) {
          Add-Content $newtepjnlpt '    <property name="jnlp.tep.connection.protocol" value="https"/> '
          $foundprotocol = 0
      } elseif ( "$line" -match '\s*<property name="jnlp.tep.connection.protocol.url.port"\s*value=.*' ) {
          Add-Content $newtepjnlpt '    <property name="jnlp.tep.connection.protocol.url.port" value="' + ${TEPSHTTPSPORT} + '"/> '
          $foundport = 0
      } elseif ( "$line" -match '\s*<property name="jnlp.tep.sslcontext.protocol" value=.*' ) {
          $temp = '    <property name="jnlp.tep.sslcontext.protocol" value="' + $TLSVER + '"/> '
          Add-Content $newtepjnlpt $temp
          $foundTLSn = 0
      } else { Add-Content $newtepjnlpt "${line}" }
  }
  $count = $foundprotocol + $foundport + $foundTLSn
  if ( $count -gt 0 ) {
      #write-host "-DEBUG-modtepjnlpt----- c=$count --$foundprotocol = $foundport = $foundTLSn"
      $tempfile = "$newtepjnlpt.temporaryfile" 
      foreach( $line in Get-Content $newtepjnlpt ) {
          if ( "$line" -match "- Custom parameters\s*-" ) {
              Add-Content $tempfile "${line}"
              if ( $foundprotocol -eq 1 ) { 
                  Add-Content $tempfile '    <property name="jnlp.tep.connection.protocol" value="https"/> '} 
              if ( $foundport -eq 1 ) { 
                  Add-Content $tempfile "    <property name=`"jnlp.tep.connection.protocol.url.port`" value=`"${TEPSHTTPSPORT}`"/> "}
              if ( $foundTLSn -eq 1 ) {
                  $temp = "    <property name=`"jnlp.tep.sslcontext.protocol`" value=`"${TLSVER}`"/> "
                  Add-Content $tempfile $temp
              }
          } else { Add-Content $tempfile "${line}" }
      }
      copy-item -Path "$tempfile" -Destination "$newtepjnlpt"
      remove-item "$tempfile"
  } else { }

  copy-item -Path "$newtepjnlpt" -Destination "$tepjnlpt"
  write-host "INFO - modtepjnlpt - $newtepjnlpt created and copied on $tepjnlpt"
  return 0
}

function modcomponentjnlpt ($componentjnlpt) # modcomponentjnlpt $HFILES["component.jnlpt"] 
{
  # returns rc=4 if file already modified
  $pattern="\s*codebase=`"https.*:${TEPSHTTPSPORT}" 
  If (select-string -Path "$componentjnlpt" -Pattern $pattern) {
      write-host "INFO - modcomponentjnlpt - $componentjnlpt contains 'codebase=https..:${TEPSHTTPSPORT}' and will not be modified"
      return 4
  }

  write-host "INFO - modcomponentjnlpt - Modifying $componentjnlpt"

  $rc = saveorgcreatenew $componentjnlpt
  $newcomponentjnlpt = $rc.new
  $savecomponentjnlpt = $rc.save

  foreach( $line in Get-Content $savecomponentjnlpt ) {
      if ( "$line" -match 'codebase="http://\$HOST\$:(.*)/' ) {
          Add-Content $newcomponentjnlpt "  codebase=`"https://`$HOST`$:${TEPSHTTPSPORT}/`""
      } else { Add-Content $newcomponentjnlpt "${line}" }
  }

  copy-item -Path "$newcomponentjnlpt" -Destination "$componentjnlpt"
  write-host "INFO - modcomponentjnlpt - $newcomponentjnlpt created and copied on $componentjnlpt"
  return 0
}

function modapplethtmlupdateparams ($applethtmlupdateparams) # modapplethtmlupdateparams $HFILES["applet.html.updateparams"]
{ 
  # returns rc=4 if file already modified 
  $pattern="^[^#]*tep.sslcontext.protocol.*verride.*$TLSVER" 
  If (select-string -Path "$applethtmlupdateparams" -Pattern $pattern) {
      $pattern="^[^#]*tep.connection.protocol.*verride.*https"
      If (select-string -Path "$applethtmlupdateparams" -Pattern $pattern) {
          write-host "INFO - modapplethtmlupdateparams - $applethtmlupdateparams contains  `"tep.sslcontext.protocol|override|'$TLSVER'`" and will not be modified"
          return 4
      }
  }

  write-host "INFO - modapplethtmlupdateparams - Modifying $applethtmlupdateparams"

  $rc = saveorgcreatenew $applethtmlupdateparams
  $newapplethtmlupdateparams = $rc.new
  $saveapplethtmlupdateparams = $rc.save

  $foundprotocol = $foundport = $foundTLSn = 1
  foreach( $line in Get-Content $saveapplethtmlupdateparams ) {
      if ( "$line" -match 'tep.connection.protocol\|override' ) {
          Add-Content $newapplethtmlupdateparams "tep.connection.protocol|override|'https'"
          $foundprotocol = 0
      } elseif ( "$line" -match 'tep.connection.protocol.url.port' ) {
          Add-Content $newapplethtmlupdateparams "tep.connection.protocol.url.port|override|'${TEPSHTTPSPORT}'"
          $foundport = 0
      } elseif ( "$line" -match 'tep.sslcontext.protocol' ) {
          $temp = "tep.sslcontext.protocol|override|'" + $TLSVER + "'"
          Add-Content $newapplethtmlupdateparams $temp
          $foundTLSn = 0 
      } else { Add-Content $newapplethtmlupdateparams "${line}" }
  }
  $count = $foundprotocol + $foundport + $foundTLSn
  if ( $count -gt 0 ) {
      #write-host "-DEBUG-modapplethtmlupdateparams----- c=$count --$foundprotocol = $foundport = $foundTLSn"
      if ( $foundprotocol -eq 1 ) { 
          Add-Content $newapplethtmlupdateparams "tep.connection.protocol|override|'https'" } 
      if ( $foundport -eq 1 ) { 
          Add-Content $newapplethtmlupdateparams "tep.connection.protocol.url.port|override|'${TEPSHTTPSPORT}'" }
      if ( $foundTLSn -eq 1 ) { 
          $temp = "tep.sslcontext.protocol|override|'" + $TLSVER + "'" 
          Add-Content $newapplethtmlupdateparams $temp 
      }
  } else { }

  copy-item -Path "$newapplethtmlupdateparams" -Destination "$applethtmlupdateparams"
  write-host "INFO - modapplethtmlupdateparams - $newapplethtmlupdateparams created and copied on $applethtmlupdateparams"
  return 0

}

function modkcjparmstxt ($kcjparmstxt) # modkcjparmstxt $HFILES["kcjparms.txt"]
{
  # returns rc=4 if file already modified
  $pattern="^[^#]*tep.sslcontext.protocol.*$TLSVER" 
  If (select-string -Path "$kcjparmstxt" -Pattern $pattern) {
      $pattern="^[^#]*tep.connection.protocol.*https"
      If (select-string -Path "$kcjparmstxt" -Pattern $pattern) {
          write-host "INFO - modkcjparmstxt - $kcjparmstxt contains `"tep.sslcontext.protocol|override|'$TLSVER'`" and will not be modified"
          return 4
      }
  }

  write-host "INFO - modkcjparmstxt - Modifying $kcjparmstxt"

  $rc = saveorgcreatenew $kcjparmstxt
  $newkcjparmstxt = $rc.new
  $savenewkcjparmstxt = $rc.save

  $foundprotocol = 1
  $foundport = 1
  $foundTLSn = 1
  foreach( $line in Get-Content $savenewkcjparmstxt ) {
      if ( $line.StartsWith("#") ) { Add-Content $newkcjparmstxt "${line}" ; continue 
      } elseif ( "$line" -match 'tep.connection.protocol \s*\|' ) {
          #Add-Content $newkcjparmstxt "${line}"
          Add-Content $newkcjparmstxt "tep.connection.protocol | string | https | Communication protocol used between TEP/TEPS (iiop,http,https)"
          $foundprotocol = 0
          continue
      } elseif ( "$line" -match 'tep.connection.protocol.url.port \s*\|' ) {
          Add-Content $newkcjparmstxt "tep.connection.protocol.url.port | int | ${TEPSHTTPSPORT} | Port used by the TEP to connect with the TEPS"
          $foundport = 0
          continue
      } elseif ( "$line" -match 'tep.sslcontext.protocol \s*\|' ) {
          Add-Content $newkcjparmstxt "tep.sslcontext.protocol | string | $TLSVER  | TLS used TEP to connect with the TEPS"
          $foundTLSn = 0
          continue
      } else { 
          Add-Content $newkcjparmstxt "${line}" 
      }
  }

  if ( $foundprotocol -eq 1 ) { 
      Add-Content $newkcjparmstxt "tep.connection.protocol | string | https | Communication protocol used between TEP/TEPS (iiop,http,https)" }
  if ( $foundport -eq 1 ) { 
      Add-Content $newkcjparmstxt "tep.connection.protocol.url.port | int | ${TEPSHTTPSPORT} | Port used by the TEP to connect with the TEPS" }
  if ( $foundTLSn -eq 1 ) { 
      $temp = "tep.sslcontext.protocol | string | " + $TLSVER + " | TLS used TEP to connect with the TEPS" 
      Add-Content $newkcjparmstxt $temp 
  }

  copy-item -Path "$newkcjparmstxt" -Destination "$kcjparmstxt"
  write-host "INFO - modkcjparmstxt - $newkcjparmstxt created and copied on $kcjparmstxt"
  return 0
}

function modjavasecurity ($javasecurity) # modjavasecurity $HFILES["java.security"] 
{
  # returns rc=4 if file already modified
  $temparray=$JAVASEC_DISABLED_ALGORITHMS.Split("\")
  $varlines=$temparray.count

  If ( $JAVASEC_DISABLED_ALGORITHMS -match "\\" ) { 
      $c=0
      $f=0
      foreach ( $value in  $temparray ) {
          $c = $c + 1
          $part = $temparray[0] -replace " ",".*"
          if ( $c -eq 1 ) {
              $pattern = "^[^#]*jdk.tls.disabledAlgorithms=${part}"
              If ( select-string -Path "$javasecurity" -Pattern $pattern) { 
                  $f= $f + 1
              }
          } else {
              $pattern = "^[^#]*${part}"
              If ( select-string -Path "$javasecurity" -Pattern $pattern) {
                  $f= $f + 1
              }
          }
      }
      if ( $f -eq $varlines ) {
          write-host "INFO - modjavasecurity - $javasecurity contains `"jdk.tls.disabledAlgorithms=$JAVASEC_DISABLED_ALGORITHMS`" and will not be modified"
          return 4
      }
  } else {
      $tempalg = $JAVASEC_DISABLED_ALGORITHMS -replace " ",".*"
      $pattern = "^[^#]*jdk.tls.disabledAlgorithms=$tempalg"
      If ( select-string -Path "$javasecurity" -Pattern $pattern) {
          write-host "INFO - modjavasecurity - $javasecurity contains `"jdk.tls.disabledAlgorithms=$JAVASEC_DISABLED_ALGORITHMS`" and will not be modified"
          return 4
      }
  }
  
  $rc = saveorgcreatenew $javasecurity
  $newjavasecurity = $rc.new
  $savenewjavasecurity = $rc.save
  $tempvarset=".\temp#variable_set.txt"

  if ( test-path "$tempvarset" ) { remove-item $tempvarset }
  else { $null = New-Item -path "." -name "$tempvarset" -ItemType "file" }

  $c=0
  foreach( $value in  $temparray ) {
      $c = $c + 1
      if ( $varlines -eq 1 ) {
          Add-Content $tempvarset "jdk.tls.disabledAlgorithms=$value"
      } elseif ( $c -eq 1 ) {
          Add-Content $tempvarset "jdk.tls.disabledAlgorithms=$value `\"
      } elseif ( $c -eq $varlines ) {
          Add-Content $tempvarset "$value"
      } else {
          Add-Content $tempvarset "$value `\"
      }
  }

  $nextline = 1
  $foundAlgo = 2
  foreach ( $lines in Get-Content $savenewjavasecurity ) {
      $line=$lines.TrimEnd()
      if ( $line.StartsWith("#") ) { Add-Content $newjavasecurity "${line}" ; continue }
      if ( $foundAlgo -eq 0  ) {
          if ( $nextline -eq 0 ) {
              if ( $line -match '\\\s*$' ) {
                  #write-host "DEBUG- write - $nextline $foundAlgo - with back #"
                  Add-Content $newjavasecurity "${line}"
              } else {
                  #write-host "DEBUG- write1 - $nextline  $foundAlgo - $line"
                  Add-Content $newjavasecurity "#${line}"  # current line = line after var
                  add-content $newjavasecurity -value (get-content $tempvarset)
                  $foundAlgo = 1
                  $nextline = 1
              }
          } else {
              #write-host "DEBUG- write2 - $nextline $foundAlgo - $line "
              $foundAlgo = 1
              add-content $newjavasecurity -value (get-content $tempvarset)
              Add-Content $newjavasecurity "${line}" # current line = line after var
          }
      } elseif ( "$line" -match 'jdk.tls.disabledAlgorithms' ) {
          #write-host "DEBUG found jdk.tls.disabledAlgorithms in = $line"
          $foundAlgo=0
          if ( "$line" -match '\\\s*$' ) {
              #write-host "DEBUG write backslash in = $line"
              Add-Content $newjavasecurity "#${line}"
              $nextline=0
          } else {
              #write-host "DEBUG NO backslas in = $line
              Add-Content $newjavasecurity "#${line}"
          }

      } else {
          #write-host "DEBUG not found jdk.tls.disabledAlgorithms in = $line"         
          Add-Content $newjavasecurity "${line}"
      }
  }

  if ( $foundAlgo -eq 2 ) {
      add-content $newjavasecurity -value (get-content $tempvarset)
  }

  remove-item $tempvarset
  copy-item -Path "$newjavasecurity" -Destination "$javasecurity"
  write-host "INFO - modjavasecurity - $newjavasecurity created and copied on $javasecurity"
  return 0
}


function modsslclientprops ($sslclientprops) # modsslclientprops $HFILES["ssl.client.props"]  
{
  # returns rc=4 if file already modified
  $pattern="^[^#]*com.ibm.ssl.protocol.*$TLSVER" 
  If (select-string -Path "$sslclientprops" -Pattern $pattern )  {
      write-host "INFO - modsslclientprops - $sslclientprops contains `"com.ibm.ssl.protocol=$TLSVER`" and will not be modified"
      return 4
  } 
  
  $rc = saveorgcreatenew $sslclientprops  
  $newsslclientprops = $rc.new
  $savesslclientprops = $rc.save

  $foundproto = 1
  foreach ( $line in Get-Content $savesslclientprops ) {
      if ( ("$line" -match 'com.ibm.ssl.protocol') -and ( -not $line.StartsWith("#")) ) {
          if ( "$line" -match 'com.ibm.ssl.protocol=$TLSVER' ) {
              write-host "INFO - modsslclientprops - $sslclientprops contains  'com.ibm.ssl.protocol=${TLSVER}'"
              Add-Content $newsslclientprops "${line}"
          } else {
              write-host "INFO - modsslclientprops - Adding 'com.ibm.ssl.protocol=${TLSVER}'"
              Add-Content $newsslclientprops "com.ibm.ssl.protocol=${TLSVER}"
              Add-Content $newsslclientprops "#${line}"
          }
          $foundproto = 0 
      } else { Add-Content $newsslclientprops "${line}" }
  }
  if ( $foundproto -eq 1 ) {
      write-host "INFO - modsslclientprops - 'com.ibm.ssl.protocol' set ${TLSVER} at the end of props"
      Add-Content $newsslclientprops "com.ibm.ssl.protocol=${TLSVER}"
  }

  copy-item -Path "$newsslclientprops" -Destination "$sslclientprops"
  write-host "INFO - modsslclientprops - $newsslclientprops created and copied on $sslclientprops"
  return 0
}

function importSelfSignedToJREcacerts ($cacerts) # importSelfSignedToJREcacerts $HFILES["cacerts"]
{
  # returns rc=4 if file already modified and rc=5 if KEYKDB does not contain ITM selfsigned certs
  # required otherwise https tacmd tesplogin may not work
  $tempstr = & GSKitcmd gsk8capicmd  -cert -details -stashed -db "$KEYKDB" -label "IBM_Tivoli_Monitoring_Certificate"
  if ( $tempstr -like '*does not contain*') {
      Write-host "INFO - importSelfSignedToJREcacerts - $KEYKDB does not contain label 'IBM_Tivoli_Monitoring_Certificate'. Hence the self seigned certs cannot be copied to the $cacerts file. Continue..."
      return 5
  }
  $out = & $KEYTOOL  -list -v -keystore  "$cacerts" -storepass changeit | Select-String "IBM Tivoli Monitoring"
  if ( $out -like '*IBM Tivoli Monitoring*') {
      $tempstr = & GSKitcmd gsk8capicmd  -cert -details -stashed -db "$KEYKDB" -label "IBM_Tivoli_Monitoring_Certificate" | Select-String "Serial "
      $serialkeyfile= $( $n= $tempstr | findstr "Serial "; $nn= $n -replace " ","" ; $i = $nn.IndexOf(":") ; $nn.substring($i+1) )
      $tempstr = & "$KEYTOOL"  -list -v -keystore "$cacerts" -storepass changeit | Select-String "IBM Tivoli Monitoring" -Context 0,1
      $serialcacerts = $( $n= $tempstr | findstr "Serial"; $nn= $n -replace " ","" ; $i = $nn.IndexOf(":") ; $nn.substring($i+1) )
      if ( $serialkeyfile -eq $serialcacerts ) {
          write-host "INFO - importSelfSignedToJREcacerts - Self signed certs were alreday imported into the JRE cacerts (serial number is equal) and will not be modified"
          return 4
      } else {
          $rc = saveorgcreatenew $cacerts
          echo "INFO - importSelfSignedToJREcacerts - Self signed cert is different in $KEYKDB and $cacerts (serial number is different)"
          echo "INFO - importSelfSignedToJREcacerts - This new cert will be added to $cacerts again (old will be deleted)"
          $tempstr =  & $KEYTOOL -list -v -keystore $cacerts  -storepass changeit | Select-String "Issuer: CN=IBM Tivoli Monitoring" -Context 7,0
          $cacertsalias = $( $n= $tempstr | findstr "Alias "; $nn= $n -replace " ","" ; $i = $nn.IndexOf(":") ; $nn.substring($i+1) )
          $result= & $KEYTOOL -delete -v -keystore "$cacerts"  -storepass changeit -alias "$cacertsalias" 2>&1
          if ( $LASTEXITCODE -gt 0  ) {
              write-host "ERROR - importSelfSignedToJREcacerts - Error during gsk8capicmd/keytool  commands. Powershell script ended!"
              return 1
          } else { write-host $result }
      }
  } else {
      $rc = saveorgcreatenew $cacerts
  }
  $newcacerts = $rc.new
  
  Write-Host "INFO - importSelfSignedToJREcacerts - Modifying $cacerts"
   
  GSKitcmd gsk8capicmd -cert -import -stashed -db $KEYKDB -target $SIGNERSP12 -target_pw changeit -label "IBM_Tivoli_Monitoring_Certificate" -new_label "ibm_tivoli_monitoring_certificate"
  $result = & $KEYTOOL -importkeystore -srckeystore $SIGNERSP12 -srcstoretype pkcs12 -srcstorepass changeit -destkeystore $cacerts -deststoretype jks -deststorepass changeit 2>&1
  if ( $LASTEXITCODE -gt 0  ) {
      write-host "ERROR - importSelfSignedToJREcacerts - Error during gsk8capicmd/keytool  commands. Powershell script ended!"
      return 1
  } else { write-host $result }

  write-host "INFO - importSelfSignedToJREcacerts - $cacerts modified"
  copy-item -Path "$cacerts" -Destination "$newcacerts"
  return 0

}

function renewCert () 
{ 
  # returns rc=4 if default cert was newed recently 
  # check exp date
  $keydate = GSKitcmd gsk8capicmd -cert -details -db $KEYKDB -stashed -label default | find "Not Before"
  $pattern = "efore : (.*) "
  $keydate = [regex]::Match($keydate,$pattern).Groups[1].Value
  $now = get-date
  $ts = New-TimeSpan -Start $keydate -End $now 
  $days = $ts.Days

  if ( $days -lt 100 ) {
      write-host "INFO - renewCert - Default self signed certificate was renewed recently ($days days ago) and will not be renewed again."
      return 4
  }

  $cmd ="& '$WSADMIN' -lang jython -c `"AdminTask.renewCertificate('-keyStoreName NodeDefaultKeyStore -certificateAlias  default')`" -c 'AdminConfig.save()'"
  $cmd += '; $Success=$?'
  Invoke-Expression $cmd
  if ( $Success ) {
      #$cmd ="& '$WSADMIN' -lang jython -c `"AdminTask.getCertificateChain('[-certificateAlias default -keyStoreName NodeDefaultKeyStore -keyStoreScope (cell):ITMCell:(node):ITMNode ]')`" "
      #Invoke-Expression $cmd 
      write-host "INFO - renewCert - Successfully renewed default self signed certificate in eWAS (previous renew was $days days ago)"
     
  } else {
      write-host "$success"
      write-host "ERROR - renewCert - Error during renewing defautl self signed certificate in eWAS. Powershell script ended!"
      return 1
  }

  GSKitcmd gsk8capicmd -cert -delete -db $KEYKDB -stashed -label default
  GSKitcmd gsk8capicmd -cert -delete -db $KEYKDB -stashed -label root
  GSKitcmd gsk8capicmd -cert -import -db $KEYP12 -pw WebAS -target $KEYKDB -target_stashed -label default -new_label default
  GSKitcmd gsk8capicmd -cert -import -db $TRUSTP12 -pw WebAS -target $KEYKDB -target_stashed -label root -new_label root
  if ( -not $? ) {
      write-host "ERROR - renewCert - Error during gsk8capicmd  commands. Powershell script ended!"
      return 1
  } else {
      write-host "INFO - renewCert - Successfully executed gsk8capicmd  commands to copy renewed default self sigend certificates to $KEYKDB." 
      #GSKitcmd gsk8capicmd -cert -list -db $KEYKDB -stashed -label default
      #GSKitcmd gsk8capicmd -cert -details -db $KEYKDB -stashed -label default | findstr "Serial Issuer Subject Not\ Before Not\ After"
      #GSKitcmd gsk8capicmd -cert -details -type p12 -db $KEYP12 -pw WebAS -label default | findstr "Serial Issuer Subject Not\ Before Not\ After"
      #GSKitcmd gsk8capicmd -cert -details -db $KEYKDB -stashed -label root | findstr "Serial Issuer Subject Not\ Before Not\ After"
      #GSKitcmd gsk8capicmd -cert -details -type p12 -db $TRUSTP12 -pw WebAS -label root | findstr "Serial Issuer Subject Not\ Before Not\ After"   
  }
  return 0
}

function modQop () 
{
  # returns rc=4 if QoP already set 
  $cmd = "& '$WSADMIN' -lang jython -c `"AdminTask.getSSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode ]')`" "
  $out= Invoke-Expression $cmd
  $pattern = "sslProtocol $TLSVER"
  $rc=[regex]::Match($out,$pattern)
  if ( $rc.success ) {
      write-host "INFO - modQop - Quality of Protection (QoP) is already set to 'sslProtocol $TLSVER' and will not be modified again." 
      return 4
  } else  {
      write-host "INFO - modQop - Quality of Protection (QoP) not set yet. Modifying..."
  } 
  
  $cmd = "& '$WSADMIN' -lang jython -c `"AdminTask.modifySSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode -keyStoreName NodeDefaultKeyStore -keyStoreScopeName (cell):ITMCell:(node):ITMNode -trustStoreName NodeDefaultTrustStore -trustStoreScopeName (cell):ITMCell:(node):ITMNode -jsseProvider IBMJSSE2 -sslProtocol $TLSVER -clientAuthentication false -clientAuthenticationSupported false -securityLevel HIGH -enabledCiphers ]') `" -c 'AdminConfig.save()'"
  $cmd += '; $Success=$?'
  #write-host $cmd
  Invoke-Expression $cmd
  if ( $Success ) {
      write-host "INFO - modQop - Successfully set $TLSVER for Quality of Protection (QoP)"
      return 0
  } else {
      write-host "ERROR - modQop - Error setting $TLSVER for Quality of Protection (QoP). Powershell script ended!"
      return 1
  }

}

function disableAlgorithms () 
{
  # returns rc=4 if property already set 
  $secxml = "$ITMHOME\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\security.xml"
  $pattern = "com.ibm.websphere.tls.disabledAlgorithms.* value=.*none"  
  if ( select-string -Path "$secxml" -Pattern $pattern ) {
      write-host "INFO - disableAlgorithms - Custom property 'com.ibm.websphere.tls.disabledAlgorithms... value=none' is already set and will not be set again"
      return 4
  } else {
     write-host "INFO - disableAlgorithms - Modifying com.ibm.websphere.tls.disabledAlgorithms WAS custom setting"
  } 
    
  $jython = "$ITMHOME\tmp\org.jy"
  $null = New-Item  -path "$ITMHOME\tmp" -name "org.jy"  -ItemType "file"
  Add-Content $jython "sec = AdminConfig.getid('/Security:/')"
  Add-Content $jython "prop = AdminConfig.getid('/Security:/Property:com.ibm.websphere.tls.disabledAlgorithms/' )"
  Add-Content $jython "if prop:" 
  Add-Content $jython "  AdminConfig.modify(prop, [['value', 'none'],['required', `"false`"]])"
  Add-Content $jython "else: "
  Add-Content $jython " AdminConfig.create('Property',sec,'[[name `"com.ibm.websphere.tls.disabledAlgorithms`"] [description `"Added due ITM TLSVn.n usage`"] [value `"none`"][required `"false`"]]') "
  Add-Content $jython "AdminConfig.save()"
  $cmd = "& '$WSADMIN' -lang jython -f '$jython'"
  $cmd += '; $Success=$?'
  #write-host $cmd 
  Invoke-Expression $cmd
  if ( $Success ) {
      Remove-Item $jython
      write-host "INFO - disableAlgorithms - Successfully set com.ibm.websphere.tls.disabledAlgorithms to none" 
      return 0
  } else {
      write-host "ERROR - disableAlgorithms - Error setting Custom Property ( com.ibm.websphere.tls.disabledAlgorithms ). Powershell script ended!"
      return 1
  }

}
