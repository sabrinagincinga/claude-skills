# build-all.ps1
# Instala dependencias y ejecuta build en todos los modulos con package.json.
#
# Dejar este script en la raiz del repo React (SGOReact) y ejecutarlo desde ahi.
# $root se autodetecta a partir de la ubicacion del propio script.
#
# Nota: el Shell NO es un modulo aparte. Es un segundo build de "aperturas"
# (yarn build:shell -> vite.shell.config.ts -> dist-shell). Por eso se corre
# como paso extra despues del build normal del modulo.
#
# Si algun modulo falla, el script sigue con los demas (para ver todos los
# errores de una sola pasada) pero termina con exit code 1 y lista los fallos.
# IMPORTANTE: si build-all falla, NO corras copiar-dist. El modulo que fallo
# puede tener un build viejo en disco y se copiaria como si fuera nuevo.

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $root

# yarn tiene que estar en el PATH; si no, el error de PowerShell es criptico.
if (-not (Get-Command yarn -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: no se encontro 'yarn' en el PATH." -ForegroundColor Red
    exit 1
}

$folders = Get-ChildItem -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'package.json') }

$ok       = @()
$fallidos = @()
$omitidos = @()

foreach ($folder in $folders) {
    $nombre = $folder.Name
    $pkg    = Get-Content (Join-Path $folder.FullName 'package.json') -Raw | ConvertFrom-Json

    # Una carpeta con package.json pero sin script 'build' no es un build fallido:
    # es algo que no corresponde compilar (una lib compartida, tooling, etc.).
    # Se omite sin bloquear, pero queda listada en el resumen: si el que falta es
    # un modulo real que perdio su script en un merge, tenes que poder verlo.
    # Hoy las 24 carpetas con package.json declaran 'build', asi que no se dispara.
    if (-not ($pkg.scripts -and $pkg.scripts.build)) {
        Write-Host "`n=== $($nombre): no declara script 'build', se omite. ===" -ForegroundColor Yellow
        $omitidos += "$nombre (sin script build)"
        continue
    }

    Push-Location $folder.FullName
    try {
        Write-Host "`n=== $($nombre): Instalando dependencias... ===" -ForegroundColor Cyan
        yarn install
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: fallo 'yarn install' en $nombre (exit $LASTEXITCODE)." -ForegroundColor Red
            $fallidos += "$nombre (install)"
            continue
        }

        Write-Host "`n=== $($nombre): Ejecutando build... ===" -ForegroundColor Cyan
        yarn build
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: fallo 'yarn build' en $nombre (exit $LASTEXITCODE)." -ForegroundColor Red
            $fallidos += "$nombre (build)"
            continue
        }
        $ok += $nombre

        # Si el package.json declara un script "build:shell", correrlo tambien.
        # Hoy aplica solo a "aperturas", que ademas del modulo compila el Shell.
        if ($pkg.scripts.'build:shell') {
            Write-Host "`n=== $($nombre): Ejecutando build:shell... ===" -ForegroundColor Cyan
            yarn build:shell
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: fallo 'yarn build:shell' en $nombre (exit $LASTEXITCODE)." -ForegroundColor Red
                $fallidos += "$nombre (build:shell)"
            } else {
                $ok += "$nombre (shell)"
            }
        }
    }
    finally {
        # En un finally para que un Ctrl+C o un error inesperado no deje
        # la sesion parada dentro de la carpeta del modulo.
        Pop-Location
    }
}

# ------------------------------------------------------------------------------
# RESUMEN
# ------------------------------------------------------------------------------
Write-Host "`n------------------------------------------------------------"
Write-Host "Builds OK: $($ok.Count)" -ForegroundColor Green

if ($omitidos.Count -gt 0) {
    Write-Host "Omitidos : $($omitidos.Count)" -ForegroundColor Yellow
    $omitidos | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "(no bloquean; si aca aparece un modulo real, revisa su package.json)" -ForegroundColor DarkGray
}

if ($fallidos.Count -gt 0) {
    Write-Host "Fallidos : $($fallidos.Count)" -ForegroundColor Red
    $fallidos | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nNO corras copiar-dist.ps1 hasta resolver estos errores." -ForegroundColor Yellow
    exit 1
}

Write-Host "`nTodos los modulos fueron construidos correctamente." -ForegroundColor Green
