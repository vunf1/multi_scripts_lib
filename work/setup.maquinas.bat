@echo off
:menu
cls
:: Display total physical memory
systeminfo | findstr /C:"Total Physical Memory"

:: Display total disks with sizes
echo.
echo Mounted Disks and Sizes:
wmic logicaldisk get size,caption

echo.
echo 1. Check Windows Activation
echo 2. Open Camera
echo 3. Exit
echo.
set /p choice="Press 1 to check Windows activation, 2 to open camera, 3 to exit: "

if "%choice%"=="1" goto check_activation
if "%choice%"=="2" goto open_camera
if "%choice%"=="3" goto exit
echo Invalid choice, please select a valid option.
pause
goto menu

:check_activation
cls
slmgr.vbs /dli
pause
goto menu

:open_camera
cls
start microsoft.windows.camera:
pause
goto menu

:exit
exit
