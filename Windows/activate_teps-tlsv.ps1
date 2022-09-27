#
# Usage: 
#   PS C:\myfolder> .\activate_teps-tlsv.ps1 [ -h ITMHOME } [ -b [no,yes] ] { -r [no,yes] }
#
# Before execution the file ". .\init_tlsv1.2.ps1" must be sourced first
#
# 20.07.2022: Version 2.0      R. Niewolik EMEA AVP Team 
#             - Complete redesign of the script released on 20.04.2022.
#               Splitted inital script into a new script, function file and files to set
#               the required variables
# 28.07.2022: Version 2.2      R. Niewolik EMEA AVP Team
#             - Minor display changes, changed variable KCJ handling
# 23.09.2022: Version 2.3      R. Niewolik EMEA AVP Team
#             - added new parameter "-d" to allow to decide if TEPS login port 15200 should be externally disabled
##

param (
    [Parameter(HelpMessage="ITM home folder")]
    [AllowEmptyString()]
    [string]$h = "",

    [Parameter(HelpMessage="Perform backup or not")]
    [string]$b= 'yes',

    [Parameter(HelpMessage="Certificate renew or not")]
    [string]$r = '',
    
    [Parameter(HelpMessage="Disable TEPS Port 15200 for external access or not")]
    [string]$d = '',

    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    $UndefinedArgs
)

write-host "INFO - Script Version 2.3"
$startTime = $(get-date)
$SCRIPTNAME = $MyInvocation.MyCommand.Name

function usage () 
{
    write-host "----"
    write-host " Usage:"
    write-host "  $SCRIPTNAME { -h ITM home } [-b [no, yes] ] {-r {no, yes} } {-d {no, yes} }"
    write-host "    -h = MANDATORY. ITM home folder"
    write-host "    -b = If backup should be performed or not, default is 'yes'. Please use that parameter carefully!!!!!!"
    write-host "    -r = MANDATORY. If default cert should be renewed"
    write-host "    -d = MANDATORY. If set to 'no' then TEPS port 15200 is not disabled for external access"
    write-host ""
    write-host " Sample executions:"
    write-host "    $SCRIPTNAME -h /opt/IBM/ITM -r yes -d no        # Backup is performed. Default keystore is renewed and TEPS port 15200 is not disabled for external access"
    write-host "    $SCRIPTNAME -h /opt/IBM/ITM -b yes -r no -d yes # Backup is performed, default keystore is not renewed and TEPS port 15200 is disabled for external access"
    write-host "    $SCRIPTNAME -h /opt/IBM/ITM -b no -r no -d no   # NO backup is performed, default keystore is not renewed and TEPS port 15200 is not disabled for external access"
    write-host "----"
    exit 1 

}


function check_param ()
{
  if ( $UndefinedArgs ) { 
    usage
  }
  if ( $d ) {  
      if ( $d -ne 'no' -and $d -ne 'yes'  ) { 
          write-host "ERROR - check_param - Bad execution syntax. Option '-d' value not correct (yes/no)"
          usage
      } else {
          write-host "INFO - check_param - Option '-d' = '$d'"
      }
  } else {
      write-host "ERROR - check_param - Option '-d' is required (yes/no)"
      usage
  }
   
  if ( $r ) {  
      if ( $r -ne 'no' -And $r -ne 'yes'  ) { 
          write-host "ERROR - check_param - Bad execution syntax. Option '-r' value not correct (yes/no)"
          usage
      } else {
          write-host "INFO - check_param - Option '-r' = '$r'"
      }
  } else {
      write-host "ERROR - check_param - Option '-r' is required (yes/no)"
      usage
  }
  if ( $b ) { 
      if ( $b -ne 'no' -And $b -ne 'yes'  ) {
          write-host "ERROR - check_param - Bad execution syntax. Option '-b' value not correct (yes/no)"
          usage
       } else {
          if ( $b -eq 'yes' ) {
              write-host "INFO - check_param - Option '-b' = '$b' (default)"
          } else {  
              write-host "INFO - check_param - Option '-b' = '$b'."
          }
      }
  }

  if ( $h ) { 
      if ( $h -ne ''  ) {
          if (Test-Path -Path "$h") { 
              write-host "INFO - check_param - Option '-h' = '$h'"
          } else {
              write-host "ERROR - check_param - Folder $h doesn't exist. Check -h option"
              usage
          }
      }
  } else { 
      write-host "ERROR - check_param - Option '-h' is required"
      usage  
  }
}


# --------------------------------------------------------------
# MAIN ---------------------------------------------------------
# --------------------------------------------------------------

# check parameter
check_param

$backup = $b # getting value (no/yes). Provided by param  "[string]$b", see at the top of this script 
$homeitm = $h # getting value provided by param "[string]$h"
$certrenew = $r # if cert needs to be renewed (no/yes). Provided by param  "[string]$r"
$httpd_disable_15200 = $d

# initialize functions and global variables
if ( test-path functions_sources.ps1 ) {
    $rc= . .\functions_sources.ps1 $homeitm
    if ( $rc -eq 1 ) { return 1 }
} else { 
    write-host "ERROR - functions_sources - File functions_sources.ps1 doesn't exists in the current directory"
    return 1
}

write-host "INFO -------------------------------------------"
write-host "INFO - main - Modifications for TLSVER=$TLSVER -"
#$ver=$TLSVER.ToLower()
#foreach ($u in Select-String -path ".\init_${ver}.ps1" -Pattern "write" | Foreach {$_.Line}) { invoke-expression $u }
write-host "INFO -------------------------------------------"

# check if TEPS installed
if ( test-path "$ITMHOME\CNPSJ" ) { 
    write-host "INFO - main - Tivoli Enterpise Portal Server is installed."
} else {
    write-host "ERROR - main - Tivoli Enterpise Portal Server not installed. Directory '$ITMHOME\CNPSJ' does not exists!"
    exit 1
}

# check if TEPS at the required version
$cmd = 'kincinfo -t cq|find "CQ  TEPS"'
$tmp = Invoke-Expression $cmd
$tmparray = $($tmp -replace '\s+',' ').Split(" ")
$tepsver = [int]$($tmparray[8] -replace '\.', '')
if ( $tepsver -lt 06300700  ) {
    write-host "ERROR - main - TEPS server must be at least at version 06.30.07.00 (is $tepsver)." 
    exit 1
} else { 
    write-host "INFO - main - TEPS version = $tepsver" 
}

# check if eWAS at the required version
$cmd = 'kincinfo -t iw|find "IW  TEPS"'
$tmp = Invoke-Expression $cmd
$tmparray = $($tmp -replace '\s+',' ').Split(" ")
$ewasver = [int]$($tmparray[9] -replace '\.', '')
if ( $ewasver -lt 08551600 ) {
    write-host "ERROR - main - eWAS server must be at least at version 08.55.16.00 (is $ewasver). Please perform an eWAS and IHS uplift as described in the udpate readme files" 
    exit 1
} else { 
    write-host "INFO - main - eWAS version = $ewasver" 
}
 
# check if TEPS running and initialized
$tepsstatus = Get-Service -Name KFWSRV
if ( $tepsstatus.Status -ne "Running" ) {
    write-host "ERROR - main - TEPS not running. Please start it and restart the procedure"
    exit 1
} elseif ( -not ( Select-String -Path "$ITMHOME\logs\kfwservices.msg" -Pattern 'Waiting for requests. Startup complete' -SimpleMatch) ) {
    write-host "ERROR - main - TEPS started but not initialized yet"
    exit 1
}

if ( $backup -eq 'yes' ) { 
    if ( test-path "$BACKUPFOLDER" ) { 
        write-host "ERROR - main - This script was started already and the folder $BACKUPFOLDER is existing! To avoid data loss, "
        write-host "before executing this script again, you must restore the original content by using the '$RESTORESCRIPT' script or delete/rename the backup folder."
        exit 1 
    } else {
        $null = New-Item -Path "$ITMHOME\Backup"  -Name (Split-Path -Leaf "$BACKUPFOLDER") -ItemType "directory"
        write-host "INFO - main - Folder $BACKUPFOLDER created."
    }
} else {
    write-host "WARNING - main - !!!! Backup will not be done because option `"-b no`" was set !!!!. Press CTRL+C in the next 7 secs if it was a mistake."
    Start-Sleep -seconds 7 
}

$global:KCJ=0 # set by special handling for TEPD in checkIfFileExists
$rc = checkIfFileExists
if ( $rc -eq 1 ) { exit 1 }

# Enable ISCLite 
$rc = EnableICSLIte "true"
if ( $rc -eq 1 ) { exit 1 }

# Backup files and folders
if ( $backup -eq 'yes' ) { 
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
    $rc = backupfile $HFILES["cacerts"]

    # create batch to restore from original files in $BACKUPFOLDER (e.g. in case of failure)
    createRestoreScript $RESTORESCRIPT 
} else {
    write-host "WARNING - main - !!!! Backup will not be done because option `"-b no`" was set !!!!. Press CTRL+C in the next 5 secs if it was a mistake."
    Start-Sleep -seconds 5
}

if ( $certrenew -eq 'yes' ) {
# Renew the default certificate
    $rc = renewCert
    if ( $rc -eq 1 ) { exit 1 }
    # restart TEPS if default certificate was renewed. Otherwise not needed.
    If ( $rc -eq 4 ) {
        write-host "INFO - main - No changes. Tivoli Enterpise Portal Server restart not required yet."
    } else { 
        restartTEPS
        EnableICSLIte "true"
    }
} else {
    write-host "WARNING - main - Certificate will NOT be renewed because option `"-r no`" was set."
}


# TLS v1.2 only configuration - TEPS/eWAS TEP, IHS, TEPS,  components
# TEPS/eWAS modify Quality of Protection (QoP)
$rc = modQop
if ( $rc -eq 1 ) { exit 1 }
$rcs = $rc

# eWAS Set custom property com.ibm.websphere.tls.disabledAlgorithms 
$rc = disableAlgorithms
if ( $rc -eq 1 ) { exit 1 }
$rcs = $rcs + $rc

# eWAS sslclientprops modification
$rc = modsslclientprops $HFILES["ssl.client.props"] 
if ( $rc -eq 1 ) { exit 1 } 
$rcs = $rcs + $rc
# test openssl s_client -connect 172.16.11.4:15206 -tls1_2 doesn't work on windows by default. Needs to be installed first in PS (Install-Module -Name OpenSSL)

# TEPS
# kwfenv add/modify variables
$rc = modkfwenv $HFILES["kfwenv"]
if ( $rc -eq 1 ) { exit 1 }
$rcs = $rcs + $rc

# IHS httpd.conf modification
$rc = modhttpconf $HFILES["httpd.conf"] $httpd_disable_15200
if ( $rc -eq 1 ) { exit 1 }
$rcs = $rcs + $rc

# restart TEPS
If ( $rcs -eq 20 ) {
     write-host "INFO - main - No changes. Tivoli Enterpise Portal Server restart not required yet."
} else { 
    $rc = restartTEPS
    if ( $rc -eq 1 ) { exit 1 }
    EnableICSLIte "true"
}

# TEPS JAVA java.security modification
$rc = modjavasecurity $HFILES["java.security"] 
if ( $rc -eq 1 ) { exit 1 }

# JAVAHOME cacerts file modification
$rc = importSelfSignedToJREcacerts $HFILES["cacerts"]
if ( $rc -eq 1 ) { exit 1 }

# Browser/WebStart client related
$rc = modtepjnlpt $HFILES["tep.jnlpt"]
if ( $rc -eq 1 ) { exit 1 }
$rcs = $rc 
$rc = modcomponentjnlpt $HFILES["component.jnlpt"] 
if ( $rc -eq 1 ) { exit 1 }
$rcs = $rcs + $rc
$rc = modapplethtmlupdateparams $HFILES["applet.html.updateparams"]
if ( $rc -eq 1 ) { exit 1 }
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
    if ( $rc -eq 1 ) { exit 1 }
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
if ( $backup -ne 'no' ) { 
    write-host " - Original files saved in folder $ITMHOME\$BACKUPFOLDER "
    write-host " - To restore the level before update run '$ITMHOME\$BACKUPFOLDER\$RESTORESCRIPT' "
} else {
    write-host "WARNING - main - Backup was NOT done because option `"-b no`" was set"
}
write-host "----- POST script execution steps ---" -ForegroundColor Yellow
#write-host " - Reconfigure TEPS and verify connections for TEP, TEPS, HUB" 
write-host " - To check eWAS settings use: https://${myhost}:15206/ibm/console"
write-host " - To check WenStart Client: https://${myhost}:${TEPSHTTPSPORT}/tep.jnlp"
write-host "------------------------------------------------------------------------------------------"

exit 0