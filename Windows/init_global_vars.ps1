# This file is sourced (". .\init_global_vars.ps1") and used by the functions_sources.ps1 procedure.
# !!!! Do NOT modify it !!!!
#
# 20.07.2022: Version 2.0      R. Niewolik EMEA AVP Team 
#             - Complete redesign of the script released on 20.04.2022. 
#               Splitted main script into this variables file and "init_gloabl_vars" file              
# 28.07.2022: Version 2.2      R. Niewolik EMEA AVP Team
#             - Minor display changes, removed variable KCJ 
##

if (  $Args ) {
    if ( Test-Path -Path "$Args\logs" ) {
        $global:ITMHOME="$Args"
    } else { 
        write-host "ERROR - init_global_vars.ps1 - ITMHOME='$Args' set by argument is not an ITMHOME folder or does not exists."
        return 1  
    }
} else {
    $cdh = Get-WmiObject -query "select * from Win32_environment where username='<system>' and name='CANDLE_HOME'" | ft -hide | out-string;
    if ( !$cdh  ) {
        write-host "ERROR - init_global_vars.ps1 - Variable %CANDLE_HOME% doesn't exists. ITMHOME cannot be evaluated"
        $sourcefilename= $MyInvocation.MyCommand.Name
        write-host "Please use '. .\$sourcefilename [path to ITMHOME]' (e.g. c:\ibm\itm) to set the correct path"
        return 1
    } else {
        $candlehome = $cdh.Split(" ")[0].trim()
        #write-host "INFO - init_global_vars.ps1 - ITM home directory by %CANDLE_HOME% is: $candlehome"
        if (Test-Path -Path "$candlehome" ) {
            $global:ITMHOME = $candlehome
        } else {
            write-host "ERROR - init_global.vars.ps1 - ITM home folder cannot be evaluated, CANDLE_HOME=$candlehome doesn't exists"
            write-host "INFO - Please set the correct path '. .\$sourcefilename [path to ITMHOME]' (e.g. c:\ibm\itm)"
            return 1
        }
    }
}

if ( ! $TLSVER ) { 
    write-host "ERROR - init_global_vars.ps1 -  Global variable TLSVER doesn't exists. Please initialize by using '. .\init_tlsv[n.n.ps1'" 
    return 1 
}

$global:TEPSHTTPSPORT="15201"
$global:BACKUPFOLDER = "$ITMHOME\Backup\backup_before_$TLSVER" 
$global:RESTORESCRIPT = "SCRIPTrestore.bat"
$global:WSADMIN = "$ITMHOME\CNPSJ\bin\wsadmin"
#$global:JAVA_HOME = ((Get-Content -path $ITMHOME\CNPS\kfwenv) | Select-String -pattern "^JAVA_HOME=(.*)").matches.groups[1].value
$global:JAVA_HOME = & $ITMHOME\InstallITM\GetJavaHome.bat
$global:KEYTOOL= "$JAVA_HOME\bin\keytool.exe"
$global:KEYKDB = "$ITMHOME\keyfiles\keyfile.kdb"
$global:KEYP12 = "$ITMHOME\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\nodes\ITMNode\key.p12"
$global:TRUSTP12 = "$ITMHOME\\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\\nodes\ITMNode\trust.p12"
$global:SIGNERSP12 = "$ITMHOME\keyfiles\signers.p12" 
$global:HFILES = @{ `
  "httpd.conf"                = "${ITMHOME}\IHS\conf\httpd.conf" ; `
  "kfwenv"                    = "${ITMHOME}\CNPS\kfwenv" ; `
  "tep.jnlpt"                 = "${ITMHOME}\Config\tep.jnlpt" ; `
  "component.jnlpt"           = "${ITMHOME}\Config\component.jnlpt" ; `
  "applet.html.updateparams"  = "${ITMHOME}\CNB\applet.html.updateparams" ; `
  "kcjparms.txt"              = "${ITMHOME}\CNP\kcjparms.txt" ; `
  "java.security"             = "${ITMHOME}\CNPSJ\java\jre\lib\security\java.security" ; `
  "trust.p12"                 = "${ITMHOME}\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\nodes\ITMNode\trust.p12" ;  `
  "key.p12"                   = "${ITMHOME}\CNPSJ\profiles\ITMProfile\config\cells\ITMCell\nodes\ITMNode\key.p12" ; `
  "ssl.client.props"          = "${ITMHOME}\CNPSJ\profiles\ITMProfile\properties\ssl.client.props" ;
  "cacerts"                   = "${JAVA_HOME}\lib\security\cacerts" ;
}
# global variable. Set to 4 in checkIfFileExists. Then TEP Desktop Client most likely not installed
write-host "INFO -------------------------------- Global variables: -------------------------------------"
Write-host "INFO - ITMHOME=$ITMHOME"
Write-host "INFO - TEPSHTTPSPORT=$TEPSHTTPSPORT"
Write-host "INFO - BACKUPFOLDER=$BACKUPFOLDER" 
Write-host "INFO - RESTORESCRIPT=$RESTORESCRIPT" 
Write-host "INFO - WSADMIN=$WSADMIN" 
Write-host "INFO - JAVA_HOME=$JAVA_HOME" 
Write-host "INFO - KEYTOOL=$KEYTOOL" 
Write-host "INFO - KEYKDB=$KEYKDB" 
Write-host "INFO - KEYP12=$KEYP12" 
Write-host "INFO - TRUSTP12=$TRUSTP12" 
Write-host "INFO - SIGNERSP12=$SIGNERSP12" 
Write-host "INFO - HFILES="
foreach ( $h in $HFILES.Keys ) {
     $out = "{0}{1,-25}{2,-15}" -f "INFO -   ","$h"," = $($HFILES.$h)"
     write-host $out
}

