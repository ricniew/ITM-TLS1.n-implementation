#
# Usage: Copy script to a directory, for examle C:\myfolder and run script in a Powershell window: 
#   PS C:\myfolder> .\activate_teps-tlsv1.2.ps1 [ -h ITMHOME ] [ -n ]
#
# 16.03.2022: Initial version  R. Niewolik EMEA AVP Team
# 13.04.2022: Version 1.31     R. Niewolik EMEA AVP Team
#             - Add check if TEPS and eWas are at the required Level
#             - Backupfolder now created in ITMHOME\backup\.. directory 
# 20.04.2022: Version 1.32     R. Niewolik EMEA AVP Team
#             - New function to check for file existance
#             - Added checks if TLSv1.2 configured already  
# 21.04.2022: Version 1.33     R. Niewolik EMEA AVP Team
#             - Improved checks if TLSv1.2 configured already
#             - Modified restore script (added "if exists")
# 22.04.2022: Version 1.34     R. Niewolik EMEA AVP Team
#             - added "-n" option to allow a run without performing a backup  
# 28.04.2022: Version 1.35     R. Niewolik EMEA AVP Team
#             - Deleted test statement in function renewCert which set $CANDLEHOME to c:\IBM\ITM
#             - Modified invoke-expression commands to support CANDLEHOME path with spaces 
#             - Successfuly tested with CANDLEHOME="C:\Program Files (x86)\ibm\ITM"        
##

param(
    [Parameter(HelpMessage="Disables backup")]
    [switch]$n = $False,

    [Parameter(HelpMessage="ITM home folder")]
    [string]$h,

    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    $UndefinedArgs
)

write-host "INFO - Script Version 1.35"
$startTime = $(get-date)

$scriptname = $MyInvocation.MyCommand.Name
if ( $UndefinedArgs ) { 
    write-host "ERROR - $scriptname - Please use the correct syntax "
    write-host ""
    write-host " Usage:"
    write-host "  $scriptname { -h ITM home } [-n ]"
    write-host ""
    write-host " Sample executions:"
    write-host "    $scriptname -h /opt/IBM/ITM       # ITM home set and a backup is performed. Should be the DEFAULT"
    write-host "    $scriptname -h /opt/IBM/ITM -n    # ITM home set AND NO backup is performed. Please use that parameter carefully!!!!!!"
    write-host ""
    exit 1
}

function getCandleHome ($candlehome) 
{
  if  ( $candlehome ) {
      write-host "INFO - getCandleHome - CANDLE_HOME set by option is:  $candlehome"
      if (Test-Path -Path "$candlehome") { 
          write-host "INFO - getCandleHome - Path $candlehome exists. OK"
          return $candlehome
      } else {
          write-host "ERROR - getCandleHome - Path $candlehome doesn't exist. NOK"
          exit 1
      }
  } else { 
      write-host "INFO - getCandleHome - Looking for environment variable CANDLE_HOME"
      $cdh = Get-WmiObject -query "select * from Win32_environment where username='<system>' and name='CANDLE_HOME'" | ft -hide | out-string;
      if ( !$cdh  ) {
          write-host "INFO - getCandleHome - No ENV CANDLE_HOME set"
          Continue
      } else { 
          $candlehome = $cdh.Split(" ")[0].trim()
          write-host "INFO - getCandleHome - CANDLE_HOME by ENV is $candlehome"
          if (Test-Path -Path "$candlehome" ) {
              write-host "INFO - getCandleHome - Path $candlehome exists. OK"
          } else {
              write-host "ERROR - getCandleHome - Path $candlehome doesn't exist. Please execute script including ITMHOME: scriptname.ps1 C:\IBM\ITM"
              exit 1
          }
      }
  }
  
  return $candlehome
}

function checkIfFileExists () 
{
  # this function als check if the files to backup exists
  if ( Test-Path -Path "$CANDLEHOME/CNPSJ" ) {
      write-host "INFO - checkIfFileExists - Directory $CANDLEHOME/CNPSJ  OK."
  } else {
      write-host "ERROR - checkIfFileExists - Directory $CANDLEHOME/CNPSJ  does NOT exists. Please check."
  }
  if ( Test-Path -Path "$CANDLEHOME\keyfiles" ) {
      write-host "INFO - checkIfFileExists - Directory $CANDLEHOME\keyfiles  OK."
  } else {
      write-host "ERROR - checkIfFileExists - Directory $CANDLEHOME\keyfiles  does NOT exists. Please check."
  }
  
  foreach ( $h in $HFILES.Keys ) {
      if ( test-path "$($HFILES.$h)" ) { 
          write-host "INFO - checkIfFileExists - File $($HFILES.$h) OK."
          continue
      } else {
          if ( $h -like '*kcjparms*') {
              write-host "WARNING - checkIfFileExists - File $($HFILES.$h) does NOT exists. KCJ component probably not installed. Continue..."
              $KCJ=4 # will be used later in main and createRestoreScript
              continue
          } else {
              write-host "ERROR - checkIfFileExists - file $($HFILES.$h) does NOT exists. Please check."
              exit 1
          }
      }      
  }
  
  return 0
}  

function backupfile ($file) 
{
  #write-host "DEBUG - backupfile- $file"
  if ( test-path "$file" ) {
      write-host "INFO - backupfile - Saving $file in $BACKUPFOLDER "
      Copy-Item -Path "$file" -Destination "$BACKUPFOLDER"
      if ( -not $? ) {
          write-host "ERROR - backupfile - Error during copy of file $filen to $BACKUPFOLDER !! Check permissions and space available."
          exit 1
      } else { 
          return 0 
      }
  }
}

function backupewasAndkeys ($backupfolder) 
{
  write-host "INFO - backupewasAndkeys - Directory $CANDLEHOME\CNPSJ saving in $BACKUPFOLDER. This can take a while..."
  Copy-Item -Path "$CANDLEHOME\CNPSJ" -Destination "$BACKUPFOLDER" -Recurse -erroraction stop
  if ( -not $? ) {
      write-host "ERROR - backupewasAndkeys - Could not copy $CANDLEHOME/CNPSJ folder to $BACKUPFOLDER !! Check permissions and available space."
      exit 1
  }
  write-host "INFO - backupewasAndkeys - Directory $CANDLEHOME\keyfiles saving in $BACKUPFOLDER"
  Copy-Item -Path "$CANDLEHOME\keyfiles" -Destination "$BACKUPFOLDER" -Recurse -erroraction stop
  write-host "INFO - backupewasAndkeys - Files successfully saved in folder $BACKUPFOLDER."
  if ( -not $? ) {
      write-host "ERROR - backupewasAndkeys - Could not copy $CANDLEHOME/keyfiles folder to $BACKUPFOLDER !! Check permissions and available space."
      exit 1
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
  Add-Content $restorebatfull "xcopy /y/s CNPSJ `"$CANDLEHOME\CNPSJ`""
  Add-Content $restorebatfull "xcopy /y/s keyfiles `"$CANDLEHOME\keyfiles`""
  Add-Content $restorebatfull " "

  foreach ( $h in $HFILES.Keys ) {
      $string="copy $h  `"$($HFILES.$h)`""
      if ( ( $file -like '*kcjparms*')  -and ( $KCJ = 4 ) ) {
          #write-host "WARNING - createRestoreScript - TEP Desktop Client apparently not installed. File 'kcjparms.txt' not added to restore script"
          continue 
      } 
      Add-Content $restorebatfull $string
      Add-Content $restorebatfull "if exist `"$($HFILES.$h).beforetls12`" del `"$($HFILES.$h).beforetls12`""
      Add-Content $restorebatfull "if exist `"$($HFILES.$h).tls12`" del `"$($HFILES.$h).tls12`""
      Add-Content $restorebatfull " "
  }
  Add-Content $restorebatfull " "
  Add-Content $restorebatfull "kinconfg -n -rKCB"
  Add-Content $restorebatfull "kinconfg -n -rKCJ"
  Add-Content $restorebatfull "cd .."

  write-host "INFO - createRestoreScript - Restore bat file created $restorebatfull"
  Start-Sleep -seconds 4
}

function EnableICSLIte ($action) 
{
  write-host "INFO - EnableICSLIte - ISCLite set enabled=$action."
  $cmd="& '$CANDLEHOME\CNPSJ\bin\wsadmin' -conntype SOAP -lang jacl -f '$CANDLEHOME\CNPSJ\scripts\enableISCLite.jacl' $action"
  $cmd += '; $Success=$?'
  #write-host "$cmd"
  $out = Invoke-Expression $cmd
  if ( $Success ) { write-host "INFO - EnableICSLIte - Successfully set ISCLite to '$action'." }
  else {
      write-host "$success"
      write-host "ERROR - EnableICSLIte - Enable ISCLite command $cmd failed. Possibly you did not set a eWAS user password. "
      write-host " Try to set a password as descirbed here https://www.ibm.com/docs/en/tivoli-monitoring/6.3.0?topic=administration-define-wasadmin-password" 
      write-host " Powershell script ended!"
      exit 1
  }
  
}

function restartTEPS () 
{
  write-host "INFO - restartTEPS - Restarting TEPS ..." -ForegroundColor Yellow
  net stop KFWSRV 
  net start KFWSRV
  if ( -not $? ) {
      write-host "ERROR - restartTEPS - TEPS restart failed. Powershell script ended!"
      exit 1
  } else {
      write-host "INFO - restartTEPS - Waiting for TEPS to initialize...."
      Start-Sleep -seconds 7
      $wait = 1
      $c=0
      while($wait -eq 1) {
          If (Select-String -Path "$CANDLEHOME\logs\kfwservices.msg" -Pattern 'Waiting for requests. Startup complete' -SimpleMatch) {
              write-host ""
              write-host 'INFO - restartTEPS - TEPS started successfully' -ForegroundColor Green
              $wait = 0 
          } Else {
              write-host -NoNewline ".."
              $c = $c + 3
              Start-Sleep -seconds 3  
          }
          if ( $c -gt 150 ) {
              write-host "ERROR - restartTEPS - TEPS restart takes too long (over 2,5) min. Something went wrong. Powershell script ended!"
              exit 1
          }
              
      }
      Start-Sleep -seconds 5
  }
}

function saveorgcreatenew ($orgfile) 
{
  [hashtable]$return = @{}
  $saveorgfile = "$orgfile.beforetls12"

  # should not happen, testing anyway
  if ( test-path "$saveorgfile" ) { 
      write-host "WARNING - saveorgcreatenew - $saveorgfile exists and will be reused (contains original content)"
  } else {
      write-host "INFO - saveorgcreatenew - $saveorgfile created to save original content" 
      Copy-Item -Path "$orgfile" -Destination "$saveorgfile"
  }

  $neworgfile = "$orgfile.tls12"
  write-host "INFO - saveorgcreatenew - $neworgfile will be the modified file"
  if ( test-path "$neworgfile" ) {
      write-host "INFO - saveorgcreatenew - $neworgfile exists already and will be deleted"
      remove-item $neworgfile
  } else {
      $dir = Split-Path $neworgfile -Parent
      $file = Split-Path $neworgfile -Leaf 
      $null = New-Item -path "$dir" -name "$file" -ItemType "file"
  }

  #write-host "DEBUG - saveorgcreatenew - new= $neworgfile save= $saveorgfile org= $orgfile"
  $return.new = "$neworgfile"
  $return.save =  "$saveorgfile"
  return $return
}


function modhttpconf ($httpdfile) 
{
  $pattern = "^\s*SSLProtocolDisable\s*TLSv11"  
  if (select-string -Path "$httpdfile" -Pattern $pattern) {
    $pattern = "^\s*SSLProtocolEnable\s*TLSv12" 
    if (select-string -Path "$httpdfile" -Pattern $pattern) {
        write-host "WARNING - modhttpconf - $httpdfile contains 'SSLProtocolEnable TLSv12' + TLS11,10 disabled and will not be modified"
        return 4
    } else {
        write-host "INFO - modhttpconf - Modifying $httpdfile"
    }
  }
  
  $rc = saveorgcreatenew $httpdfile
  
  $newhttpdfile = $rc.new
  $savehttpdfile = $rc.save
  $foundsslcfg = 1
  foreach( $line in Get-Content $savehttpdfile ) {
      #echo -- $foundsslcfg
      if ( $line.StartsWith("#") ) { Add-Content $newhttpdfile "${line}" ; continue }
      if ( "$line" -match "ServerName\s*(.*):15200" ) {
          $temp = 'ServerName ' + $matches[1] + ':15201'
          Add-Content $newhttpdfile $temp
          Add-Content $newhttpdfile "#${line}"
          continue
      }
      if ( "$line" -match "Listen\s*0.0.0.0:15200" ) {
          $temp = 'ServerName ' + $matches[1] + ':15201'
          Add-Content $newhttpdfile "Listen 127.0.0.1:15200"
          Add-Content $newhttpdfile "#${line}"
          continue
      }
      if ( $foundsslcfg -eq 1 ) {  
          if ( $line -eq '<VirtualHost *:15201>') {
              #echo Debug -modhttpconf-----line= $line -- foundsslcfg= $foundsslcfg 
              $ch = $CANDLEHOME -replace "\\", '/'
              $foundsslcfg = 0
              Add-Content $newhttpdfile $line
              $temp = '  DocumentRoot "' + ${ch} + '/CNB"'
              Add-Content $newhttpdfile $temp
              Add-Content $newhttpdfile '  SSLEnable'
              Add-Content $newhttpdfile '  SSLProtocolDisable SSLv2'
              Add-Content $newhttpdfile '  SSLProtocolDisable SSLv3'
              Add-Content $newhttpdfile '  SSLProtocolDisable TLSv10'
              Add-Content $newhttpdfile '  SSLProtocolDisable TLSv11'
              Add-Content $newhttpdfile '  SSLProtocolEnable TLSv12'
              Add-Content $newhttpdfile '  SSLCipherSpec ALL -SSL_RSA_WITH_3DES_EDE_CBC_SHA'
              $temp = '  ErrorLog "' + ${ch} + '/IHS/logs/sslerror.log"' 
              Add-Content $newhttpdfile $temp
              $temp = '  TransferLog "' + ${ch} + '/IHS/logs/sslaccess.loclsg"'
              Add-Content $newhttpdfile $temp
              $temp = '  KeyFile "' + $ch + '/keyfiles/keyfile.kdb"'
              Add-Content $newhttpdfile "$temp"
              $temp = '  SSLStashfile "' + ${ch} + '/keyfiles/keyfile.sth\"' 
              Add-Content $newhttpdfile $temp
              Add-Content $newhttpdfile '  SSLServerCert IBM_Tivoli_Monitoring_Certificate'
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


function modkfwenv ($kfwenv) 
{
  $pattern="KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only" 
  if (select-string -Path "$kfwenv" -Pattern $pattern) {
     $pattern="KDEBE_TLS11_ON=NO"
     if (select-string -Path "$kfwenv" -Pattern $pattern) {
         write-host "WARNING - modkfwenv - $kfwenv contains 'KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only' and will not be modified"
         return 4
     } else {
         write-host "INFO - modkfwenv - Modifying $kfwenv"
     }
  }

  $rc = saveorgcreatenew $kfwenv
  
  $newkfwenv = $rc.new
  $savekfwenv = $rc.save
  $foundKFWORB = $foundTLS10 = $foundTLS11 = $foundTLS12 = 1

  foreach( $line in Get-Content $savekfwenv ) {
      if ( $line.StartsWith("#") ) { Add-Content $newkfwenv "${line}" ; continue }
      if ( "$line" -match "KFW_ORB_ENABLED_PROTOCOLS" ) {
          Add-Content $newkfwenv "KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only" 
          $foundKFWORB = 0 ; continue
      } elseif ( "$line" -match "KDEBE_TLS10_ON" ) {
          Add-Content $newkfwenv "KDEBE_TLS10_ON=NO" 
          $foundTLS10 = 0 ; continue
          continue
      } elseif ( "$line" -match "KDEBE_TLS11_ON" ) {
          Add-Content $newkfwenv "KDEBE_TLS11_ON=NO"
          $foundTLS11 = 0 ; continue
      } elseif ( "$line" -match "KDEBE_TLSV12_CIPHER_SPECS" ) {
          Add-Content $newkfwenv "KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256"
          $foundTLS12 = 0 ; continue
      } else { Add-Content $newkfwenv "${line}" }
  }
  if ( $foundKFWORB -eq 1 ) { Add-Content $newkfwenv 'KFW_ORB_ENABLED_PROTOCOLS=TLS_Version_1_2_Only' } 
  if ( $foundTLS10 -eq 1 )  { Add-Content $newkfwenv 'KDEBE_TLS10_ON=NO'} 
  if ( $foundTLS11 -eq 1 )  { Add-Content $newkfwenv 'KDEBE_TLS11_ON=NO' }
  if ( $foundTLS12 -eq 1 )  { Add-Content $newkfwenv 'KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256' }
  copy-item -Path "$newkfwenv" -Destination "$kfwenv"
  write-host "INFO - modkfwenv - $newkfwenv created and copied on $kfwenv"  
  return 0
}


function modtepjnlpt ($tepjnlpt) 
{
  $pattern="\s*<property name=`"jnlp.tep.sslcontext.protocol`.*TLSv1.2" 
  If (select-string -Path "$tepjnlpt" -Pattern $pattern) {
      $pattern="codebase=`"https.*:15201"
      If (select-string -Path "$tepjnlpt" -Pattern $pattern) { 
          write-host "WARNING - modtepjnlpt - $tepjnlpt contains 'jnlp.tep.sslcontext.protocol value=`"TLSv1.2`"' and will not be modified"
          return 4
      } else {
         write-host "INFO - modtepjnlpt - Modifying $tepjnlpt"
      }
  }

  $rc = saveorgcreatenew $tepjnlpt
  $newtepjnlpt = $rc.new
  $savetepjnlpt = $rc.save
  $foundprotocol = $foundport = $foundTLS12 = 1
  foreach( $line in Get-Content $savetepjnlpt ) {
      if ( "$line" -match 'codebase="http://\$HOST\$:(.*)/' ) {
          Add-Content $newtepjnlpt '  codebase="https://$HOST$:15201/"> '
      } elseif ( "$line" -match '\s*<property name="jnlp.tep.connection.protocol"\s*value=.*' ) {
          Add-Content $newtepjnlpt '    <property name="jnlp.tep.connection.protocol" value="https"/> '
          $foundprotocol = 0
      } elseif ( "$line" -match '\s*<property name="jnlp.tep.connection.protocol.url.port"\s*value=.*' ) {
          Add-Content $newtepjnlpt '    <property name="jnlp.tep.connection.protocol.url.port" value="15201"/> '
          $foundport = 0
      } elseif ( "$line" -match '\s*<property name="jnlp.tep.sslcontext.protocol" value=.*' ) {
          Add-Content $newtepjnlpt '    <property name="jnlp.tep.sslcontext.protocol" value="TLSv1.2"/> '
          $foundTLS12 = 0
      } else { Add-Content $newtepjnlpt "${line}" }
  }
  $count = $foundprotocol + $foundport + $foundTLS12
  if ( $count -gt 0 ) {
      #write-host "-DEBUG-modtepjnlpt----- c=$count --$foundprotocol = $foundport = $foundTLS12"
      $tempfile = "$newtepjnlpt.temporaryfile" 
      foreach( $line in Get-Content $newtepjnlpt ) {
          if ( "$line" -match "- Custom parameters\s*-" ) {
              Add-Content $tempfile "${line}"
              if ( $foundprotocol -eq 1 ) { Add-Content $tempfile '    <property name="jnlp.tep.connection.protocol" value="https"/> '} 
              if ( $foundport -eq 1 ) { Add-Content $tempfile '    <property name="jnlp.tep.connection.protocol.url.port" value="15201"/> '}
              if ( $foundTLS12 -eq 1 ) { Add-Content $tempfile '    <property name="jnlp.tep.sslcontext.protocol" value="TLSv1.2"/> '}
          } else { Add-Content $tempfile "${line}" }
      }
      copy-item -Path "$tempfile" -Destination "$newtepjnlpt"
      remove-item "$tempfile"
  } else { }
  copy-item -Path "$newtepjnlpt" -Destination "$tepjnlpt"
  write-host "INFO - modtepjnlpt - $newtepjnlpt created and copied on $tepjnlpt"
  return 0
}


function modcomponentjnlpt ($componentjnlpt) 
{
  $pattern="codebase=`"https.*:15201" 
  If (select-string -Path "$componentjnlpt" -Pattern $pattern) {
      write-host "WARNING - modcomponentjnlpt - $componentjnlpt contains 'codebase=https..:15201' and will not be modified"
      return 4
  } else {
     write-host "INFO - modcomponentjnlpt - Modifying $componentjnlpt"
  }

  $rc = saveorgcreatenew $componentjnlpt

  $newcomponentjnlpt = $rc.new
  $savecomponentjnlpt = $rc.save
  foreach( $line in Get-Content $savecomponentjnlpt ) {
      if ( "$line" -match 'codebase="http://\$HOST\$:(.*)/' ) {
          Add-Content $newcomponentjnlpt '  codebase="https://$HOST$:15201/" '
      } else { Add-Content $newcomponentjnlpt "${line}" }
  }
  copy-item -Path "$newcomponentjnlpt" -Destination "$componentjnlpt"
  write-host "INFO - modcomponentjnlpt - $newcomponentjnlpt created and copied on $componentjnlpt"
  return 0
}

function modapplethtmlupdateparams ($applethtmlupdateparams) 
{  
  $pattern="tep.sslcontext.protocol.*verride.*TLSv1.2" 
  If (select-string -Path "$applethtmlupdateparams" -Pattern $pattern) {
      $pattern="tep.connection.protocol.*verride.*https"
      If (select-string -Path "$applethtmlupdateparams" -Pattern $pattern) {
          write-host "WARNING - modapplethtmlupdateparams - $applethtmlupdateparams contains  `"tep.sslcontext.protocol|override|'TLSv1.2'`" and will not be modified"
          return 4
      } else {
          write-host "INFO - modapplethtmlupdateparams - Modifying $applethtmlupdateparams"
      }
  }

  $rc = saveorgcreatenew $applethtmlupdateparams

  $newapplethtmlupdateparams = $rc.new
  $saveapplethtmlupdateparams = $rc.save
  $foundprotocol = $foundport = $foundTLS12 = 1
  foreach( $line in Get-Content $saveapplethtmlupdateparams ) {
      if ( "$line" -match 'tep.connection.protocol\|override' ) {
          Add-Content $newapplethtmlupdateparams "tep.connection.protocol|override|'https'"
          $foundprotocol = 0
      } elseif ( "$line" -match 'tep.connection.protocol.url.port' ) {
          Add-Content $newapplethtmlupdateparams "tep.connection.protocol.url.port|override|'15201'"
          $foundport = 0
      } elseif ( "$line" -match 'tep.sslcontext.protocol' ) {
          Add-Content $newapplethtmlupdateparams "tep.sslcontext.protocol|override|'TLSv1.2'"
          $foundTLS12 = 0 
      } else { Add-Content $newapplethtmlupdateparams "${line}" }
  }
  $count = $foundprotocol + $foundport + $foundTLS12
  if ( $count -gt 0 ) {
      #write-host "-DEBUG-modapplethtmlupdateparams----- c=$count --$foundprotocol = $foundport = $foundTLS12"
      if ( $foundprotocol -eq 1 ) { Add-Content $newapplethtmlupdateparams "tep.connection.protocol|override|'https'" } 
      if ( $foundport -eq 1 ) { Add-Content $newapplethtmlupdateparams "tep.connection.protocol.url.port|override|'15201'" }
      if ( $foundTLS12 -eq 1 ) { Add-Content $newapplethtmlupdateparams "tep.sslcontext.protocol|override|'TLSv1.2'" }
  } else { }
  copy-item -Path "$newapplethtmlupdateparams" -Destination "$applethtmlupdateparams"
  write-host "INFO - modapplethtmlupdateparams - $newapplethtmlupdateparams created and copied on $applethtmlupdateparams"
  return 0

}

function modkcjparmstxt ($kcjparmstxt) 
{
  $pattern="tep.sslcontext.protocol.*TLSv1.2" 
  If (select-string -Path "$kcjparmstxt" -Pattern $pattern) {
      $pattern="tep.connection.protocol.*https"
      If (select-string -Path "$kcjparmstxt" -Pattern $pattern) {
          write-host "WARNING - modkcjparmstxt - $kcjparmstxt contains `"tep.sslcontext.protocol|override|'TLSv1.2'`" and will not be modified"
          return 4
      } else {
          write-host "INFO - modkcjparmstxt - Modifying $kcjparmstxt"
      }
  }

  $rc = saveorgcreatenew $kcjparmstxt

  $newkcjparmstxt = $rc.new
  $savenewkcjparmstxt = $rc.save
  $foundprotocol = 1
  $foundport = 1
  $foundTLS12 = 1
  foreach( $line in Get-Content $savenewkcjparmstxt ) {
      if ( $line.StartsWith("#") ) { Add-Content $newkcjparmstxt "${line}" ; continue 
      } elseif ( "$line" -match 'tep.connection.protocol \s*\|' ) {
          #Add-Content $newkcjparmstxt "${line}"
          Add-Content $newkcjparmstxt "tep.connection.protocol | string | https | Communication protocol used between TEP/TEPS (iiop,http,https)"
          $foundprotocol = 0
          continue
      } elseif ( "$line" -match 'tep.connection.protocol.url.port \s*\|' ) {
          Add-Content $newkcjparmstxt "tep.connection.protocol.url.port | int | 15201 | Port used by the TEP to connect with the TEPS"
          $foundport = 0
          continue
      } elseif ( "$line" -match 'tep.sslcontext.protocol \s*\|' ) {
          Add-Content $newkcjparmstxt "tep.sslcontext.protocol | string | TLSv1.2 | TLS used TEP to connect with the TEPS"
          $foundTLS12 = 0
          continue
      } else { Add-Content $newkcjparmstxt "${line}" }
  }

  if ( $foundprotocol -eq 1 ) { Add-Content $newkcjparmstxt "tep.connection.protocol | string | https | Communication protocol used between TEP/TEPS (iiop,http,https)" }
  if ( $foundport -eq 1 ) { Add-Content $newkcjparmstxt "tep.connection.protocol.url.port | int | 15201 | Port used by the TEP to connect with the TEPS" }
  if ( $foundTLS12 -eq 1 ) { Add-Content $newkcjparmstxt "tep.sslcontext.protocol | string | TLSv1.2 | TLS used TEP to connect with the TEPS" }

  copy-item -Path "$newkcjparmstxt" -Destination "$kcjparmstxt"
  write-host "INFO - modkcjparmstxt - $newkcjparmstxt created and copied on $kcjparmstxt"
  return 0
}

function modjavasecurity ($javasecurity) 
{
  $pattern="jdk.tls.disabledAlgorithms=MD5.*SSLv3.*DSA.*DESede.*DES.*RSA.*keySize\s*<\s*2048" 
  If (select-string -Path "$javasecurity" -Pattern $pattern) {
      write-host "WARNING - modjavasecurity - $javasecurity contains `"jdk.tls.disabledAlgorithms=MD5, SSLv3, DSA, DESede, DES, RSA keySize < 2048`" and will not be modified"
      return 4
  } else {
      write-host "INFO - modjavasecurity - Modifying $javasecurity"
  }

  $rc = saveorgcreatenew $javasecurity

  $newjavasecurity = $rc.new
  $savenewjavasecurity = $rc.save
  $nextline = 1
  $foundAlgo = 1
  foreach ( $lines in Get-Content $savenewjavasecurity ) {
      $line=$lines.TrimEnd()
      if ( $line.StartsWith("#") ) { Add-Content $newjavasecurity "${line}" ; continue }
      if ( $nextline -eq 0  ) {
          if ( $line -notmatch '\\\s*$' ) {
              Add-Content $newjavasecurity "${line}"
              Add-Content $newjavasecurity "jdk.tls.disabledAlgorithms=MD5, SSLv3, DSA, DESede, DES, RSA keySize < 2048"
              $foundAlgo = 0
              $nextline = 1
              continue
          } else {  
              Add-Content $newjavasecurity "${line}"
              continue
          }
      } elseif ( ( "$line" -match 'jdk.tls.disabledAlgorithms' ) -and ( $line -match '\\\s*$' ) ) {
          Add-Content $newjavasecurity "${line}"
          $nextline = 0
          continue 
      } else {         
          Add-Content $newjavasecurity "${line}"
      }
  }
  if ( $foundAlgo -eq 1 ) {
      Add-Content $newjavasecurity "jdk.tls.disabledAlgorithms=MD5, SSLv3, DSA, DESede, DES, RSA keySize < 2048"
  }
  copy-item -Path "$newjavasecurity" -Destination "$javasecurity"
  write-host "INFO - modjavasecurity - $newjavasecurity created and copied on $javasecurity"
  return 0
}


function modsslclientprops ($sslclientprops) 
{
  $pattern="com.ibm.ssl.protocol.*TLSv1.2" 
  If (select-string -Path "$sslclientprops" -Pattern $pattern) {
      write-host "WARNING - modsslclientprops - $sslclientprops contains `"com.ibm.ssl.protocol=TLSv1.2`" and will not be modified"
      return 4
  } else {
      write-host "INFO - modsslclientprops - Modifying $sslclientprops"
  }  
  
  $rc = saveorgcreatenew $sslclientprops
  
  $newsslclientprops = $rc.new
  $savesslclientprops = $rc.save
  $foundproto = 1
  foreach ( $line in Get-Content $savesslclientprops ) {
      if ( ("$line" -match 'com.ibm.ssl.protocol') -and ( -not $line.StartsWith("#")) ) {
          if ( "$line" -match 'com.ibm.ssl.protocol=TLSv1.2' ) {
              write-host "INFO - modsslclientprops - $sslclientprops contains  'com.ibm.ssl.protocol=TLSv1.2'"
              Add-Content $newsslclientprops "${line}"
          } else {
              write-host "INFO - modsslclientprops - Adding 'com.ibm.ssl.protocol=TLSv1.2'"
              Add-Content $newsslclientprops "com.ibm.ssl.protocol=TLSv1.2"
              Add-Content $newsslclientprops "#${line}"
          }
          $foundproto = 0 
      } else { Add-Content $newsslclientprops "${line}" }
  }
  if ( $foundproto -eq 1 ) {
      write-host "INFO - modsslclientprops - 'com.ibm.ssl.protocol' set TLSv1.2 at the end of props"
      Add-Content $newsslclientprops "com.ibm.ssl.protocol=TLSv1.2"
  }
  copy-item -Path "$newsslclientprops" -Destination "$sslclientprops"
  write-host "INFO - modsslclientprops - $newsslclientprops created and copied on $sslclientprops"
  return 0
}

function renewCert  
{ 
  $KEYKDB="$CANDLEHOME\\keyfiles\\keyfile.kdb"
  $KEYP12="$CANDLEHOME\\CNPSJ\\profiles\\ITMProfile\\config\\cells\\ITMCell\\nodes\\ITMNode\\key.p12"
  $TRUSTP12="$CANDLEHOME\\CNPSJ\\profiles\\ITMProfile\\config\\cells\\ITMCell\\nodes\\ITMNode\\trust.p12"

  # check exp date
  $keydate = GSKitcmd gsk8capicmd -cert -details -db $KEYKDB -stashed -label default | find "Not Before"
  $pattern = "efore : (.*) "
  $keydate = [regex]::Match($keydate,$pattern).Groups[1].Value
  $now = get-date
  $ts = New-TimeSpan -Start $keydate -End $now 
  $days = $ts.Days

  if ( $days -lt 10 ) {
      write-host "WARNING - renewCert - Default certificate was renewed recently ($days days ago) and will not be renewed again"
      return 4
  } else {
      write-host "INFO - renewCert -  Default certificate will be renewed again ($days)" 
  } 

  $cmd ="& '$CANDLEHOME\CNPSJ\bin\wsadmin' -lang jython -c `"AdminTask.renewCertificate('-keyStoreName NodeDefaultKeyStore -certificateAlias  default')`" -c 'AdminConfig.save()'"
  $cmd += '; $Success=$?'
  #write-host $cmd
  Invoke-Expression $cmd
  if ( $Success ) {
      #$cmd ="& '$CANDLEHOME\CNPSJ\bin\wsadmin' -lang jython -c `"AdminTask.getCertificateChain('[-certificateAlias default -keyStoreName NodeDefaultKeyStore -keyStoreScope (cell):ITMCell:(node):ITMNode ]')`" "
      #Invoke-Expression $cmd 
      write-host "INFO - renewCert - Successfully renewed Certificate in eWAS"
     
  } else {
      write-host "$success"
      write-host "ERROR - renewCert - Error during renewing Certificate in eWAS. Powershell script ended!"
      exit 1
  }

  GSKitcmd gsk8capicmd -cert -delete -db $KEYKDB -stashed -label default
  GSKitcmd gsk8capicmd -cert -delete -db $KEYKDB -stashed -label root
  GSKitcmd gsk8capicmd -cert -import -db $KEYP12 -pw WebAS -target $KEYKDB -target_stashed -label default -new_label default
  GSKitcmd gsk8capicmd -cert -import -db $TRUSTP12 -pw WebAS -target $KEYKDB -target_stashed -label root -new_label root
  if ( -not $? ) {
      write-host "ERROR - renewCert - Error during gsk8capicmd  commands. Powershell script ended!"
      exit 1
  } else {
      write-host "INFO - renewCert - Successfully executed gsk8capicmd  commands to copy renewed certificates to $KEYKDB." 
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
  # check if set already
  $cmd = "& '$CANDLEHOME\CNPSJ\bin\wsadmin' -lang jython -c `"AdminTask.getSSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode ]')`" "
  $out= Invoke-Expression $cmd
  $pattern = "sslProtocol TLSv1.2"
  $rc=[regex]::Match($out,$pattern)
  if ( $rc.success ) {
      write-host "WARNING - modQop - Quality of Protection (QoP) is already set to 'sslProtocol SSL_TLSv2' and will not be modified again." 
      return 4
  } else  {
      write-host "INFO - modQop - Quality of Protection (QoP) not set yet. Modifying..."
  } 
  
  $cmd = "& '$CANDLEHOME\CNPSJ\bin\wsadmin' -lang jython -c `"AdminTask.modifySSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode -keyStoreName NodeDefaultKeyStore -keyStoreScopeName (cell):ITMCell:(node):ITMNode -trustStoreName NodeDefaultTrustStore -trustStoreScopeName (cell):ITMCell:(node):ITMNode -jsseProvider IBMJSSE2 -sslProtocol TLSv1.2 -clientAuthentication false -clientAuthenticationSupported false -securityLevel HIGH -enabledCiphers ]') `" -c 'AdminConfig.save()'"
  $cmd += '; $Success=$?'
  #write-host $cmd
  Invoke-Expression $cmd
  if ( $Success ) {
      write-host "INFO - modQop - Successfully set TLSv1.2 for Quality of Protection (QoP)"
      return 0
  } else {
      write-host "ERROR - modQop - Error setting TLSv1.2 for Quality of Protection (QoP). Powershell script ended!"
      exit 1
  }

}

function disableAlgorithms () 
{
  $secxml = "$CANDLEHOME\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\security.xml"
  $pattern = "com.ibm.websphere.tls.disabledAlgorithms.* value=.*none"  
  if ( select-string -Path "$secxml" -Pattern $pattern ) {
      write-host "WARNING - disableAlgorithms - Custom property 'com.ibm.websphere.tls.disabledAlgorithms... value=none' is already set and will not be set again"
      return 4
  } else {
     write-host "INFO - disableAlgorithms - Modifying $secxml"
  } 
  
   
  $jython = "$CANDLEHOME\tmp\org.jy"
  $null = New-Item  -path "$CANDLEHOME\tmp" -name "org.jy"  -ItemType "file"
  Add-Content $jython "sec = AdminConfig.getid('/Security:/')"
  Add-Content $jython "prop = AdminConfig.getid('/Security:/Property:com.ibm.websphere.tls.disabledAlgorithms/' )"
  Add-Content $jython "if prop:" 
  Add-Content $jython "  AdminConfig.modify(prop, [['value', 'none'],['required', `"false`"]])"
  Add-Content $jython "else: "
  Add-Content $jython " AdminConfig.create('Property',sec,'[[name `"com.ibm.websphere.tls.disabledAlgorithms`"] [description `"Added due ITM TSLv1.2 usage`"] [value `"none`"][required `"false`"]]') "
  Add-Content $jython "AdminConfig.save()"
  $cmd = "& '$CANDLEHOME\CNPSJ\bin\wsadmin' -lang jython -f '$jython'"
  $cmd += '; $Success=$?'
  #write-host $cmd 
  Invoke-Expression $cmd
  if ( $Success ) {
      Remove-Item $jython
      write-host "INFO - modQop - Successfully set com.ibm.websphere.tls.disabledAlgorithms to none" 
      return 0
  } else {
      write-host "ERROR - modQop - Error setting Custom Property ( com.ibm.websphere.tls.disabledAlgorithms ). Powershell script ended!"
      exit 1
  }

}

# --------------------------------------------------------------
# MAIN ---------------------------------------------------------
# --------------------------------------------------------------
$nobackup = $n # getting value provided by param  "[switch]$n = $False", see at top of this script
$tmphome = $h # getting value provided by param "[string]$h"

$CANDLEHOME = getCandleHome $tmphome
$BACKUPFOLDER = "$CANDLEHOME\Backup\backup_before_TLS1.2" 
$RESTORESCRIPT = "SCRIPTrestore.bat"

$permissions = kincinfo -r
if ( $permissions.Contains(‘Cannot obtain all necessary privileges’) ) {
    write-host "ERROR - main - You have not permissions to execute required commands (e.g. kincinfo). You must be logged in with an administrator account"
    exit 1
} else {
    write-host "INFO - main - Permissions OK kincinfo can be executed."
}

$cmd = 'kincinfo -t cq|find "CQ  TEPS"'
$tmp = Invoke-Expression $cmd
$tmparray = $($tmp -replace '\s+',' ').Split(" ")
$tepsver = [int]$($tmparray[8] -replace '\.', '')
if ( $tepsver -lt 06300700  ) {
    write-host "ERROR - main - TEPS server must be at least at version 06.30.07.00 (is $tepsver)." 
    exit
} else { 
    write-host "INFO - main - TEPS version = $tepsver" 
}

$cmd = 'kincinfo -t iw|find "IW  TEPS"'
$tmp = Invoke-Expression $cmd
$tmparray = $($tmp -replace '\s+',' ').Split(" ")
$ewasver = [int]$($tmparray[9] -replace '\.', '')
if ( $ewasver -lt 08551600 ) {
    write-host "ERROR - main - eWAS server must be at least at version 08.55.16.00 (is $ewasver). Please perform an eWAS and IHS uplift as described in the udpate readme files" 
    exit
} else { 
    write-host "INFO - main - eWAS version = $ewasver" 
}

$tepsstatus = Get-Service -Name KFWSRV
if ( $tepsstatus.Status -ne "Running" ) {
    write-host "ERROR - main - TEPS not running. Please start it and restart the procedure"
    exit 1
} elseif ( -not ( Select-String -Path "$CANDLEHOME\logs\kfwservices.msg" -Pattern 'Waiting for requests. Startup complete' -SimpleMatch) ) {
    write-host "ERROR - main - TEPS started but not connected to TEMS"
    exit 1
}

if ( -not $nobackup ) { 
    if ( test-path "$BACKUPFOLDER" ) { 
        write-host "ERROR - main - This script was started already and the folder $BACKUPFOLDER exists already! To avoid data loss, "
        write-host "before executing this script again, you must restore the original content by using the '$RESTORESCRIPT' script and delete/rename the backup folder."
        exit 1 
    } else {
        $null = New-Item -Path "$CANDLEHOME\Backup"  -Name (Split-Path -Leaf "$BACKUPFOLDER") -ItemType "directory"
        write-host "INFO - main - Folder $BACKUPFOLDER created."
    }
} else {
    write-host "WARNING - main - !!!! Backup will not be done because option `"-n`" was set !!!!. Press CTRL+C in the next 7 secs if it was a mistake."
    Start-Sleep -seconds 7 
}

if ( test-path "$CANDLEHOME\CNPSJ" ) { 
    write-host "INFO - main - Tivoli Enterpise Portal Server is installed."
} else {
    write-host "ERROR - main - Tivoli Enterpise Portal Server not installed. Directory '$CANDLEHOME\CNPSJ' does not exists!"
    exit 1
} 

$HFILES = @{ `
  "httpd.conf"                = "${CANDLEHOME}\IHS\conf\httpd.conf" ; `
  "kfwenv"                    = "${CANDLEHOME}\CNPS\kfwenv" ; `
  "tep.jnlpt"                 = "${CANDLEHOME}\Config\tep.jnlpt" ; `
  "component.jnlpt"           = "${CANDLEHOME}\Config\component.jnlpt" ; `
  "applet.html.updateparams"  = "${CANDLEHOME}\CNB\applet.html.updateparams" ; `
  "kcjparms.txt"              = "${CANDLEHOME}\CNP\kcjparms.txt" ; `
  "java.security"             = "${CANDLEHOME}\CNPSJ\java\jre\lib\security\java.security" ; `
  "trust.p12"                 = "${CANDLEHOME}\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\nodes\ITMNode\trust.p12" ;  `
  "key.p12"                   = "${CANDLEHOME}\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\nodes\ITMNode\key.p12" ; `
  "ssl.client.props"          = "${CANDLEHOME}\CNPSJ\profiles\ITMProfile\properties\ssl.client.props" ;
}
$rc = checkIfFileExists
<#
#>

# Enable ISCLite 
EnableICSLIte "true"

if ( -not $nobackup ) { 
    backupewasAndkeys $BACKUPFOLDER
    $rc = backupfile $HFILES["httpd.conf"]
    $rc = backupfile $HFILES["kfwenv"] 
    $rc = backupfile $HFILES["tep.jnlpt"]
    $rc = backupfile $HFILES["component.jnlpt"]
    $rc = backupfile $HFILES["applet.html.updateparams"] 
    If ( $KCJ -ne 4 ) { 
        $rc = backupfile $HFILES["kcjparms.txt"] 
    }
    $rc = backupfile $HFILES["java.security"] 
    $rc = backupfile $HFILES["trust.p12"]
    $rc = backupfile $HFILES["key.p12"]
    $rc = backupfile $HFILES["ssl.client.props"]

    # create batch to restore from original files in $BACKUPFOLDER (e.g. in case of failure)
    createRestoreScript $RESTORESCRIPT 
} else {
    echo "WARNING - main - !!!! Backup will not be done because option `"-n`" was set !!!!. Press CTRL+C in the next 5 secs if it was a mistake."
    Start-Sleep -seconds 7
}

# Renew the default certificate
$rc = renewCert

# restart TEPS if  default certificate was renewed. otherwise not needed.
If ( $rc -eq 4 ) {
     write-host "INFO - main - No Tivoli Enterpise Portal Server restart required yet."
} else { 
    restartTEPS
    EnableICSLIte "true"
}

# TLS v1.2 only configuration - TEPS/eWAS TEP, IHS, TEPS,  components
# TEPS/eWAS modify Quality of Protection (QoP)
$rc = modQop
$rcs = $rc

# eWAS Set custom property com.ibm.websphere.tls.disabledAlgorithms 
$rc = disableAlgorithms
$rcs = $rcs + $rc

# eWAS sslclientprops modification
$rc = modsslclientprops $HFILES["ssl.client.props"]  
$rcs = $rcs + $rc
# test openssl s_client -connect 172.16.11.4:15206 -tls1_2 doesn't work on windows by default. Needs to be installed first in PS (Install-Module -Name OpenSSL)

# TEPS
# kwfenv add/modify variables
$rc = modkfwenv $HFILES["kfwenv"]
$rcs = $rcs + $rc

# IHS httpd.conf modification
$rc = modhttpconf $HFILES["httpd.conf"]
$rcs = $rcs + $rc

# restart TEPS
If ( $rcs -eq 20 ) {
     write-host "INFO - main - No changes, hence no Tivoli Enterpise Portal Server restart required yet."
} else { 
    restartTEPS
    EnableICSLIte "true"
}

# TEPS JAVA java.security modification
$rc = modjavasecurity $HFILES["java.security"] 

# Browser/WebStart client related
$rc = modtepjnlpt $HFILES["tep.jnlpt"] 
$rcs = $rc 
$rc = modcomponentjnlpt $HFILES["component.jnlpt"] 
$rcs = $rcs + $rc
$rc = modapplethtmlupdateparams $HFILES["applet.html.updateparams"]
$rcs = $rcs + $rc
If ( $rcs -eq 12 ) {
    write-host "INFO - main - No changes hence no need to reconfigure KCB"
} else {
    write-host "INFO - main - Reconfiguring KCB"
    kinconfg -n -rKCB
    if ( -not $? ) {
        write-host "ERROR - main - Executing kinconfg reconfigure of CNP $cmd failed. Powershell script ended!"
        exit 1
    }
    Start-Sleep -seconds 15 
}

# Desktop client related
if ( $KCJ -eq 4  ) {
    write-host "WARNING - main - TEP Desktop client not installed ('kcjparms.txt' not existing)."
} else {
    $rc = modkcjparmstxt $HFILES["kcjparms.txt"]
    if ( $rc -eq 4 ) {
        write-host "INFO - main - No changes hence no need to reconfigure KCJ"
    } else { 
        write-host "INFO - main - Reconfiguring KCJ"
        kinconfg -n -rKCJ
        if ( -not $? ) {
            write-host "ERROR - main - Executing kinconfg reconfigure of CNP $cmd failed. Powershell script ended!"
            exit 1
        }
        Start-Sleep -seconds 10
    }
}

#EnableICSLIte "false"

write-host ""
$elapsedTime = new-timespan $startTime $(get-date) 
$myhost = Invoke-Expression -Command "hostname"
write-host "------------------------------------------------------------------------------------------"
write-host "INFO - main - Procedure successfully finished Elapsedtime:$($elapsedTime.ToString("hh\:mm\:ss")) " -ForegroundColor Green
write-host " - Original files saved in folder $CANDLEHOME\$BACKUPFOLDER "
write-host " - To restore the level before update run '$CANDLEHOME\$BACKUPFOLDER\BATrestoreBAT.bat' "
write-host "----- POST script execution steps ---" -ForegroundColor Yellow
write-host " - Reconfigure TEPS and verify connections for TEP, TEPS, HUB" 
write-host " - To check eWAS settings use: https://${myhost}:15206/ibm/console"
write-host " - To check WenStart Client: https://${myhost}:15201/tep.jnlp"
write-host "------------------------------------------------------------------------------------------"

exit 0
