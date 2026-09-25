---
name: soporte-capsa
description: >
  Skill de contexto experto para el trabajo de soporte y migración del cliente Grupo Capsa.
  Activar manualmente cuando se vaya a trabajar cualquier tarea relacionada con Capsa:
  redacción de mails o comunicaciones, planificación de evolutivos, gestión de work items
  en Azure DevOps, revisión de código del proyecto SGO, reportes de horas, o cualquier
  consulta sobre procesos del equipo. Una vez activado, Claude tiene contexto completo del
  proyecto, el equipo, los procesos y el estilo de comunicación — no hace falta re-explicar nada.
---

# Contexto experto — Soporte Capsa

## 1. Contexto del proyecto

**Cliente:** Grupo Capsa
**Sistema:** SGO (Sistema de Gestión Operativa)
**Proveedor:** ENTA Consulting
**Responsable de cuenta / PM funcional:** Sabrina (la usuaria de este skill)

### Ejercicio anual
El ejercicio anual comienza el **1 de mayo** de cada año. Las iteraciones en Azure DevOps siguen este calendario (ej: el ejercicio 2025-2026 va de mayo 2025 a abril 2026).

### Proyecto de migración
SGO está siendo migrado de **.NET Framework 4.5 MVC** a **.NET Core API + React**.
- La migración está en curso — hay ramas activas y un equipo de desarrollo trabajando en paralelo con el soporte habitual.
- Los **evolutivos de migración** son features del sistema legacy que surgieron durante el proceso de migración: cosas que estaban en el sistema viejo y que hay que trasladar o validar en el nuevo. Son en su mayoría cortos (bug-like), no parten de especificaciones nuevas sino del comportamiento anterior en el sistema legacy.

### Estructura Azure DevOps
- **Proyecto DevOps:** SGO
- **Area Paths de migración:** `SGO\Migracion\ModuloXX` — exclusivo del proyecto de migración, NO aparece en queries ni tableros de soporte habitual.
- **Area Paths de soporte:** `SGO\GF12 - Instalaciones`, `SGO\GF05 - Perforaciones`, etc. — son los que se usan en el flujo estándar.
- **Iteraciones:** `SGO\Ejercicio 2025-2026\08 - MES AÑO` (ej: `SGO\Ejercicio 2025-2026\08 - JUL 26`)
- **Tipos de work item:** Bug, Task, PBI (Product Backlog Item). Los evolutivos de migración están cargados como Tasks.

### Módulos de evolutivos (22 módulos)
Hay 22 módulos de evolutivos pendientes de la migración. El **Módulo 20** es especial:
- Es de tipo **validación**: ¿el ticket fue desarrollado en la migración o no?
- Si **SÍ** → valida y cierra rápido.
- Si **NO** → implementar tomando como referencia el desarrollo legacy (sin especificación formal requerida, ya que se basa en el comportamiento anterior).
- Por esto tiene una velocidad diferente (~7T/sem vs ~6T/sem estándar) y se marca con ⭐ en la planificación.

---

## 2. El equipo

### Composición general
El equipo cuenta con **3 desarrolladores, incluyendo a Sabrina**. Sin embargo, Sabrina está mayormente enfocada en tareas administrativas y de liderazgo: reuniones, resolución de bloqueos, code review, documentación y coordinación general. No codea con frecuencia en el día a día actual.

**Visión de evolución del equipo:** encaminarse hacia un equipo más autónomo en conocimiento de negocio, uso de IA en desarrollo y organización. Para esto se planea aplicar KPIs. El objetivo final es que Sabrina pueda aportar más en términos de desarrollo a medida que el equipo gane independencia.

### Capacidad para evolutivos de migración (contexto específico)
Lo siguiente aplica **exclusivamente al trabajo de los evolutivos pendientes de la migración SGO**, no al soporte general:
- **2 desarrolladores + 1 QA** al **30% de dedicación**.
- Disponibilidad: **2 devs × 1,5 días/semana cada uno** (o 1 dev × 3 días — capacidad equivalente, depende del flujo de soporte).
- Sabrina no cuenta en esta capacidad ya que su foco es la coordinación.

### Velocidades estimadas (evolutivos)
| Rol | Tarea | Velocidad |
|-----|-------|-----------|
| Dev (estándar) | Tickets evolutivos | ~6 tickets/semana |
| Dev (Módulo 20 ⭐) | Validación + eventual impl. | ~7 tickets/semana |
| QA | Creación de TCs (formalización en doc) | ~8 TCs/semana (~45 min/ticket) |
| QA | Ejecución de TCs | ~10 ejecuciones/semana |
| Full team (S12+) | Ejecución (3 personas) | ~40 ejecuciones/semana |

### Creación de TCs
Los tickets ya tienen evidencia de prueba en el ticket original (capturas, comentarios, validaciones). Esta evidencia sirve de base, pero la formalización implica: trasladar al documento de TCs, ordenar los pasos, entender el contexto. Por eso se estima ~45 min por ticket aunque la evidencia ya exista.

### Planificación de evolutivos (referencia)
- **S1–S11:** Dev trabaja módulos, QA crea TCs + ejecuta en paralelo.
- **S12–S14:** Dev cierra desarrollo (fin S11) y se une a QA ejecución. Full team ~40 ejec/sem.
- **Fecha de cierre acordada con el cliente:** semana 14, septiembre 2026.

---

## 3. Forma de trabajo

### Gestión semanal de evolutivos en Azure DevOps — conversión Task → PBI
Antes de arrancar cada semana con los evolutivos planificados:
1. **Convertir** las Tasks de esa semana de Task → PBI.
2. **Area Path:** tomar el del ticket de soporte asociado (ej: `SGO\GF12 - Instalaciones`), NO mantener el de migración.
3. **Iteration:** asignar la del mes de trabajo (ej: `SGO\Ejercicio 2025-2026\08 - JUL 26`).
4. **Progresivo:** solo se convierten los de esa semana — no el backlog completo.

Esto permite que los tickets queden visibles en las queries y reportes de soporte del módulo correspondiente, manteniendo el vínculo con el ticket original de migración.

### Reglas de conteo del tablero de evolutivos (hoja "Estado Actual")

El seguimiento se alimenta del export CSV de Azure DevOps (hoja "Datos Tickets CSV",
que además del ID/Area/State/Title necesita las columnas Work Item Type, Assigned To y Tags).
El módulo sale del Area Path ("...\ModuloXX") o, si el ticket ya se pasó a un Area de
soporte, del título ("Modulo XX"). Métricas:

- **ToDo Dev** = tickets en estado New o To Do.
- **In Progress** = tickets en estado In Progress o Code Review (un PR abierto sigue
  contando como In Progress hasta que se mergea).
- **Terminados Dev** = tickets en Committed, Testing o Done (independiente del tipo y la asignación).
- **TC en prog.** = ticket tipo PBI, en estado Committed y asignado a la Natalia *externa*
  (Externo Natalia Parrello / ext_natalia.parrello@grupocapsa.com.ar) — NO la interna de Enta.
- **TC Hechos** = ticket con la tag `TC_LISTO` o en estado Done (contar sin duplicar los que son ambas cosas).
- **Ejec. en prog.** = ticket tipo PBI, en estado Testing.
- **Done QA** = ticket en estado Done.

Nota: para diferenciar el trabajo de QA se usará una tag (`TC_LISTO` para TC hechos);
otras tags de QA que aparecen en el tablero: ACTUALIZADO TC, IMPLEMENTADO EN TC, NO REQ. ACT. TC, TRIAGE.

### WIP y Code Review (aplica al equipo en general)
- Los tickets en **Code Review cuentan dentro del WIP** del desarrollador — el ticket no está terminado hasta que se mergea.
- El **dueño del PR** es el responsable de hacer avanzar el Code Review: pingar al revisor, hacer follow-up. No hay un WIP limit separado para Code Review porque el mecanismo de control ya existe orgánicamente con el dueño del PR.
- Sabrina es la revisora habitual. Si un ticket está bloqueado en Code Review, el dev debe activarla — no esperar pasivamente.

### Estructura de ramas (migración SGO)
El flujo actual de ramas es:

```
develop → release trunk → master
```

Para actualizar el ambiente de testing:
```
master → rama intermedia (x) → testing
```

Al completar el pasaje de master a producción:
```
testing → release trunk → master
```
En este punto se hace una pasada completa de pruebas por el proyecto y finalmente **se pisa develop con la nueva rama master** (ya probada), llevando todo el desarrollo de la migración a master.

### Compilar el front (SGOReact)

Para instalar dependencias y compilar todos los módulos del front: [`herramientas/build-front/build-all.ps1`](herramientas/build-front/build-all.ps1). Se copia a la raíz de SGOReact y se corre desde ahí. Para llevar los builds al repo back está `copiar-dist.ps1`, en la misma carpeta, pero **escribe en el repo back**: solo con su OK y solo si `build-all` terminó sin fallidos. Detalle en el [README](herramientas/build-front/README.md).

### Acceso a las bases de datos del SGO

Las cadenas de conexión están en `Capsa.OyG.Web/appsettings.Local.json` (archivo local, gitignoreado por `**/*.local.json`). Apuntan a las bases de **ambientes de prueba** — hoy `dasgo02.grupocapsa.net` y `acsgo02.grupocapsa.net`, ambas con catálogo `CapsaOYG3`.

**Regla:**
- **Consultas de sólo lectura (`SELECT`): se pueden ejecutar sin pedir confirmación.** Son ambientes de prueba y el relevamiento de datos es parte normal del trabajo.
- **Cualquier query que no sea de sólo lectura se confirma antes de ejecutarla.** Esto incluye `INSERT`, `UPDATE`, `DELETE`, `MERGE`, DDL (`CREATE`/`ALTER`/`DROP`), `EXEC` de stored procedures que escriban, y correr migraciones contra la base. Mostrar el SQL exacto y esperar el OK.

Antes de asumir que un dato es igual en todas las bases, **relevarlo**: los Ids de las tablas de configuración los asigna SQL Server al insertar y difieren entre bases. Un caso real: los `SistemasExtraccionDynamicFields` de BME/ECS comparten sólo 4 Ids entre `dasgo02` y `acsgo02`, y algunos campos existen en una base y no en la otra. Ver [ef6-migraciones-snapshot.md](ef6-migraciones-snapshot.md) para el tema migraciones.

---

## 4. Estilo de comunicación

Sabrina escribe en un tono **directo, cercano y organizado** — profesional pero sin rigidez corporativa.

### Patrones de sus mails

**Apertura:** "Buenos días," o directo al punto. Nunca "Estimados,".

**Cuerpo:**
- Primera persona singular: "les comparto", "quedo atenta", "quería contarles".
- Conversacional pero estructurado — usa secciones con título en negrita cuando hay varias partes.
- Cuando hay muchos ítems o responsables, usa emojis/íconos para organizar (📌, 📧, ✅).
- Las aclaraciones las da de forma natural: "quería corregir eso:" en lugar de "corresponde aclarar que:".

**Cierre:** "Quedo atenta a cualquier consulta. ¡Saludos!" o "Quedo atenta ante cualquier duda o comentario. Saludos,". Nunca "Quedamos a disposición".

**Firma:** Sabrina tiene firma automática generada por Outlook. No replicar ni inventar una — terminar el mail en el cierre y dejar que Outlook agregue la firma.

### Ejemplos de frases características
- ✅ "Les comparto el archivo de planificación..."
- ✅ "Quería contarles cómo vamos a trabajarlos."
- ✅ "De a poco — solo los de esa semana."
- ✅ "Quedo atenta. ¡Saludos!"
- ❌ "Estimados, nos dirigimos a ustedes para informarles..."
- ❌ "Quedamos a disposición ante cualquier consulta."
- ❌ "Se procederá a la conversión de los work items."
- ❌ [agregar firma inventada — Outlook la pone automáticamente]

### Al redactar para Sabrina
- Escribí en primera persona singular de Sabrina.
- Preferí frases cortas y activas sobre frases largas y pasivas.
- Si hay que corregir algo que se dijo en una reunión, tratalo de forma directa pero sin drama: "quería corregir algo que mencioné en la reunión".
- El tono es el de alguien que conoce bien a su interlocutor y respeta su tiempo.

---

## 5. Incidentes y conocimiento técnico

- **[incidente-401-ws-seguridad.md](incidente-401-ws-seguridad.md)** — Modelo de seguridad SGP ↔ WS de Seguridad (cookie con permisos/dimensiones cacheados en login vs token delegado al WS en runtime) y el incidente de jun 2026: 401 en HTML = página de IIS (infra), no de la app. **RESUELTO** por Infra (faltaba la IP de NATeo del enlace nuevo en el allow list del web site de la consola de seguridad; aleatorio por balanceo SD-WAN). Incluye tabla de cómo distinguir un 401 de la app vs de IIS, el ticket Jira `SCA-30827`, y la mejora pendiente en SGP (manejar el fallo del WS para no devolver 500 opaco). Leer antes de tocar temas de permisos/seguridad de SGP.

- **[paradas-y-cierres-diarios.md](paradas-y-cierres-diarios.md)** — Injerencia de las **paradas** de pozos en los **cierres diarios** del SGO legacy. Qué cierres **bloquean** la edición de una parada: **solo Petróleo, Agua y Gas** (Provisorio o Definitivo); las plantas y LPG **no** bloquean. El cierre toma un **snapshot** de las paradas (horas de marcha → pérdidas localizadas → prorrateo): editar una parada no recalcula un día ya cerrado hasta re-cerrarlo. Injerencia entre días: una **parada Programada multi-día** sí afecta días posteriores, y en áreas **que prorratean** el re-cierre del día editado **no** autocorrige los días posteriores cerrados (hay que reabrirlos/re-cerrarlos a mano). Leer antes de responder consultas operativas sobre apertura de cierres para editar paradas o inconsistencias entre días.

- **[ef6-migraciones-snapshot.md](ef6-migraciones-snapshot.md)** — El error `AutomaticMigrationsDisabledException` de EF6 ("pending changes... automatic migration is disabled"): a qué se debe (snapshot del modelo de la **última migración por Id** desincronizado con el modelo compilado, típico tras nivelaciones/merges), la diferencia entre el **initializer** `MigrateDatabaseToLatestVersion` (lo que aplica migraciones al levantar) y `AutomaticMigrationsEnabled` (migraciones sin archivo), y cómo se resuelve: una nueva migración code-based que refresque el snapshot — **vacía** si el diff son cambios que la base ya tiene (metadata stale), o con el diff si es esquema real (siempre verificar contra la base). Incluye cómo **correr una migración EF6 sin VS2019** (no hay `dotnet ef`; se usa `MigrationScaffolder` por código — ver la herramienta [`herramientas/generar-migracion-ef6/`](herramientas/generar-migracion-ef6/)). Leer antes de tocar migraciones EF6 / diagnosticar ese error.

---

## 6. Proyecto Consola de Seguridad Web (CSA)

- **[proyecto-csa.md](proyecto-csa.md)** — Contexto técnico del proyecto **CSA** (repo `grupocapsa/ConsolaSeguridadWeb`), la app de administración de seguridad de Capsa (usuarios, roles, permisos, dimensiones, aplicaciones, entornos) y contracara administrativa del **WS de Seguridad** que consume SGP (ver [incidente-401-ws-seguridad.md](incidente-401-ws-seguridad.md)). Monorepo: **backend .NET 7** (`Security-console-server`, OData + `GenericCrudController<T>`, Repository/UoW, EF Core Identity, autorización por atributos de permisos, WS de Seguridad como proyecto `SecurityApi` aparte) + **frontend React 18 + Vite** (`security-console-client`, MSAL/Azure AD, Redux Toolkit, KendoReact con licencia, capa REST `entaFetch` sobre OData, patrón Composite/Container/Form). Leer antes de tocar código o tickets de CSA.

---

## 7. Informe mensual de horas (para el cliente)

- **[informe-mensual.md](informe-mensual.md)** — Cómo armar el **informe mensual de seguimiento** (Seguimiento ENTA → Capsa): un PDF de 6 páginas dirigido al cliente y al equipo, con el esfuerzo del mes y el acumulado del ejercicio. Incluye qué **capturas del dashboard** hacen falta y qué aporta cada widget, la **estructura** de las 6 páginas, los **datos fijos** (planificado 480 h/mes Soporte y 160 h/mes Power Platform, ejercicio mayo–abril, fuente del dashboard), las **fórmulas** de saldo mensual/acumulado, las reglas de **continuidad** mes a mes, las **inconsistencias a verificar** antes de publicar (pivot vs tipo de ticket, saltos en realizados, área SGO pelada) y el **histórico del ejercicio 2026/2027** para arrastrar los saldos. Leer antes de armar el informe de un mes nuevo.
