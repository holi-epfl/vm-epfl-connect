@echo off
setlocal enabledelayedexpansion

:: ===================================================================
::  wsl-update.bat
::
::  This script automates the process of:
::  1. Reading a TCP address from connected_info.log.
::  2. Parsing the hostname and port.
::  3. Safely updating the user's SSH config file with the new info.
:: ===================================================================

set "LOG_FILE=%USERPROFILE%\.wsl-connect\connected_info.log"
set "SSH_HOST_ALIAS=wsl-epfl"
set "SSH_USER=holi-epfl"

echo INFO: Checking for log file at %LOG_FILE%...
if not exist "%LOG_FILE%" (
    echo ERROR: The log file was not found!
    goto :ERROR_AND_PAUSE
)
for %%A in ("%LOG_FILE%") do set "FILE_SIZE=%%~zA"
if %FILE_SIZE%==0 (
    echo ERROR: The log file is empty.
    goto :ERROR_AND_PAUSE
)
echo SUCCESS: Log file found and is not empty.
echo.

echo INFO: Reading and parsing connection info...
set /p NGROK_URL=<%LOG_FILE%
set "URL_PARSED=%NGROK_URL:tcp://=%"
for /f "tokens=1,2 delims=:" %%H in ("%URL_PARSED%") do (
    set "HOSTNAME=%%H"
    set "PORT=%%I"
)
if not defined HOSTNAME (
    echo ERROR: Could not parse the Hostname from the URL.
    goto :ERROR_AND_PAUSE
)
if not defined PORT (
    echo ERROR: Could not parse the Port from the URL.
    goto :ERROR_AND_PAUSE
)
echo SUCCESS: Parsed connection details:
echo   -^> Hostname: %HOSTNAME%
echo   -^> Port:     %PORT%
echo.

echo INFO: Rebuilding the SSH config file...
set "SSH_DIR=%USERPROFILE%\.ssh"
set "SSH_CONFIG_FILE=%SSH_DIR%\config"
set "TEMP_CONFIG_FILE=%TEMP%\ssh_config_%RANDOM%.tmp"

if not exist "%SSH_DIR%" mkdir "%SSH_DIR%"
set "inTargetBlock=0"
(
    if exist "%SSH_CONFIG_FILE%" (
        for /f "usebackq tokens=* delims=" %%L in ("%SSH_CONFIG_FILE%") do (
            set "line=%%L"
            if /i "!line:Host %SSH_HOST_ALIAS%=!" NEQ "!line!" (
                set "inTargetBlock=1"
            ) else (
                if "!inTargetBlock!"=="1" (
                    if "!line:Host =!" NEQ "!line!" (
                        set "inTargetBlock=0"
                    )
                )
            )
            if "!inTargetBlock!"=="0" (
                echo(!line!
            )
        )
    )
) > "%TEMP_CONFIG_FILE%"
(
    echo.
    echo Host %SSH_HOST_ALIAS%
    echo     HostName %HOSTNAME%
    echo     User %SSH_USER%
    echo     Port %PORT%
) >> "%TEMP_CONFIG_FILE%"
move /Y "%TEMP_CONFIG_FILE%" "%SSH_CONFIG_FILE%" > nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Could not update the SSH config file. Check permissions.
    goto :ERROR_AND_PAUSE
)
echo SUCCESS: SSH config was updated.
echo.
goto :SUCCESS

:SUCCESS
echo ===================================================================
echo.
echo  SUCCESS: Script finished. Your SSH config is now updated.
echo  You can now connect using: ssh %SSH_HOST_ALIAS%
echo.
goto :END

:ERROR_AND_PAUSE
echo.
echo ===================================================================
echo.
echo  AN ERROR OCCURRED. Please review the messages above.
echo.
pause

:END
exit /b 0