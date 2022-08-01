# ITM-TLS1.n-implementation

Author: Richard Niewolik

Contact: niewolik@de.ibm.com

Revision: 2.2


Content
-------

[1 General](#1-general) <BR>
[1.1 Prerequisites](#1.1) <BR>
[1.2 General Approaches](#1.2)

[2 Tivoli Enterprise Management Server](#2-tems)

[3 Tivoli Enterprise Portal Server](#3-teps) <BR>
[3.1 Prerequisites](#3.1) <BR>
[3.2 Download script files](#3.2) <BR>
[3.3 Syntax](#3.3) <BR>
[3.4 Execution](#3.4) <BR>
[3.4.1 Via script activate_teps-tlsv](#3.4.1) <BR>
[3.4.2 Step by step using functions](#3.4.2) <BR>
[3.5 Verifications](#3.5) 

[4 Summarization and Pruning Agent](#4-summarization-and-pruning-agent)

[5 Warehouse Proxy Agent](#5-warehouse-proxy-agent)

[6 Tivoli Enterprise Management Agent](#6-agents)  <BR>
[6.1 Alternative A](#6.1) <BR>
[6.2 Alternative B](#6.2) <BR>
[6.3 Other Alternatives](#6.3) <BR>

[7 Troubleshooting](#7-Troubleshooting)

[8 Appendixes](#8-appendixes)

<BR> 

#

1 General
=========

This asset can be used to configure ITM components to use only TLS v1.n. So far only TLSv1.2 can be implemented. 
A step by step description for TLSv1.2 created by IBM Support exists: https://www.ibm.com/support/pages/tivoli-monitoring-v6307-tls-v12-only-configuration-tep-ihs-teps-teps-ewas-components-and-ewas-default-certificate-renewal. **This** Github entry provides 
- automation scripts for the TEPS related configuration changes 
- and some additional details

1.2 Prerequisites<a id='1.1'></a>
-----------------

**For TLSv1.2**

1. Your environment **must be at least at ITM 6.3 FP7** and a **WAS 855 uplift must have been performed** before implementing TLSv1.2. 
If a WAS 855 uplift was not performed in the TEPS host as described in the update readme files, you must execute _Appendix B_ action as described in the IBM Support document. To check if a WAS uplift was made use `ITMHOME/[arch]/iw/bin/versionInfo.sh` or `ITMHOME\CNPSJ\bin\versionInfo.bat`. The version must be at least `8.5.5.16`

2. Following ciphers are used in the provided `init_tlsv1.2` files. If you want to use them, you need to set it wherever the variable `KDEBE_TLSV12_CIPHER_SPECS`is referanced in this document
    - `KDEBE_TLSVNN_CIPHER_SPECS="TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384"` 

    **Note:** If other cipher specs needs to be used, you **must** modify the `init_tlsv[n].[n]` file ( for example "init_tlsv1.2" ) and use them everywhere they are set in this document.
    The list above is a subset of the allowed ciphers which considered as save. A complete list of TLSv1.2 ciphers available in ITM is [here](https://github.ibm.com/NIEWOLIK/ITM-TLS1.n-implementation/blob/main/itm_allowed_TLSV1.2.cipherspecs.txt

3. Following new ports will be used and needs to be opened on the firewall **and** on the local firewall on the hosts where the Warehouse Proxy Agent and the Tivoli Enterprise Portal Server are running:
    - 15201 port to connect to the TEPS. 
    - 65100 port for the Warehouse proxy agent (WPA). **Note**: You must configure the WPA to bind to HTTP  (listening on port 63358) and HTTPS (listening on port 65100) before you configure all the agents to connect using HTTPS for TEMS connection. The WPA must be able to handle both HTTP and HTTPS connections during the time you update the ITM Agents to use HTTPS and TLSv1.2 only. This, because you cannot update all the agents at the same time and you will have a mix of Agents using HTTP (connect over 63358 to WPA) and HTTPS (connect over 65100 to WPA). 
    - If you did not use HTTPS so far and firewall is in use, port 3660 needs to be opened on the firewall between the Agents and the TEMS. 
    - Also, if you use a local firewalls (TEMS,TEPS, WPA hsots), you need to allow incomming traffic on port 3660, 15201 and 65100


1.2 General Approaches<a id='1.2'></a>
----------------------

**A.** If all your TEMS and Agents are **already using IP.SPIPE** you need:
  
  1. Leave the TEMS configuration as it is.
  2. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)
  3. Check if the Summarization and Pruning Agent is using HTTPS and port 15201 to connect to TEPS. If not, configure it accordignly.
  4. Configure all your Agents to use TLSV1.2 and the specific ciphers for the TEMS connenction (**how to**: see Agents section)
  

**B.** If all your TEMS and Agents **use only IP.PIPE** you need:

  1. Make sure that port 3660 is open on the firewall (Agent/TEPS - TEMS connection). If a local firewall is in use, also here allow incomming connection on 3660.
  2. First configure your TEMS and the WPA to use IP.SPIPE and IP.PIPE (**how to**: see TEMS and WPA section). By default TLSV1.x and all existing ciphers are allowed to be used.
  3. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)
  4. Configure the Summarization and Pruning Agent to use HTTPS and port 15201 to connect to TEPS.
  5. Configure all your Agents to use IP.SPIPE with  TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)

**C.**
If all your TEMS use **both IP.SPIPE and IP.PIPE** and **some Agents use IP.PIPE and others IP.SPIPE** you need:

  1. Leave the TEMS configuration as it is.
  2. Configure your TEPS to use IP.SPIPE with TLSV1.2 and the specific ciphers for the TEMS connection (**how to**: See TEPS section for further config TEPS actions related to TLSv1.2 only usage)
  3. Check if the Summarization and Pruning Agent is using HTTPS and port 15201 to connect to TEPS. If not, configure it accordignly.
  4. Configure all your Agents to use IP.SPIPE with TLSV1.2 and the specific ciphers only for the TEMS connenction (**how to**: see Agents section)

<BR> [\[goto top\]](#content)

2 TEMS
=======

To use TLSV1.n, all TEMS server (HUB and remote TEMS) **must** use IP.SPIPE (HTTPS) for communication.

**CONFIGURE IP.SPIPE on TEMS:**

To do so you need to reconfigure your **HUB and each RTEMS**:

  - Windows: Use MTEMS tool to configure and **add** IP.SPIPE protocol to your TEMS 
 <img src="https://media.github.ibm.com/user/85313/files/567d2e00-b415-11ec-9930-33bc3a4c462e" width="25%" height="25%">
 
  - Linux/AIX: Use `itmcmd config -S -t TEMS` tool to configure and **add** IP.SPIPE protocol to your TEMS 
  - Restart TEMS

Now you can configure TEPS and agents to connect to the TEMS using IP.SPIPE

**THEN:**

As soon **all ITM components are connected to TEMS using IP.SPIPE with TLSV1.n** and **the specific ciphers** you can disable IP.PIPE + TLS10 + TLS11+ ... on all TEMS.

WINDOWS (sample for TLSv1.2):

  1.  In: [ITMHOME]\CMS\KBBENV add or modify the following options <BR>
```
  KDEBE_TLS10_ON=NO
  KDEBE_TLS11_ON=NO
  KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]
```
  2. Reconfigure TEMS using MTEMS tool and disable IP.PIPE protocol
  <img src="https://media.github.ibm.com/user/85313/files/3d25b300-b410-11ec-8f0b-36670dee661b" width="25%" height="25%">
  
  3. Restart the TEMSs

LINUX/AIX (sample for TLSv1.2):

  1.  In `[ITMHOME]/table/[TEMSNAME]/config/ms.ini` add or modify the following options
```
  KDEBE_TLS10_ON=NO
  KDEBE_TLS11_ON=NO
  KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]
```
     
  2.  Reconfigure TEMS using `itmcmd config -S -t TEMS` disable IP.PIPE protocol
  3.  Restart the TEMSs

<BR> [\[goto top\]](#content)

3 TEPS 
======

The manual process described in the IBM Support document section: "_TLS v1.2 only configuration - TEP, IHS, TEPS, TEPS/eWAS components_"  (https://www.ibm.com/support/pages/tivoli-monitoring-v6307-tls-v12-only-configuration-tep-ihs-teps-teps-ewas-components-and-ewas-default-certificate-renewal), was automated. It contains the following files:

**For WINDOWS**

1. `activate_teps-tlsv.ps1`&nbsp;(main script)
2. `functions_sources.ps1`&nbsp;&nbsp;&nbsp;(functions used; sourced by activate_teps-tlsv.ps1) 
3. `init_global_vars.ps1`&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(global variables; sourced byfunctions_sources.ps1)
4. `init_tlsv1.2.ps1`&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(TLSv1.2 specific variables; **must** be sourced before starting activate_teps-tlsv.ps1 or sourcing functions_sources.ps1) 

**For Linux/Unix**
1. `activate_teps-tlsvn.sh`&nbsp;(main script)
2. `functions_sources.h`&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(functions used; sourced by activate_teps-tlsv.sh) 
3. `init_global_vars`&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(global variables; sourced by functions_sources.h)
4. `init_tlsv1.2`&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(TLSv1.2 specific variables; **must** be sourced before starting activate_teps-tlsv.sh or sourcing functions_sources.h) 

The files `init_tlsv1.2` (Linux) and `init_tlsv1.2.ps1` Windows contain the TLS version specifiyc setting you need to set before execution. For another TLS version copy this file and change values as required. This are the current settings for TLSv1.2:

    TLSVER="TLSv1.2" 
    KDEBE_TLSVNN_CIPHER_SPECS="TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384"
    KFW_ORB_ENABLED_PROTOCOLS="TLS_Version_1_2_Only" 
    KDEBE_TLS_DISABLE="TLS10,TLS11"
    HTTP_SSLCIPHERSPEC="ALL -SSL_RSA_WITH_3DES_EDE_CBC_SHA"
    JAVASEC_DISABLED_ALGORITHMS="SSLv3, TLSv1, TLSv1.1, RC4, DES, SHA1, DHE, MD5withRSA, DH keySize < 2048, DESede, \ EC keySize < 224, 3DES_EDE_CBC, anon, NULL, DES_CBC"

The Bash shell functions and files ware tested on RedHat linux only, but should run on other Linux Distributions and Unix systems as well.

3.1 Prerequisites<a id='3.1'></a>
-----------------

- Before starting the script, please verify that the TEPS is started and **connected to TEMS using IP.SPIPE**
- Assure that port 15201 is open on the Firewall and on the local firewall on the TEPS host (needed to connect using TEP client)
- Update the `wasadmin` password if **not** done so far
    - UNIX: <BR>`$CANDLEHOME/{archdir}/iw/scripts/updateTEPSEPass.sh wasadmin {newpass}` <BR> For example <BR> _/opt/IBM/ITM/lx8266/iw/scripts/ updateTEPSEPass.sh wasadmin mypass_
    - WINDOWS: <BR>`%CANDLE_HOME%\CNPSJ\scripts\updateTEPSEPass.bat wasadmin {newpass}` <BR> For example<BR>  _C:\IBM\ITM\CNPSJ\scripts\updateTEPSEPass.bat wasadmin mypass_ 
- PowerShell on Windows and Bash Shell on Linux must exists
- For TLSv1.2, if a WAS 855 uplift was not performed on the TEPS host as described in the update readme files, you must execute _Appendix B_ action as described in the PDF  document mentioned above. To check if a WAS uplift was made use ITMHOME/[arch]/iw/bin/versionInfo.sh or ITMHOME\CNPSJ\bin\versionInfo.bat. The version must be at least 8.5.5.16
- **If you use your own CA root and issuer certs** in `keyfiles/keyfile.kdb` and eWAS, you should execute the script with the option `-r no` to suppress the ITM default certification renewal. For example `./activate_teps-tlsv1.2.sh -h /opt/IBM/ITM -r no`. If you not set this option, the selfesigned **default** and the **root** cert will be deleted in the `keyfile.db` and imported from the newly created `key.p12` (from eWAS) file. This can break your certification chain. Hence, your own certificates will most likely be not present anymore in the newly created `keyfile.kdb`.
    
3.2 Download script files<a id='3.2'></a>
-------------------------

Download latest version and unzip/tar the downloaded archive to a temporary folder.

Use these links:
 
- For Windows: [ZIP format](https://github.com/ricniew/ITM-TLS1.n-implementation/archive/refs/tags/2.2.zip) 
- For Unix/linux: [TAR format](https://github.com/ricniew/ITM-TLS1.n-implementation/archive/refs/tags/2.2.tar.gz) 

Or Use "Download ZIP" to save asset to a temporary folder. Then unzip it.

https://github.ibm.com/NIEWOLIK/ITM-TLS1.n-implementation/archive/2.zip
<img src="https://media.github.ibm.com/user/85313/files/a8ede000-b0df-11ec-86d9-bf7e122e6f83" width="55%" height="55%">


3.3 Syntax<a id='3.3'></a>
-----------------

**Windows:**
    
`.\activate_teps-tlsv.ps1 { -h ITM home } { -r [no, yes] } [-b {no, yes[default]} ] `

`-h` = Mandatory. ITM home folder. 
<BR>
`-r` = Mandatory [yes, no]. If set to `no` the ITM default cert will NOT be renewed. 
<BR>
`-b` = Optional [yes, no]. If backup should be performed or not, default is 'yes'. **Optional. Please use that parameter carefully!!**
    
**Note**: If your ITMHOME folder name contains spaces, you must start it as: `.\activate_tls1.2.ps1  -h 'C:\Program Files (x86)\ibm\ITM'`

**Unix/Linux**

`./activate_teps-tlsv.sh { -h ITM home } { -r [no, yes] } [ -a arch ] [-b {no, yes[default]} ] `

`-h` = Mandatory. ITM home folder. 
<BR>
`-r` = Mandatory [yes, no]. If set to `no` the ITM default cert will NOT be renewed. 
<BR>
`-a` = Optional.. Arch folder name (e.g. lx8266). 
<BR>
`-b` = Optional [yes, no]. If backup should be performed or not, default is 'yes'. **Optional. Please use that parameter carefully!!**
    

3.4 Execution<a id='3.4'></a>
-----------------

You have two alternatives how to use the scripts. Either you use the script `activate_teps-tlsv` which does everything for you, or you use the functions one by one.
The prefered way would be to use the script. The second alternative is more usefull for testing and verification purposes.

3.4.1 Via script activate_teps-tlsv <a id='3.4.1'></a>
-----------------------------------
&nbsp;&nbsp;&nbsp;**On Windows**:

  - Open a PowerShell cmd prompt and go to the temp directory where you have donloaded the script: `cd c:\temp\ITM-TLS1.n-implementation-[tag]\windows`
  - **Source** the TLS Version specific variables file. For example: `. .\init_tlsv1.2.ps1`. For another TLS version copy this file and change values as required.
  - Execute `.\activate_teps-tlsv.ps1` 

&nbsp;&nbsp;&nbsp;Samples: 

 `> cd c:\temp\ITM-TLS1.n-implementation-2.2\windows` <BR>
    
       > . .\init_tlsv1.2.ps1 ; .\activate_teps-tlsv.ps1 -h C:\IBM\ITM -r yes                 # Backup is performed. Default keystore is renewed"
       > . .\init_tlsv1.2.ps1 ; .\activate_teps-tlsv.ps1 -h "C:\Program Files\IBM\ITM" -r yes # Backup is performed. Default keystore is renewed"
       > . .\init_tlsv1.2.ps1 ; .\activate_teps-tlsv.ps1 -h C:\IBM\ITM -b yes -r no           # Backup is performed, default keystore is not renewed"
       > . .\init_tlsv1.2.ps1 ; .\activate_teps-tlsv.ps1 -h C:\IBM\ITM -b no -r no            # NO backup is performed and default keystore is not renewed"

&nbsp;&nbsp;&nbsp;**On UNIX/Linux**:

   - Open shell prompt and go to the temp directory where you have donloaded the script: `cd /tmp/ITM-TLS1.n-implementation-[tag]/unix`
   - **Source** the TLS Version specific variables file. For example: `. ./init_tlsv1.2`
   - Execute´./activate_teps-tlsv.sh` 

&nbsp;&nbsp;&nbsp;Samples: 

`> cd /tmp/ITM-TLS1.n-implementation-2.2/unix`

    > . ./init_tlsv1.2 ; ./activate_teps-tlsv.sh -h /opt/IBM/ITM -r yes                 # A backup is performed and default keystore is renewed"
    > . ./init_tlsv1.2 ; ./activate_teps-tlsv.sh -h /opt/IBM/ITM -b no -r yes -a lx8266 # NO backup is performed, default keystore is renewed, arch folder is lx8266"
    > . ./init_tlsv1.2 ; ./activate_teps-tlsv.sh -h /opt/IBM/ITM -b no -r no            # NO backup is performed and default keystore is not renewed"

<BR>

3.4.2 Step by step using functions <a id='3.4.2'></a>
-----------------------------------

Alternatively, you can execute each function from the command prompt. It is more usefull for testing and verification purposes. But before starting to modify files or options you must:

- **Perform a backup of all files and settings you want to modify**. Otherwise you cannot go back in case of failures.
- Execute `. .\init_tlsv1.2.ps1` for Windows or `. ./init_tlsv1.2` for Unix/Linux to initialize TLS version specific variables. For another TLS version copy this file and change values as required.

Open a Linux terminal or Powershell command prompt and execute each function manually to modify the required option or files. <BR>
Below the recommended sequence (example for TLSv1.2 changes on Linux; but it applies to Windows as well, you only need to adjust the syntax):

    # cd /tmp/ITM-TLS1.n-implementation-2/unix
    # . ./init_tlsv1.2 ; . ./functions_sources.h /opt/IBM/ITM
    # checkIfFileExists
    # EnableICSLite "true"
    # renewCert
    # restartTEPS ; EnableICSLite "true" # if required
    # modQop
    # disableAlgorithms
    # modsslclientprops "${AFILES["ssl.client.props"]}" 
    # modcqini "${AFILES["cq.ini"]}"
    # modhttpconf "${AFILES["httpd.conf"]}"
    # restartTEPS ; EnableICSLite "true" # if required
    # modjavasecurity "${AFILES["java.security"]}"
    # importSelfSignedToJREcacerts "${AFILES["cacerts"]}"
    # modtepjnlpt "${AFILES["tep.jnlpt"]}"
    # modcompjnlpt "${AFILES["component.jnlpt"]}"
    # modapplethtmlupdateparams "${AFILES["applet.html.updateparams"]}"
    # ${ITMHOME}/bin/itmcmd config -A cw

As you can see  `modtepjnlpt "${AFILES["tep.jnlpt"]}"` (on windows the option would be `$HFILES["tep.jnlpt"]`), an array/hash element containing the file path is passed to some functions. The FILES variable is declared by file `init_global_vars` ( or `init_global_vars.ps1` on Windows) which is sourced by the `functions_sources.h` (or `functions_sources.ps1` on Windows).

However, you can choose another sequence, but make sure you know when a TEPS restart is required.

Sample execution for `tep.jnlpt` modification when file was modified already:

    PS C:\IBM\script> modtepjnlpt $HFILES["tep.jnlpt"]
    INFO - modtepjnlpt - C:\IBM\ITM\Config\tep.jnlpt contains 'jnlp.tep.sslcontext.protocol value="TLSv1.2"' and will not be modified
    4
    
    PS C:\IBM\script



3.5 Verifications<a id='3.5'></a>
-----------------

**Test TEP login:**

- Access <BR>`https://[yourhost]:15201/tep.jnlp` <BR> to test Webstart client (you may need to delete the Java cache)

**Test TEP Desktop Client login (only IF USED)**

On Windows:

Use the MTEMS tool (Management Tivoli Enterprise Monitoring Services) to reconfigure the "Tivoli Enterpise Desktop Client" to pick the changes. Following parameters needs to be edited and the 'In Use' check box must be set: 

    tep.connection.protocol value: https 
    tep.connection.protocol.url.port value: 15201  
    tep.sslcontext.protocol value: TLSv1.2

As documented in the support link referenced above, when all the parameters have been edited, click OK to save your changes. The changes will take effect the next time the TEP Desktop client is launched.

On Linux/Unix

Export your DISPLAY Variable and then execute: `itmcmd agent start cj` or `itmcmd agent -o [your instance] start cj`

NOTE: the changes made by the script are global. If your have defined TEPD instances to connect to another TEPS running on a remote host, and this TEPS is not TLSV1.n enabled, you must modify the `ITMHOME/lx8266/cj/bin/cnp_[instance].sh`. Locate the code and replace  with: 

    61: # Check if TEP_JAVA_HOME defined; if not, set to same value as JAVA_HOME
    62: if [ ! ${TEP_JAVA_HOME} ]; then
    63:     export TEP_JAVA_HOME=${JAVA_HOME}
    64: fi
    65: IBM_JVM_ARGS="-Xgcpolicy:gencon -Xquickstart"

**Test HTTPS tacmd tepslogin**

- Command <BR>`tacmd tepslogin -s https://[yourhost]:15201 -u [yuor user] - p [your password]`

**To verify certs usage for ports 15206 (eWas Console) or 15201 (TEPS HTTPS). Sample outputs for port 15206:**

- Command <BR>`$> openssl s_client -crlf -connect localhost:15206  -servername localhost -tls1_2 < /dev/null | egrep "Secure Renegotiation|Server public key | SSL handshake"`. <BR>Output:
    ```
    depth=1 C = US, O = IBM, OU = ITMNode, OU = ITMCell, OU = Root Certificate, CN = falcate1
    verify error:num=19:self signed certificate in certificate chain
    DONE
    Server public key is 2048 bit
    Secure Renegotiation IS supported
    ```
- Command <BR>`$> openssl s_client  -connect localhost:15206 2>/dev/null |  openssl x509 -noout -dates`. <BR>Output:
    ```
    notBefore=Mar 31 15:22:36 2022 GMT
    notAfter=Mar 31 15:22:36 2023 GMT
    ```
- Commnad <BR>`$> openssl s_client  -connect localhost:15206 2>/dev/null |  openssl x509 -noout -issuer -nameopt multiline`. <BR>Output:
    ```issuer=
        countryName               = US
        organizationName          = IBM
        organizationalUnitName    = ITMNode
        organizationalUnitName    = ITMCell
        organizationalUnitName    = Root Certificate
        commonName                = falcate1
    ```

<BR> [\[goto top\]](#content)
  
4 Summarization and Pruning Agent
=================================

Configure and check if the S&P Agent is connecting through HTTPS and port 15201 to the TEPS. <BR>
You  **must**  perform this step just after you have configured the TEPS to use HTTPS only, otherwise your Warehouse Database will not be summarized and pruned:

<img src="https://media.github.ibm.com/user/85313/files/dc6d4d00-c640-11ec-9f31-40b1c555503f" width="40%" height="40%">

Also do not forget to set Cipher variables as shown in the Agent section.

<BR> [\[goto top\]](#content)

5 Warehouse Proxy Agent
=======================

Assure WPA port 65100 is open on the firewall (general and local). 

**Note**: 
1. You must configure the WPA to bind to HTTP (listening on port 63358) and HTTPS (listening on port 65100) **before** you configure all the agents to connect using HTTPS for TEMS connection. The WPA must be able to handle both HTTP and HTTPS connections during the time you update the ITM Agents to use HTTPS and specifiy TLSv1.2 ciphers only. This, because you cannot update all the agents at the same time and you will have a mix of Agents using HTTP (connect over 63358 to WPA) and HTTPS (connect over 65100 to WPA).
2. At the WPA, the ciphers to use TLSv1.2 only **must** be set **after** all the agents are configured to use HTTPS + specic ciphers. This for the same reason as in item 1. The cipher variables can be set the same way as for the other agents.

<BR> [\[goto top\]](#content)
    
6 Agents
========

6.1 Alternative A<a id='6.1'></a>
-----------------

**Samples are for TLSv1.2**

Use ITM `tacmd setagentconnection` command.

If you use failover RTEMS and IP.PIPE was used: <BR>
- `tacmd setagentconnection -n falcate1:LZ -a -p SERVER=[your primary rtems] PROTOCOL1=IP.SPIPE IP_SPIPE_PORT=3660 BACKUP=Y BSERVER=[your secodary rtems] BPROTOCOL1=IP.SPIPE BIP_SPIPE_PORT=3660` <BR>([ITMHOME]/config/.ConfigDate/[pc]env file is modified, agents are reconfigured and restartet)
- `tacmd setagentconnection -n falcate1:LZ -a -e  KDEBE_TLS10_ON=NO KDEBE_TLS11_ON=NO KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]` <BR>([ITMHOME]/config/[pc].environment file is created with the KDEBE settings for each agent running on the system, agents are restarted)

If you don't use failover RTEMS (agent connects to one TEMS only) and IP.PIPE was used: <BR>
- `tacmd setagentconnection -n falcate1:LZ -a -p SERVER=[your primary tems] PROTOCOL=IP.SPIPE IP_SPIPE_PORT=3660` <BR>([ITMHOME]/config/.ConfigDate/[pc]env file is modified, agents are reconfigured and restartet)
- `tacmd setagentconnection -n falcate1:LZ -a -e KDEBE_TLS10_ON=NO KDEBE_TLS11_ON=NO KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]` <BR>([ITMHOME]/config/[pc].environment file is created with the KDEBE settings for each agent running on the system, agents are restarted)
 
If IP.SPIPE was already used: <BR>
- `tacmd setagentconnection -n falcate1:LZ -a -e KDEBE_TLS10_ON=NO KDEBE_TLS11_ON=NO KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]` <BR>([ITMHOME]/config/[pc].environment file is created with the KDEBE settings for each agent running on the system, agents are restarted)


**Important Notes:** 
- **(1)**: You can **only** use the `tacmd` when the OS Agent is running. 
- **(2)**: On windows the `tacmd setagentconnection` commands are **only** working when the agent is running with **administration** rigths.
- **(3)**: On Windows instead of using option `-a` in  `tacmdsetagentconnection` is not supproted on hosts where ITM TEMSs running (Technote: https://www.ibm.com/support/pages/node/6587038). You need to use the `-t ` to modify the agents (e.c. "-t nt "). For example: `tacmd setagentconnection -n Primary:myhost:NT -t nt -p SERVER=[your primary tems] PROTOCOL=IP.SPIPE IP_PIPE_PORT=3660`
- **(4)**: On Windows the option `-e` of `tacmdsetagentconnection` command with multiple variable settings is not supported in versions <= ITM 6.3 FP7 SP6. You would need to execute one comamnd for each KDEBE variable. For example <BR> `tacmd setagentconnection -n Primary:myhost:NT -t nt -e KDEBE_TLS10_ON=NO` <BR> `tacmd setagentconnection -n Primary:myhost:NT -t nt -e KDEBE_TLS11_ON=NO` <BR> `tacmd setagentconnection -n Primary:myhost:NT -t sy -e KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]`

- **(5)**: On Windows, the `-e` option creates a `[Overwrite local settings]` section in the `ITMHOME\TMAITM6_64\k[pc]cma.ini` file with the new variable settings. Then the agent is reconfigured and a registry entry is added to `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment` for the specified variable (for example KDEBE_TLSV12_CIPHER_SPECS). This means that in the future, any manual change to the registry key of this variable will be overwritten by the override section, regardless of what you have specified.

- **(6)**:On Linux/Unix, the `-e` option creates an `ITMHOME/config/[pc].environment` file with the new variable settings. Then the agent will be reconfigured and restarted. This means that in the future, if you configure the agent for the same values but set them in the [pc].ini file, they will be overwritten by the `[pc].environment` settings.
- **(7)**: On Windows, the `-p SERVER=[your primary rtems] PROTOCOL=IP.SPIPE ...` option overrides the CT_CMSLIST and KDC_FAMILIES registry keys. If you have ever used the `Override Local Settings` section of the `ITMHOME\TMAITM6_64\k[pc]cma.ini` file to set the same variables, the `tacmd` command will not change anything because the new settings will be overwritten by the `Override Local Settings` section.
- **(8)**: On Linux the option `-p SERVER=[your primary rtems] PROTOCOL=IP.SPIPE ...` is configuring and overiding the TEMS and KDC_FAMILIES values in `ITMHOME/config/.ConfigData/[pc]env` file. Hence if you ever used the `ITMHOME/config/[pc].environment` to set same varaibles, the `tacmd` command will not change anything, because they will be overwritten by the `[pc].environment` file settings.

6.2 Alternative B<a id='6.2'></a>
-----------------

**Samples are for TLSv1.2**

Reconfigure Agents using local ITM silent configuration.

ON WINDOWS:
1. Modifiy the correspondig **ITMHOME\TMAITM6_64\k[pc]cma.ini** file. If the `[Override Local Settings]` doesn't exists, create one at the end of the **_k[pc]cma.ini_** file. For example `kntcma.ini`. Add or modify the following settings.

    If you use failover RTEMS:
    ```
    [Override Local Settings]
    CTIRA_HIST_DIR=@LogPath@\History\@CanProd@
    KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]
    KDEBE_TLS11_ON=NO
    KDEBE_TLS10_ON=NO
    CT_CMSLIST=IP.SPIPE:[your primary rtems];IP.SPIPE:[your secondary rtems]
    KDC_FAMILIES=IP.SPIPE PORT:3660 IP use:n SNA use:n IP.PIPE use:n IP6 use:n IP6.PIPE use:n IP6.SPIPE use:n
    ```
    If you NOT use failover RTEMS:
    ```
    [Override Local Settings]
    CTIRA_HIST_DIR=@LogPath@\History\@CanProd@
    KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]
    KDEBE_TLS11_ON=NO
    KDEBE_TLS10_ON=NO
    CT_CMSLIST=IP.SPIPE:[your primary tems]
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
    HOSTNAME=[your primary rtems]
    MIRROR=[your secondary rtems]
    CUSTOM#KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]
    CUSTOM#KDEBE_TLS10_ON=NO
    CUSTOM#KDEBE_TLS11_ON=NO
    ```

    If you NOT use failover RTEMS:
    ```
    CMSCONNECT=YES
    NETWORKPROTOCOL=ip.spipe
    IPSPIPEPORTNUMBER=3660
    HOSTNAME=[your primary tems]
    CUSTOM#KDEBE_TLSV12_CIPHER_SPECS=[your cipher settings]
    CUSTOM#KDEBE_TLS10_ON=NO
    CUSTOM#KDEBE_TLS11_ON=NO
    ```

2. Execute `ITMHOME/bin/itmcmd config -A -p [respfile] [pc]`. For examle `itmcmd config -A -p resposefile.txt lz`. For instance agent use `itmcmd config -A -p [respfile] -o [instance] [pc]`
3. Restart the agent using `ITMHOME/bin/itmcmd agent stop/start [pc]`, for example `itmcmd agent stop lz ; itmcmd agent start lz`. For instance agents use `itmcmd agent -p [instance] -f stop [pc] ; itmcmd agent -p [instance] -f start [pc]`

**Important notes:**
- Before a mass rollout, you must successfully test it for each agent type you want to modify
- When executing config as shown above `ITMHOME/config/.ConfigData/[pc]env` file is updated and `ITMHOME/config/[pc].environment` updated or created if not existing before.

6.3 Other Alternatives<a id='6.3'></a>
-----------------

**Samples are for TLSv1.2**

You can perform local config steps or modify/create the correspondig config files by using remote commands. For examle tacmd executecommnad, getfile, putfile or use your own distribution tools.

On Windows you may try to edit or add configuration settings directly in the registry  `HKEY_LOCAL_MACHINE\SOFTWARE\Candle\K[pc]\Ver610\Primary\Environment`:

<img src="https://media.github.ibm.com/user/85313/files/b72bde00-b9b4-11ec-98cb-f210ff3d4edb" width="55%" height="55%">

Please always check if the registry settings are taken over by the agents after restart. Also, always check that the `ITMHOME\TMAITM6_64\k[pc]cma.ini` file does not contain an `[Override Local Settings]` section with the same variable names as that one you manually set in the registry. The `[Override Local Settings]` section overrides your manual registry changes the next time an agent is reconfigured by the MTEMS tools.  

On Linux/Unix you could add the required variables directly into the ITMHOME/config/[pc].ini file. That way you do not need the [pc].environemnt file. But this is not working for instance agents, here the instance config file `[pc]_[inst].config` must be modified.

<BR> [\[goto top\]](#content)


7 Troubleshooting
=================

Content from PDF file: https://www.ibm.com/support/pages/tivoli-monitoring-v6307-tls-v12-only-configuration-tep-ihs-teps-teps-ewas-components-and-ewas-default-certificate-renewal

Traces for IHS and the TEPS/eWAS
--------------------------------

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

Unable to login to Tivoli Enterprise Portal (TEP Webstart)
---------------------------------------------------------

Please read the technote
https://www.ibm.com/support/pages/unable-login-tivoli-enterprise-portal-tep-webstart-client


List cert files
---------------

WINDOWS: open DOS prompt

    set CANDLE_HOME=c:\IBM\ITM
    for /f "tokens=*" %i in ('%ITMHOME%\InstallITM\GetJavaHome.bat') do set JAVA_HOME=%i
    set KEYTOOL=%JAVA_HOME%\bin\keytool.exe
    set KEYFILE=%CANDLE_HOME%\keyfiles\keyfile.kdb
    set SIGNP12=%CANDLE_HOME%\keyfiles\signers.p12
    set CACERTS=%JAVA_HOME%\lib\security\cacerts

    GSKitcmd gsk8capicmd -cert -list -stashed -db %KEYFILE% -label "IBM_Tivoli_Monitoring_Certificate"
    GSKitcmd gsk8capicmd -cert -list -stashed -db %KEYFILE%
    GSKitcmd gsk8capicmd -cert -list  -db %SIGNP12% -pw  changeit # if created in case of self signed certs used

    %KEYTOOL%  -list -v -keystore  %CACERTS% -storepass changeit | findstr /I "ibm"
    %KEYTOOL%  -list -v -keystore  %CACERTS% -storepass changeit | findstr /I /R "\Alias name \Issuer \Owner"

UNIX: open terminal

    export CH=/opt/IBM/ITM
    grep GskitInstallDir_64 $CH/config/gsKit.config
    GSKITDIR=$(grep GskitInstallDir_64 $CH/config/gsKit.config | cut -d= -f2)
    if [ -z "$GSKITDIR" ] ; then       GSKITDIR=$(grep GskitInstallDir $CH/config/gsKit.config | cut -d= -f2);   fi
    GSKIT_LIB=$(ls -d $GSKITDIR/lib*)
    GSKIT_BIN=$(ls -d $GSKITDIR/bin)
    export PATH=$GSKIT_BIN:/usr/bin:$CH/bin:$PATH
    export LD_LIBRARY_PATH_64=$GSKIT_LIB:$LD_LIBRARY_PATH_64
    export LD_LIBRARY_PATH=$GSKIT_LIB:$LD_LIBRARY_PATH
    export GSKCAPI=$(basename $(ls -d $GSKIT_BIN/gsk*capicmd*))
    export KEYTOOL=$CH/JRE/lx8266/bin/keytool
    export KEYFILE=$CH/keyfiles/keyfile.kdb
    export CACERTS=$CH/JRE/lx8266/lib/security/cacerts
    export SIGNP12=$CH/keyfiles/signers.p12 # if created in case of self signed certs used

    $GSKCAPI -cert -list -stashed -db $KEYFILE
    $GSKCAPI -cert -details -stashed -db $KEYFILE -label root
    $GSKCAPI -cert -list  -db $SIGNP12 -pw  changeit

    $KEYTOOL -list -v -keystore ${CACERTS}  -storepass changeit| egrep "Alias name:|Owner:|Issuer:"
    $KEYTOOL -list -v -keystore ${CACERTS}  -storepass changeit|grep -i "IBM"

<BR> [\[goto top\]](#content)

8 Appendixes
============

Sample run of the activate_teps-tlsv1.2.sh script on Linux:
```
[root@falcate1 scripts]# clear; ./activate_teps-tlsv.sh -h /opt/IBM/ITM -r yes -b yes
INFO - Script Version 2.2
INFO - check_param - Option '-r' = 'yes'
INFO - check_param - Option '-b' = 'yes'
INFO - check_param - Option '-h' = '/opt/IBM/ITM'
INFO - check_param - Option '-a' for ITM arch folder name was not set. Trying to evaluate ...
INFO -------------------------------- Globale variables: ------------------------------------
INFO - ITMHOME=/opt/IBM/ITM
INFO - ARCH=lx8266
INFO - TEPSHTTPSPORT=15201
INFO - BACKUPFOLDER=/opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - RESTORESCRIPT=SCRIPTrestore.sh
INFO - WSADMIN=/opt/IBM/ITM/lx8266/iw/bin/wsadmin.sh
INFO - GSKCAPI=gsk8capicmd_64
INFO - KEYTOOL=/opt/IBM/ITM/JRE/lx8266/bin/keytool
INFO - JAVAHOME=/opt/IBM/ITM/JRE/lx8266
INFO - KEYKDB=/opt/IBM/ITM/keyfiles/keyfile.kdb
INFO - KEYP12=/opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12
INFO - TRUSTP12=/opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12
INFO - SIGNERSP12=/opt/IBM/ITM/keyfiles/signers.p12
INFO - AFILES=
INFO -   tep.jnlpt                 = /opt/IBM/ITM/config/tep.jnlpt
INFO -   cq.ini                    = /opt/IBM/ITM/config/cq.ini
INFO -   cacerts                   = /opt/IBM/ITM/JRE/lx8266/lib/security/cacerts
INFO -   component.jnlpt           = /opt/IBM/ITM/config/component.jnlpt
INFO -   ssl.client.props          = /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props
INFO -   trust.p12                 = /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12
INFO -   key.p12                   = /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12
INFO -   java.security             = /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security
INFO -   applet.html.updateparams  = /opt/IBM/ITM/lx8266/cw/applet.html.updateparams
INFO -   httpd.conf                = /opt/IBM/ITM/lx8266/iu/ihs/HTTPServer/conf/httpd.conf
INFO -   cj.environment            = /opt/IBM/ITM/config/cj.environment
INFO -------------------------------------------
INFO - main - Modifications for TLSVER=TLSv1.2 -
INFO -------------------------------------------
INFO - main - TEPS = 06300711 eWAS = 08551600
INFO - main - Backup directory is: /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - checkIfFileExists - Directory /opt/IBM/ITM/lx8266/iw  OK.
INFO - checkIfFileExists - Directory /opt/IBM/ITM/keyfiles  OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/config/tep.jnlpt OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/config/cq.ini OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/JRE/lx8266/lib/security/cacerts OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/config/component.jnlpt OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12 OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12 OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/lx8266/cw/applet.html.updateparams OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/lx8266/iu/ihs/HTTPServer/conf/httpd.conf OK.
INFO - checkIfFileExists - File /opt/IBM/ITM/config/cj.environment OK.
INFO - EnableICSLite - Set ISCLite to 'true'
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
WASX7303I: The following options are passed to the scripting environment and are available as arguments that are stored in the argv variable: "[true]"
ISClite is not running
ISClite started

INFO - backup - Saving Directory /opt/IBM/ITM/lx8266/iw in /opt/IBM/ITM/backup/backup_before_TLSv1.2. This can take a while...
INFO - backup - Saving /opt/IBM/ITM/keyfiles/ in /opt/IBM/ITM/backup/backup_before_TLSv1.2...
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iu/ihs/HTTPServer/conf/httpd.conf in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/config/cq.ini in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/config/tep.jnlpt in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/config/component.jnlpt in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/cw/applet.html.updateparams in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/config/cj.environment in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/trust.p12 in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/config/cells/ITMCell/nodes/ITMNode/key.p12 in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - backupfile - Saving /opt/IBM/ITM/JRE/lx8266/lib/security/cacerts in /opt/IBM/ITM/backup/backup_before_TLSv1.2
INFO - createRestoreScript - Restore script created: /opt/IBM/ITM/backup/backup_before_TLSv1.2/SCRIPTrestore.sh
INFO - renewCert - Renewing default certificate
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
TEPSEWASBundle loaded.
'\nCWPKI0704I: The personal certificate with the default alias in the NodeDefaultKeyStore keystore has been RENEWED.'
''
INFO - renewCert - Running gsk8capicmd_64 commands
INFO - renewCert - Successfully renewed Certificate (previous renew was 121 days ago)
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
..............
INFO - restartTEPS - TEPS restarted successfully.
INFO - EnableICSLite - Set ISCLite to 'true'
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
WASX7303I: The following options are passed to the scripting environment and are available as arguments that are stored in the argv variable: "[true]"
ISClite is not running
ISClite started

INFO - modQop - Quality of Protection (QoP) not set yet. Modifying...
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
TEPSEWASBundle loaded.
''
''
INFO - modQop - Successfully set TLSv1.2 for Quality of Protection (QoP)
INFO - disableAlgorithms - Modifying com.ibm.websphere.tls.disabledAlgorithms
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
INFO - disableAlgorithms - Successfully set com.ibm.websphere.tls.disabledAlgorithms to none
INFO - modsslclientprops - Modifying /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props
INFO - modsslclientprops - /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props.TLSv1.2 created and copied on /opt/IBM/ITM/lx8266/iw/profiles/ITMProfile/properties/ssl.client.props
INFO - modcqini - Modifying /opt/IBM/ITM/config/cq.ini
INFO - modcqini - /opt/IBM/ITM/config/cq.ini.TLSv1.2 created and copied on /opt/IBM/ITM/config/cq.ini
INFO - modhttpconf - Modifying /opt/IBM/ITM/lx8266/iu/ihs/HTTPServer/conf/httpd.conf
INFO - modhttpconf - /opt/IBM/ITM/lx8266/iu/ihs/HTTPServer/conf/httpd.conf.TLSv1.2 created and copied on /opt/IBM/ITM/lx8266/iu/ihs/HTTPServer/conf/httpd.conf
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
..............
INFO - restartTEPS - TEPS restarted successfully.
INFO - EnableICSLite - Set ISCLite to 'true'
WASX7209I: Connected to process "ITMServer" on node ITMNode using SOAP connector;  The type of process is: UnManagedProcess
WASX7303I: The following options are passed to the scripting environment and are available as arguments that are stored in the argv variable: "[true]"
ISClite is not running
ISClite started

INFO - modjavasecurity - Modifying /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security
INFO - modjavasecurity - /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security.TLSv1.2 created and copied on /opt/IBM/ITM/lx8266/iw/java/jre/lib/security/java.security
INFO - importSelfSignedToJREcacerts - Modifying /opt/IBM/ITM/JRE/lx8266/lib/security/cacerts
Entry for alias ibm_tivoli_monitoring_certificate successfully imported.
Import command completed:  1 entries successfully imported, 0 entries failed or cancelled
INFO - importSelfSignedToJREcacerts - Imported self signed certs into JRE cacerts
INFO - modtepjnlpt - Modifying /opt/IBM/ITM/config/tep.jnlpt
INFO - modtepjnlpt - /opt/IBM/ITM/config/tep.jnlpt.TLSv1.2 created and copied on /opt/IBM/ITM/config/tep.jnlpt
INFO - modcompjnlpt - Modifying /opt/IBM/ITM/config/component.jnlpt
INFO - modcompjnlpt - /opt/IBM/ITM/config/component.jnlpt.TLSv1.2 created and copied on /opt/IBM/ITM/config/component.jnlpt
INFO - modapplethtmlupdateparams - Modifying /opt/IBM/ITM/lx8266/cw/applet.html.updateparams
INFO - modapplethtmlupdateparams - /opt/IBM/ITM/lx8266/cw/applet.html.updateparams.TLSv1.2 created and copied on /opt/IBM/ITM/lx8266/cw/applet.html.updateparams
INFO - main - Reconfiguring TEP WebSstart/Browser client 'cw'
Agent configuration started...
Agent configuration completed...
INFO - modcjenvironment - Modifying /opt/IBM/ITM/config/cj.environment
INFO - modcjenvironment - /opt/IBM/ITM/config/cj.environment.TLSv1.2 created and copied on /opt/IBM/ITM/config/cj.environment
INFO - main - Reconfiguring TEP Desktop Client 'cj'
+------------------------REMINDER-------------------------+
| KCIIN0219W This Agent was previously configured using   |
| the 'Host Specific Configuration' option (the '-t'      |
| option on the command line). To reconfigure, remember   |
| to select 'CREATE HOST SPECIFIC CONFIGURATION' (on the  |
| GUI) or use the command line '-t' option.               |
+---------------------------------------------------------+
Agent configuration started...
Agent configuration completed...

------------------------------------------------------------------------------------------
INFO - main - Procedure successfully finished Elapsedtime: 6 min
 - Original files saved in folder /opt/IBM/ITM/backup/backup_before_TLSv1.2
 - To restore the level before update run '/opt/IBM/ITM/backup/backup_before_TLSv1.2/SCRIPTrestore.sh'
----- POST script execution steps ---
 - Reconfigure TEPS and verify connections for TEP, TEPS, HUB
 - To check eWAS settings use: https://falcate1.fyre.ibm.com:15206/ibm/console
 - To check TEP WebStart  use: https://falcate1.fyre.ibm.com:15201/tep.jnlp
------------------------------------------------------------------------------------------
[root@falcate1 scripts]#


```
<BR> [\[goto top\]](#content)
