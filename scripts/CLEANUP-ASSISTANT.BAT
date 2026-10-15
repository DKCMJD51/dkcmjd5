@echo off
chcp 936 >nul
title 系统清理与优化助手 - DKCMJD5
setlocal enabledelayedexpansion

:: ===== 模式判断：加参数 -dry 只检测不清理（预览） =====
set "DRY=0"
if /i "%~1"=="-dry" set "DRY=1"

:: ===== 管理员权限检测 =====
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [提示] 本工具需要管理员权限，正在重新启动...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================================
echo     系统清理与优化助手（DKCMJD5）
echo     为《三角洲行动》打造干净、稳定的系统与网络环境
echo ============================================================
if %DRY% equ 1 (
    echo [模式] 预览模式（-dry）：只检测与统计，不删除任何文件
) else (
    echo [模式] 完整模式：检测 + 清理 + 网络优化
)
echo 运行时间：%date% %time%
echo.

set /a TOTAL=0

:: ============ 第 1 步：游戏环境敏感项检测（只读） ============
echo [第 1 步 / 共 4 步] 游戏环境敏感项检测（只读）
echo ------------------------------------------------------------
echo.
echo [虚拟显卡/虚拟显示器 - 反作弊环境判定敏感项]
pnputil /enum-devices /class Display 2>nul | findstr /i "GameViewer Virtual" >nul && (
    echo   [注意] 发现 GameViewer 虚拟显卡设备
    echo       虚拟显卡是投屏/远程类软件安装的组件，可能被反作弊系统
    echo       判定为"环境异常"。建议游戏前退出对应软件。
) || (
    echo   [OK] 未发现虚拟显示设备
)
echo.
echo [远程控制软件 - 游戏前必须退出]
set "REMOTE=0"
tasklist /fi "imagename eq todesk.exe" 2>nul | findstr /i "todesk" >nul && (set REMOTE=1 & echo   [注意] ToDesk 主程序正在运行)
tasklist /fi "imagename eq Todesk_service.exe" 2>nul | findstr /i "todesk" >nul && (set REMOTE=1 & echo   [注意] ToDesk 后台服务正在运行)
if !REMOTE! equ 0 echo   [OK] 未发现远程控制软件在运行
echo.
echo [按键/宏类进程 - 触发反作弊的高危项]
tasklist 2>nul | findstr /i "anjian Macro 按键" >nul && echo   [注意] 发现按键类进程，请关闭后再进入游戏 || echo   [OK] 未发现按键类进程
echo.
echo [反作弊组件状态]
tasklist 2>nul | findstr /i "ace" >nul && echo   [i] 反作弊组件在线 || echo   [i] 反作弊组件未运行（游戏未启动属正常）
echo.

:: ============ 第 2 步：系统垃圾清理（白名单） ============
echo [第 2 步 / 共 4 步] 系统垃圾清理（仅可再生缓存，不动个人文件）
echo ------------------------------------------------------------
echo.

:: --- 用户临时文件 ---
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$i=@(Get-ChildItem -LiteralPath '%TEMP%' -Recurse -Force -ErrorAction SilentlyContinue); if($i.Count){ ($i|ForEach-Object{$_.Length}|Measure-Object -Sum).Sum }else{ 0 }"`) do set S=%%a
if not defined S set S=0
set /a S=!S!/1048576
echo 用户临时文件: !S! MB
set /a TOTAL+=!S!
if %DRY% equ 0 (
    call :CLEAN "%TEMP%"
)
echo.

:: --- Windows 临时文件 ---
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$s=0; if(Test-Path -LiteralPath 'C:\Windows\Temp'){ $i=@(Get-ChildItem -LiteralPath 'C:\Windows\Temp' -Recurse -Force -ErrorAction SilentlyContinue); if($i.Count){ $s=($i|ForEach-Object{$_.Length}|Measure-Object -Sum).Sum } }; $s"`) do set S=%%a
if not defined S set S=0
set /a S=!S!/1048576
echo Windows 临时文件: !S! MB
set /a TOTAL+=!S!
if %DRY% equ 0 (
    call :CLEAN "C:\Windows\Temp"
)
echo.

:: --- 系统日志 / 错误报告 / 蓝屏转储 ---
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$t=0; foreach($p in @('C:\ProgramData\Microsoft\Windows\WER','C:\Windows\Minidump','C:\Windows\Logs','C:\Windows\MEMORY.DMP')){ if(Test-Path -LiteralPath $p){ $i=@(Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue); if($i.Count){ $t+=($i|ForEach-Object{$_.Length}|Measure-Object -Sum).Sum } } }; $t"`) do set S=%%a
if not defined S set S=0
set /a S=!S!/1048576
echo 系统日志/错误报告/转储: !S! MB
set /a TOTAL+=!S!
if %DRY% equ 0 (
    call :CLEAN "C:\ProgramData\Microsoft\Windows\WER"
    call :CLEAN "C:\Windows\Minidump"
    call :CLEAN "C:\Windows\Logs"
    powershell -NoProfile -Command "$f='C:\Windows\MEMORY.DMP'; if(Test-Path -LiteralPath $f -PathType Leaf){ Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }"
    echo   - 已清理
)
echo.

:: --- 着色器缓存（D3D/NVIDIA，重建后游戏首次加载略慢属正常） ---
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$t=0; foreach($p in @('%LOCALAPPDATA%\D3DSCache','%LOCALAPPDATA%\NVIDIA\DXCache','%LOCALAPPDATA%\NVIDIA\GLCache')){ if(Test-Path -LiteralPath $p){ $i=@(Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue); if($i.Count){ $t+=($i|ForEach-Object{$_.Length}|Measure-Object -Sum).Sum } } }; $t"`) do set S=%%a
if not defined S set S=0
set /a S=!S!/1048576
echo 着色器缓存: !S! MB
set /a TOTAL+=!S!
if %DRY% equ 0 (
    call :CLEAN "%LOCALAPPDATA%\D3DSCache"
    call :CLEAN "%LOCALAPPDATA%\NVIDIA\DXCache"
    call :CLEAN "%LOCALAPPDATA%\NVIDIA\GLCache"
    echo   - 已清理
)
echo.

:: --- 浏览器缓存（Edge/Chrome，只删 Cache，不碰登录/书签/历史） ---
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$t=0; foreach($base in @('%LOCALAPPDATA%\Microsoft\Edge\User Data','%LOCALAPPDATA%\Google\Chrome\User Data')){ if(Test-Path -LiteralPath $base){ Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | ForEach-Object { foreach($c in @('Cache','Code Cache')){ $x=Join-Path $_.FullName $c; if(Test-Path -LiteralPath $x){ $i=@(Get-ChildItem -LiteralPath $x -Recurse -Force -ErrorAction SilentlyContinue); if($i.Count){ $t+=($i|ForEach-Object{$_.Length}|Measure-Object -Sum).Sum } } } } } }; $t"`) do set S=%%a
if not defined S set S=0
set /a S=!S!/1048576
echo 浏览器缓存: !S! MB
set /a TOTAL+=!S!
if %DRY% equ 0 (
    if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data" (
        for /d %%d in ("%LOCALAPPDATA%\Microsoft\Edge\User Data\*") do (
            call :CLEAN "%%d\Cache"
            call :CLEAN "%%d\Code Cache"
        )
    )
    if exist "%LOCALAPPDATA%\Google\Chrome\User Data" (
        for /d %%d in ("%LOCALAPPDATA%\Google\Chrome\User Data\*") do (
            call :CLEAN "%%d\Cache"
            call :CLEAN "%%d\Code Cache"
        )
    )
    echo   - 已清理
)
echo.

:: --- Windows 更新缓存（保持更新服务原状态） ---
set "WU=0"
sc query wuauserv 2>nul | findstr /i "RUNNING" >nul && set "WU=1"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$s=0; if(Test-Path -LiteralPath 'C:\Windows\SoftwareDistribution\Download'){ $i=@(Get-ChildItem -LiteralPath 'C:\Windows\SoftwareDistribution\Download' -Recurse -Force -ErrorAction SilentlyContinue); if($i.Count){ $s=($i|ForEach-Object{$_.Length}|Measure-Object -Sum).Sum } }; $s"`) do set S=%%a
if not defined S set S=0
set /a S=!S!/1048576
echo Windows 更新缓存: !S! MB
set /a TOTAL+=!S!
if %DRY% equ 0 (
    if !S! gtr 0 (
        net stop wuauserv >nul 2>&1
        call :CLEAN "C:\Windows\SoftwareDistribution\Download"
        if !WU! equ 1 net start wuauserv >nul 2>&1
        echo   - 已清理（更新服务状态已恢复原样）
    )
)
echo.

:: --- 回收站（仅报告，默认不清空） ---
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$s=0; try{ (New-Object -ComObject Shell.Application).Namespace(0xA).Items() | ForEach-Object { $s += $_.Size } }catch{}; [math]::Round($s/1MB,0)"`) do set RB=%%a
if not defined RB set RB=0
echo 回收站: !RB! MB（本工具默认不清空，误删文件靠它找回；确需清空请自行右键回收站）
echo.

:: ============ 第 3 步：网络环境优化（合法项） ============
echo [第 3 步 / 共 4 步] 网络环境优化
echo ------------------------------------------------------------
ipconfig /flushdns >nul 2>&1 && echo [OK] DNS 缓存已刷新 || echo [i] DNS 刷新失败（可忽略）
echo.
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$r=@(Test-Connection 223.5.5.5 -Count 3 -ErrorAction SilentlyContinue); if($r.Count){ $a=($r|ForEach-Object{$_.ResponseTime}|Measure-Object -Average).Average; '阿里DNS(223.5.5.5) 平均延迟: {0:N0} ms' -f $a } else { '阿里DNS(223.5.5.5) 无响应' }"`) do echo   %%a
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$r=@(Test-Connection 119.29.29.29 -Count 3 -ErrorAction SilentlyContinue); if($r.Count){ $a=($r|ForEach-Object{$_.ResponseTime}|Measure-Object -Average).Average; '腾讯DNS(119.29.29.29) 平均延迟: {0:N0} ms' -f $a } else { '腾讯DNS(119.29.29.29) 无响应' }"`) do echo   %%a
echo.
echo 当前系统时间: %date% %time%
echo   （系统时间偏差过大会被反作弊判定异常，请确认时间正确）
echo.

:: ============ 第 4 步：汇总与建议 ============
echo [第 4 步 / 共 4 步] 汇总与游戏前建议
echo ------------------------------------------------------------
set /a TOTALGB=!TOTAL!/1024
echo 本次可释放/已释放：约 !TOTAL! MB（!TOTALGB! GB）
if %DRY% equ 1 echo （预览模式未删除任何文件，双击重新运行即执行清理）
echo.
echo ============================================================
echo 游戏前建议（降低"环境异常"误判概率）：
echo   1. 退出 ToDesk 等远程/投屏软件，确认虚拟显卡相关软件未运行
echo   2. 关闭浏览器、网盘同步、直播/录屏软件
echo   3. 不挂按键宏、脚本、加速器以外的无关程序
echo   4. 保持显卡驱动与反作弊组件为最新版本
echo   5. 游戏目录所在盘剩余空间保持 15%% 以上
echo ============================================================
echo.
echo 执行完成！按任意键退出。
pause >nul
endlocal
goto :EOF

:: ============================================================
:: 安全清理子例程：仅删除白名单目录的内容（含多重复核）
:: 参数 %1 = 目标目录（静态路径或已校验的派生路径）
:: ============================================================
:CLEAN
set "CP=%~1"
:: 源校验：目标为空则放弃
if "%CP%"=="" goto :EOF
:: 基础校验：拒绝盘符根目录、Windows 根目录、根路径
if /i "%CP%"=="C:\" goto :EOF
if /i "%CP%"=="D:\" goto :EOF
if /i "%CP%"=="E:\" goto :EOF
if /i "%CP%"=="F:\" goto :EOF
if /i "%CP%"=="C:\Windows" goto :EOF
if "%CP%"=="\" goto :EOF
if "%CP:~0,1%"=="\" goto :EOF
:: 最终校验 + 删除：PowerShell 规范化路径后再次拒绝根目录，仅删除该目录内内容
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$p='%CP%'; $f=[IO.Path]::GetFullPath($p).TrimEnd('\'); if($f -eq '\' -or $f -match '^[A-Za-z]:\\$' -or $f -eq 'C:\Windows' -or -not (Test-Path -LiteralPath $f)){ exit 1 }; Get-ChildItem -LiteralPath $f -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; 'ok'"`) do set CLEANED=%%a
if "%CLEANED%"=="ok" echo   - 已清理
set "CLEANED="
goto :EOF
