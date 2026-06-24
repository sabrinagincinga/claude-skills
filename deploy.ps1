# Despliega cada skill del repo a la carpeta de skills personales de Claude Code.
# Uso: ./deploy.ps1
$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$target = Join-Path $env:USERPROFILE ".claude\skills"

New-Item -ItemType Directory -Force -Path $target | Out-Null

$skills = Get-ChildItem -Path $repoRoot -Directory |
    Where-Object { $_.Name -notlike ".*" }

if (-not $skills) {
    Write-Host "No se encontraron skills para desplegar."
    return
}

foreach ($skill in $skills) {
    $dest = Join-Path $target $skill.Name
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $skill.FullName $dest -Recurse
    Write-Host "Desplegado: $($skill.Name) -> $dest"
}

Write-Host "Listo. Reiniciá la sesión de Claude Code para recargar los skills."
