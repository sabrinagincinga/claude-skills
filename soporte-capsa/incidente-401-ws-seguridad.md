# Incidente — 401/IIS desde el WS de Seguridad (jun 2026)

Contexto de un incidente de producción y, sobre todo, del **modelo de seguridad SGP ↔ WS de Seguridad**, que es reutilizable para futuros análisis. Documentado a partir del análisis de junio 2026.

> Nota de nombres: en este incidente el sistema se referencia como **SGP** (repo `SGP-server`, URL `sgpac.grupocapsa.net`), y el servicio de permisos como **WS / Consola de Seguridad** (repo aparte `ConsolaSeguridadWeb/Security-console-server`, URL `csa.grupocapsa.com.ar`). Tener presente la posible relación con el "SGO" del contexto general — usar los nombres tal como aparecen en cada repo/mail.

## Componentes

- **SGP** — backend .NET Core API + React. Repo `SGP3.0/SGP-server`.
- **WS de Seguridad (SecurityApi)** — servicio aparte que **provee permisos y dimensiones** a todas las apps. Repo `ConsolaSeguridadWeb/Security-console-server` (proyectos `Security-console-server` = consola web, y `Security-console-server.SecurityApi` = la API que consume SGP). **Hosteado detrás de IIS** (`UseIIS()`/`UseIISIntegration()`), autenticación **JWT Bearer** (`AddMicrosoftIdentityWebApi`, Azure AD).

## Modelo de seguridad SGP (hechos no obvios y reutilizables)

Hay **dos autenticaciones distintas** que conviene no confundir:

1. **Sesión del usuario contra SGP (cookie).** Los **permisos y dimensiones se consultan al WS UNA sola vez, en el login** (`ExternalSignInCapsaController.Correlate` → `SecurityClient.Login`) y quedan horneados como claims en la cookie (válida 24 h). `NovedadesHandler` y demás handlers validan con `IHttpContextService.IsInRole(...)`, que lee de `HttpContext.User` (la cookie), **no del WS**.
   - ⇒ **La validación de permisos de un usuario ya logueado NO depende del WS en runtime.** Si el WS está caído, el chequeo de roles igual pasa.

2. **Token delegado de SGP para *llamar* al WS.** Varias operaciones sí le pegan al WS **en runtime**, vía `IDownstreamApiForUserService` → `GetForUserAsync("SecurityApi", ...)` (token OBO de vida corta ~1h, cacheado en SQL `Cache` table). Ejemplos:
   - Crear/guardar novedad → `ServicioNovedad.ConfigurarEntidadNovedad` → `CompletarNombreUsuarios` → `_securityClient.GetUsuario(novedad.Autor)` (resuelve nombre del autor).
   - `GetAutores` (al abrir "nueva novedad").
   - **Permisos de Trabajo** → `GetUsuariosConPermisos` / `GetUsuariosConDimensiones`.
   - ⇒ Si el WS falla en estas llamadas, **la operación rompe**. Hoy se traduce en un **500 opaco** ("Oops, algo salió mal"): el fallo del downstream no está manejado.

## Cómo distinguir un fallo de app vs un fallo de infra (IIS) en el WS

Clave diagnóstica reutilizable:

- El **SecurityApi nunca devuelve una página HTML** ante un 401:
  - 401 de la app = **body vacío** + header `WWW-Authenticate: Bearer` (lo emite el middleware de auth; ni siquiera pasa por el exception handler).
  - El `ErrorController` solo atrapa **excepciones no manejadas** y devuelve **ProblemDetails JSON** (`Problem(...)`), nunca una vista Razor.
- Por lo tanto, una respuesta HTML tipo **`Server Error` / `401 - Unauthorized: Access is denied due to invalid credentials`** (charset iso-8859-1, fuente Verdana) es la **página por defecto de IIS** → el rechazo es a **nivel de infraestructura/hosting**, antes de entrar a la app.
- **Confirmación rápida:** mirar el `Content-Type` de la respuesta 401. `text/html` ⇒ IIS/infra. Vacío o `application/json` ⇒ app.
- **Prueba de campo:** navegar a `csa.grupocapsa.com.ar` **sin VPN** devuelve esa misma página 401 ⇒ confirma que el 401 es una **condición de acceso a nivel de red/IIS** (la que normalmente habilita la VPN / allowlist de IP).

### Cómo se ve un 401 *real de la app* (vs el de IIS)

Para diagnósticos futuros, comparar la respuesta:

| | **401 de la app (SecurityApi)** | **401 de IIS (infra)** |
|---|---|---|
| Body | **Vacío** (`Content-Length: 0`) | **Página HTML** "Server Error / 401 - Unauthorized: Access is denied due to invalid credentials" |
| `Content-Type` | Ausente (no hay body) | `text/html; charset=iso-8859-1` |
| `WWW-Authenticate` | **Presente:** `Bearer error="invalid_token", error_description="..."` (token vencido/ausente/firma inválida) | Normalmente ausente, o `Negotiate`/`NTLM` si fuera Windows Auth |
| Origen | Middleware JWT Bearer (Kestrel/ASP.NET Core) | IIS, **antes** de entrar a la app |
| Causa típica | Token OBO vencido o no enviado, scope/audience mal | Allowlist de IP / restricción de red / Windows Auth |

- Si alguna vez aparece un **403** desde la app (no 401), eso **sí** sale del `ErrorController` como `RolesException` → `Problem(... status 403 "Forbidden")` en **JSON** (`application/problem+json`). Tampoco es HTML.
- Regla práctica: **HTML ⇒ infra/IIS. Body vacío con `WWW-Authenticate: Bearer` ⇒ token/app. JSON `problem+json` ⇒ regla de negocio/autorización de la app.**

## El incidente concreto

- Semana previa: problema de **DNS** hacia el WS (Infra confirmó resuelto el viernes).
- Esta semana: usuarios **no pueden cargar novedades**; luego se sumó **Permisos de Trabajo**. **Reiniciar la app** da alivio temporal y el problema vuelve al rato.
- El 500 que ve SGP lleva embebido un **401 en HTML** (page de IIS) desde el WS ⇒ no es DNS (ya resuelto) ni token vencido ni bug del último pasaje (confirmado: el último pasaje **no tocó seguridad/auth**).
- **Hipótesis original (a confirmar con Infra):** la config de IIS/allowlist quedó inconsistente y el tráfico se balanceaba por distintos caminos ⇒ las peticiones que caían por el camino malo daban 401 ⇒ **intermitencia** ("a algunos sí, a otros no", "el reinicio ayuda un rato"). Posible coletazo del incidente de DNS.
- **Ticket:** `SCA-30827` en Jira (`grupocapsa.atlassian.net`), creado por Cyn. (Capsa usa Jira para algunos tickets de soporte además de Azure DevOps.)

## Resolución (CONFIRMADA por Infra)

**Marcos Andres Milohanich** (Infra — CAPSA CAPEX) confirmó la causa raíz, alineada con la hipótesis:

> Faltaba agregar la **IP de NATeo del enlace nuevo** (el que se sumó la semana pasada) en el **allow list del web site de la consola de seguridad**. Por eso el problema era **aleatorio**: sucedía cuando la **SD-WAN** mandaba una sesión de tráfico por ese enlace. Ya quedó agregada → no debería volver a pasar.

Es decir: **allowlist a nivel del web site (IIS) en la consola de seguridad**, e intermitencia por **balanceo de la SD-WAN entre enlaces** (no por nodos detrás de un LB, como se planteó; el mecanismo es el enlace de salida, no el servidor de destino). El 401 era la página de IIS exactamente como anticipaba el análisis del código. Confirmado además que **no fue el último pasaje de SGP** ni el DNS en sí (aunque el enlace nuevo se sumó en el marco de esos cambios de red).

## Detalle técnico del 500 (confirmado con el error completo)

El JSON de error capturado confirma el diagnóstico al 100%. Datos clave:

- El **body HTML de IIS viene embebido en el campo `title`** del ProblemDetails (la página "Server Error / 401 - Unauthorized: Access is denied due to invalid credentials", `charset=iso-8859-1`). `status: 500`.
- **Path exacto del fallo** (este caso fue al **abrir el formulario / cargar autores**, un GET — no el guardado):
  `NovedadesController.GetAutores` → `ServicioNovedad.GetAutores` (línea 534) → `ObtenerAutores` (línea 1257) → `SecurityClient.GetUsuariosConDimensiones` (POST `ObtenerUsuarios`) → `DownstreamApiForUserService.ExecuteWithAuthenticationCheck` (línea 59) → `DownstreamApi.PostForUserAsync` → **`DownstreamApi.DeserializeOutput`** ← acá explota.
- **Por qué termina en 500 y no se maneja:** `DownstreamApi` recibe la respuesta 401 con body **HTML** e intenta **deserializarla como JSON** → lanza en `DeserializeOutput`. Pero `ExecuteWithAuthenticationCheck` solo atrapa `MicrosoftIdentityWebChallengeUserException` o `MsalUiRequiredException` ([DownstreamApiForUserService.cs:55](../../../source/repos/SGP3.0/SGP-server/SGP-server.ClientServices/Services/DownstreamApiForUserService.cs#L55)). Una falla de deserialización **no es** ninguna de esas dos ⇒ **no se captura** ⇒ se propaga como 500. O sea: el 401 del WS ni siquiera se reconoce como problema de auth; se lo trata como una respuesta cuyo body no parsea.

## Pendientes / próximos pasos

1. ~~Capturar el error completo / pedir a Infra revisar IIS-allowlist~~ → **resuelto por Infra** (IP de NATeo del enlace nuevo agregada al allow list). Error completo capturado y confirmado.
2. **Validar con usuarios** que dejó de reproducirse y **cerrar `SCA-30827`**.
3. Mejora en **SGP** (pendiente, independiente de la causa raíz): hacer resiliente la llamada al WS. Concretamente en `DownstreamApiForUserService.ExecuteWithAuthenticationCheck`: **ampliar el manejo** para contemplar respuestas HTTP no exitosas / fallo de deserialización (hoy el `catch` solo cubre `MsalUiRequiredException`/`ChallengeUserException`), y devolver un mensaje claro tipo "servicio de seguridad no disponible" en vez del 500 opaco. Aplica a todo lo que pega al WS: `GetAutores`/`ObtenerAutores`, guardado de novedades (`GetUsuario`) y Permisos de Trabajo (`GetUsuariosConPermisos`/`GetUsuariosConDimensiones`).

## Para comunicar el incidente

Planteamiento usado en el mail: la hipótesis de causa raíz se presenta como **preguntas a Infra** ("¿Es posible que…?"), no como afirmación. Solo se afirma con firmeza lo que el código respalda al 100%: que **la app no genera esa página HTML** (⇒ el 401 es de IIS/infra) y que se reproduce **sin VPN**. El resto queda como hipótesis abierta hasta tener el error completo.
