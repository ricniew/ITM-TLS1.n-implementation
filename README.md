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



#

1 General
=========

.... **in construction**

A step by step description was provided by IBM Support: https://www.ibm.com/support/pages/sites/default/files/inline-files/$FILE/ITMTEPSeWASTLSv12_ref_2_1.pdf. 
This Github entry provides automation scripts for the TEPS related configuration changes and some additional information.

Following ciphers are refered in this document,  the provided TEPS scripts and sample respose files:
- `KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256"`

If others needs to be used, you **must** modify the TEPS scripts and use them everywhere they are set in this document.



2 TEMS
==============

.... in **construction** 

To use TLS and specifically TLSV1.2 all TEMS (HUB and remote TEMS) **must** use IP.SPIPE (HTTPS) for cummunication.

**CONFIGURE IP.SPIPE on TEMS:**

To do so you need to reconfigure your TEMS:
    - Windows: Use MTEMS tool to configure and add IP.SPIPE protocol to your TEMS 
    - Linux/AIX: Use `itmcmd config -S -t TEMS` tool to configure and add IP.SPIPE protocol to your TEMS 

**APPROACHES**

**A.** If all your TEMS and Agents are **already using IP.SPIPE** you need:

  1. Configure all your Agents to use TLSV1.2 and the specific ciphers for the TEMS connenction (**how to**: see Agents section)
  2. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

**B.** If all your TEMS and Agents **uses only IP.PIPE** you need:

  1. First configure your TEMS to use IP.SPIPE and IP:PIPE (By default TLSV1.x and the specific ciphers are allowed to be used).
  2. Configure all your Agents to use IP.SPIPE with  TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

**C.**
If all your TEMS uses **both IP:SPIPE and IP.PIPE** and **some Agents uses PIPE and others SPIPE** you need:

  1. Leave the TEMS configuration as it is.
  2. Configure all your Agents to use IP.SPIPE with TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)

**THEN:**

As soon **all ITM components are connected to TEMS using IP.SPIPE with TLSV1.2** and **the specific ciphers** you can disable TLS10 + TLS11 on all TEMS.

1. In the TEMS config file: 

     - Windows: [ITMHOME]\CMS\KBBENV 
     - Linux/AIX: [ITMHOME]/table/[TEMSNAME]/KBBENV (**Note:**: As soon you reconfigure your TEMS at one point in the future, the KBBENV will be rebuild and you chages are gone. To avoid this you can edit the  [ITMHOME]/config/ms.ini file instead and reconfigure your TEMS) 

2. Check if the following statements exist, if they do not, add them.
    
    ```
    KDEBE_TLS10_ON=NO
    KDEBE_TLS11_ON=NO
    KDEBE_TLSV12_CIPHER_SPECS=TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256
    ```
    
3. Restart the TEMSs



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

<img src="https://media.github.ibm.com/user/85313/files/a8ede000-b0df-11ec-86d9-bf7e122e6f83" width="60%" height="60%">

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

5 Appendixes
============

**.... in construction**


