@echo off
:: 注册 hyjzbbs:// 协议到注册表
:: 需要管理员权限运行

set EXE_PATH=%~dp0hjyz_bbs.exe

REG ADD "HKEY_CLASSES_ROOT\hyjzbbs" /ve /d "URL:QingTan Protocol" /f
REG ADD "HKEY_CLASSES_ROOT\hyjzbbs" /v "URL Protocol" /d "" /f
REG ADD "HKEY_CLASSES_ROOT\hyjzbbs\DefaultIcon" /ve /d "\"%EXE_PATH%\",0" /f
REG ADD "HKEY_CLASSES_ROOT\hyjzbbs\shell\open\command" /ve /d "\"%EXE_PATH%\" \"%%1\"" /f

echo 协议注册完成！
pause
