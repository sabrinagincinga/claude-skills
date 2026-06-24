# claude-skills

Fuente de verdad de mis skills de Claude Code. Cada carpeta de primer nivel es un skill
(contiene su `SKILL.md` y archivos de apoyo).

## Estructura

```
claude-skills/
  soporte-capsa/
    SKILL.md                      # skill de contexto del cliente Grupo Capsa
    incidente-401-ws-seguridad.md # conocimiento técnico referenciado por el skill
  deploy.ps1                      # copia los skills del repo a ~/.claude/skills
  README.md
```

## Regla de oro

**Se edita acá, en el repo.** Este repo es el original; las copias en
`~/.claude/skills/` (local) y en Cowork son derivadas. Si editás en otro lado,
traé el cambio de vuelta al repo antes de commitear, o se pierde en el próximo deploy.

> No usamos symlink porque en Windows requiere privilegios de administrador
> (Developer Mode desactivado). Por eso el sync es por copia.

## Sincronizar con Claude Code local

Después de clonar, hacer `git pull`, o editar un skill:

```powershell
./deploy.ps1
```

Copia cada carpeta de skill del repo a `~/.claude/skills/<skill>/`, pisando la versión
anterior. Reiniciá la sesión de Claude Code para que recargue los skills.

## Sincronizar con Cowork

Cowork (nube) no lee tu disco local. Para actualizar un skill allá, traé el contenido
del `SKILL.md` correspondiente desde este repo (copiar/pegar o importar). Mantené el
repo como única referencia.

## Encoding

Guardar siempre como **UTF-8 sin BOM**. Si al mover un archivo entre ambientes aparecen
caracteres rotos (`migraciÃ³n` en vez de `migración`), es que se guardó con otra
codificación: recuperar desde el repo.
