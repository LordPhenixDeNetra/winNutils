<#
.SYNOPSIS
  Compacte le disque virtuel de Docker Desktop (docker_data.vhdx) pour rendre l'espace a Windows.

.DESCRIPTION
  Supprimer des images dans Docker Desktop libere de la place DANS le .vhdx, jamais sur C:.
  Ce script : mesure, nettoie (optionnel), arrete Docker et WSL, compacte le .vhdx, puis affiche le gain.

.PARAMETER Prune
  Nettoie avant de compacter : cache de build + images sans etiquette + conteneurs arretes.
  Les volumes ne sont JAMAIS touches (sauf avec -Volumes).

.PARAMETER Volumes
  Avec -Prune : supprime aussi les volumes inutilises. ATTENTION : perte de donnees (bases de test...).

.PARAMETER Path
  Chemin du .vhdx si Docker est installe ailleurs que dans l'emplacement par defaut (ex. N:\...).

.PARAMETER Restart
  Relance Docker Desktop a la fin.

.EXAMPLE
  .\Compact-DockerVhdx.ps1                      # compacte seulement
  .\Compact-DockerVhdx.ps1 -Prune -Restart      # nettoie, compacte, relance Docker
  .\Compact-DockerVhdx.ps1 -WhatIf              # montre ce qui serait fait, sans rien changer

A lancer dans un PowerShell ouvert EN ADMINISTRATEUR.
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Prune,
    [switch]$Volumes,
    [string]$Path,
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'

function Format-Size([long]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} Go' -f ($bytes / 1GB)) }
    return ('{0:N0} Mo' -f ($bytes / 1MB))
}

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# --- 1. Localiser le .vhdx -------------------------------------------------
Step 'Recherche du disque virtuel Docker'
if (-not $Path) {
    $candidates = @(
        "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx",   # Docker Desktop recent
        "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx",          # Docker Desktop plus ancien
        "$env:LOCALAPPDATA\Docker\wsl\main\ext4.vhdx"
    )
    $Path = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Path -or -not (Test-Path $Path)) {
    throw "Aucun .vhdx trouve. Relance avec -Path 'C:\chemin\vers\docker_data.vhdx' (cherche : Get-ChildItem `$env:LOCALAPPDATA -Recurse -Filter *.vhdx)."
}
$Path = (Resolve-Path $Path).Path
$drive = Split-Path -Qualifier $Path
$before = (Get-Item $Path).Length
$freeBefore = (Get-PSDrive ($drive.TrimEnd(':'))).Free
Write-Host "Fichier   : $Path"
Write-Host "Taille    : $(Format-Size $before)"
Write-Host "Libre sur $drive : $(Format-Size $freeBefore)"

# --- 2. Mesurer et nettoyer (optionnel) ------------------------------------
$dockerOk = $false
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker info *> $null
    $dockerOk = ($LASTEXITCODE -eq 0)
}

if ($dockerOk) {
    Step 'Ce que Docker occupe (docker system df)'
    docker system df
    if ($Prune) {
        Step 'Nettoyage'
        if ($PSCmdlet.ShouldProcess('Docker', 'builder prune -af + image prune -f + container prune -f')) {
            docker builder prune -af
            docker image prune -f
            docker container prune -f
            if ($Volumes) {
                Write-Host 'ATTENTION : suppression des volumes inutilises.' -ForegroundColor Yellow
                docker volume prune -f
            }
        }
    }
} elseif ($Prune) {
    Write-Host 'Docker ne repond pas : nettoyage ignore (le compactage se fait quand meme).' -ForegroundColor Yellow
}

# --- 3. Arreter Docker et WSL proprement -----------------------------------
Step 'Arret de Docker Desktop et de WSL'
if ($PSCmdlet.ShouldProcess('Docker Desktop / WSL', 'arret')) {
    Get-Process 'Docker Desktop', 'com.docker.backend', 'com.docker.proxy' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    wsl --shutdown
    Start-Sleep -Seconds 3
    try { Stop-Service WSLService -Force -ErrorAction Stop } catch { Write-Host 'Service WSL deja arrete (ou non arretable) : on continue.' }
    Start-Sleep -Seconds 3

    # Attendre que plus aucun processus ne tienne le fichier
    $locked = $true
    foreach ($i in 1..15) {
        try {
            $fs = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
            $fs.Close(); $locked = $false; break
        } catch { Start-Sleep -Seconds 2 }
    }
    if ($locked) {
        throw "Le fichier est toujours utilise par un autre processus. Ferme Docker Desktop, tes terminaux WSL et VirtualBox/VMware, puis relance."
    }
}

# --- 4. Compacter avec diskpart --------------------------------------------
Step 'Compactage (peut durer plusieurs minutes, ne ferme pas la fenetre)'
if ($PSCmdlet.ShouldProcess($Path, 'compact vdisk')) {
    $script = Join-Path $env:TEMP 'compact-docker-vhdx.txt'
    @(
        "select vdisk file=`"$Path`"",
        'attach vdisk readonly',
        'compact vdisk',
        'detach vdisk',
        'exit'
    ) | Set-Content -Path $script -Encoding ASCII
    try {
        diskpart /s $script
    } finally {
        # Filet de securite : si diskpart a echoue en cours de route, on detache quand meme
        @("select vdisk file=`"$Path`"", 'detach vdisk', 'exit') |
            Set-Content -Path $script -Encoding ASCII
        diskpart /s $script *> $null
        Remove-Item $script -Force -ErrorAction SilentlyContinue
    }
}

# --- 5. Bilan --------------------------------------------------------------
Step 'Bilan'
$after = (Get-Item $Path).Length
$freeAfter = (Get-PSDrive ($drive.TrimEnd(':'))).Free
Write-Host ("Taille du .vhdx : {0}  ->  {1}" -f (Format-Size $before), (Format-Size $after)) -ForegroundColor Green
Write-Host ("Libre sur {0} : {1}  ->  {2}" -f $drive, (Format-Size $freeBefore), (Format-Size $freeAfter)) -ForegroundColor Green

if ($Restart) {
    Step 'Relance de Docker Desktop'
    $exe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $exe) { Start-Process $exe } else { Write-Host 'Docker Desktop.exe introuvable : relance-le a la main.' -ForegroundColor Yellow }
} else {
    Write-Host "`nDocker Desktop est arrete : relance-le quand tu en as besoin." -ForegroundColor Yellow
}
