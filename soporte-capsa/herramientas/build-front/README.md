# build-front

Scripts para compilar el front de SGO (repo **SGOReact**, un módulo React por carpeta) y
copiar los builds al repo back.

| Script | Qué hace |
|---|---|
| [`build-all.ps1`](build-all.ps1) | `yarn install` + `yarn build` en cada carpeta con `package.json` (y `yarn build:shell` donde exista: hoy solo `aperturas`, que compila también el Shell). Sigue aunque un módulo falle y al final lista los fallidos; si hubo alguno, termina con exit code 1. |
| [`copiar-dist.ps1`](copiar-dist.ps1) | Copia el build de cada módulo al repo back, en la subcarpeta que sale del `base:` de su `vite.config.ts` (Bombas es CRA: usa `build` y el `homepage` del `package.json`). Antes de copiar limpia la carpeta destino. |

## Cómo usarlos

1. Copiar los dos `.ps1` a la **raíz del repo SGOReact**: la carpeta de trabajo se toma de la
   ubicación del script.
2. Correr `.\build-all.ps1`.
3. Solo si terminó sin fallidos, correr `.\copiar-dist.ps1`. Si un módulo falló, puede quedar un
   build viejo en disco y se copiaría como si fuera nuevo.

## Antes de correr `copiar-dist.ps1`

- Revisar `$destRoot` al inicio del script. El default es
  `%USERPROFILE%\source\repos\SGO\SGOreact`; si el repo back está en otra ubicación
  (por ejemplo `source\repos\SGODevelop\SGO`), ajustarlo.
- **Escribe en el repo back** (borra y reemplaza las carpetas de cada módulo). Para validar
  que un merge del front compila alcanza con `build-all.ps1`.

## Requisitos

- `yarn` en el PATH.
- Acceso al registro de paquetes para el `yarn install`.
