# ITM-TLS1.2-implementation

**Prereqs:**

- Before staring the script, please verify that the TEPS is started and **connected to TEMS using IP.SPIPE**
- Update the `wasadmin` password if **not** done so far
    - **Unix**: `$CANDLEHOME/{archdir}/iw/scripts/updateTEPSEPass.sh wasadmin {yourpass}` (e.g. _/opt/IBM/ITM/lx8266/iw/scripts/ updateTEPSEPass.sh wasadmin itmuser_ )
    - **Windows**: `%CANDLE_HOME%\CNPSJ\scripts\updateTEPSEPass.bat wasadmin {yourpass}` (e.g. _c:\IBM\ITM\CNPSJ\scripts\updateTEPSEPass.bat wasadmin itmuser_ )

**Download the scripts:**

Use "Download ZIP" to save scripts to a temp folder. Then unzip it.

<img src="https://media.github.ibm.com/user/85313/files/a8ede000-b0df-11ec-86d9-bf7e122e6f83" width="60%" height="60%">

**Execution:**

Windows: 
- Open PowerShell cmd prompt and go to the temp directory
- launch script via `.\activate_teps-tlsv1.2.ps1`

After script finished reconfigure TEPS, CNP (TEP Destopt CLient) and CNB (TEP Browser/WebStart CLient) component using MTEMS

Unix/Linux
- Open shell prompt and go to the temp directory
- launch script via `./activate_teps-tlsv1.2.sh`
