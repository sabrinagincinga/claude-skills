# Proyecto — Consola de Seguridad Web (CSA)

Contexto técnico del proyecto **Consola de Seguridad Web** (CSA) de Grupo Capsa. Leer antes de trabajar código o tickets sobre este repo.

## 1. Qué es CSA

**CSA (Consola de Seguridad)** es la aplicación web de administración de seguridad de Grupo Capsa: gestiona **usuarios, roles, permisos, dimensiones, aplicaciones y entornos** para el resto de los sistemas del grupo (entre ellos SGP/SGO).

Es la contracara administrativa del **WS de Seguridad** que aparece en [incidente-401-ws-seguridad.md](incidente-401-ws-seguridad.md): CSA es donde se *administran* los permisos/dimensiones; el WS de Seguridad es donde otros sistemas los *consumen* en runtime. Ambos viven en este mismo repo (ver §3, proyecto `SecurityApi`).

- **Repo Azure DevOps:** `grupocapsa/ConsolaSeguridadWeb`
- **Tenant Azure AD (auth):** `grupocapsacapex.onmicrosoft.com` (tenant id `a5b83bcd-8fbc-4e2c-9ea5-86aa438e80e8`)
- **Ruta local:** `c:\Users\Sabrina\source\repos\ConsolaSeguridadWeb`
- **Rama principal de trabajo:** `develop`

## 2. Arquitectura general

Monorepo con dos mitades: **backend .NET 7** y **frontend React + Vite**.

```
ConsolaSeguridadWeb/
├── Security-console-server/    ← backend (.NET 7, C#)
├── security-console-client/    ← frontend (React 18 + TS + Vite)
└── azure-pipelines-develop.yml ← CI del cliente (build React, licencia Kendo, artifact)
```

> Ojo con el casing: la carpeta del server es `Security-console-server` (con S mayúscula), la del cliente `security-console-client` (minúscula).

### Backend — `Security-console-server` (.NET 7)

Solución multi-proyecto en capas. El `RootNamespace` es `SecurityConsole`.

| Proyecto | Rol |
|----------|-----|
| `Security-console-server` | **API principal de la consola.** Controllers **OData** (Aplicaciones, Usuarios, Roles, Permisos, Dimensiones, Security) + controllers MVC (Login, ExternalSignIn, Error). Auth con Azure AD (JWT Bearer + OpenIdConnect, Microsoft.Identity.Web). |
| `Security-console-server.SecurityApi` | **El WS de Seguridad** que consumen los sistemas externos (SGP/SGO). Un `SeguridadController`. Program.cs + Startup.cs propios → se despliega aparte. |
| `Security-console-server.SecurityApi.Services` / `.Mock` | Lógica del WS de Seguridad y su mock para tests/dev. |
| `Security-console-server.Model` | Entidades EF Core: `Aplicacion`, `Entorno`, `Usuario`, `Rol`, `Permiso`, `Dimension`, tablas puente (`UsuarioRol`, `PermisoRol`, `RolEntorno`, `UsuarioDimension`…), `AuditTrail`, `AuditoriaUsuarios`, `SecurityConsoleUser/Role` (Identity). |
| `Security-console-server.Services` | Lógica de negocio (DTOs, servicios de aplicación, auditoría con `CSAAuditProfile`, `AuthContext`, `UserIdentityLogic`). |
| `Security-console-server.DataAccess` | EF Core. `SecurityConsoleContext : IdentityDbContext`. Patrón **Repository + Unit of Work** (`ICSAUnitOfWork`, `IRepository<T>`, `AuditProvider`). Migrations acá. |
| `Security-console-server.ClientServices` | Cliente hacia servicios externos (`SecurityClient`, integración con **Microsoft Graph**). |
| `Security-console-server.Utilities` | Helpers transversales (Excel, excepciones, security). |
| `Security-console-server.Tests` | Tests. |

**Patrón clave — OData + GenericCrud:** el CRUD principal se expone por **OData**. `GenericCrudController<TEntity>` (abstracto) da Get/Post/Put/Delete genéricos sobre `IRepository<TEntity>`; cada controller concreto (ej. `AplicacionesController : GenericCrudController<Aplicacion>`) hereda y agrega acciones OData específicas (`CSA.GetSidePanelData`, `CSA.GetAplicacionesEntorno`, etc.).

**Autorización basada en atributos:** los controllers declaran requisitos con atributos como `[IgnoreEnvironmentAuthorize("VerAplicaciones")]`, `[RolesRequirementOnCreate("EditarAplicaciones")]`, `[RolesRequirementOnUpdate(...)]`, `[RolesRequirementOnDelete(...)]`. También existe `CSAAuthorizeAttribute` para autorización por rol/policy (agregado en ticket #6050). Los permisos son strings (`VerAplicaciones`, `EditarAplicaciones`…).

**Auditoría:** cambios sobre entidades auditables se registran en `AuditTrail` vía `AuditProvider` / `CSAAuditProfile` (marcadas con `SyncableAttribute` y trabajo reciente de los tickets #4937 y #7862).

### Frontend — `security-console-client` (React 18 + TS + Vite)

- **Build:** Vite (dev en `https://localhost:3002`). Scripts: `yarn dev`, `yarn build`, `yarn lint`.
- **Auth:** MSAL (`@azure/msal-react` / `msal-browser`) contra Azure AD. Se puede desactivar con `VITE_APP_AUTH_MODE !== "ad"` (modo dev sin AD). Scope: `https://grupocapsacapex.onmicrosoft.com/AppSeguridad/develop`.
- **Estado:** Redux Toolkit + redux-persist + thunks. Store en `src/store/`; slices por feature en `common/.../store/slice` y en cada módulo.
- **UI:** **KendoReact** (⚠️ requiere licencia — `KENDO_UI_LICENSE`, se activa en el pipeline) + Bootstrap 5 / react-bootstrap + styled-components. i18n en español (`@progress/kendo-react-intl`, locale `es`).
- **Forms:** react-final-form.
- **Data:** capa REST propia `entaFetch` (wrapper sobre fetch que arma queries OData: skip/take/sort/filter/count) + `entaBatch`. Cada feature tiene su `rest/api.tsx`.

**Módulos de negocio (carpetas en `src/`):**
- `Aplicaciones/` — ABM de aplicaciones.
- `Entornos/` — subdividido en **Desarrollo / Produccion / Prototipo**; dentro: dimensiones, roles, permisosPorRol, rolesPorUsuario, usuariosPorRol, usuariosPorDimension, dimensionesPorUsuario, copiarPermisosAUsuarios, drawerCopiarEntorno, etc.
- `Permisos/`, `Usuarios/`.
- `common/` — auth, rest (entaFetch), components (grid, form, layout, routes), store, hooks, notifications, breadcrums, messages.

**Convención de componentes (muy repetida):** por cada vista/acción se ve el trío **Composite / Container / (Form|Grid|Toolbar)**, y los drawers de alta/edición/eliminación como `AplicacionAltaDrawer`, `AplicacionEditDrawer`, `AplicacionDeleteDrawer`. El `Container` conecta con Redux/rest; el `Composite` compone la UI; `Form`/`Grid`/`Toolbar` son presentacionales.

### Conceptos de dominio (vocabulario del proyecto)
- **Aplicación:** sistema del grupo administrado en la consola.
- **Entorno:** Desarrollo / Producción / Prototipo. Muchos permisos/roles/dimensiones se administran **por entorno**.
- **Dimensión:** eje de datos (ej. las dimensiones que también usa SGP) que acota el alcance de un usuario.
- **Rol → Permisos**, **Usuario → Roles**, **Usuario → Dimensiones**: el grafo de autorización que después consume el WS de Seguridad.
- Operaciones frecuentes de copia: copiar accesos de usuario, copiar dimensiones, copiar permisos a usuarios, replicar/copiar un entorno.

## 3. Cómo levantar el proyecto

- **Frontend:** `cd security-console-client && yarn install && yarn dev` → `https://localhost:3002`. Necesita licencia Kendo activada localmente y las vars `VITE_APP_AUTH_*` (client id, redirect url, auth mode).
- **Backend:** abrir la solución en `Security-console-server` con Visual Studio / `dotnet`. Dos hosts desplegables: la API de la consola (`Security-console-server`) y el WS de Seguridad (`SecurityApi`). Config en `appsettings.json` / `appsettings.Development.json`.
- **CI:** `azure-pipelines-develop.yml` solo buildea el **cliente** (yarn install → activar licencia Kendo → build → zip → artifact `develop`) al pushear a `develop` tocando `security-console-client`.

## 4. Notas de flujo
- Trabajo sobre `develop`. Convención de commits del repo: `#<numeroTicket>: <descripción>` y merges vía PR (`Merged PR NNNN: #ticket ...`).
- Los tickets salen de Azure DevOps (org `grupocapsa`, proyecto `ConsolaSeguridadWeb`).
