$sourceFile = Join-Path $PSScriptRoot 'huckstepwin_5k_16x10.png'
$destDir    = "$env:WINDIR\Web\Wallpaper\Corp"
New-Item -ItemType Directory -Path $destDir -Force | Out-Null
$wallFile   = Join-Path $destDir 'huckstepwin_5k_16x10.png'

Copy-Item $sourceFile $wallFile -Force

$sysPol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
New-Item -Path $sysPol -Force | Out-Null
Set-ItemProperty -Path $sysPol -Name Wallpaper      -Value $wallFile
Set-ItemProperty -Path $sysPol -Name WallpaperStyle -Value 10  # Fill

$adPol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop'
New-Item -Path $adPol -Force | Out-Null
Set-ItemProperty -Path $adPol -Name NoChangingWallPaper -Value 1 -Type DWord
