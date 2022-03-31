# ITM-TLS1.2-implementation

**Prereqs:**
- Before staring the script, please verify that the TEPS is started and **connected to TEMS using IP.SPIPE**
- Update the `wasadmin` password if **not** done so far
    - **Unix**: `$CANDLEHOME/{archdir}/iw/scripts/updateTEPSEPass.sh wasadmin itmuser` (e.g. _/opt/IBM/ITM/lx8266/iw/scripts/ updateTEPSEPass.sh wasadmin itmuser_ )
    - **Windows**: `%CANDLE_HOME%\CNPSJ\scripts\updateTEPSEPass.bat wasadmin itmuser` (e.g. _c:\IBM\ITM\CNPSJ\scripts\updateTEPSEPass.bat wasadmin itmuser_ )

Windows: 
- Download the `activate_teps-tlsv1.2.ps1` script to a temp folder
- Open PowerShell cmd prompt and go to the temp directory
- launch script via `.\activate_teps-tlsv1.2.ps1`

After script finished reconfigure TEPS, CNP (TEP Destopt CLient) and CNB (TEP Browser/WebStart CLient) component using MTEMS

Unix/Linux
Windows: 
- Download the `activate_teps-tlsv1.2.sh` script to a temp folder
- Open PowerShell cmd prompt and go to the temp directory
- launch script via `./activate_teps-tlsv1.2.sh`
