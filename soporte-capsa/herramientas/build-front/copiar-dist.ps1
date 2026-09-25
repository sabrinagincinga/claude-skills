# copiar-dist.ps1
# Copia los builds compilados de cada modulo del repo React al repo back (SGOreact),
# ubicando cada uno en la subcarpeta que corresponde segun el "base:" de su vite.config.ts.
#
# Requisito previo: haber corrido build-all.ps1 para generar los builds.
#
# Casos que NO siguen la logica general:
#   - Bombas : es CRA (react-scripts), no Vite. Compila a "build" y el destino
#              sale del "homepage" del package.json.
#   - Shell  : no es una carpeta propia. Es un segundo build de "aperturas"
#              (vite.shell.config.ts) que compila a "dist-shell" con base "/Shell/".
#
# Nota: los modulos Vite pueden declarar un outDir distinto de "dist"
# (ej: polimeros usa "build"), por eso se lee del propio vite.config.ts.
#
# ------------------------------------------------------------------------------
# CONFIGURACION
# ------------------------------------------------------------------------------
# $root se autodetecta: es la carpeta donde esta ubicado este script.
# Deja este .ps1 en la raiz del repo React (SGOReact) y no hace falta tocar nada aca.
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition

# $destRoot es la UNICA ruta a revisar. Por defecto asume que el repo back esta en
# %USERPROFILE%\source\repos\SGO\SGOreact. Si lo tenes en otra ubicacion, ajustalo.
$destRoot = Join-Path $env:USERPROFILE "source\repos\SGO\SGOreact"
# ------------------------------------------------------------------------------

# Validaciones iniciales
if (-not (Test-Path $root)) {
    Write-Host "ERROR: no se encontro la carpeta de origen: $root" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $destRoot)) {
    Write-Host "ERROR: no se encontro la carpeta de destino: $destRoot" -ForegroundColor Red
    Write-Host "Revisa la variable `$destRoot al inicio del script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Origen : $root"
Write-Host "Destino: $destRoot"
Write-Host ""

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------

# Contadores para el resumen final.
$script:copiados = @()
$script:omitidos = @()
$script:errores  = @()

# Lee el valor de una propiedad de un vite.config.ts (base, outDir, etc.)
#
# Dos precauciones para no agarrar la linea equivocada:
#  1. Ignora lineas comentadas: los configs tienen comentarios de cabecera que
#     mencionan 'base:' y 'outDir:' y darian un falso positivo.
#  2. El patron esta anclado a inicio de linea o a un separador ({ , ;), asi
#     'database:' u otra propiedad que TERMINE en el nombre buscado no matchea.
function Get-ViteValue {
    param($ConfigPath, $Property)

    $regex = "(?:^|[{,;])\s*$($Property)\s*:\s*[""']([^""']+)[""']"

    foreach ($line in Get-Content $ConfigPath) {
        $texto = $line.Trim()
        if ($texto.StartsWith("//") -or $texto.StartsWith("*") -or $texto.StartsWith("/*")) { continue }

        $match = [regex]::Match($texto, $regex)
        if ($match.Success) { return $match.Groups[1].Value.Trim("/") }
    }
    return $null
}

# Copia el contenido de $SrcPath dentro de $destRoot\$SubFolder.
# Limpia el destino antes de copiar: Vite hashea los assets, asi que sin limpiar
# los .js/.css de builds viejos se acumulan para siempre en el repo back.
# La limpieza se hace DESPUES de validar que el origen existe, para que un build
# faltante nunca deje la carpeta destino vacia.
function Copy-Build {
    param($Nombre, $SrcPath, $SubFolder)

    if (-not (Test-Path $SrcPath)) {
        Write-Host "No se encontro el build de $Nombre en '$SrcPath', se omite." -ForegroundColor DarkGray
        $script:omitidos += "$Nombre (sin build en '$SrcPath')"
        return
    }
    if ([string]::IsNullOrWhiteSpace($SubFolder)) {
        Write-Host "No se pudo determinar la carpeta destino para $Nombre, se omite." -ForegroundColor Yellow
        $script:omitidos += "$Nombre (destino no determinado)"
        return
    }

    $destPath = Join-Path $destRoot $SubFolder

    # Guardarrail: el destino tiene que quedar DENTRO de $destRoot y no ser el
    # $destRoot mismo. Evita que un "base:" raro (ej: "../algo") haga que la
    # limpieza borre algo fuera de la carpeta de deploy.
    $destFull = [System.IO.Path]::GetFullPath($destPath)
    $rootFull = [System.IO.Path]::GetFullPath($destRoot).TrimEnd('\') + '\'
    if (-not $destFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "Destino invalido para $Nombre ('$SubFolder' queda fuera de $destRoot), se omite." -ForegroundColor Red
        $script:errores += "$Nombre (destino fuera de $destRoot)"
        return
    }

    Write-Host "Copiando build de $Nombre -> $SubFolder ..." -ForegroundColor Cyan

    # -ErrorAction Stop para que un fallo (archivo bloqueado, permisos) caiga en
    # el catch en vez de seguir de largo y reportar un exito que no ocurrio.
    try {
        if (Test-Path $destPath) {
            # -Force en Get-ChildItem para incluir archivos ocultos (el wildcard * los omite).
            Get-ChildItem -Path $destPath -Force -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction Stop
        } else {
            New-Item -ItemType Directory -Path $destPath -Force -ErrorAction Stop | Out-Null
        }

        Copy-Item -Path (Join-Path $SrcPath "*") -Destination $destPath -Recurse -Force -ErrorAction Stop
        $script:copiados += "$Nombre -> $SubFolder"
    }
    catch {
        Write-Host "ERROR copiando $($Nombre): $($_.Exception.Message)" -ForegroundColor Red
        $script:errores += "$Nombre ($($_.Exception.Message))"
    }
}

# ------------------------------------------------------------------------------
# CASOS ESPECIALES
# ------------------------------------------------------------------------------

# --- Bombas: CRA, compila a "build", destino segun "homepage" del package.json ---
$bombasDir = Join-Path $root "bombas"
$bombasPkg = Join-Path $bombasDir "package.json"
if (Test-Path $bombasPkg) {
    $homepage = (Get-Content $bombasPkg -Raw | ConvertFrom-Json).homepage
    Copy-Build -Nombre "Bombas" -SrcPath (Join-Path $bombasDir "build") -SubFolder $homepage.Trim("/")
} else {
    Write-Host "No se encontro el package.json de bombas, se omite." -ForegroundColor DarkGray
}

# --- Shell: segundo build de "aperturas" (vite.shell.config.ts -> dist-shell) ---
$shellConfig = Join-Path $root "aperturas\vite.shell.config.ts"
if (Test-Path $shellConfig) {
    $shellBase   = Get-ViteValue -ConfigPath $shellConfig -Property "base"
    $shellOutDir = Get-ViteValue -ConfigPath $shellConfig -Property "outDir"
    if (-not $shellOutDir) { $shellOutDir = "dist-shell" }
    Copy-Build -Nombre "Shell" -SrcPath (Join-Path $root "aperturas\$shellOutDir") -SubFolder $shellBase
} else {
    Write-Host "No se encontro vite.shell.config.ts en aperturas, se omite el Shell." -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# RESTO DE LOS MODULOS (Vite)
# ------------------------------------------------------------------------------

# Carpetas que ya se procesaron arriba con logica propia
$exclude = @("bombas")

# Solo se consideran modulos las carpetas con package.json: asi .github, .vscode
# y demas no generan ruido de "se omite" en el log.
$modulos = Get-ChildItem -Path $root -Directory |
    Where-Object { (Test-Path (Join-Path $_.FullName 'package.json')) -and ($exclude -notcontains $_.Name) }

foreach ($modulo in $modulos) {
    $viteConfig = Join-Path $modulo.FullName "vite.config.ts"

    if (-not (Test-Path $viteConfig)) {
        Write-Host "No se encontro vite.config.ts en $($modulo.Name), se omite." -ForegroundColor Yellow
        $script:omitidos += "$($modulo.Name) (sin vite.config.ts)"
        continue
    }

    $baseValue = Get-ViteValue -ConfigPath $viteConfig -Property "base"
    if (-not $baseValue) {
        Write-Host "No se encontro 'base:' en vite.config.ts de $($modulo.Name), se omite." -ForegroundColor Yellow
        $script:omitidos += "$($modulo.Name) (sin 'base:' parseable)"
        continue
    }

    # outDir puede no estar declarado; el default de Vite es "dist".
    $outDir = Get-ViteValue -ConfigPath $viteConfig -Property "outDir"
    if (-not $outDir) { $outDir = "dist" }

    Copy-Build -Nombre $modulo.Name -SrcPath (Join-Path $modulo.FullName $outDir) -SubFolder $baseValue
}

# ------------------------------------------------------------------------------
# RESUMEN
# ------------------------------------------------------------------------------
Write-Host "`n------------------------------------------------------------"
Write-Host "Copiados: $($script:copiados.Count)" -ForegroundColor Green

if ($script:omitidos.Count -gt 0) {
    Write-Host "Omitidos: $($script:omitidos.Count)" -ForegroundColor Yellow
    $script:omitidos | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "(si esperabas ver un modulo aca arriba, revisa que su build exista)" -ForegroundColor DarkGray
}

if ($script:errores.Count -gt 0) {
    Write-Host "Errores : $($script:errores.Count)" -ForegroundColor Red
    $script:errores | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nLa copia termino con errores." -ForegroundColor Red
    exit 1
}

Write-Host "`nListo!" -ForegroundColor Green
