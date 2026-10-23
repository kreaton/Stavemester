# Publishes Stavemester and uploads it to an FTP server, without a Visual Studio publish profile.
#
#   pwsh scripts\Deploy-Ftp.ps1 -FtpHost ftp.example.com -User me -Folder webroots/www/test
#
# Each setting can instead come from an environment variable (FTP_HOST, FTP_USERNAME,
# FTP_PASSWORD, FTP_FOLDER), the same names as the GitHub secrets. The password is asked
# for if it isn't set, so it never has to be typed on the command line.
param(
    [string]$FtpHost = $env:FTP_HOST,
    [string]$User = $env:FTP_USERNAME,
    [string]$Folder = $env:FTP_FOLDER,
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

if (-not $FtpHost) { throw 'Set -FtpHost or FTP_HOST.' }
if (-not $User) { throw 'Set -User or FTP_USERNAME.' }
if (-not $Folder) { $Folder = '' }

$password = $env:FTP_PASSWORD
if (-not $password) {
    $secure = Read-Host "FTP password for $User@$FtpHost" -AsSecureString
    $password = [System.Net.NetworkCredential]::new('', $secure).Password
}
$credential = [System.Net.NetworkCredential]::new($User, $password)

$root = Split-Path $PSScriptRoot -Parent
$publishDir = Join-Path $root 'src\Stavemester\bin\Publish'

if (-not $SkipPublish) {
    if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }
    dotnet publish (Join-Path $root 'src\Stavemester\Stavemester.csproj') -c Release -o $publishDir
    if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }
}

$baseUri = "ftp://$FtpHost/" + ($Folder.Trim('/') -replace '\\', '/')

function Invoke-Ftp([string]$uri, [string]$method, [string]$file) {
    $request = [System.Net.FtpWebRequest]::Create($uri)
    $request.Method = $method
    $request.Credentials = $credential
    $request.UsePassive = $true
    $request.UseBinary = $true
    $request.KeepAlive = $true
    if ($file) {
        $source = [System.IO.File]::OpenRead($file)
        $stream = $request.GetRequestStream()
        try { $source.CopyTo($stream) } finally { $stream.Dispose(); $source.Dispose() }
    }
    $request.GetResponse().Dispose()
}

function New-FtpFolder([string]$uri) {
    # Fails when the folder already exists, which is fine.
    try { Invoke-Ftp $uri ([System.Net.WebRequestMethods+Ftp]::MakeDirectory) $null } catch { }
}

# Create every folder on the way down to the target, then mirror the publish output into it.
$path = "ftp://$FtpHost"
foreach ($part in $Folder.Trim('/').Split('/', [StringSplitOptions]::RemoveEmptyEntries)) {
    $path += "/$part"
    New-FtpFolder $path
}

Get-ChildItem $publishDir -Recurse -Directory | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($publishDir.Length).TrimStart('\') -replace '\\', '/'
    New-FtpFolder "$baseUri/$relative"
}

$files = Get-ChildItem $publishDir -Recurse -File
$i = 0
foreach ($file in $files) {
    $i++
    $relative = $file.FullName.Substring($publishDir.Length).TrimStart('\') -replace '\\', '/'
    Write-Host ("[{0}/{1}] {2}" -f $i, $files.Count, $relative)
    Invoke-Ftp "$baseUri/$([Uri]::EscapeDataString($relative) -replace '%2F', '/')" ([System.Net.WebRequestMethods+Ftp]::UploadFile) $file.FullName
}

Write-Host "Uploaded $($files.Count) files to $baseUri" -ForegroundColor Green
