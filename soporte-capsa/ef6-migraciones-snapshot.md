# EF6 — `AutomaticMigrationsDisabledException` (snapshot inconsistente)

Guía para el error de migraciones de Entity Framework 6 en SGO (.NET Framework, Code First).

## El error

```
System.Data.Entity.Migrations.Infrastructure.AutomaticMigrationsDisabledException:
Unable to update database to match the current model because there are pending changes
and automatic migration is disabled. Either write the pending model changes to a
code-based migration or enable automatic migration. Set
DbMigrationsConfiguration.AutomaticMigrationsEnabled to true to enable automatic migration.
```

Aparece al **levantar la app** (o al correr `Update-Database`).

## ¿A qué se debe?

- SGO usa **EF6 Code First con migraciones code-based**. Cada migración guarda, además de
  `Up()`/`Down()`, un **snapshot del modelo**: el recurso `Target` de su `.resx`, que es un
  EDMX serializado y comprimido (gzip + base64).
- Al arrancar, el initializer `MigrateDatabaseToLatestVersion` aplica las migraciones
  code-based pendientes y luego **compara el modelo compilado actual contra el snapshot de
  la ÚLTIMA migración por Id**. Si difieren y `AutomaticMigrationsEnabled = false`, tira la
  excepción (no hay un archivo de migración que cubra ese delta y no puede/quiere inventarlo).
- **Causa típica (nivelaciones / merges):** una migración creada en una rama que **no tenía
  todas las migraciones previas** queda con un snapshot **desactualizado** — le falta una
  entidad/tabla/columna que sí está en el modelo mergeado. Como manda el snapshot de la
  **última migración por Id**, EF ve esos elementos como "cambios pendientes" aunque el
  esquema de la base ya esté bien.

## Dos conceptos que se confunden

| | Qué controla |
|---|---|
| **DatabaseInitializer** (`MigrateDatabaseToLatestVersion`) | Lo que **aplica** las migraciones code-based a la base al levantar. Es la razón de que "las migraciones se apliquen solas". Independiente del flag. |
| **`AutomaticMigrationsEnabled`** | Las migraciones **automáticas sin archivo**. `false` (correcto en prod) = EF solo aplica migraciones code-based; si detecta un delta que ningún archivo cubre, tira la excepción. **No** es lo que aplica migraciones al arrancar. |

Corolario: si esto rompe en local, **rompe igual en el ambiente publicado** (mismo initializer,
`AutomaticMigrationsEnabled = false`). Deshabilitar el check en local (initializer nulo,
`disableDatabaseInitialization`) sirve solo para un smoke test, no como solución.

## ¿Cómo se soluciona conceptualmente?

El fix es **una nueva migración code-based que refresque el snapshot** al modelo actual.
No se puede editar el snapshot a mano (es un blob comprimido); solo se regenera scaffoldeando.
Antes de generar, hay que **ver el diff** para no romper:

1. **Scaffoldear normal (diff)** contra una base **sincronizada** con todas las migraciones y
   mirar el `Up()`:
   - Si el `Up()` propone cambios que la base **ya tiene** (un `CreateTable` de una tabla que
     ya existe, un `RenameColumn`/`AlterColumn` ya aplicado, etc.) → es **snapshot stale /
     metadata**. Aplicar ese diff **rompería** (doble aplicación: crear una tabla existente,
     renombrar una columna que ya no existe con el nombre viejo). El fix correcto es una
     **migración vacía**: `Up()`/`Down()` vacíos + snapshot refrescado. No toca el esquema
     (que ya está bien), solo re-sincroniza el snapshot.
   - Si el `Up()` propone un cambio **real** que la base no tiene → es un cambio pendiente
     legítimo; se conserva ese diff.
2. **Verificar el estado real consultando la base** (¿la tabla/columna existe? ¿la nullabilidad
   es la esperada?) — no asumir. Es el dato que decide entre "vacía" y "diff real".
3. Se puede **validar el snapshot** decodificando el recurso `Target` del `.resx`
   (base64 → gunzip → EDMX) y buscando la entidad/columna esperada, para confirmar que la
   migración generada capturó el modelo completo.

> ⚠️ Ojo con el orden por Id: una migración de re-baseline tiene un Id nuevo (posterior), así
> que pasa a ser **la última**. Si su snapshot se generó antes de que existiera algún cambio
> que sí está en el modelo, **reintroduce** el problema. Siempre regenerar contra el modelo
> **final** (todas las migraciones ya integradas) y, si la rama base avanzó, re-verificar.

## ¿Cómo correr una migración EF6 sin pasar a VS2019?

Contexto: la **Package Manager Console** (`Add-Migration` / `Update-Database`) puede fallar en
VS Insiders (bug `IsWebSiteProject` → `ArgumentNullException`), y **EF6 no tiene `dotnet ef`**
(eso es exclusivo de EF Core). Opciones:

- **Scaffold por código** con `System.Data.Entity.Migrations.Design.MigrationScaffolder` desde
  un console chico que referencie el proyecto **DAL** + **EntityFramework**. Genera los 3
  archivos (`.cs`, `.Designer.cs`, `.resx`) igual que `Add-Migration`, sin depender de la PMC.
  Herramienta lista para usar: [`herramientas/generar-migracion-ef6/`](herramientas/generar-migracion-ef6/).
  - `Scaffold(nombre)` = diff normal. Necesita una base **sincronizada** con todas las
    migraciones o tira `MigrationsPendingException`.
  - `Scaffold(nombre, ignoreChanges: true)` = migración **vacía** (solo snapshot). No exige la
    base sincronizada.
  - En ambos casos necesita una connection string que resuelva el contexto (EF la usa para el
    `ProviderManifestToken`).
- **`Add-Migration` en una máquina con VS2019** y la PMC sana.
- **`migrate.exe`** (del paquete EF6) **no** sirve: solo **aplica** migraciones, no scaffoldea.

## Cableado de la migración generada

Mover los 3 archivos a `Capsa.OyG.DAL\Migrations\` y agregarlos al `.csproj` del DAL con el
mismo patrón que las demás migraciones:

```xml
<!-- ItemGroup de <Compile> -->
<Compile Include="Migrations\<Id>_<Nombre>.cs" />
<Compile Include="Migrations\<Id>_<Nombre>.Designer.cs">
  <DependentUpon><Id>_<Nombre>.cs</DependentUpon>
</Compile>

<!-- ItemGroup de <EmbeddedResource> -->
<EmbeddedResource Include="Migrations\<Id>_<Nombre>.resx">
  <DependentUpon><Id>_<Nombre>.cs</DependentUpon>
</EmbeddedResource>
```

La `.resx` **tiene** que quedar como `EmbeddedResource` (ahí vive el snapshot); si no, el
`Designer` no lo encuentra en runtime.
