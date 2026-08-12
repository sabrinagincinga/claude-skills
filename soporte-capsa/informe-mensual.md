# Informe mensual de horas (Seguimiento ENTA → Capsa)

Informe de estatus **mensual** dirigido al **cliente (Grupo Capsa) y al equipo**. Resume el
esfuerzo (horas) y la actividad del mes vencido, dentro del ejercicio anual en curso.

- **Archivo entregable:** PDF de 6 páginas, nombrado `Resumen_MES-AÑO.pdf` (ej: `Resumen_Julio-2026.pdf`).
- **Cuándo se arma:** con el mes ya cerrado, alrededor de mediados del mes siguiente
  (ej: el de junio se publicó el 22/07; el de julio, el 12/08). La fecha de publicación va en la portada.
- **Fuente de los datos:** dashboard de Azure DevOps
  `https://grupocapsa.visualstudio.com/SGO/_dashboards/dashboard/b1752fce-e92a-4a73-a759-4e5db60c581b`

## Qué datos hacen falta (capturas del dashboard)

Sabrina comparte capturas de los widgets. Cada uno alimenta una parte del informe:

| Widget del dashboard | Aporta |
|---|---|
| **Esfuerzo (hs) Mes Pasado** (dona) | Horas del mes por proyecto + total → donut de portada interna |
| **Cantidad de Ticket Mes Pasado** (dona) | Tickets resueltos en el mes + total |
| **Esfuerzo Mes por Dev** (matriz) | Horas por persona (interno; no se incluye en el PDF al cliente) |
| **Tickets pendientes** (dona) | Pendientes del ejercicio, por proyecto |
| **Tickets realizados este ejercicio** (dona) | Realizados acumulados del ejercicio |
| **Esfuerzo por tipo de Ticket** (dona) | PBI / Task / Bug acumulados |
| **Esfuerzo Total por Mes** (matriz pivot) | Horas por mes y por proyecto → tabla "Esfuerzo acumulado" |
| **Cantidad de Reclamos en el Ejercicio** | Casi siempre 0 |
| **Esfuerzo en Tickets Críticos** (barras) | Horas de críticos del ejercicio |
| **Esfuerzo PowerApps por mes** (barras) | Horas Power Platform por mes |
| **Esfuerzo PoweApps por tipo de ticket** (dona) | PBI / Task / Bug de Power Platform |
| **Esfuerzo por Solución** (dona) | Reparto de Power Platform por solución |

## Estructura del PDF (6 páginas)

1. **Portada** — logo ENTA, "Seguimiento Enta Consulting / Informe MES AÑO", Versión, Fecha de Publicación, "IT Capsa-Capex", índice.
2. **Introducción** (lista de sistemas mantenidos + nota del ejercicio) + **donuts** "Esfuerzo (hs) Mes Pasado" y "Cantidad de Ticket Mes Pasado".
3. **Tickets pendientes / realizados** (dos donas) + tabla mensual (# Tickets: Pendientes / Realizados por mes) + **Esfuerzo acumulado** (tabla pivot por mes/proyecto) + línea "ESFUERZO: N hrs.".
4. **Esfuerzo por tipo de Ticket** (dona) + **Cantidad de Reclamos** (Total 0) + encabezado "Esfuerzo en Tickets Críticos".
5. **Gráfico de críticos** + texto + **Fuente de la Información** (URL) + **tabla "Resumen de esfuerzo Soporte (Desarrollo) según planificación"**.
6. **Power Platform** — tres gráficos + "Esfuerzo este mes" + "Planificado a la fecha" + **tabla "Resumen de esfuerzo Power Platform según planificación"**.

## Datos fijos (no cambian mes a mes)

- **Ejercicio:** 1 de mayo → 30 de abril. El informe indica el ejercicio en curso (ej: 2026/2027).
- **Planificación mensual Soporte (Desarrollo):** **480 h/mes**.
- **Planificación mensual Power Platform:** **160 h/mes**.
- **Índice de reclamos:** con 0 reclamos → "0 => 0 % < al 10%".
- **Sistemas mantenidos** (lista de la introducción): SGO (.Net), Gestión de Plantas (.Net CORE – React), Recorridas Operativas (Power Apps), otros proyectos legacy (.Net), Gestión de Partes Calientes (.Net CORE – React), Consola de Seguridad (.Net CORE – React), Cuadrillas (.Net), Tubulares (.Net CORE – Angular).

## Fórmulas (tablas de planificación)

- **Saldo mensual** = horas ejecutadas del mes − horas planificadas del mes.
- **Saldo acumulado** = saldo acumulado del mes anterior + saldo mensual del mes.
- **Fila Total** = suma de planificadas, suma de ejecutadas, y el saldo acumulado final (que coincide con la suma de saldos mensuales).
- **"ESFUERZO: N hrs."** (headline de la pág. 3) = suma de los totales mensuales del pivot "Esfuerzo Total por Mes" (= total de ejecutadas de la tabla de Soporte).

## Continuidad mes a mes

Cada informe **agrega una fila/columna** al anterior y **arrastra** los saldos acumulados. Las filas de meses previos deben quedar **idénticas** al informe anterior; solo se suma el mes nuevo. Conviene tener a mano el PDF del mes anterior para copiar los valores previos sin recalcular.

## Inconsistencias a vigilar antes de publicar

Algunas queries del cliente **no tienen bien el filtro de Activity** y traen números inflados. Verificar siempre:

1. **Filtro de Activity (la causa más común).** Las queries de **"Tickets realizados este ejercicio"** y **"Esfuerzo por tipo de Ticket"** deben excluir las Activity que no son desarrollo, con el filtro **`Activity Not In (Requirements, Testing, Design)`**. Si ese filtro falta, esas queries cuentan también los tickets funcionales / QA / diseño y quedan infladas. **Control rápido:** el total de "Esfuerzo por tipo de Ticket" tiene que **coincidir** con el total del pivot "Esfuerzo Total por Mes"; si no coincide, falta el filtro. *(Caso julio 2026: sin el filtro, tipo daba 1.910 y realizados 233; con el filtro aplicado, tipo dio 1.753 —igual que el pivot— y realizados 183.)*
2. **Realizados este ejercicio.** Si salta fuerte de un mes a otro, casi siempre es el filtro de Activity del punto 1; contrastar con la cantidad de tickets del mes (sanity-check).
3. **Área "SGO" pelada.** En las pivots por módulo, ignorar filas con Area Path `SGO` sin módulo (no corresponden a un módulo concreto).
4. **Power Platform planificado.** La tabla usa **160 h/mes**. (En el informe de mayo el texto decía "120 h/mes" pero la tabla usaba 160; se unificó en 160.)

## Histórico del ejercicio 2026/2027 (para continuidad)

**Esfuerzo Total por Mes (pivot, horas):**

| Mes | ConsolaSeg | SGO | SGP3.0 | Cuadrillas | Total |
|---|---|---|---|---|---|
| 01 - MAY 26 | 12 | 519 | 54 | 0 | 585 |
| 02 - JUN 26 | 4 | 501 | 78 | 21 | 604 |
| 03 - JUL 26 | 2 | 520 | 26 | 16 | 564 |

**Soporte (Desarrollo) — planificado 480/mes:**

| Mes | Ejecutadas | Saldo mensual | Saldo acumulado |
|---|---|---|---|
| Mayo | 585 | +105 | +105 |
| Junio | 604 | +124 | +229 |
| Julio | 564 | +84 | +313 |

**Power Platform — planificado 160/mes:**

| Mes | Ejecutadas | Saldo mensual | Saldo acumulado |
|---|---|---|---|
| Mayo | 115 | -45 | -45 |
| Junio | 148 | -12 | -57 |
| Julio | 120,5 | -39,5 | -96,5 |

**Otros acumulados a fin de julio 2026** (con el filtro de Activity aplicado): Pendientes 19 · Realizados 183 · Tipo de ticket: PBI 855 / Task 547 / Bug 351 (total 1.753, = pivot) · Críticos 5 hs (solo mayo) · Reclamos 0.

## Cómo se genera

El PDF replica el formato del cliente. Se recrean los gráficos con **matplotlib** (donas con total al centro, pivot como barras/tabla coloreada, barras de meses) usando la paleta del dashboard (SGO cian, SGP3.0 naranja/rojo, Cuadrillas gris, ConsolaSeg violeta/dorado; tipos: PBI azul, Task amarillo, Bug rojo) y se arma el documento de 6 páginas con **reportlab**, tomando el PDF del mes anterior como referencia de layout. Los scripts base de un mes sirven de plantilla para el siguiente: solo se actualizan los datos y se agrega el mes nuevo.
