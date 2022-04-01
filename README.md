# ITM-TLS1.2-implementation

Author: Richard Niewolik

Contact: niewolik@de.ibm.com

Revision: 1.0

#

[1 General](#1-general)

[2 Tivoli Enterprise Portal Server](#2-teps)

[3 Tivoli Enterprise Management Server](#3-tems)

[4 Tivoli Enterprise Management Agent](#4-agents)

[5 Appendixes](#5-appendixes)



#

1 General
=========

A step by step description was provided by IBM Support: https://www.ibm.com/support/pages/sites/default/files/inline-files/$FILE/ITMTEPSeWASTLSv12_ref_2_1.pdf. 
This Github entry provides automation scripts for the TEPS related configuration changes and some additional information.

.... in construction

2 TEPS
==============

The manual process described in the "_TLS v1.2 only configuration - TEP, IHS, TEPS, TEPS/eWAS components_" section of ITMTEPSeWASTLSv12_ref_2_1.pdf documented, was automated and two scripts have been created, one PowerShell script for Windows and a Bash shell script for Linux:
1 _activate_teps-tlsv1.2.ps1_
1 _activate_teps-tlsv1.2.sh_
The Bash shell script was tested on RedHat linux only, but should run on other Linux distribution and Unix as well-

**Prereqs:**

- Before staring the script, please verify that the TEPS is started and **connected to TEMS using IP.SPIPE**
- Update the `wasadmin` password if **not** done so far
    - **Unix**: `$CANDLEHOME/{archdir}/iw/scripts/updateTEPSEPass.sh wasadmin {yourpass}` (e.g. _/opt/IBM/ITM/lx8266/iw/scripts/ updateTEPSEPass.sh wasadmin itmuser_ )
    - **Windows**: `%CANDLE_HOME%\CNPSJ\scripts\updateTEPSEPass.bat wasadmin {yourpass}` (e.g. _c:\IBM\ITM\CNPSJ\scripts\updateTEPSEPass.bat wasadmin itmuser_ 
- PowerShell on Windows and Bash Shell on Linux must exists

**Download the scripts:**

Use "Download ZIP" to save scripts to a temp folder. Then unzip it.

<img src="https://media.github.ibm.com/user/85313/files/a8ede000-b0df-11ec-86d9-bf7e122e6f83" width="60%" height="60%">

**Execution:**

Both scripts are looking for the ITMHOME folder variables (%CANDLE_HOME on Windows and $CANDLEHOME on Linux). If not existing you need to use the `-h [ITMHOME]` option. The Shell script tries also to find the required "arch" folder (e.g. lx8266) but you can use the `a [ arch ]` to provide the directory name.

Windows: 
- Open PowerShell cmd prompt and go to the temp directory
- launch script via `.\activate_teps-tlsv1.2.ps1 [-h ITMHOME ]`

After script finished reconfigure TEPS, CNP (TEP Destopt CLient) and CNB (TEP Browser/WebStart CLient) component using MTEMS

Unix/Linux
- Open shell prompt and go to the temp directory
- launch script via `./activate_teps-tlsv1.2.sh [-h ITMHOME] -a [ arch ]`

.... in construction

3 TEMS
==============

.... in construction


4 Agents
==============

.... in construction

5 Appendixes
============

.... in construction


