# Paradas y cierres diarios — injerencia y bloqueos

Conocimiento técnico-funcional del módulo de **Cierres Diarios** (área `BalancesCierres`) del SGO legacy, en relación con la edición de **paradas** de pozos. Útil para resolver consultas operativas del cliente sobre "qué cierres tengo que abrir para editar una parada" y para entender inconsistencias entre días.

Rutas clave:
- `Capsa.OyG.Dominio\ProduccionInyeccion\Parada.cs`
- `Capsa.OyG.Servicio\Extensions\ParadaExtension.cs`
- `Capsa.OyG.Servicio\BalancesCierres\ServicioCierreDiarioPetroleoGas.cs`
- `Capsa.OyG.Servicio\BalancesCierres\ServicioCierreDiarioPetroleo.cs`
- `Capsa.OyG.Servicio\ProduccionInyeccion\ServicioParada.cs`
- `Capsa.OyG.Web\Controllers\BaseController.cs`
- `Capsa.OyG.Servicio\BalancesCierres\ServicioCierreDiario.cs`

---

## 1. Qué rol juega la parada en el cierre

La parada no es un dato decorativo: define las **horas de marcha** del pozo y, a partir de ahí, las **pérdidas localizadas** y el **prorrateo** de la producción de batería hacia cada pozo.

Cadena de cálculo (en `ServicioCierreDiarioPetroleoGas.cs`):
- `HorasMarcha = 24 - duraciónParada`
- `PerdidasLocalizadas = duraciónParada * VPV / (24 - duraciónParada)`
- Esos valores se persisten en `VpvPozo` y `VpvPozoDetallePerdida`, y de ahí se totalizan las baterías.

**Punto clave — el cierre toma una FOTO (snapshot).** Al cerrar el día (`CerrarDiaProvisorio`) se lee la parada *en vivo* (`GetParadasPorFechas`), se recalcula y se guarda el resultado. El recálculo se dispara **al cerrar**, no al editar la parada ni al abrir el día (petróleo: `ServicioCierreDiarioPetroleo.cs:697` → `UpdateVpvHorasMarcha`; gas: `ServicioCierreDiarioGas.cs:556`).

Consecuencia: si se edita una parada de un día ya cerrado y **no** se vuelve a cerrar, el snapshot de ese día queda desfasado respecto del dato maestro de la parada. Abrir el día (`AbrirCierre`) solo cambia el estado a *Pendiente* y borra los prorrateos; recién al **re-cerrar** se recalcula.

---

## 2. Qué cierres BLOQUEAN la edición de una parada

**Respuesta corta: Petróleo, Agua y Gas. Las plantas NO.**

La edición / alta / baja de una parada se valida con `ValidarOperacionNoCierreDiario` (`BaseController.cs:228-233`), que llama a `ExistenCierresProvisoriosPetroleoGasAgua(area, díaOperativo)` (`ServicioCierreDiario.cs:326-350`). Ese método mira **solo tres entidades**, para el área y la fecha, en estado **distinto de Pendiente** (es decir, **Provisorio o Definitivo**):

- `CierreDiarioGas`
- `CierreDiarioPetroleo`
- `CierreDiarioAgua`

Si **cualquiera** de los tres está cerrado para ese día/área → lanza `NegocioExceptionProhibido` y no deja tocar la parada.

La baja lo confirma desde otro punto: `ServicioParada.Eliminar` (`ServicioParada.cs:1244-1248`) define explícitamente `tiposCierresBloqueantes = { Petroleo, Agua, Gas }`.

| Cierre diario | ¿Bloquea editar parada? |
|---------------|-------------------------|
| Petróleo | ✅ Sí |
| Agua | ✅ Sí |
| Gas | ✅ Sí |
| Planta de Tratamiento | ❌ No |
| Planta de Polímeros | ❌ No |
| LPG | ❌ No |

**Para habilitar la edición de una parada hay que abrir los tres (Petróleo, Agua y Gas)** de ese día/área. Con que uno solo siga cerrado, queda bloqueada. Las plantas y LPG no hace falta abrirlas.

---

## 3. Injerencia entre días (¿editar el día 5 rompe el 6+?)

Depende de **dos factores**: el **tipo de parada** y si el área **prorratea**.

**Tipo de parada** (`ParadaExtension.cs:44-59`):
- **Diaria** (un solo día): su efecto vive solo en ese día. No toca al día siguiente por sí misma.
- **Programada multi-día** (`FechaInicio`/`FechaFin`, abarca varios días): contribuye a **cada día del rango** (días intermedios cuentan 24 h; el día de `FechaFin` usa `DuracionParadaFin`). Editarla (duración, correr la `FechaFin`) cambia el cálculo correcto de los días posteriores dentro del rango.

**Si el área prorratea o no** — documentado explícitamente en `ServicioCierreDiarioPetroleoGas.cs:60-81`:
> *"…por si se abrió un día y había otros posteriores cerrados. En caso de prorrateo no puedo actualizar más de un día porque los datos dependen del prorrateo; en cambio si no prorratea actualizo hasta el próximo día pendiente o el último cerrado."*

- **Área que prorratea:** al re-cerrar el día 5, el recálculo se limita **solo al día 5** (`fechaHasta = fecha`). **No** toca los días 6, 7 que estén cerrados. → Si la parada afectaba a esos días, **no se autocorrigen**: hay que abrir y re-cerrar cada día posterior afectado, a mano.
- **Área que NO prorratea:** el recálculo avanza desde el día 5 hasta el próximo día pendiente (o el último cerrado). → Los días posteriores cerrados **se recalculan solos** (horas de marcha / pérdidas).

El setting de prorrateo es `CierreDiario_ProrrateaPetroleo` (y equivalente de gas), por área.

**Secuencialidad:** el sistema permite abrir un día anterior dejando los posteriores cerrados (de ahí esa lógica). Cerrar exige que el día anterior esté cerrado (`ValidarCierreDiarioDiaAnterior`, validación mandatoria), pero **abrir no cascadea** hacia adelante. Esa asimetría es la que habilita la inconsistencia.

| Caso | ¿Afecta al día 6+? |
|------|--------------------|
| Parada **Diaria** del día 5 | No al 6. Solo desfasa el día 5 hasta re-cerrarlo. |
| Parada **Programada** que abarca el 6+ | **Sí.** Cambia el valor correcto del 6+. |
| Área **que prorratea** | El re-cierre del 5 **no** arregla el 6+. Reabrir/re-cerrar cada día posterior. |
| Área **que no prorratea** | El re-cierre del 5 **sí** propaga y arregla el 6+. |

**Dato colateral (petróleo):** además de las paradas, el **stock de oleoducto** encadena día a día (stock final → inicial del siguiente). Aun sin paradas, reabrir y modificar un día puede requerir revisar los posteriores por el stock.
