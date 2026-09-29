@echo off
setlocal
if "%~1"=="--help" goto usage
if /I "%~1"=="3CG" (set "DEVICE=xczu3cg") else if /I "%~1"=="3EG" (set "DEVICE=xczu3eg") else goto usage
if not "%~2"=="" goto usage
if not defined XILINX_ROOT (
  echo Set XILINX_ROOT to the directory containing Vivado and Vitis.
  exit /b 1
)
call "%XILINX_ROOT%\Vivado\2023.2\settings64.bat"
if errorlevel 1 exit /b 1
call "%XILINX_ROOT%\Vitis\2023.2\settings64.bat"
if errorlevel 1 exit /b 1
if not exist "%~dp0..\workspace" mkdir "%~dp0..\workspace"
if errorlevel 1 exit /b 1
pushd "%~dp0..\workspace"
if errorlevel 1 exit /b 1
make -f ..\hdl\Makefile.windows DEVICE=%DEVICE% MODE=lvds XSA_NAME=system_top.xsa
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%
:usage
echo Usage: set XILINX_ROOT=C:\Xilinx, then run sw\compile-xsa.cmd 3CG or 3EG
if "%~1"=="--help" exit /b 0
exit /b 2
