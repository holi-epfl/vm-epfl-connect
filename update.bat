@echo off
setlocal enabledelayedexpansion

:: ===================================================================
::  wsl-update.bat (v13 - Pure DOS-style Logic)
::
::  This script is built from scratch using only fundamental batch
::  commands to rebuild the SSH config file safely.
:: ===================================================================

set "LOG_FILE=%USERPROFILE%\.vm-epfl-connect\connected_info.log"
set "SSH_HOST_ALIAS=vm-epfl"
set "SSH_USER=holi"

cd %USERPROFILE%\.vm-epfl-connect
git pull

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

echo INFO: Rebuilding the SSH config file using basic line-by-line logic...
set "SSH_DIR=%USERPROFILE%\.ssh"
set "SSH_CONFIG_FILE=%SSH_DIR%\config"
set "TEMP_CONFIG_FILE=%TEMP%\ssh_config_%RANDOM%.tmp"

if not exist "%SSH_DIR%" mkdir "%SSH_DIR%"

:: This is the core logic block. It reads the original file and writes
:: to a temporary file, skipping only the target host block.
set "isSkippingBlock=0"
(
    if exist "%SSH_CONFIG_FILE%" (
        for /f "usebackq tokens=* delims=" %%L in ("%SSH_CONFIG_FILE%") do (
            set "line=%%L"

            :: Tokenize the current line to check if it's a "Host" line
            set "firstToken="
            set "secondToken="
            for /f "tokens=1,2" %%A in ("!line!") do (
                set "firstToken=%%A"
                set "secondToken=%%B"
            )

            :: Logic Step 1: Check if this line is the start of the block we want to skip.
            if /i "!firstToken!"=="Host" if /i "!secondToken!"=="%SSH_HOST_ALIAS%" (
                set "isSkippingBlock=1"
            )

            :: Logic Step 2: If we are currently skipping, check if this line is a NEW host, which means we should stop skipping.
            if "!isSkippingBlock!"=="1" if /i "!firstToken!"=="Host" if /i "!secondToken!" NEQ "%SSH_HOST_ALIAS%" (
                set "isSkippingBlock=0"
            )

            :: Logic Step 3: If the "skip" switch is off, then print the current line.
            if "!isSkippingBlock!"=="0" (
                echo(!line!
            )
        )
    )
) > "%TEMP_CONFIG_FILE%"

:: Add the new, updated host entry to the end of the temp file
(
    echo.
    echo Host %SSH_HOST_ALIAS%
    echo     HostName %HOSTNAME%
    echo     User %SSH_USER%
    echo     Port %PORT%
) >> "%TEMP_CONFIG_FILE%"

:: Replace the original config with our newly created one
move /Y "%TEMP_CONFIG_FILE%" "%SSH_CONFIG_FILE%" > nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Could not update the SSH config file. Check permissions.
    goto :ERROR_AND_PAUSE
)

echo SUCCESS: SSH config was rebuilt successfully.
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