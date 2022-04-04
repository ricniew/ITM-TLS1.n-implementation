# ITM-TLS1.2-implementation

Author: Richard Niewolik

Contact: niewolik@de.ibm.com

Revision: 1.0

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

.... **in construction**

A step by step description was provided by IBM Support: https://www.ibm.com/support/pages/sites/default/files/inline-files/$FILE/ITMTEPSeWASTLSv12_ref_2_1.pdf. **This** Github entry provides 
- automation scripts for the TEPS related configuration changes 
- and some additional details.

Following ciphers are refered in this document, in the provided TEPS scripts and the attached sample respose files:
- `KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256`

**Note:** If others cipher specs needs to be used, you **must** modify the TEPS scripts and use them everywhere they are set in this document.

**APPROACHES**

**A.** If all your TEMS and Agents are **already using IP.SPIPE** you need:
  
  1. Leave the TEMS configuration as it is.
  2. Configure all your Agents to use TLSV1.2 and the specific ciphers for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

**B.** If all your TEMS and Agents **uses only IP.PIPE** you need:

  1. First configure your TEMS to use IP.SPIPE and IP.PIPE (**how to**: see TEMS section). By default TLSV1.x and all existing ciphers are allowed to be used.
  2. Configure all your Agents to use IP.SPIPE with  TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

**C.**
If all your TEMS uses **both IP.SPIPE and IP.PIPE** and **some Agents uses PIPE and others SPIPE** you need:

  1. Leave the TEMS configuration as it is.
  2. Configure all your Agents to use IP.SPIPE with TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)


2 TEMS
==============

.... in **construction** 

To use TLS and specifically TLSV1.2 all TEMS (HUB and remote TEMS) **must** use IP.SPIPE (HTTPS) for cummunication.

**CONFIGURE IP.SPIPE on TEMS:**

To do so you need to reconfigure your TEMS:

  - Windows: Use MTEMS tool to configure and **add** IP.SPIPE protocol to your TEMS 
 <img src="https://media.github.ibm.com/user/85313/files/567d2e00-b415-11ec-9930-33bc3a4c462e" width="25%" height="25%">
 
  - Linux/AIX: Use `itmcmd config -S -t TEMS` tool to configure and **add** IP.SPIPE protocol to your TEMS 
  - Restart TEMS
  - Now you can configure TEPS and agents to connect to the TEMS using IP.SPIPE


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

  1.  In [ITMHOME]/table/[TEMSNAME]/KBBENV add or modify the following options
```
  KDEBE_TLS10_ON=NO
  KDEBE_TLS11_ON=NO
  KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256
```
  (**Note:**: As soon you reconfigure your TEMS at one point in the future, the KBBENV will be rebuild and you chages are gone. To avoid this you can edit the  [ITMHOME]/config/ms.ini file instead and reconfigure your TEMS)
    
  2.  Reconfigure TEMS using `itmcmd config -S -t TEMS` disable IP.PIPE protocol
  3.  Restart the TEMSs


3 TEPS
==============

.... in **construction** 

The manual process described in the "_TLS v1.2 only configuration - TEP, IHS, TEPS, TEPS/eWAS components_" section of ITMTEPSeWASTLSv12_ref_2_1.pdf documented, was automated and two scripts have been created, one PowerShell script for Windows and a Bash shell script for Linux:
1. _activate_teps-tlsv1.2.ps1_
1. _activate_teps-tlsv1.2.sh_

The Bash shell script was tested on RedHat linux only, but should run on other Linux Distributions and Unix systems as well.

**Prereqs:**

- Before staring the script, please verify that the TEPS is started and **connected to TEMS using IP.SPIPE**
- Update the `wasadmin` password if **not** done so far
    - **Unix**: `$CANDLEHOME/{archdir}/iw/scripts/updateTEPSEPass.sh wasadmin {yourpass}` (e.g. _/opt/IBM/ITM/lx8266/iw/scripts/ updateTEPSEPass.sh wasadmin itmuser_ )
    - **Windows**: `%CANDLE_HOME%\CNPSJ\scripts\updateTEPSEPass.bat wasadmin {yourpass}` (e.g. _c:\IBM\ITM\CNPSJ\scripts\updateTEPSEPass.bat wasadmin itmuser_ 
- PowerShell on Windows and Bash Shell on Linux must exists )

**Download the scripts:**

Use "Download ZIP" to save scripts to a temp folder. Then unzip it.

<img src="https://media.github.ibm.com/user/85313/files/a8ede000-b0df-11ec-86d9-bf7e122e6f83" width="55%" height="55%">

**Execution:**

Both scripts are looking for the ITMHOME folder variables (%CANDLE_HOME on Windows and $CANDLEHOME on Linux). If not existing you need to use the `-h [ITMHOME]` option. The Shell script tries also to find the required "arch" folder (e.g. lx8266) but you can use the `a [ arch ]` to provide the directory name.

Windows: 
- Open PowerShell cmd prompt and go to the temp directory
- launch script via `.\activate_teps-tlsv1.2.ps1 [-h ITMHOME ]`

Unix/Linux
- Open shell prompt and go to the temp directory
- launch script via `./activate_teps-tlsv1.2.sh [-h ITMHOME] -a [ arch ]`



4 Agents
==============

**.... in construction**

ALTERNATIVE 1

Use ITM `tacmd` commands
Sample:
 .....

**Note1:** You can **only** use the `tacmd` when the OS Agent is running. 
**Note1:** The `tacmd` commands are **only** working on Windows agents when the agent is running with **administration** rigths. 

ALTERNATIVE 2
Manually Use local ITM silent configuration
Sample:
 .....

ALTERNATIVE 3
Reconfigure Agents using your own distribution tools by using local ITM silent configuration.


5 Appendixes
============

**.... in construction**


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


