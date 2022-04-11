# ITM-TLS1.2-implementation

Author: Richard Niewolik

Contact: niewolik@de.ibm.com

Revision: 1.0


.... **in construction**


#

[1 General](#1-general)

[2 Tivoli Enterprise Management Server](#2-tems)

[3 Tivoli Enterprise Portal Server](#3-teps)

[4 Tivoli Enterprise Management Agent](#4-agents)

[5 Appendixes](#5-appendixes)

[6 Troubleshooting](#6-Troubleshooting)



#

1 General
=========

A step by step description was provided by IBM Support: https://www.ibm.com/support/pages/sites/default/files/inline-files/$FILE/ITMTEPSeWASTLSv12_ref_2_1.pdf. **This** Github entry provides 
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

The manual process described in the "_TLS v1.2 only configuration - TEP, IHS, TEPS, TEPS/eWAS components_" section of ITMTEPSeWASTLSv12_ref_2_1.pdf documented, was automated and two scripts have been created, one PowerShell script for Windows and a Bash shell script for Linux:
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
- **If you use your own CA root and issuer certs** in `keyfiles/keyfile.kdb`, you need to check if those are still existing in the new keydb and add them again if required."

**Download the scripts:**

Use "Download ZIP" to save scripts to a temp folder. Then unzip it.

<img src="https://media.github.ibm.com/user/85313/files/a8ede000-b0df-11ec-86d9-bf7e122e6f83" width="55%" height="55%">

**Execution:**

Both scripts are looking for the ITMHOME folder variables (%CANDLE_HOME on Windows and $CANDLEHOME on Linux). If not existing you need to use the `-h [ITMHOME]` option. The Shell script tries also to find the required "arch" folder (e.g. lx8266) but you can use the `a [ arch ]` to provide the directory name.

Windows: 
- Open PowerShell cmd prompt and go to the temp directory
- Launch script via `.\activate_teps-tlsv1.2.ps1 [-h ITMHOME ]`

Unix/Linux
- Open shell prompt and go to the temp directory
- Launch script via `./activate_teps-tlsv1.2.sh [-h ITMHOME] -a [ arch ]`

<BR>

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

- **(5)**: On windows the option `-e` option creates an `[Override Local Settings]` section in the `ITMHOME\TMAITM6_64\k[pc]cma.ini` with the new variable settings. Then it reconfigures the agent and adds a registry entry into  `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment` (for example for  KDEBE_TLSV12_CIPHER_SPECS). This means that in future, every manuall change in that registry key, will be overwritten by the override section regardless what you set in the MTEMS tool.
- **(6)**: On Linux/Unix the option `-e` option creates an `ITMHOME/config/[pc].environment` file with the new variable settings. Then it restarts the agent. This means that in future, when configuring the agent for the same values, it will be overwritten by the `[pc].environment` settings.
- **(7)**: On windows the option `-p SERVER=myprimary1 PROTOCOL=IP.SPIPE ...` is overriding the CT_CMSLIST and KDC_FAMILIES registry keys. Hence if you ever used the `[Override Local Settings]` section in the `ITMHOME\TMAITM6_64\k[pc]cma.ini` to set these variables in that file, the `tacmd` command will not change anything, because they will be overwritten by the override section.
- **(8)**: On Linux the option `-p SERVER=myprimary1 PROTOCOL=IP.SPIPE ...` is configuring and overiding the TEMS and KDC_FAMILIES values in `ITMHOME/config/.ConfigData/[pc]env` file. Hence if you ever used the `ITMHOME/config/[pc].environment` to set same varaibles the `tacmd` command will not change anything, because they will be overwritten by the `[pc].environment` file settings.

**ALTERNATIVE B** ---------------

Reconfigure Agents using local ITM silent configuration.

ON WINDOWS:
1. Modifiy the correspondig **ITMHOME\TMAITM6_64\k[pc]cma.ini** file. If the `[Override Local Settings]`, create one at the end of the **_k[pc]cma.ini_** file. For example `kntcma.ini`. Add or modifythe following settings.

If you  use failover RTEMS:
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
- **(1)** The variables you add into the ini file `[Override Local Settings]` section, will be added or modified in the exsiting Registry key `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment`. In future, every manuall change in that registry key or MTEMS configuration tool, will be overwritten by the override section regardless what you set in the MTEMS tool. 
This behavior may differ for subnode or instance agents.
- **(2)** Before a mass rollout, you must successfully test it for each agent type you want to modify

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

You perform local config steps or modify/create the correspondig config files by using remote commands. For examle tacmd executecommnad, getfile, putfile or use your own distribution tools.

On Windows you may try to edit or add configuration settings directly in the registry  `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment`:

<img src="https://media.github.ibm.com/user/85313/files/b72bde00-b9b4-11ec-98cb-f210ff3d4edb" width="55%" height="55%">

Please always  check if the registry settings are picked up by the agents after restart. Also always check if the `ITMHOME\TMAITM6_64\k[pc]cma.ini` file does not contain an `[Override Local Settings]` section with the same variables names as those you have manually set in the reagistry. The `[Override Local Settings]` section will override your manual registry changes the next time an agent is reconfigured by the MTEMS tools.  

On Linux/Unix you could add the required variables directly into the ITMHOME/config/[pc].ini file. That way you do not need the [pc].environemnt file. But this is not working for instance agents, where the instance config file must be modified.

<BR>

5 Appendixes
============

.....

<BR>

6 Troubleshooting
=================

Content from: https://www.ibm.com/support/pages/sites/default/files/inline-files/$FILE/ITMTEPSeWASTLSv12_ref_2_1.pdf

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


