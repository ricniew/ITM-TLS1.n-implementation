# ITM-TLS1.2-implementation

Author: Richard Niewolik

Contact: niewolik@de.ibm.com

Revision: 1.0



#

[1 General](#1-general)

[2 Tivoli Enterprise Management Server](#2-tems)

[3 Tivoli Enterprise Portal Server](#3-teps)

[4 Tivoli Enterprise Management Agent](#4-agents)

[5 Troubleshooting](#5-Troubleshooting)

[6 Appendixes](#6-appendixes)

<BR>

#

1 General
=========

A step by step description was provided by IBM Support: https://www.ibm.com/support/pages/tivoli-monitoring-v6307-tls-v12-only-configuration-tep-ihs-teps-teps-ewas-components-and-ewas-default-certificate-renewal. **This** Github entry provides 
- automation scripts for the TEPS related configuration changes 
- and some additional details.

**PREREQUISITES**

Your environment **must be at least at ITM 6.3 FP7** and a **WAS 855 uplift must have been performed** before implementing TLSv1.2. 
If a WAS 855 uplift was not performed in the TEPS host as described in the update readme files, you must execute _Appendix B_ action as described in above document. To check if a WAS uplift was made use `ITMHOME/[arch]/iw/bin/versionInfo.sh` or `ITMHOME\CNPSJ\bin\versionInfo.bat`. The version must be at least `8.5.5.16`

Following ciphers are refered in this document, in the provided TEPS scripts and the sample response files (see Agent section):
- `KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256`

**Note:** If others cipher specs needs to be used, you **must** modify the TEPS scripts and use them everywhere they are set in this document.

**APPROACHES**

**A.** If all your TEMS and Agents are **already using IP.SPIPE** you need:
  
  1. Leave the TEMS configuration as it is.
  2. Configure all your Agents to use TLSV1.2 and the specific ciphers for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

**B.** If all your TEMS and Agents **use only IP.PIPE** you need:

  1. First configure your TEMS to use IP.SPIPE and IP.PIPE (**how to**: see TEMS section). By default TLSV1.x and all existing ciphers are allowed to be used.
  2. Configure all your Agents to use IP.SPIPE with  TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

**C.**
If all your TEMS use **both IP.SPIPE and IP.PIPE** and **some Agents use IP.PIPE and others IP.SPIPE** you need:

  1. Leave the TEMS configuration as it is.
  2. Configure all your Agents to use IP.SPIPE with TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

<BR>
  
2 TEMS
==============

To use TLS, specifically TLSV1.2, all TEMS server (HUB and remote TEMS) **must** use IP.SPIPE (HTTPS) for communication.

**CONFIGURE IP.SPIPE on TEMS:**

To do so you need to reconfigure your **HUB and each RTEMS**:

  - Windows: Use MTEMS tool to configure and **add** IP.SPIPE protocol to your TEMS 
 <img src="https://media.github.ibm.com/user/85313/files/567d2e00-b415-11ec-9930-33bc3a4c462e" width="25%" height="25%">
 
  - Linux/AIX: Use `itmcmd config -S -t TEMS` tool to configure and **add** IP.SPIPE protocol to your TEMS 
  - Restart TEMS

Now you can configure TEPS and agents to connect to the TEMS using IP.SPIPE

**THEN:**

As soon **all ITM components are connected to TEMS using IP.SPIPE with TLSV1.2** and **the specific ciphers** you can disable IP.PIPE + TLS10 + TLS11 on all TEMS.

WINDOWS:

  1.  In: [ITMHOME]\CMS\KBBENV add or modify the following options <BR>
```
  KDEBE_TLS10_ON=NO
  KDEBE_TLS11_ON=NO
  KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256
```
  2. Reconfigure TEMS using MTEMS tool and disable IP.PIPE protocol
  <img src="https://media.github.ibm.com/user/85313/files/3d25b300-b410-11ec-8f0b-36670dee661b" width="25%" height="25%">
  
  3. Restart the TEMSs

LINUX/AIX

  1.  In `[ITMHOME]/table/[TEMSNAME]/config/ms.ini` add or modify the following options
```
  KDEBE_TLS10_ON=NO
  KDEBE_TLS11_ON=NO
  KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256
```
     
  2.  Reconfigure TEMS using `itmcmd config -S -t TEMS` disable IP.PIPE protocol
  3.  Restart the TEMSs

<BR>

3 TEPS
==============

The manual process described in  "_TLS v1.2 only configuration - TEP, IHS, TEPS, TEPS/eWAS components_" section of the PDF file provided (https://www.ibm.com/support/pages/tivoli-monitoring-v6307-tls-v12-only-configuration-tep-ihs-teps-teps-ewas-components-and-ewas-default-certificate-renewal), was automated and two scripts have been created, one PowerShell script for Windows and a Bash shell script for Linux:

1. Windows [activate_teps-tlsv1.2.ps1](https://github.ibm.com/NIEWOLIK/ITM-TLS1.2-implementation/blob/main/activate_teps-tlsv1.2.ps1)
1. Linux/Unix [activate_teps-tlsv1.2.sh](https://github.ibm.com/NIEWOLIK/ITM-TLS1.2-implementation/blob/main/activate_teps-tlsv1.2.sh)

The Bash shell script was tested on RedHat linux only, but should run on other Linux Distributions and Unix systems as well.

**Prereqs:**

- Before starting the script, please verify that the TEPS is started and **connected to TEMS using IP.SPIPE**
- Update the `wasadmin` password if **not** done so far
    - **Unix**: `$CANDLEHOME/{archdir}/iw/scripts/updateTEPSEPass.sh wasadmin {yourpass}` (e.g. _/opt/IBM/ITM/lx8266/iw/scripts/ updateTEPSEPass.sh wasadmin itmuser_ )
    - **Windows**: `%CANDLE_HOME%\CNPSJ\scripts\updateTEPSEPass.bat wasadmin {yourpass}` (e.g. _c:\IBM\ITM\CNPSJ\scripts\updateTEPSEPass.bat wasadmin itmuser_ 
- PowerShell on Windows and Bash Shell on Linux must exists
- If a WAS 855 uplift was not performed in the TEPS host as described in the update readme files, you must execute _Appendix B_ action as described in ITMTEPSeWASTLSv12 pdf  document. To check if a WAS uplift was made use ITMHOME/[arch]/iw/bin/versionInfo.sh or ITMHOME\CNPSJ\bin\versionInfo.bat. The version must be at least 8.5.5.16
- **If you use your own CA root and issuer certs** in `keyfiles/keyfile.kdb`, you need to check if they are still present in the newly created keyfile.kdb and add them back if needed.

**Download the scripts:**

Use "Download ZIP" to save scripts to a temp folder. Then unzip it.

<img src="https://media.github.ibm.com/user/85313/files/a8ede000-b0df-11ec-86d9-bf7e122e6f83" width="55%" height="55%">

**Execution:**

Both scripts are looking for the ITMHOME folder variables (%CANDLE_HOME% on Windows and $CANDLEHOME on Linux). If not existing you need to use the `-h [ITMHOME]` option. The Shell script tries also to find the required "arch" folder (e.g. lx8266) but you can use the `-a [ arch ]` to provide the directory name.

Windows: 
- Open PowerShell cmd prompt and go to the temp directory
- Launch script via `.\activate_teps-tlsv1.2.ps1 [-h ITMHOME ]`

Unix/Linux
- Open shell prompt and go to the temp directory
- Launch script via `./activate_teps-tlsv1.2.sh [-h ITMHOME] -a [ arch ]`

<BR>
  
**Verification**

Test TEP login:

- Access `https://[yourhost]:15201/tep.jnlp` to test Webstart client (you may need to delete the Java cache)

To verify certs usage for ports 15206 (eWas Console) or 15201 (TEPS HTTPS). Sample outputs for port 15206:

- Command `openssl s_client -crlf -connect localhost:15206  -servername localhost -tls1_2 < /dev/null | egrep "Secure Renegotiation|Server public key | SSL handshake"`. Output:
    ```
    depth=1 C = US, O = IBM, OU = ITMNode, OU = ITMCell, OU = Root Certificate, CN = falcate1
    verify error:num=19:self signed certificate in certificate chain
    DONE
    Server public key is 2048 bit
    Secure Renegotiation IS supported
    ```
- Command `openssl s_client  -connect localhost:15206 2>/dev/null |  openssl x509 -noout -dates`. Output:
    ```
    notBefore=Mar 31 15:22:36 2022 GMT
    notAfter=Mar 31 15:22:36 2023 GMT
    ```
- Commnad `openssl s_client  -connect localhost:15206 2>/dev/null |  openssl x509 -noout -issuer -nameopt multiline`. Output:
    ```issuer=
        countryName               = US
        organizationName          = IBM
        organizationalUnitName    = ITMNode
        organizationalUnitName    = ITMCell
        organizationalUnitName    = Root Certificate
        commonName                = falcate1
    ```

4 Agents
==============

**ALTERNATIVE A** ---------------

Use ITM `tacmd setagentconnection` command.

If you use failover RTEMS and IP.PIPE was used: <BR>
- `tacmd setagentconnection -n falcate1:LZ -a -p SERVER=myprimary1 PROTOCOL1=IP.SPIPE IP_SPIPE_PORT=3660 BACKUP=Y BSERVER=mysecondary1 BPROTOCOL1=IP.SPIPE BIP_SPIPE_PORT=3660` <BR>([ITMHOME]/config/.ConfigDate/[pc]env file is modified, agents are reconfigured and restartet)
- `tacmd setagentconnection -n falcate1:LZ -a -e  KDEBE_TLS10_ON=NO KDEBE_TLS11_ON=NO KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256` <BR>([ITMHOME]/config/[pc].environment file is created with the KDEBE settings for each agent running on the system, agents are restarted)

If you don't use failover RTEMS (agent connects to one TEMS only) and IP.PIPE was used: <BR>
- `tacmd setagentconnection -n falcate1:LZ -a -p SERVER=myprimary1 PROTOCOL=IP.SPIPE IP_SPIPE_PORT=3660` <BR>([ITMHOME]/config/.ConfigDate/[pc]env file is modified, agents are reconfigured and restartet)
- `tacmd setagentconnection -n falcate1:LZ -a -e KDEBE_TLS10_ON=NO KDEBE_TLS11_ON=NO KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256` <BR>([ITMHOME]/config/[pc].environment file is created with the KDEBE settings for each agent running on the system, agents are restarted)
 
If IP.SPIPE was already used: <BR>
- `tacmd setagentconnection -n falcate1:LZ -a -e KDEBE_TLS10_ON=NO KDEBE_TLS11_ON=NO KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256` ([ITMHOME]/config/[pc].environment file is created with the KDEBE settings for each agent running on the system, agents are restarted)



**Important Notes:** 
- **(1)**: You can **only** use the `tacmd` when the OS Agent is running. 
- **(2)**: On windows the `tacmd setagentconnection` commands are **only** working when the agent is running with **administration** rigths.
- **(3)**: On Windows the option `-a` of `tacmdsetagentconnection` command **does not work**. You would need to use the `-t ` to modify the agents (e.c. "-t nt "). For example: `tacmd setagentconnection -n Primary:myhost:NT -t nt -p SERVER=myprimary1 PROTOCOL=IP.SPIPE IP_PIPE_PORT=3660`
- **(4)**: On Windows the option `-e` of `tacmdsetagentconnection` command with multiple variable settings **does not work**. You would need to execute one comamnd for each KDEBE variable. For example <BR> `tacmd setagentconnection -n Primary:myhost:NT -t nt -e KDEBE_TLS10_ON=NO` <BR> `tacmd setagentconnection -n Primary:myhost:NT -t nt -e KDEBE_TLS11_ON=NO` <BR> `tacmd setagentconnection -n Primary:myhost:NT -t sy -e KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256`

- **(5)**: On Windows, the `-e` option creates a `[Overwrite local settings]` section in the `ITMHOME\TMAITM6_64\k[pc]cma.ini` file with the new variable settings. Then the agent is reconfigured and a registry entry is added to `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment` for the specified variable (for example KDEBE_TLSV12_CIPHER_SPECS). This means that in the future, any manual change to the registry key of this variable will be overwritten by the override section, regardless of what you have specified.

- **(6)**:On Linux/Unix, the `-e` option creates an `ITMHOME/config/[pc].environment` file with the new variable settings. Then the agent will be reconfigured and restarted. This means that in the future, if you configure the agent for the same values but set them in the [pc].ini file, they will be overwritten by the `[pc].environment` settings.
- **(7)**: On Windows, the `-p SERVER=myprimary1 PROTOCOL=IP.SPIPE ...` option overrides the CT_CMSLIST and KDC_FAMILIES registry keys. If you have ever used the `Override Local Settings` section of the `ITMHOME\TMAITM6_64\k[pc]cma.ini` file to set the same variables, the `tacmd` command will not change anything because the new settings will be overwritten by the `Override Local Settings` section.
- **(8)**: On Linux the option `-p SERVER=myprimary1 PROTOCOL=IP.SPIPE ...` is configuring and overiding the TEMS and KDC_FAMILIES values in `ITMHOME/config/.ConfigData/[pc]env` file. Hence if you ever used the `ITMHOME/config/[pc].environment` to set same varaibles, the `tacmd` command will not change anything, because they will be overwritten by the `[pc].environment` file settings.

**ALTERNATIVE B** ---------------

Reconfigure Agents using local ITM silent configuration.

ON WINDOWS:
1. Modifiy the correspondig **ITMHOME\TMAITM6_64\k[pc]cma.ini** file. If the `[Override Local Settings]` doesn't exists, create one at the end of the **_k[pc]cma.ini_** file. For example `kntcma.ini`. Add or modify the following settings.

    If you use failover RTEMS:
    ```
    [Override Local Settings]
    CTIRA_HIST_DIR=@LogPath@\History\@CanProd@
    KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256, TLS_RSA_WITH_AES_256_CBC_SHA256
    KDEBE_TLS11_ON=NO
    KDEBE_TLS10_ON=NO
    CT_CMSLIST=IP.SPIPE:RTEMS-MINUTEST1;IP.SPIPE:RTEMS-MINUTEST2
    KDC_FAMILIES=IP.SPIPE PORT:3660 IP use:n SNA use:n IP.PIPE use:n IP6 use:n IP6.PIPE use:n IP6.SPIPE use:n
    ```
    If you NOT use failover RTEMS:
    ```
    [Override Local Settings]
    CTIRA_HIST_DIR=@LogPath@\History\@CanProd@
    KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256, TLS_RSA_WITH_AES_256_CBC_SHA256
    KDEBE_TLS11_ON=NO
    KDEBE_TLS10_ON=NO
    CT_CMSLIST=IP.SPIPE:RTEMS-MINUTEST1
    KDC_FAMILIES=IP.SPIPE PORT:3660 IP use:n SNA use:n IP.PIPE use:n IP6 use:n IP6.PIPE use:n IP6.SPIPE use:n
    ```

2. Stop the agent using **_net stop [servicename]_** , for example `net stop KNTCMA_Primary`
3. Reconfigure the agent by executing `kinconfg -n -rK[pc]`, for example `kinconfg -n -rKNT`. And wait until _kinconfg.exe_ process finishes (no more the 10 seconds). For instance agents you may use `kinconfg -n -riK[pc][instance]`
4. Start the agent using **_net start [servicename]_** , for example `net stop KNTCMA_Primary`

**Important notes:**
- **(1)** The variables you add into the ini file `[Override Local Settings]` section, will be added or modified in the exsiting Registry key `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment` after reconfiguration. In future, every manuall change in that registry key or MTEMS configuration tool, will be overwritten by the override section and your changes will be ignored. 
This behavior may differ for subnode or instance agents.
- **(2)** Before a mass rollout, you must successfully test new settings for each agent type you want to modify

ON LINUX/UNIX:

1. Create a silent config response file, e.g. _resposefile.txt_ with following content
    If you use failover RTEMS:
    ```
    CMSCONNECT=YES
    FTO=YES
    NETWORKPROTOCOL=ip.spipe
    IPSPIPEPORTNUMBER=3660
    HSNETWORKPROTOCOL=ip.spipe
    HSIPSPIPEPORTNUMBER=3660
    HOSTNAME=rtems-falcate1.my.dom.com
    MIRROR=rtems-minutest1.my.dom.com
    CUSTOM#KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256
    CUSTOM#KDEBE_TLS10_ON=NO
    CUSTOM#KDEBE_TLS11_ON=NO
    ```

    If you NOT use failover RTEMS:
    ```
    CMSCONNECT=YES
    NETWORKPROTOCOL=ip.spipe
    IPSPIPEPORTNUMBER=3660
    HOSTNAME=rtems-falcate1.my.dom.com
    CUSTOM#KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256
    CUSTOM#KDEBE_TLS10_ON=NO
    CUSTOM#KDEBE_TLS11_ON=NO
    ```

2. Execute `ITMHOME/bin/itmcmd config -A -p [respfile] [pc]`. For examle `itmcmd config -A -p resposefile.txt lz`. For instance agent use `itmcmd config -A -p [respfile] -o [instance] [pc]`
3. Restart the agent using `ITMHOME/bin/itmcmd agent stop/start [pc]`, for example `itmcmd agent stop lz ; itmcmd agent start lz`. For instance agents use `itmcmd agent -p [instance] -f stop [pc] ; itmcmd agent -p [instance] -f start [pc]`

**Important notes:**
- Before a mass rollout, you must successfully test it for each agent type you want to modify
- When executing config as shown above `ITMHOME/config/.ConfigData/[pc]env` file is updated and `ITMHOME/config/[pc].environment` updated or created if not existing before.

**OTHER ALTERNATIVE** ---------------

You can perform local config steps or modify/create the correspondig config files by using remote commands. For examle tacmd executecommnad, getfile, putfile or use your own distribution tools.

On Windows you may try to edit or add configuration settings directly in the registry  `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment`:

<img src="https://media.github.ibm.com/user/85313/files/b72bde00-b9b4-11ec-98cb-f210ff3d4edb" width="55%" height="55%">

Please always  check if the registry settings are picked up by the agents after restart. Also always check if the `ITMHOME\TMAITM6_64\k[pc]cma.ini` file does not contain an `[Override Local Settings]` section with the same variables names as those you have manually set in the reagistry. The `[Override Local Settings]` section will override your manual registry changes the next time an agent is reconfigured by the MTEMS tools.  

On Linux/Unix you could add the required variables directly into the ITMHOME/config/[pc].ini file. That way you do not need the [pc].environemnt file. But this is not working for instance agents, where the instance config file must be modified.

<BR>

5 Troubleshooting
=================

Content from PFD file: https://www.ibm.com/support/pages/tivoli-monitoring-v6307-tls-v12-only-configuration-tep-ihs-teps-teps-ewas-components-and-ewas-default-certificate-renewal

**Trace settings for both IHS and the TEPS/eWAS**

For the TEPS/eWAS, they should use the TEPS/e Administration Console to set the trace options for their run-time environment (they don't have to save these TEPS/eWAS tracing options in their configuration).
Here are the steps to perform against the files on the TEPS machine:

1. Edit the httpd.conf file (see IHS 1.)
Locate the LogLevel directive in the file, and change the assigned value from “warn” to
“debug”
Save the changes to the file.
2. Edit the plugin-cfg.xml file. (see Appendix B 8.)
Locate the string "<Log LogLevel=" in the file, and change the assigned value from "Error" to
"Detail" (leave all other variables as is)
Save the changes to the file.
3. Activate and login to the TEPS/e Administration Console:
4.  From the TEPS/e Admin Console, select
“Troubleshooting” -> “Logs and Trace” -> ITMServer -> “Diagnostic Trace” -> “Change Log
Level Details” -> Click the "Runtime” tab.
In the entry panel, you will see the default trace string of *=info. Replace that string with
the following (best to copy-and-paste to avoid typing errors):
*=info:TCPChannel=all:HTTPChannel=all:com.ibm.ws.jaxrs.=all:com.ibm.websphere.jaxrs.=all:org.apache.wink.=all:com.ibm.ws.http.HttpConnection=finest:com.ibm.ws.http.HttpRequest=finest:com.ibm.ws.http.HttpResponse=finest:com.ibm.ws.ssl.*=finest
5. Click “OK” at the bottom of the screen to save the changes to the Runtime tab. That level of tracing is now enabled for the TEPS/eWAS. You should not restart the TEPS.
6. Re-run the failing scenario where attempts to login to the TEPS using the TEP JWS client. Once the failure occurs, run a pdcollect against the TEPS server machine and upload the resulting pdcollect archive to ecurep for review. Please also include the updated
plugin-cfg.xml and httpd.conf file that was edited for this test in step 1&2 above.

**Unable to login to Tivoli Enterprise Portal (TEP) webstart client**
Please read the technote
https://www.ibm.com/support/pages/unable-login-tivoli-enterprise-portal-tep-webstart-client

<BR>

6 Appendixes
============

Sample run of the activate_teps-tlsv1.2.sh script in Linux:
```
[root@falcate1 IBM]# ./activate_teps-tlsv1.2.sh -h /opt/IBM/ITM
INFO - main - ITM home directory is: /opt/IBM/ITM
INFO - main - ITM arch directory is: /opt/IBM/ITM/lx8266
INFO - main - Backup directory is: /opt/IBM/ITM/backup_before_TLS1.2
INFO - EnableICSLite - Set ISCLite to 'true' 
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
WASX7303I: The following options are passed to the scripting environment and are available as arguments that are stored in the argv variable: "[true]"
ISClite is not running
ISClite started 

INFO - backup - Saving Directory /opt/IBM/ITM/lx8266/iw in /opt/IBM/ITM/backup_before_TLS1.2. This can take a while...
INFO - backup - Saving Directory /opt/IBM/ITM/lx8266/iw in /opt/IBM/ITM/backup_before_TLS1.2. This can take a while...
INFO - backupfile - Saving /opt/IBM/ITM/lx8266//iu/ihs/HTTPServer/conf/httpd.conf in backup_before_TLS1.2 
INFO - backupfile - Saving /opt/IBM/ITM/config/cq.ini in backup_before_TLS1.2 
INFO - backupfile - Saving /opt/IBM/ITM/config/tep.jnlpt in backup_before_TLS1.2 
INFO - backupfile - Saving /opt/IBM/ITM/config/component.jnlpt in backup_before_TLS1.2 
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/cw/applet.html.updateparams in backup_before_TLS1.2 
WARNING - backupfile - file /opt/IBM/ITM/lx8266/cj/kcjparms.txt does NOT exists and not saved. KCJ componenent probably not installed. Continue...
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security in backup_before_TLS1.2 
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12 in backup_before_TLS1.2 
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12 in backup_before_TLS1.2 
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props in backup_before_TLS1.2 
WARNING - createRestoreScript - TEP Desktop Client apparently not installed. File 'kcjparms.txt' not added to restore script
INFO - createRestoreScript - Restore bat file created /opt/IBM/ITM/backup_before_TLS1.2/SCRIPTrestore.sh
 /opt/IBM/ITM/lx8266/iw/bin/wsadmin.sh -lang jython -c "AdminTask.renewCertificate('-keyStoreName NodeDefaultKeyStore -certificateAlias  default')" -c "AdminConfig.save()"
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
TEPSEWASBundle loaded.
'\nCWPKI0704I: The personal certificate with the default alias in the NodeDefaultKeyStore keystore has been RENEWED.'
''
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
TEPSEWASBundle loaded.
'[[alias default] [version 3] [size 2048] [serialNumber 1162375622885617] [issuedTo [CN=falcate1, OU=ITMCell, OU=ITMNode, O=IBM, C=US]] [issuedBy [CN=falcate1, OU=Root Certificate, OU=ITMCell, OU=ITMNode, O=IBM, C=US]] [fingerPrint 24:18:2E:7C:CC:FD:20:73:27:87:62:58:F8:13:8C:90:B1:50:33:CC] [signatureAlgorithm SHA256withRSA(1.2.840.113549.1.1.11)] [validity [Valid from Mar 31, 2022 to Mar 31, 2023.]] [index 0] ]\n[[alias default] [version 3] [size 2048] [serialNumber 1059435484107525] [issuedTo [CN=falcate1, OU=Root Certificate, OU=ITMCell, OU=ITMNode, O=IBM, C=US]] [issuedBy [CN=falcate1, OU=Root Certificate, OU=ITMCell, OU=ITMNode, O=IBM, C=US]] [fingerPrint 29:2D:FB:FC:0F:AF:D7:6D:7D:89:0E:3A:EC:61:80:50:39:FE:AB:7C] [signatureAlgorithm SHA256withRSA(1.2.840.113549.1.1.11)] [validity [Valid from Mar 30, 2022 to Mar 26, 2037.]] [index 1] ]'
INFO - renewCert - Successfully renewed Certificate
INFO - renewCert - Running GSKitcmd.sh commands
INFO - renewCert - GSKitcmd.sh commands finished. See label and issuer info below...

CANDLEHOME=/opt/IBM/ITM /opt/IBM/ITM/bin/GSKitcmd.sh gsk8capicmd_64 -cert -list -db /opt/IBM/ITM/keyfiles/keyfile.kdb -stashed -label default 
-default
!root

CANDLEHOME=/opt/IBM/ITM /opt/IBM/ITM/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db /opt/IBM/ITM/keyfiles/keyfile.kdb -stashed -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
Serial : 04212caa1900f1
Issuer : "CN=falcate1,OU=Root Certificate,OU=ITMCell,OU=ITMNode,O=IBM,C=US"
Subject : CN=falcate1,OU=ITMCell,OU=ITMNode,O=IBM,C=US
Not Before : March 31, 2022 5:20:16 AM PDT
Not After : March 31, 2023 5:20:16 AM PDT
    SubjectKeyIdentifier

CANDLEHOME=/opt/IBM/ITM /opt/IBM/ITM/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12 -pw WebAS -label default | egrep 'Serial|Issuer|Subject|Not Before|Not After'
Serial : 04212caa1900f1
Issuer : "CN=falcate1,OU=Root Certificate,OU=ITMCell,OU=ITMNode,O=IBM,C=US"
Subject : CN=falcate1,OU=ITMCell,OU=ITMNode,O=IBM,C=US
Not Before : March 31, 2022 5:20:16 AM PDT
Not After : March 31, 2023 5:20:16 AM PDT
    SubjectKeyIdentifier

CANDLEHOME=/opt/IBM/ITM /opt/IBM/ITM/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db /opt/IBM/ITM/keyfiles/keyfile.kdb -stashed -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
Serial : 03c38d0bb15305
Issuer : "CN=falcate1,OU=Root Certificate,OU=ITMCell,OU=ITMNode,O=IBM,C=US"
Subject : "CN=falcate1,OU=Root Certificate,OU=ITMCell,OU=ITMNode,O=IBM,C=US"
Not Before : March 30, 2022 12:44:34 AM PDT
Not After : March 26, 2037 12:44:34 AM PDT
    SubjectKeyIdentifier

CANDLEHOME=/opt/IBM/ITM /opt/IBM/ITM/bin/GSKitcmd.sh gsk8capicmd_64 -cert -details -db /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12 -pw WebAS -label root | egrep 'Serial|Issuer|Subject|Not Before|Not After'
Serial : 03c38d0bb15305
Issuer : "CN=falcate1,OU=Root Certificate,OU=ITMCell,OU=ITMNode,O=IBM,C=US"
Subject : "CN=falcate1,OU=Root Certificate,OU=ITMCell,OU=ITMNode,O=IBM,C=US"
Not Before : March 30, 2022 12:44:34 AM PDT
Not After : March 26, 2037 12:44:34 AM PDT
    SubjectKeyIdentifier
INFO - restartTEPS - Restarting TEPS ...
Processing. Please wait...
systemctl stop ITMAgents1.cq.service RC: 0
Stopping Tivoli Enterprise Portal Server ...
Product Tivoli Enterprise Portal Server was stopped gracefully.
Product IBM Eclipse Help Server was stopped gracefully.
Agent stopped...
Processing. Please wait...
systemctl start ITMAgents1.cq.service RC: 0
Starting Tivoli Enterprise Portal Server ...
Eclipse Help Server is required by Tivoli Enterprise Portal Server (TEPS) and will be started...
Eclipse Help Server was successfully started
Tivoli Enterprise Portal Server started
INFO - restartTEPS - Waiting for TEPS to initialize....
............
INFO - restartTEPS - TEPS restarted successfully.
INFO - EnableICSLite - Set ISCLite to 'true' 
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
WASX7303I: The following options are passed to the scripting environment and are available as arguments that are stored in the argv variable: "[true]"
ISClite is not running
ISClite started 

/opt/IBM/ITM/lx8266/iw/bin/wsadmin.sh -lang jython -c  "AdminTask.modifySSLConfig('[-alias NodeDefaultSSLSettings -scopeName (cell):ITMCell:(node):ITMNode -keyStoreName NodeDefaultKeyStore -keyStoreScopeName (cell):ITMCell:(node):ITMNode -trustStoreName NodeDefaultTrustStore -trustStoreScopeName (cell):ITMCell:(node):ITMNode -jsseProvider IBMJSSE2 -sslProtocol TLSv1.2 -clientAuthentication false -clientAuthenticationSupported false -securityLevel HIGH -enabledCiphers ]')" -c  "AdminConfig.save()"
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
TEPSEWASBundle loaded.
''
''
INFO - modQop - Successfully set TLSv1.2 for Quality of Protection (QoP)
/opt/IBM/ITM/lx8266/iw/bin/wsadmin.sh -lang jython -f /opt/IBM/ITM/tmp/org.jy
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
INFO - disableAlgorithms - Successfully set com.ibm.websphere.tls.disabledAlgorithms to none
INFO - modsslclientprops - Start /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props modification 
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props.beforetls12 created to save original content
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props.tls12 will be the modified file
INFO - modsslclientprops - /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props.tls12 created and copied on /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props
INFO - modhttpconf - Start /opt/IBM/ITM/lx8266//iu/ihs/HTTPServer/conf/httpd.conf creation 
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266//iu/ihs/HTTPServer/conf/httpd.conf.beforetls12 created to save original content
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266//iu/ihs/HTTPServer/conf/httpd.conf.tls12 will be the modified file
INFO - modhttpconf - /opt/IBM/ITM/lx8266//iu/ihs/HTTPServer/conf/httpd.conf.tls12 created and copied on /opt/IBM/ITM/lx8266//iu/ihs/HTTPServer/conf/httpd.conf
INFO - modcqini - Start /opt/IBM/ITM/config/cq.ini creation 
INFO - saveorgcreatenew - /opt/IBM/ITM/config/cq.ini.beforetls12 created to save original content
INFO - saveorgcreatenew - /opt/IBM/ITM/config/cq.ini.tls12 will be the modified file
INFO - modcqini - /opt/IBM/ITM/config/cq.ini.tls12 created and copied on /opt/IBM/ITM/config/cq.ini
INFO - modjavasecurity - Start /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security creation 
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security.beforetls12 created to save original content
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security.tls12 will be the modified file
INFO - modjavasecurity - /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security.tls12 created and copied on /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security
INFO - restartTEPS - Restarting TEPS ...
Processing. Please wait...
systemctl stop ITMAgents1.cq.service RC: 0
Stopping Tivoli Enterprise Portal Server ...
Product Tivoli Enterprise Portal Server was stopped gracefully.
Product IBM Eclipse Help Server was stopped gracefully.
Agent stopped...
Processing. Please wait...
systemctl start ITMAgents1.cq.service RC: 0
Starting Tivoli Enterprise Portal Server ...
Eclipse Help Server is required by Tivoli Enterprise Portal Server (TEPS) and will be started...
Eclipse Help Server was successfully started
Tivoli Enterprise Portal Server started
INFO - restartTEPS - Waiting for TEPS to initialize....
............
INFO - restartTEPS - TEPS restarted successfully.
INFO - modtepjnlpt - Start  creation 
INFO - saveorgcreatenew - /opt/IBM/ITM/config/tep.jnlpt.beforetls12 created to save original content
INFO - saveorgcreatenew - /opt/IBM/ITM/config/tep.jnlpt.tls12 will be the modified file
INFO - modtepjnlpt - /opt/IBM/ITM/config/tep.jnlpt.tls12 created and copied on /opt/IBM/ITM/config/tep.jnlpt
INFO - modcompjnlpt - Start modcompjnlpt creation 
INFO - saveorgcreatenew - /opt/IBM/ITM/config/component.jnlpt.beforetls12 created to save original content
INFO - saveorgcreatenew - /opt/IBM/ITM/config/component.jnlpt.tls12 will be the modified file
INFO - modcompjnlpt - /opt/IBM/ITM/config/component.jnlpt.tls12 created and copied on /opt/IBM/ITM/config/component.jnlpt
INFO - modapplethtmlupdateparams - Start /opt/IBM/ITM/lx8266/cw/applet.html.updateparams creation 
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266/cw/applet.html.updateparams.beforetls12 created to save original content
INFO - saveorgcreatenew - /opt/IBM/ITM/lx8266/cw/applet.html.updateparams.tls12 will be the modified file
INFO - modapplethtmlupdateparams - /opt/IBM/ITM/lx8266/cw/applet.html.updateparams.tls12 created and copied on /opt/IBM/ITM/lx8266/cw/applet.html.updateparams
INFO - main - Reconfiguring TEP WebSstart/Broswer client 'cw'
Agent configuration started...
Agent configuration completed...
WARNING - main - TEP Desktop client not installed and was not modified ('kcjparms.txt' not existing) 
INFO - EnableICSLite - Set ISCLite to 'false' 
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
WASX7303I: The following options are passed to the scripting environment and are available as arguments that are stored in the argv variable: "[false]"
ISClite is not running

------------------------------------------------------------------------------------------
INFO - main - Procedure successfully finished Elapsedtime: 4 min 
 - Original files saved in folder /opt/IBM/ITM/backup_before_TLS1.2 
 - To restore the level before update run '/opt/IBM/ITM/backup_before_TLS1.2/SCRIPTrestore.sh' 
----- POST script execution steps ---
 - Reconfigure TEPS and verify connections for TEP, TEPS, HUB
 - To check eWAS settings use: https://falcate1.fyre.ibm.com:15206/ibm/console/login
 - To check TEP WebStart  use: https://falcate1.fyre.ibm.com:15201/tep.jnlp
------------------------------------------------------------------------------------------
[root@falcate1 IBM]# 
```
<BR>




