# Κατεβάζει το PocketBase binary για τοπικό development (Windows).
# Το binary ΔΕΝ μπαίνει στο git — τρέξε αυτό μετά από fresh clone.
$ErrorActionPreference = "Stop"
$version = "0.39.8"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$url = "https://github.com/pocketbase/pocketbase/releases/download/v$version/pocketbase_${version}_windows_amd64.zip"
$zip = Join-Path $here "pb.zip"

Write-Host "Downloading PocketBase v$version ..."
Invoke-WebRequest -Uri $url -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $here -Force
Remove-Item $zip
& (Join-Path $here "pocketbase.exe") --version
Write-Host "OK. Ξεκίνα με:  .\pocketbase.exe serve"
