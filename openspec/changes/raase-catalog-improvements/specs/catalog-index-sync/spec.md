# Catalog Index Sync Specification

## Purpose

Pasos de cierre obligatorios del change: sincronía de los índices del catálogo, validador strict como gate y preservación de los conteos del registro (39 entradas / 610 micro-skills / 35 dominios).

## Requirements

### Requirement: Sincronía de los tres índices

Toda edición del catálogo MUST quedar reflejada en `skills-roblox/SKILLS.md`, `skills-roblox/AGENTS.md` y `skills-roblox/.atl/skill-registry.md` (regenerado con la skill `skill-registry` si está desactualizado), de modo que la lista de 39 skills y sus descripciones coincidan con los archivos `SKILL.md` finales. Si ninguna descripción cambia, los índices MUST permanecer sin modificación (verificación no-op explícita).

#### Scenario: Índices reflejan la edición

- GIVEN una skill editada cuya descripción cambió
- WHEN el lector compara índices y archivos `SKILL.md`
- THEN los tres índices muestran la descripción final

#### Scenario: No-op verificado

- GIVEN ediciones que no cambian descripciones
- WHEN se comparan los índices contra la línea base
- THEN los tres permanecen sin cambios

### Requirement: Validador strict como gate de cierre

El cierre MUST ejecutar el validador del catálogo en modo strict desde la raíz del repo (`validate-skills.mjs "skills-roblox" --strict`) y MUST obtener 39/39 evaluaciones exitosas con exit 0.

#### Scenario: Gate verde

- GIVEN el catálogo editado
- WHEN se ejecuta el validador strict
- THEN la salida reporta 39/39 pass, 0 errores
- AND el exit code es 0

### Requirement: Conteos y registro intactos

El catálogo MUST mantener 39 entradas, 610 micro-skills y 35 dominios. MUST NOT crear micro-habilidades numeradas nuevas: las adiciones van en reglas existentes o en anexos no numerados.

#### Scenario: Conteos sin cambios

- GIVEN el catálogo final
- WHEN se cuentan entradas, micro-skills y dominios
- THEN los valores son 39 / 610 / 35

#### Scenario: Sin reglas numeradas nuevas

- GIVEN los archivos editados (`roblox-02`, `roblox-04`, `roblox-07`, `roblox-09`, `roblox-35`, `roblox-36`)
- WHEN se revisan los rangos numerados de cada dominio
- THEN no aparece ningún ítem numerado fuera de los rangos existentes

### Requirement: Prohibición de cambios en raase_skills.json

`agent/raase_skills.json` MUST NOT modificarse en este change.

#### Scenario: Registro intacto

- GIVEN el diff del change
- WHEN se inspecciona `agent/raase_skills.json`
- THEN no hay cambios
