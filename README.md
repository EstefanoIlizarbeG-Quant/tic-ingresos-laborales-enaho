# TIC e ingresos laborales con ENAHO 2023–2025

Análisis de la relación entre uso de computadora, actividades informáticas e ingresos laborales en Lima Metropolitana y Callao, según condición de informalidad.

**Autor:** Estéfano Ilizarbe.

El proyecto reúne construcción y validación de datos, estimaciones MCO con errores agrupados, diagnósticos, análisis de sensibilidad y un ejercicio de selección de Heckman. Las estimaciones se realizan en **Stata** y las figuras se reconstruyen en **Python**.

## Estado de publicación

Ya están disponibles el código, la documentación, 27 tablas agregadas y cinco logs revisados. Las figuras se incorporarán en el tercer bloque.

| Carpeta o archivo disponible | Contenido |
|---|---|
| `stata/` | Configuración, master y programas de estimación y diagnóstico. |
| `python/` | Programa de reconstrucción de figuras. |
| `resultados/tablas/` | 27 tablas agregadas exportadas de Stata. |
| `resultados/logs/` | Cinco registros históricos con rutas locales sustituidas y listados individuales omitidos cuando corresponde. |
| `docs/` | Reproducción, alcance y trazabilidad. |
| `datos/README.md` | Entradas y tratamiento de los datos locales. |
| `requirements.txt` | Dependencias de Python. |

## Datos y muestras

- Fuente: ENAHO 2023–2025; 2022 se utiliza para una validación complementaria.
- Muestra MCO: **18 065 observaciones**: 6 090 de 2023, 6 004 de 2024 y 5 971 de 2025.
- Inferencia principal de los resultados aportados: **772 conglomerados/subconglomerados**.
- Heckman-Mincer principal: **28 363 observaciones**, con **18 069 seleccionadas**. Se documenta por separado de la muestra TIC.

Las comparaciones se interpretan como **asociaciones condicionales**. Los descriptivos sin ponderación describen la muestra analizada.

## Resultados disponibles

| Análisis | Tablas |
|---|---:|
| [Sensibilidad de MCO](resultados/tablas/07_sensibilidad/) | 3 |
| [Diagnósticos de MCO](resultados/tablas/08B_diagnosticos/) | 3 |
| [Forma funcional de la educación](resultados/tablas/08C_educacion/) | 4 |
| [Asociaciones y brechas TIC](resultados/tablas/08D_TIC/) | 3 |
| [Tipo de trabajador](resultados/tablas/08E_tipo_trabajador/) | 6 |
| [Comparabilidad y composición anual](resultados/tablas/08_comparabilidad/) | 4 |
| [Selección de Heckman](resultados/tablas/10_Heckman/) | 4 |

Los [logs](resultados/logs/) documentan ejecuciones previas aportadas por el autor. Las copias públicas omiten los listados de observaciones individuales y conservan las estimaciones y los resúmenes agregados.

## Ejecutar en Stata

Se requiere Stata 17 o posterior y los módulos originales detallados en [la guía de reproducción](docs/reproduccion.md).

Desde la raíz del repositorio, configure las rutas locales en `stata/00_configuracion.do` y ejecute:

```stata
do "stata/00_configuracion.do"
do "$ENAHO_REPO/stata/master_enaho_2023_2025.do"
do "$ENAHO_REPO/stata/10_Heckman_estimacion_y_pruebas.do"
```

El master contiene las etapas 01–08E. La etapa 10 de Heckman se ejecuta por separado.

## Generar las figuras en Python

Instale las dependencias desde la raíz del repositorio:

```bash
python -m pip install -r requirements.txt
```

El siguiente comando utiliza las tablas incluidas para generar siete figuras con resultados agregados:

```bash
python python/graficos_enaho.py
```

Para generar las 18 figuras se necesitan además las bases locales `base_mco_complemento_etapa08E.dta` y `base_heckman_estimacion_etapa10.dta`:

```bash
python python/graficos_enaho.py --datos-privados /ruta/a/bases_locales
```

Consulte [los datos requeridos](datos/README.md) y [la trazabilidad](docs/trazabilidad.md).

## Validación y alcance

Se comprobaron la estructura de las 27 tablas, el rango de sus valores p y el orden de los intervalos disponibles. Los CSV conservan los valores exportados por Stata. La generación de las siete figuras se verificó con las tablas incluidas.

Las copias Stata adaptan las rutas y añaden una comprobación de configuración; la lógica estadística aportada se conserva. Su ejecución integral sigue pendiente. Los resultados documentados corresponden a ejecuciones previas del autor.

Los microdatos y el manuscrito se conservan fuera de esta entrega. Consulte [el estado y alcance](docs/estado_y_alcance.md).
