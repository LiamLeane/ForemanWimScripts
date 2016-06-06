$invocationPath = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

. (Join-Path $invocationPath "Globals.ps1")
CheckUpdates "10.0"
Invoke-Expression ((Join-Path $invocationPath "Wim.ps1") + (GetWimArguments "10.0"))