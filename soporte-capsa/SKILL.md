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
