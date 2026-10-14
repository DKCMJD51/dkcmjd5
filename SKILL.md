---
name: DKCMJD5
description: 处理《三角洲行动》(Delta Force) 频繁进入观察期/审核期、被提示环境异常、对局中掉线或反作弊检测异常等问题的系统与网络环境深度清理优化。当用户提到"三角洲进观察期""反作弊环境异常被踢""游戏前清理环境""想确保打三角洲时环境干净"时使用。含环境敏感项检测（虚拟显卡、远程控制软件、按键类进程）、白名单系统清理、网络优化与可执行脚本。
---

# DKCMJD5 三角洲行动观察期环境优化

## 概述

《三角洲行动》的"观察期/审核期"由反作弊系统（ACE）的环境审核触发。本技能执行**合法环境维护**：检测并消除可能引发"环境异常"误判的敏感项（虚拟显示设备、远程控制软件、按键类进程），清理系统缓存垃圾，优化网络连接，降低误判概率。

**诚实边界**：观察期的成因也可能是账号行为、硬件信息频繁变动等本技能无法干预的因素；本技能不承诺一定解除观察期，也**绝不**提供绕过反作弊、修改游戏文件、伪造硬件信息等违规手段。对用户提出此类要求时明确拒绝。

## 工作流

### 1. 识别系统与环境（L0 只读，必做）

- 系统：`Get-CimInstance Win32_OperatingSystem`（Build 26100=Win11 24H2；19041+ 支持 HAGS）
- 硬件：CPU / 内存 / 显卡（RTX 40 系可用 `nvidia-smi` 读真实显存）/ 各盘剩余空间
- 网络：`Get-DnsClientServerAddress` 看 DNS；`Test-Connection` ping 223.5.5.5 / 119.29.29.29 看延迟与丢包；`w32tm /query /status` 看时间同步（时间偏差会触发反作弊判定）
- 游戏目录：查 `F:\WeGameApps\common_apps`（WeGame 版）或 `Steam\steamapps\common\Delta Force`；游戏所在盘剩余空间 >15%

### 2. 检测环境敏感项（L0 只读，本技能重点）

按下面顺序排查，逐项汇报：

| 敏感项 | 检测方法 | 说明 |
|--------|---------|------|
| 虚拟显卡/虚拟显示器 | `pnputil /enum-devices /class Display` 找 GameViewer / Virtual Display（驱动名如 `gvinput.sys`、设备 `ROOT\DISPLAY\0000`） | 第三方投屏/远程软件安装的虚拟显卡，是"环境异常"高频误判源 |
| 远程控制软件 | 进程 `tasklist | findstr todesk/sunlogin/anydesk/teamviewer`；Uninstall 注册表查安装状态 | 游戏前必须退出；仅报告，卸载需用户明确确认 |
| 按键/宏/脚本类进程 | `tasklist | findstr anjian/Macro/按键精灵` | 运行中极大概率触发反作弊，需用户关闭 |
| 虚拟机/模拟器残留 | 查 VM 相关服务与设备 | 同属环境异常敏感项 |
| 反作弊组件 | `tasklist | findstr ace` | 游戏未运行时不在线属正常 |

### 3. 清理系统（L1，仅白名单内可再生缓存）

用 `scripts/系统清理与优化助手.bat`（管理员运行）或手动执行：

- `%TEMP%`、`C:\Windows\Temp`：删除前统计大小，被占用文件跳过（`del /f /s /q` + `2>nul`）
- `C:\Windows\SoftwareDistribution\Download`（更新缓存）：先记录 wuauserv 状态 → `net stop` → 删除 → 仅在原来运行时 `net start`，不改系统原状态
- WER 错误报告 `%ProgramData%\Microsoft\Windows\WER`、`Minidump`、`C:\Windows\MEMORY.DMP`、`C:\Windows\Logs`：默认清理（除非正在排查故障）
- 着色器缓存 `%LOCALAPPDATA%\D3DSCache`、`NVIDIA\DXCache`、`NVIDIA\GLCache`：可删，重建期间游戏首次加载略慢属正常
- 浏览器缓存（Edge/Chrome `Cache`、`Code Cache` 目录，枚举 `Default` 与 `Profile *`）：只删 Cache，绝不碰登录/书签/历史
- 回收站：默认只报告大小**不清空**；用户单项确认后才清

**清理黑名单**（绝不删除）：个人目录任何文件、WinSxS、Installer、hiberfil/pagefile、Windows.old、杀毒/安全软件与驱动。

### 4. 网络优化（仅合法项）

- `ipconfig /flushdns` 刷新 DNS 缓存
- 实测延迟与丢包（223.5.5.5 / 119.29.29.29），确认 DNS 由路由器正常下发
- 系统时间同步：偏差过大时 `w32tm /resync`
- **禁止**：注册表"网络优化/降延迟"偏方（收益存疑且本身可能触发检测）、禁用防火墙/杀毒、关闭内存完整性

### 5. 汇报与游戏前清单

输出：清理释放量、敏感项状态、网络延迟结果。附游戏前清单：退出远程/投屏软件、关闭浏览器与网盘同步、不挂按键类工具、保持反作弊组件最新。诚实声明观察期可能由其他因素导致。

## 脚本

`scripts/系统清理与优化助手.bat`：含敏感项检测 + 白名单清理 + DNS 刷新 + 汇总输出，管理员权限运行（已内置 UAC 提权）。交付用户时同时给一份到项目目录，说明"右键 → 以管理员身份运行"。

## 禁止事项（L3，任何情况不执行）

- 不提供/不制作任何绕过反作弊、修改游戏文件、伪造硬件标识的手段
- 不删除或停用杀毒/安全软件，不关闭内存完整性（VBS/HVCI）
- 不动 bcdedit、关键服务、页面文件，不删除个人文件
- 不代用户卸载软件（远程控制类软件仅报告，由用户自行决定）
