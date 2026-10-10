@echo off
rem hvigorw.bat - HarmonyOS 构建启动脚本（Windows）
rem 优先使用 PATH 中的 hvigorw（DevEco Command Line Tools），否则转交工程内 wrapper。
setlocal
set DIR=%~dp0
where hvigorw >nul 2>nul
if %errorlevel%==0 (
  hvigorw %*
  exit /b %errorlevel%
)
if not exist "%DIR%hvigor\hvigor-wrapper.js" (
  echo hvigor-wrapper.js not found: "%DIR%hvigor\hvigor-wrapper.js"
  echo 请安装 DevEco Command Line Tools 或使用 DevEco Studio 打开工程同步。
  exit /b 1
)
node "%DIR%hvigor\hvigor-wrapper.js" %*
exit /b %errorlevel%
