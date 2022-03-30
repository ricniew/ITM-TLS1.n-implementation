#
# Usage: Copy script to a directory, for examle C:\myfolder and run script in a Powershell window: 
#   PS C:\myfolder> .\activate_teps-tlsv1.2.ps1 [ -h ITMHOME ]
#
# 16.03.2022: Initial version  by R. Niewolik EMEA AVP Team
# 29.03.2022: Version 1.3      by R. Niewolik EMEA AVP Team
#
param($h)

$startTime = $(get-date)

function getCandleHome ($candlehome) {
  if  ( $candlehome ) {
      $parcandlehome=$args[0]
      write-host "INFO - getCandleHome - CANDLE_HOME set by option is:  $candlehome"
      if (Test-Path -Path $candlehome) {
          write-host "INFO - getCandleHome - Path $candlehome exists. OK"
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
          if (Test-Path -Path $candlehome) {
              write-host "INFO - getCandleHome - Path $candlehome exists. OK"
          } else {
              write-host "ERROR - getCandleHome - Path $candlehome doesn't exist. Please execute script including ITMHOME: scriptname.ps1 C:\IBM\ITM"
              exit 1
          }
      }
  }
  return $candlehome
}


function backupfile ($file) {
  #write-host "DEBUG - backupfile- $file"
  if ( test-path $file ) {
      write-host "INFO - backupfile - Saving $file in $BACKUPFOLDER "
      Copy-Item -Path "$file" -Destination $BACKUPFOLDER
      if ( -not $? ) {
          write-host "ERROR - backupfile - Could not copy $file could not be saved to $BACKUPFOLDER !! Check permissions and available space."
          exit 1
      } else { return 0 }
  } else {
      if ( $file -like '*kcjparms*') {
          write-host "WARNING - backupfile - File $file does NOT exists and could not be saved (possibly TEP Destop Client not installed) "
          return 4
      } else {
          write-host "ERROR - backupfile - Could not backup $file to $BACKUPFOLDER !! Check for existance, permissions and available space."
      } 
  }
}

function backupewasAndkeys ($backupfolder) {
  write-host "INFO - backupewasAndkeys - Directory $CANDLEHOME\CNPSJ saving in $BACKUPFOLDER. This can take a while..."
  Copy-Item -Path "$CANDLEHOME\CNPSJ" -Destination $BACKUPFOLDER -Recurse -erroraction stop
  if ( -not $? ) {
      write-host "ERROR - backupewasAndkeys - Could not copy $CANDLEHOME/CNPSJ folder to $BACKUPFOLDER !! Check permissions and available space."
      exit 1
  }
  write-host "INFO - backupewasAndkeys - Directory $CANDLEHOME\keyfiles saving in $BACKUPFOLDER"
  Copy-Item -Path "$CANDLEHOME\keyfiles" -Destination $BACKUPFOLDER -Recurse -erroraction stop
  write-host "INFO - backupewasAndkeys - Files successfully saved in folder $BACKUPFOLDER."
  if ( -not $? ) {
      write-host "ERROR - backupewasAndkeys - Could not copy $CANDLEHOME/keyfiles folder to $BACKUPFOLDER !! Check permissions and available space."
      exit 1
  }
}

function createRestoreScript ($restorebat) {
  $restorebatfull = "$BACKUPFOLDER\$restorebat"
  if ( test-path $restorebatfull ) { 
       write-host "WARNING - createRestoreScript - Script $restorebatfull exists already and will be deleted"
       remove-item $restorebatfull
  }

  New-Item -Path $BACKUPFOLDER -Name $restorebat -ItemType "file"
  Add-Content $restorebatfull "cd $BACKUPFOLDER"
  Add-Content $restorebatfull "xcopy /y/s CNPSJ $CANDLEHOME"
  Add-Content $restorebatfull "xcopy /y/s keyfiles $CANDLEHOME"
  Add-Content $restorebatfull " "

  foreach ( $h in $HFILES.Keys ) {
      $string="copy $h  $($HFILES.$h)"
      if ( ( $file -like '*kcjparms*')  -and ( $KCJ = 4 ) ) {
          write-host "WARNING - createRestoreScript - TEP Desktop Client apparently not installed. File 'kcjparms.txt' not added to restore script"
          continue 
      } 
      Add-Content $restorebatfull $string
      Add-Content $restorebatfull "del $($HFILES.$h).beforetls12"
      Add-Content $restorebatfull "del $($HFILES.$h).tls12"
      Add-Content $restorebatfull " "
  }
  Add-Content $restorebatfull " "
  Add-Content $restorebatfull "kinconfg -n -rKCB"
  Add-Content $restorebatfull "kinconfg -n -rKCJ"
  Add-Content $restorebatfull "cd .."

  write-host "INFO - createRestoreScript - Restore bat file created $restorebatfull"
  Start-Sleep -seconds 4
}


function saveorgcreatenew ($orgfile) {
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
      $null = New-Item -path $dir -name $file -ItemType "file"
  }

  #write-host "DEBUG - saveorgcreatenew - new= $neworgfile save= $saveorgfile org= $orgfile"
  $return.new = "$neworgfile"
  $return.save =  "$saveorgfile"
  return $return
}


function modhttpconf ($httpdfile) {
  write-host "INFO - modhttpconf - Start $httpdfile creation "
  $rc = saveorgcreatenew $httpdfile
  if ( $rc.rc -eq 1 ) {
       write-host "WARNING - modhttpconf - IHS component apparently not installed. File $httpdfile not modified !"
       return $rc.rc 
  }
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
          Add-Content $newhttpdfile "${line}"
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

}


function modkfwenv ($kfwenv) {
  write-host "INFO - modkfwenv - Start $kfwenv creation "
  $rc = saveorgcreatenew $kfwenv
  if ( $rc.rc -eq 1 ) {
       write-host "WARNING - modkfwenv - TEPS component apparently not installed. File $kfwenv not modified !"
       return $rc.rc 
  }
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
}


function modtepjnlpt ($tepjnlpt) {
  write-host "INFO - modtepjnlpt - Start $tepjnlpt creation "
  $rc = saveorgcreatenew $tepjnlpt
  if ( $rc.rc -eq 1 ) {
       write-host "WARNING - modtepjnlpt - CNB component apparently not installed. File $tepjnlpt not modified !"
       return $rc.rc 
  }
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
}


function modcomponentjnlpt ($componentjnlpt) {
  write-host "INFO - modcomponentjnlpt - Start $componentjnlpt creation "
  $rc = saveorgcreatenew $componentjnlpt
  if ( $rc.rc -eq 1 ) {
       write-host "WARNING - modcomponentjnlpt - CNB component apparently not installed. File $componentjnlpt not modified !"
       return $rc.rc 
  }
  $newcomponentjnlpt = $rc.new
  $savecomponentjnlpt = $rc.save
  foreach( $line in Get-Content $savecomponentjnlpt ) {
      if ( "$line" -match 'codebase="http://\$HOST\$:(.*)/' ) {
          Add-Content $newcomponentjnlpt '  codebase="https://$HOST$:15201/" '
      } else { Add-Content $newcomponentjnlpt "${line}" }
  }
  copy-item -Path "$newcomponentjnlpt" -Destination "$componentjnlpt"
  write-host "INFO - modcomponentjnlpt - $newcomponentjnlpt created and copied on $componentjnlpt"
}

function modapplethtmlupdateparams ($applethtmlupdateparams) {
  write-host "INFO - modapplethtmlupdateparams - Start $applethtmlupdateparams creation "
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

}

function modkcjparmstxt ($kcjparmstxt) {
  write-host "INFO - modkcjparmstxt - Start $kcjparmstxt creation "
  $rc = saveorgcreatenew $kcjparmstxt
  if ( $rc.rc -eq 1 ) {
       write-host "WARNING - modkcjparmstxt - CNP component apparently not installed. File $kcjparmstxt not modified !"
       return $rc.rc 
  }
   
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
}

function modjavasecurity ($javasecurity) {
  write-host "INFO - modjavasecurity - Start $javasecurity creation "
  $rc = saveorgcreatenew $javasecurity
  if ( $rc.rc -eq 1 ) {
       write-host "WARNING - modjavasecurity - ITHOME/CNPSJ/JAVA component apparently not installed. File $javasecurity not modified !"
       return $rc.rc 
  }
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
}


function modsslclientprops ($sslclientprops) {
  write-host "INFO - modsslclientprops - Start $sslclientprops modification "
  $rc = saveorgcreatenew $sslclientprops
  if ( $rc.rc -eq 1 ) {
       write-host "WARNING - modsslclientprops - $sslclientprops not installed. File $sslclientprops not modified !"
       return $rc.rc 
  }
  $newsslclientprops = $rc.new
  $savesslclientprops = $rc.save
  $foundproto = 1
  foreach ( $line in Get-Content $savesslclientprops ) {
      if ( ("$line" -match 'com.ibm.ssl.protocol') -and ( -not $line.StartsWith("#")) ) {
          if ( "$line" -match 'com.ibm.ssl.protocol=TLSv1.2' ) {
              write-host "INFO - modsslclientprops - $sslclientprops contains already 'com.ibm.ssl.protocol=TLSv1.2'"
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
}


function restartTEPS () {
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
              Write-Host ""
              Write-Host 'INFO - restartTEPS - TEPS started successfully' -ForegroundColor Green
              $wait = 0 
          } Else {
              Write-Host -NoNewline ".."
              $c = $c + 3
              Start-Sleep -seconds 3  
          }
          #if ( $c -gt 150 ) {
          #    write-host "ERROR - restartTEPS - TEPS restart takes too long (over 2,5) min. Something went wrong. Powershell script ended!"
          #    exit 1
          #}
              
      }
      Start-Sleep -seconds 5
  }
}

function EnableICSLIte ($action) {
  write-host "INFO - EnableICSLIte - Enable ISCLite."
  $cmd="$CANDLEHOME\CNPSJ\bin\wsadmin -conntype SOAP -lang jacl -f $CANDLEHOME\CNPSJ\scripts\enableISCLite.jacl $action"
  $cmd += '; $Success=$?'
  write-host "$cmd"
  Invoke-Expression $cmd
  if ( $Success ) { write-host "INFO - EnableICSLIte - Successfully enabled ISCLite." }
  else {
      write-host "$success"
      write-host "ERROR - EnableICSLIte - Enable ISCLite command $cmd failed. Possibly you did not set a eWAS user password. "
      Write-Host " Try to set a password as descirbed here https://www.ibm.com/docs/en/tivoli-monitoring/6.3.0?topic=administration-define-wasadmin-password" 
      write-host " Powershell script ended!"
      exit 1
  }
}
# --------------------------------------------------------------
# MAIN ---------------------------------------------------------
# --------------------------------------------------------------
if ( $h )  { $tmphome = $h }
else { $tmphome = "" } 

$CANDLEHOME = getCandleHome $tmphome
$BACKUPFOLDER = "$CANDLEHOME\backup_before_TLS1.2" # will be create in candlehome
$RESTORESCRIPT = "BATrestore.bat"

$tepsstatus = Get-Service -Name KFWSRV
if ( $tepsstatus.Status -ne "Running" ) {
    write-host "ERROR - main - TEPS not running. Please start it and restart the procedure"
    exit 1
} elseif ( -not ( Select-String -Path "$CANDLEHOME\logs\kfwservices.msg" -Pattern 'Waiting for requests. Startup complete' -SimpleMatch) ) {
        Write-Host "ERROR - main - TEPS started but not connected to TEMS"
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

<# #>

if ( -not (test-path $CANDLEHOME) ) { 
    write-host "ERROR - main - Folder $CANDLEHOME does not exists. Please check and restart"
    exit 1
}
if ( test-path $BACKUPFOLDER ) { 
    write-host "ERROR - main - This script was started already and the folder $BACKUPFOLDER exists already! To avoid data loss, "
    write-host "before executing this script again, you must restore the original content by using the '$RESTORESCRIPT' script and delete/rename the backup folder."
    exit 1 
} else {
    $null = New-Item -Path $CANDLEHOME  -Name (Split-Path -Leaf $BACKUPFOLDER) -ItemType "directory"
    write-host "INFO - main - Folder $BACKUPFOLDER created."
}
if ( test-path $CANDLEHOME\CNPSJ ) { 
    write-host "INFO - main - Tivoli Enterpise Portal Server is installed."
} else {
    write-host "ERROR - main - Tivoli Enterpise Portal Server not installed. Directory '$CANDLEHOME\CNPSJ' does not exists!"
    exit 1
} 

# Enable ISCLite 
EnableICSLIte "true"

backupewasAndkeys $BACKUPFOLDER
$HTTPD = backupfile $HFILES["httpd.conf"]
$KFW = backupfile $HFILES["kfwenv"] 
$TEPT = backupfile $HFILES["tep.jnlpt"]
$COMPONENTT = backupfile $HFILES["component.jnlpt"]
$APPLET = backupfile $HFILES["applet.html.updateparams"] 
$KCJ = backupfile $HFILES["kcjparms.txt"] 
$JAVASEC = backupfile $HFILES["java.security"] 
$TRUST = backupfile $HFILES["trust.p12"]
$JEYP = backupfile $HFILES["key.p12"]
$SSLPROPS = backupfile $HFILES["ssl.client.props"]

createRestoreScript $RESTORESCRIPT # create batch to restore original files in $BACKUPFOLDER (in case of failure)

# Renew the default certificate
$cmd ="$CANDLEHOME\CNPSJ\bin\wsadmin -lang jython -c `"AdminTask.renewCertificate('-keyStoreName NodeDefaultKeyStore -certificateAlias  default')`" -c 'AdminConfig.save()'"
$cmd += '; $Success=$?'
write-host $cmd
Invoke-Expression $cmd
if ( $Success ) {
    $cmd ="$CANDLEHOME\CNPSJ\bin\wsadmin -lang jython -c `"AdminTask.getCertificateChain('[-certificateAlias default -keyStoreName NodeDefaultKeyStore -keyStoreScope (cell):ITMCell:(node):ITMNode ]')`" "
    Invoke-Expression $cmd 
    write-host "INFO - main - Successfully renewed Certificate in eWAS"
   
} else {
    write-host "$success"
    write-host "ERROR - maim - Error during renewing Certificate in eWAS. Powershell script ended!"
    exit 1
}

$KEYKDB="$CANDLEHOME\\keyfiles\\keyfile.kdb"
$KEYP12="$CANDLEHOME\\CNPSJ\\profiles\\ITMProfile\\config\\cells\\ITMCell\\nodes\\ITMNode\\key.p12"
$TRUSTP12="$CANDLEHOME\\CNPSJ\\profiles\\ITMProfile\\config\\cells\\ITMCell\\nodes\\ITMNode\\trust.p12"
GSKitcmd gsk8capicmd -cert -delete -db $KEYKDB -stashed -label default
GSKitcmd gsk8capicmd -cert -delete -db $KEYKDB -stashed -label root
GSKitcmd gsk8capicmd -cert -import -db $KEYP12 -pw WebAS -target $KEYKDB -target_stashed -label default -new_label default
GSKitcmd gsk8capicmd -cert -import -db $TRUSTP12 -pw WebAS -target $KEYKDB -target_stashed -label root -new_label root
if ( -not $? ) {
    write-host "ERROR - maim - Error during gsk8capicmd  commands. Powershell script ended!"
} else {
    write-host ""
    write-host "INFO - main - Successfully executed gsk8capicmd  commands to copy renewed certificates to $KEYKDB. See label and issuer info below..." 
    write-host ""
    GSKitcmd gsk8capicmd -cert -list -db $KEYKDB -stashed -label default
    write-host ""
    GSKitcmd gsk8capicmd -cert -details -db $KEYKDB -stashed -label default | findstr "Serial Issuer Subject Not\ Before Not\ After"
    write-host ""
    GSKitcmd gsk8capicmd -cert -details -type p12 -db $KEYP12 -pw WebAS -label default | findstr "Serial Issuer Subject Not\ Before Not\ After"
    write-host ""
    GSKitcmd gsk8capicmd -cert -details -db $KEYKDB -stashed -label root | findstr "Serial Issuer Subject Not\ Before Not\ After"
    write-host ""
    GSKitcmd gsk8capicmd -cert -details -type p12 -db $TRUSTP12 -pw WebAS -label root | findstr "Serial Issuer Subject Not\ Before Not\ After"
}

# restart TEPS
restartTEPS
EnableICSLIte "true"

# TLS v1.2 only configuration - TEPS/eWAS TEP, IHS, TEPS,  components
# TEPS/eWAS modify Quality of Protection (QoP)

$cmd = "$CANDLEHOME\CNPSJ\bin\wsadmin -lang jython -c `"AdminTask.modifySSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode -keyStoreName NodeDefaultKeyStore -keyStoreScopeName (cell):ITMCell:(node):ITMNode -trustStoreName NodeDefaultTrustStore -trustStoreScopeName (cell):ITMCell:(node):ITMNode -jsseProvider IBMJSSE2 -sslProtocol TLSv1.2 -clientAuthentication false -clientAuthenticationSupported false -securityLevel HIGH -enabledCiphers ]') `" -c 'AdminConfig.save()'"
$cmd += '; $Success=$?'
write-host $cmd
Invoke-Expression $cmd
if ( $Success ) {
    write-host "INFO - main - Successfully set TLSv1.2 for Quality of Protection (QoP)"
} else {
    write-host "ERROR - main - Error setting TLSv1.2 for Quality of Protection (QoP). Powershell script ended!"
    exit 1
}

# eWAS Set custom property com.ibm.websphere.tls.disabledAlgorithms 
$jython = "$CANDLEHOME\tmp\org.jy"
$null = New-Item  -path "$CANDLEHOME\tmp" -name "org.jy"  -ItemType "file"
Add-Content $jython "sec = AdminConfig.getid('/Security:/')"
Add-Content $jython "prop = AdminConfig.getid('/Security:/Property:com.ibm.websphere.tls.disabledAlgorithms/' )"
Add-Content $jython "if prop:" 
Add-Content $jython "  AdminConfig.modify(prop, [['value', 'none'],['required', `"false`"]])"
Add-Content $jython "else: "
Add-Content $jython " AdminConfig.create('Property',sec,'[[name `"com.ibm.websphere.tls.disabledAlgorithms`"] [description `"Added due ITM TSLv1.2 usage`"] [value `"none`"][required `"false`"]]') "
Add-Content $jython "AdminConfig.save()"
$cmd = "$CANDLEHOME\CNPSJ\bin\wsadmin -lang jython -f $jython"
$cmd += '; $Success=$?'
write-host $cmd 
Invoke-Expression $cmd
if ( $Success ) {
    Remove-Item $jython
    write-host "INFO - main - Successfully set com.ibm.websphere.tls.disabledAlgorithms to none" 
} else {
    write-host "ERROR - main - Error setting Custom Property ( com.ibm.websphere.tls.disabledAlgorithms ). Powershell script ended!"
    exit 1
}

# eWAS sslclientprops modification
modsslclientprops $HFILES["ssl.client.props"]  
# test openssl s_client -connect 172.16.11.4:15206 -tls1_2 doesn't work on windows by default. Needs to be installed first in PS (Install-Module -Name OpenSSL)

# TEPS
# kwfenv add/modify variables
modkfwenv $HFILES["kfwenv"]

# IHS httpd.conf modification
modhttpconf $HFILES["httpd.conf"]

# restart TEPS
restartTEPS

# TEPS JAVA java.security modification
modjavasecurity $HFILES["java.security"] 

# Browser/WebStart client related
modtepjnlpt $HFILES["tep.jnlpt"]  
modcomponentjnlpt $HFILES["component.jnlpt"] 
modapplethtmlupdateparams $HFILES["applet.html.updateparams"]

write-host "INFO - main - Reconfiguring KCB"
kinconfg -n -rKCB
if ( -not $? ) {
    write-host "ERROR - main - Executing kinconfg reconfigure of CNP $cmd failed. Powershell script ended!"
    exit 1
}
Start-Sleep -seconds 15 

# Desktop client related
if ( $KCJ -eq 0  ) {
    modkcjparmstxt $HFILES["kcjparms.txt"]
    write-host "INFO - main - Reconfiguring KCJ"
    kinconfg -n -rKCJ
    if ( -not $? ) {
        write-host "ERROR - main - Executing kinconfg reconfigure of CNP $cmd failed. Powershell script ended!"
        exit 1
    }
    Start-Sleep -seconds 10
} else {
    write-host "WARNING - main - TEP Desktop client not installed ('kcjparms.txt' not existing). Continue.. "
}

EnableICSLIte "false"

write-host ""
$elapsedTime = new-timespan $startTime $(get-date) 
$myhost = Invoke-Expression -Command "hostname"
write-host "------------------------------------------------------------------------------------------"
write-host "INFO - main - Procedure successfully finished Elapsedtime:$($elapsedTime.ToString("hh\:mm\:ss")) " -ForegroundColor Green
write-host " - Original files saved in folder $CANDLEHOME\$BACKUPFOLDER "
write-host " - To restore the level before update run '$CANDLEHOME\$BACKUPFOLDER\BATrestoreBAT.bat' "
write-host "----- POST script execution steps ---" -ForegroundColor Yellow
write-host " - Reconfigure TEPS and verify connections for TEP, TEPS, HUB" 
write-host " - To check eWAS settings use: https://$myhost:15206/ibm/console/login"
write-host " - To check WenStart Client: https://$myhost:15201/tep.jnlp"
write-host "------------------------------------------------------------------------------------------"

exit
