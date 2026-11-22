# One-line start for a PowerShell tool from GitHub, nothing to download by hand:
#   irm https://raw.githubusercontent.com/OWNER/REPO/main/get.ps1 | iex
# Loads the latest release (main if the repo has none) into %LOCALAPPDATA%\<Name>\<version>
# and starts the entry script in Windows PowerShell 5.1. -ExecutionPolicy Bypass applies only
# to that one process. Another version: $env:TOOL_REF = 'v1.2.0' (or 'main') before the line.
# Works for public repos only. Template from dev-team-framework (templates/repo/get.ps1):
# copy to the repo root, set the values in the block below, keep the file ASCII.
& {
    $Repo   = 'dominguez-posh/M365-MFA-Manager' # GitHub owner/repo
    $Name   = 'M365MfaTool'         # folder under %LOCALAPPDATA%
    $Entry  = 'Start-M365MfaTool.ps1' # entry script, relative to the repo root
    $Extra  = @('-HideConsole')                 # extra arguments for the entry script
    $Hidden = $true                 # $true: no console window (WPF tools that hide it themselves)

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest in 5.1 is slow with the progress bar
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    try { [Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials } catch { }

    $ref = $env:TOOL_REF
    if (-not $ref) {
        try {
            $ref = (Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'get.ps1' } -UseBasicParsing).tag_name
        } catch { $ref = 'main' }
    }
    $root   = Join-Path $env:LOCALAPPDATA $Name
    $target = Join-Path $root ($ref -replace '[^\w.-]', '_')
    $tmp    = Join-Path $env:TEMP ($Name + '-' + [guid]::NewGuid().ToString('N'))

    Write-Host "$Name ($ref) is loading from github.com/$Repo ..."
    New-Item -ItemType Directory -Force -Path $tmp, $root | Out-Null
    try {
        $zip = Join-Path $tmp 'tool.zip'
        Invoke-WebRequest "https://github.com/$Repo/archive/$ref.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $tmp -Force
        $src = Get-ChildItem $tmp -Directory | Select-Object -First 1   # GitHub packs everything into <repo>-<ref>\
        $fresh = $true
        if (Test-Path $target) {
            try { Remove-Item $target -Recurse -Force } catch { $fresh = $false; Write-Host "$target is in use, starting the copy already there." }
        }
        if ($fresh) { Move-Item $src.FullName $target }
    }
    finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }

    Get-ChildItem $target -Recurse -File | Unblock-File
    $script = Join-Path $target $Entry
    if (-not (Test-Path $script)) { throw "Entry script $Entry not found in $target." }
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script + '"')) + $Extra
    $style = if ($Hidden) { 'Hidden' } else { 'Normal' }
    Start-Process $ps -ArgumentList $argList -WorkingDirectory $target -WindowStyle $style
    Write-Host "$Name started from $target"
}
