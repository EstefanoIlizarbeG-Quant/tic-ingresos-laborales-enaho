# Trazabilidad de archivos

## Código Stata

| Original | Copia organizada |
|---|---|
| `MASTER ENTREGA FINAL 2023-2025.do` | `stata/master_enaho_2023_2025.do` |
| `07_Precios_y_sensibilidad_MCO.do` | `stata/07_Precios_y_sensibilidad_MCO.do` |
| `08_Comparabilidad_y_composicion_TIC.do` | `stata/08_Comparabilidad_y_composicion_TIC.do` |
| `08B_Diagnosticos_MCO.do` | `stata/08B_Diagnosticos_MCO.do` |
| `08C_Forma_funcional_educacion_integrada.do` | `stata/08C_Forma_funcional_educacion_integrada.do` |
| `08D_Graficos_TIC_e_ingresos.do` | `stata/08D_Graficos_TIC_e_ingresos.do` |
| `08E_Contrastes_TIC_por_tipo.do` | `stata/08E_Contrastes_TIC_por_tipo.do` |
| `10_Heckman_estimacion_y_pruebas.do` | `stata/10_Heckman_estimacion_y_pruebas.do` |

Los archivos originales se conservan en el paquete privado. Se adaptaron rutas locales, se añadió una comprobación de configuración y se normalizó el nombre del master. No se corrigieron reglas de estimación.

El script `winzori.do` se conserva como fragmento incompleto y queda fuera de la ejecución canónica. Los resultados antiguos y la auditoría de identificadores se mantienen como antecedentes privados.

## Tablas

Las 27 tablas siguientes están disponibles en el segundo bloque de publicación junto con el código y la documentación del primero.

| Original | Ubicación |
|---|---|
| `actividades_por_anio.csv` | `resultados/tablas/08_comparabilidad/actividades_por_anio.csv` |
| `asociaciones_TIC_IC.csv` | `resultados/tablas/08D_TIC/asociaciones_TIC_IC.csv` |
| `asociaciones_tipo.csv` | `resultados/tablas/08E_tipo_trabajador/asociaciones_tipo.csv` |
| `brechas_TIC_IC.csv` | `resultados/tablas/08D_TIC/brechas_TIC_IC.csv` |
| `cambios_educacion.csv` | `resultados/tablas/08C_educacion/cambios_educacion.csv` |
| `coeficientes_diagnostico_MCO.csv` | `resultados/tablas/08B_diagnosticos/coeficientes_diagnostico_MCO.csv` |
| `coeficientes_forma_educacion.csv` | `resultados/tablas/08C_educacion/coeficientes_forma_educacion.csv` |
| `coeficientes_heckman.csv` | `resultados/tablas/10_Heckman/coeficientes_heckman.csv` |
| `coeficientes_sensibilidad(1).csv` | `resultados/tablas/07_sensibilidad/coeficientes_sensibilidad.csv` |
| `coeficientes_tipo.csv` | `resultados/tablas/08E_tipo_trabajador/coeficientes_tipo.csv` |
| `composicion_usuarios.csv` | `resultados/tablas/08_comparabilidad/composicion_usuarios.csv` |
| `contrastes_TIC_educacion.csv` | `resultados/tablas/08C_educacion/contrastes_TIC_educacion.csv` |
| `contrastes_anio_intensidad.csv` | `resultados/tablas/08_comparabilidad/contrastes_anio_intensidad.csv` |
| `contrastes_sensibilidad(1).csv` | `resultados/tablas/07_sensibilidad/contrastes_sensibilidad.csv` |
| `densidades_tic.csv` | `resultados/tablas/08E_tipo_trabajador/densidades_tic.csv` |
| `diferencias_tipo.csv` | `resultados/tablas/08E_tipo_trabajador/diferencias_tipo.csv` |
| `parametrizacion_diagnostico.csv` | `resultados/tablas/08B_diagnosticos/parametrizacion_diagnostico.csv` |
| `parametros_heckman.csv` | `resultados/tablas/10_Heckman/parametros_heckman.csv` |
| `pruebas_diagnostico.csv` | `resultados/tablas/08B_diagnosticos/pruebas_diagnostico.csv` |
| `pruebas_forma_educacion.csv` | `resultados/tablas/08C_educacion/pruebas_forma_educacion.csv` |
| `pruebas_heckman.csv` | `resultados/tablas/10_Heckman/pruebas_heckman.csv` |
| `pruebas_sensibilidad(1).csv` | `resultados/tablas/07_sensibilidad/pruebas_sensibilidad.csv` |
| `pruebas_tipo.csv` | `resultados/tablas/08E_tipo_trabajador/pruebas_tipo.csv` |
| `resumen_cuatro_grupos.csv` | `resultados/tablas/08D_TIC/resumen_cuatro_grupos.csv` |
| `resumen_modelos_heckman.csv` | `resultados/tablas/10_Heckman/resumen_modelos_heckman.csv` |
| `resumen_modelos_tipo.csv` | `resultados/tablas/08E_tipo_trabajador/resumen_modelos_tipo.csv` |
| `resumen_tic.csv` | `resultados/tablas/08_comparabilidad/resumen_tic.csv` |

Las variantes de 08D modifican etiquetas, orden de columnas y redondeo. Se conservan en los originales. Las copias públicas usan un solo nombre por tabla. Los tres CSV de sensibilidad recibidos con `(1)` se renombraron sin ese sufijo, conservando sus bytes.

## Logs

Los cinco registros se encuentran en `resultados/logs/`: MCO, sensibilidad, forma funcional educativa, contrastes por tipo de trabajador y Heckman. Todos proceden de ejecuciones previas aportadas por el autor. Se sustituyeron las rutas personales en las copias públicas.

Además, `07_Precios_y_sensibilidad_MCO.log` omite dos salidas de observaciones individuales y `10_Heckman_estimacion_y_pruebas.log` omite una. La omisión se señala en cada ubicación del log. Los coeficientes, las pruebas y los resúmenes agregados se conservan. Los registros originales permanecen en privado.
