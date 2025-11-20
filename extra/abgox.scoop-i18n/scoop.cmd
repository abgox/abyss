@echo off
where /q pwsh.exe
if %errorlevel% equ 0 (
    @REM pwsh -noprofile -ex unrestricted -file "${scoop.ps1}"  %*
    pwsh.exe -noprofile -ex unrestricted -command ". '${scoop-i18n.ps1}'; . '${scoop.ps1}'" %*
) else (
    @REM powershell -noprofile -ex unrestricted -file "${scoop.ps1}"  %*
    powershell -noprofile -ex unrestricted -command ". '${scoop-i18n.ps1}'; . '${scoop.ps1}'"  %*
)
