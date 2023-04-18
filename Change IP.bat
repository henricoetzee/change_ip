@echo off

:init
 setlocal DisableDelayedExpansion
 set cmdInvoke=1
 set winSysFolder=System32
 set "batchPath=%~0"
 for %%k in (%0) do set batchName=%%~nk
 set "vbsGetPrivileges=%temp%\OEgetPriv_%batchName%.vbs"
 setlocal EnableDelayedExpansion

:checkPrivileges
  NET FILE 1>NUL 2>NUL
  if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
  if '%1'=='ELEV' (echo ELEV & shift /1 & goto gotPrivileges)
  ECHO.
  ECHO **************************************
  ECHO Invoking UAC for Privilege Escalation
  ECHO **************************************

  ECHO Set UAC = CreateObject^("Shell.Application"^) > "%vbsGetPrivileges%"
  ECHO args = "ELEV " >> "%vbsGetPrivileges%"
  ECHO For Each strArg in WScript.Arguments >> "%vbsGetPrivileges%"
  ECHO args = args ^& strArg ^& " "  >> "%vbsGetPrivileges%"
  ECHO Next >> "%vbsGetPrivileges%"

  if '%cmdInvoke%'=='1' goto InvokeCmd 

  ECHO UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%vbsGetPrivileges%"
  goto ExecElevation

:InvokeCmd
  ECHO args = "/c """ + "!batchPath!" + """ " + args >> "%vbsGetPrivileges%"
  ECHO UAC.ShellExecute "%SystemRoot%\%winSysFolder%\cmd.exe", args, "", "runas", 1 >> "%vbsGetPrivileges%"

:ExecElevation
 "%SystemRoot%\%winSysFolder%\WScript.exe" "%vbsGetPrivileges%" %*
 exit /B

:gotPrivileges
 setlocal & cd /d %~dp0
 if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul  &  shift /1)

REM   -------------END OF PRIVILEDGE FUNCTION-------------------

mode con: cols=90 lines=35

:set_interface
cls
setlocal enabledelayedexpansion
echo.
echo.
echo 				Choose interface:
set /a counter = 1
for /F "skip=3 tokens=2,3* delims= " %%G in ('netsh interface show interface') DO (
	echo 			!counter!: %%I:		%%G
	set /a counter += 1
)
echo 			r: refresh
echo 			q: quit
choice /C 123456789qr /N
if %errorlevel% == 10 goto end
if %errorlevel% == 11 goto set_interface
set choice=%ERRORLEVEL% 
set /a counter = 1
set interface=none
for /F "skip=3 tokens=2,3* delims= " %%G in ('netsh interface show interface') DO (
	if !counter! == %choice% set interface="%%I"
	set /a counter += 1
)
echo %interface%
setlocal disabledelayedexpansion
goto start

:waiting
echo Waiting...
timeout /T 2 /NOBREAK >nul
cls

:start
cls
netsh interface show interface name = %interface% |find "Disabled">nul
if %ERRORLEVEL% == 0 (
	echo.
	echo 		   [31mInterface disabled[0m
)
netsh interface show interface name = %interface% |find "Disconnected">nul
if %ERRORLEVEL% == 0 (
	echo.
	echo 		   [31mInterface not connected[0m
)
if %ERRORLEVEL% == 1 netsh int ip show config name = %interface%
echo.
echo 		   Choose new IP or option:
echo.
echo 			1: DHCP
echo 			2: 192.168.12.22
echo 			3: 169.254.1.2
echo			4: 192.168.12.22 (no gateway)
echo			5: 192.168.5.22
echo 			m: manual
echo 			t: manual 2 addresses
echo 			n: manual DNS
echo 			d: disable network interface
echo 			e: enable network interface
echo 			p: ping
echo 			r: refresh
echo 			c: change network interface
echo 			q: quit
choice /C 123qrdemptnc4 /N
if %ERRORLEVEL% == 1 goto dhcp
if %ERRORLEVEL% == 2 goto 12
if %ERRORLEVEL% == 3 goto 169
if %ERRORLEVEL% == 4 goto end
if %ERRORLEVEL% == 5 goto start
if %ERRORLEVEL% == 6 goto disable
if %ERRORLEVEL% == 7 goto enable
if %ERRORLEVEL% == 8 goto manual
if %ERRORLEVEL% == 9 goto ping
if %ERRORLEVEL% == 10 goto twee
if %ERRORLEVEL% == 11 goto dns
if %ERRORLEVEL% == 12 goto set_interface
if %ERRORLEVEL% == 13 goto 12nogate
if %ERRORLEVEL% == 14 goto 5

goto end

:dhcp
netsh int ip set address name = %interface% source = dhcp
netsh int ip set dns name = %interface% source = dhcp
goto waiting

:12
netsh interface ip set address %interface% static 192.168.12.22 255.255.255.0 192.168.12.1
netsh interface ip set dnsservers %interface% static 192.168.12.1 validate=no
netsh interface ip add dnsservers %interface% 8.8.8.8 index=2 validate=no
goto waiting

:169
netsh interface ip set address %interface% static 169.254.1.2 255.255.255.0 169.254.1.1
netsh interface ip set dnsservers %interface% static 169.254.1.1 validate=no
goto waiting

:12nogate
netsh interface ip set address %interface% static 192.168.12.22 255.255.255.0
goto waiting

:5
netsh interface ip set address %interface% static 192.168.5.22 255.255.255.0
goto waiting

:manual
set /p "ip=IP address:"
set /p "mask=Subnet mask:"
set /p "gate=Gateway:"
netsh interface ip set address %interface% static %ip% %mask% %gate%
goto waiting

:dns
set /p "DNS1=DNS 1:"
set /p "DNS2=DNS 2:"
netsh interface ip set dnsservers %interface% static %DNS1% validate=no
netsh interface ip add dnsservers %interface% %DNS2% index=2 validate=no
goto waiting

:twee
set /p "ip=IP address 1:"
set /p "mask=Subnet mask 1:"
set /p "gate=Gateway:"
set /p "ip2=IP address 2:"
set /p "mask2=Subnet mask 2:"
netsh interface ip set address %interface% static %ip% %mask% %gate%
netsh interface ip add address %interface% %ip2% %mask2%
goto waiting

:ping
set /p "ping=IP to ping: "
echo Trying to ping %ping%
ping -n 1 %ping% | findstr /r /c:"[0-9] *ms" >nul
if %errorlevel% == 0 echo [32mPing successfull[0m
if %errorlevel% gtr 0 echo [31mPing failed[0m
pause
goto start

:disable
netsh interface set interface %interface% disable
goto waiting

:enable
netsh interface set interface %interface% enable
goto waiting

:end
