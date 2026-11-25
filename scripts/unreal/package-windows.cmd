@echo off
setlocal
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI"
if not defined UE_ROOT set "UE_ROOT=%ProgramFiles%\Epic Games\UE_5.8"
set "BATCH=%UE_ROOT%\Engine\Build\BatchFiles"
set "PROJECT=%ROOT%\unreal\FifthAvenue\FifthAvenue.uproject"
if not exist "%BATCH%\RunUAT.bat" (
    echo Set UE_ROOT to your Unreal Engine 5.8 installation.
    exit /b 1
)
call "%BATCH%\Build.bat" FifthAvenueEditor Win64 Development "-Project=%PROJECT%" -WaitMutex -NoHotReload
if errorlevel 1 exit /b %errorlevel%
call "%BATCH%\RunUAT.bat" BuildCookRun "-project=%PROJECT%" -platform=Win64 -clientconfig=Development -skipbuildeditor -nocompileeditor -build -cook -stage -pak -package -prereqs -nop4 -unattended -map=/Game/Manhattan/HeraldSquare "-stagingdirectory=%ROOT%\dist\unreal-windows"
exit /b %errorlevel%
