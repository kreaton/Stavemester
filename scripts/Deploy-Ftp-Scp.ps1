# Publishes Stavemester and uploads it to an FTP server with WinSCP (https://winscp.net).
# Unlike Deploy-Ftp.ps1 it synchronizes, so only new and changed files are uploaded.
#
#   pwsh scripts\Deploy-Ftp-Scp.ps1 -FtpHost ftp.example.com -User me -Folder webroots/www/test
#
# Each setting can instead come from an environment variable (FTP_HOST, FTP_USERNAME,
# FTP_PASSWORD, FTP_FOLDER), the same names as the GitHub secrets. The password is asked
# for if it isn't set, so it never has to be typed on the command line.
param(
    [string]$FtpHost = $env:FTP_HOST,
    [string]$User = $env:FTP_USERNAME,
    [string]$Folder = $env:FTP_FOLDER,
    [string]$WinScp,
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

if (-not $FtpHost) { throw 'Set -FtpHost or FTP_HOST.' }
if (-not $User) { throw 'Set -User or FTP_USERNAME.' }
if (-not $Folder) { $Folder = '' }

# WinSCP.com is the console version of WinSCP; look in the usual install folders, then PATH.
if (-not $WinScp) {
    $WinScp = @(
        "${env:ProgramFiles(x86)}\WinSCP\WinSCP.com",
        "$env:ProgramFiles\WinSCP\WinSCP.com",
        "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $WinScp) { $WinScp = (Get-Command WinSCP.com -ErrorAction SilentlyContinue).Source }
    if (-not $WinScp) { throw 'WinSCP.com not found. Install WinSCP or pass -WinScp <path>.' }
}

$password = $env:FTP_PASSWORD
if (-not $password) {
    $secure = Read-Host "FTP password for $User@$FtpHost" -AsSecureString
    $password = [System.Net.NetworkCredential]::new('', $secure).Password
}

$root = Split-Path $PSScriptRoot -Parent
$publishDir = Join-Path $root 'src\Stavemester\bin\Publish'

if (-not $SkipPublish) {
    if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }
    dotnet publish (Join-Path $root 'src\Stavemester\Stavemester.csproj') -c Release -o $publishDir
    if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }
}

# In WinSCP scripts a " inside a quoted value is written as "".
function Quote([string]$value) { '"' + $value.Replace('"', '""') + '"' }

# Relative to the folder the FTP login starts in, like the other deploy scripts.
$remote = $Folder.Trim('/') -replace '\\', '/'
if (-not $remote) { $remote = '.' }

# The commands go in a temporary script file rather than on the command line,
# so the password doesn't show up in the process list.
$script = @"
option batch abort
option confirm off
open ftp://$([Uri]::EscapeDataString($User))@$FtpHost/ -passive=on -password=$(Quote $password)
synchronize remote $(Quote $publishDir) $(Quote $remote)
exit
"@

$scriptFile = New-TemporaryFile
try {
    Set-Content -Path $scriptFile -Value $script -Encoding utf8
    & $WinScp /ini=nul /script="$scriptFile"
    if ($LASTEXITCODE -ne 0) { throw "WinSCP failed (exit code $LASTEXITCODE)." }
}
finally {
    Remove-Item $scriptFile -Force
}

Write-Host "Synchronized $publishDir to ftp://$FtpHost/$remote" -ForegroundColor Green
