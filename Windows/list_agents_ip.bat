@echo off
REM For remote connections it is better to use the IP instead of hostname. Hostname may not work sometimes
REM set HUBHOST=9.20.199.88
set HOSTNAME=localhost
set SQLLIB=.
echo SELECT NODE, HOSTADDR FROM O4SRV.INODESTS; > itm_get_node_address.sql

REM for ip.pipe use port 1918
set KDC_PORTS=(2 135 3661)

echo %HOSTNAME%  | findstr /r "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"
if ERRORLEVEL 1 GOTO hostname
    echo IP.SPIPE:#%HOSTNAME% > runCMSsql_site.txt
    echo IP.PIPE:#%HOSTNAME% >> runCMSsql_site.txt
:hostname
    echo IP.SPIPE:%HOSTNAME% > runCMSsql_site.txt
    echo IP.PIPE:%HOSTNAME% >> runCMSsql_site.txt
:continue
set KDC_GLBSITES=runCMSsql_site.txt

kdstsns itm_get_node_address.sql *HUB  | findstr "\/NM" > itm_get_node_address.out
for /F "tokens=1 delims=<" %%i in (itm_get_node_address.out) do @echo %%i 




