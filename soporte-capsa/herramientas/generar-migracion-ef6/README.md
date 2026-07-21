# generar-migracion-ef6

Mini herramienta para **generar una migración EF6 sin la Package Manager Console**.
Pensada para SGO cuando la PMC está rota (VS Insiders, bug `IsWebSiteProject`) y no se puede
usar `dotnet ef` (es exclusivo de EF Core).

Contexto conceptual completo (por qué del error, cómo decidir entre migración vacía o diff
real, etc.): ver [`../../ef6-migraciones-snapshot.md`](../../ef6-migraciones-snapshot.md).

## Qué hace

Ejecuta `MigrationScaffolder.Scaffold` — lo mismo que `Add-Migration` por dentro — y escribe
los 3 archivos de la migración (`.cs`, `.Designer.cs`, `.resx`) en una carpeta de salida.

```
MigracionTool.exe <NombreMigracion> [--empty] [--out <carpeta>]
```

- `<NombreMigracion>`: nombre de la clase (ej. `ResyncSnapshot`).
- `--empty`: migración **vacía** (`ignoreChanges`) → solo refresca el snapshot, sin
  operaciones de esquema. **No** exige base sincronizada. Es el fix para snapshot stale.
- sin `--empty`: **diff normal** → muestra el `Up()`/`Down()` real. **Requiere** una base
  sincronizada con todas las migraciones (si no, `MigrationsPendingException`). Útil para
  **ver** qué propone antes de decidir.
- `--out <carpeta>`: salida (default `.\_migracion_generada`).

Imprime el `UserCode` (Up/Down) en consola, así se ve el diff sin abrir archivos.

## Cómo compilarlo (sin proyecto en la solución)

Se compila con `csc` del framework contra los **binarios ya construidos** del DAL (compilá la
solución SGO primero, así el `bin` refleja el modelo actual). Ajustá `$bin` a tu ruta.

```powershell
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$bin = "C:\...\SGO\Capsa.OyG.DAL\bin\Debug"   # bin del DAL recién compilado
$src = "C:\...\claude-skills\soporte-capsa\herramientas\generar-migracion-ef6\MigracionTool.cs"

& $csc /nologo /out:"$bin\MigracionTool.exe" `
  /r:"$bin\EntityFramework.dll" `
  /r:"$bin\EntityFramework.SqlServer.dll" `
  /r:"$bin\Capsa.OyG.Dal.dll" `
  /r:"$bin\Capsa.OyG.Dominio.dll" `
  /r:"System.Xml.Linq.dll" `
  $src
```

Se compila **dentro del `bin` del DAL** a propósito: así el `.exe` encuentra al lado todas las
dependencias (EntityFramework, etc.) en runtime.

## Config necesaria (connection string)

Al lado del `.exe` tiene que haber un `MigracionTool.exe.config` con la connection string del
contexto (nombre `CapsaOyGContext`). EF la usa para el `ProviderManifestToken`; para el diff
normal, además, apuntá a una base **sincronizada con todas las migraciones**. Ver
[`MigracionTool.exe.config.ejemplo`](MigracionTool.exe.config.ejemplo).

## Cómo correrlo

```powershell
# 1) Ver el diff real (base sincronizada) para decidir:
& "$bin\MigracionTool.exe" ResyncSnapshot

# 2) Si el diff son cambios que la base YA tiene (snapshot stale) -> migración vacía:
& "$bin\MigracionTool.exe" ResyncSnapshot --empty
```

## Después de generar

1. Revisar el `Up()`: vacío = re-baseline de snapshot; con operaciones = cambio real
   (ver la guía conceptual para decidir).
2. Mover los 3 archivos a `Capsa.OyG.DAL\Migrations\`.
3. Cablearlos en `Capsa.OyG.Dal.csproj` (`.cs` como `Compile`, `.Designer.cs` como `Compile`
   con `DependentUpon`, `.resx` como `EmbeddedResource` con `DependentUpon`).
4. Rebuild + levantar la app para confirmar que ya no tira `AutomaticMigrationsDisabledException`.
5. Borrar el `MigracionTool.exe`, su `.config` y la carpeta de salida (son temporales).

## Validar el snapshot (opcional)

Para confirmar que la migración capturó una entidad/columna esperada, decodificar el recurso
`Target` del `.resx` (base64 → gunzip → EDMX) y buscar el nombre:

```powershell
[xml]$x = Get-Content "<Id>_<Nombre>.resx" -Raw
$b64 = ($x.root.data | Where-Object { $_.name -eq 'Target' }).value
$bytes = [Convert]::FromBase64String($b64)
$gz = New-Object System.IO.Compression.GzipStream(
        (New-Object System.IO.MemoryStream(,$bytes)),
        [System.IO.Compression.CompressionMode]::Decompress)
$edmx = (New-Object System.IO.StreamReader($gz)).ReadToEnd()
[regex]::Matches($edmx, 'NombreDeLaTablaOColumna').Count   # > 0 = está en el snapshot
```
