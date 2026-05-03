param(
    [string]$SourceFile = "C:\Other\Git\Alien-Diplomacy\Godot\gemma-2-2b-it-Q4_K_M.gguf",
    [string]$PackageName = "com.example.aliendiplomacy",
    [string]$RemotePath = "files/gemma-2-2b-it-Q4_K_M.gguf",
    [switch]$VerifyHash
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb not found in PATH."
}
if (-not (Test-Path -LiteralPath $SourceFile)) {
    throw "Source file not found: $SourceFile"
}

$sourceInfo = Get-Item -LiteralPath $SourceFile
$sourceBytes = [int64]$sourceInfo.Length
$remoteDir = [System.IO.Path]::GetDirectoryName($RemotePath).Replace("\", "/")
if ([string]::IsNullOrWhiteSpace($remoteDir)) {
    $remoteDir = "."
}

Write-Host "Package: $PackageName"
Write-Host "Source : $SourceFile ($([Math]::Round($sourceBytes / 1MB, 2)) MB)"
Write-Host "Target : /data/user/0/$PackageName/$RemotePath"
Write-Host "Method : adb push -> /data/local/tmp -> run-as copy"

# Stage in a globally writable temp location first.
$tmpName = "{0}.{1}.tmp" -f (Split-Path -Leaf $RemotePath), (Get-Random -Maximum 999999)
$tmpPath = "/data/local/tmp/$tmpName"
Write-Host "Staging: $tmpPath"
& adb push $SourceFile $tmpPath
if ($LASTEXITCODE -ne 0) {
    throw "adb push failed with exit code $LASTEXITCODE"
}

# Copy into app sandbox as app user.
Write-Host "Installing into app sandbox..."
& adb shell run-as $PackageName mkdir -p $remoteDir
if ($LASTEXITCODE -ne 0) {
    throw "run-as mkdir failed with exit code $LASTEXITCODE"
}

& adb shell run-as $PackageName cp $tmpPath $RemotePath
if ($LASTEXITCODE -ne 0) {
    Write-Warning "run-as cp failed, trying cat fallback..."
    & adb shell run-as $PackageName sh -c "cat $tmpPath > $RemotePath"
    if ($LASTEXITCODE -ne 0) {
        throw "run-as copy failed with exit code $LASTEXITCODE"
    }
}

# Clean staging file (best effort).
& adb shell rm -f $tmpPath | Out-Null

Write-Host "Upload complete. Verifying file exists..."
& adb shell run-as $PackageName ls -lh $RemotePath

$remoteSizeLine = (& adb shell run-as $PackageName stat -c %s $RemotePath 2>$null | Select-Object -First 1).Trim()
if (-not $remoteSizeLine) {
    $remoteSizeLine = (& adb shell run-as $PackageName wc -c $RemotePath | Select-Object -First 1).Trim()
}
$remoteSize = ($remoteSizeLine -replace "[^0-9]", "")
if (-not $remoteSize) {
    throw "Could not read remote file size."
}
Write-Host "Size   : local=$sourceBytes bytes, remote=$remoteSize bytes"
if ([int64]$remoteSize -ne $sourceBytes) {
    throw "Size mismatch after transfer."
}

if ($VerifyHash) {
    Write-Host "Calculating local SHA256..."
    $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceFile).Hash.ToLower()

    Write-Host "Calculating remote SHA256..."
    $remoteHashLine = (& adb shell run-as $PackageName sh -c "sha256sum $RemotePath 2>/dev/null || toybox sha256sum $RemotePath 2>/dev/null" | Select-Object -First 1).Trim()
    if (-not $remoteHashLine) {
        Write-Warning "Could not read remote hash (sha256sum/toybox unavailable)."
        return
    }

    $remoteHash = ($remoteHashLine -split "\s+")[0].ToLower()
    Write-Host "Local : $localHash"
    Write-Host "Remote: $remoteHash"

    if ($localHash -eq $remoteHash) {
        Write-Host "SHA256 OK: hashes match."
    }
    else {
        throw "SHA256 mismatch. File transfer may be corrupted."
    }
}