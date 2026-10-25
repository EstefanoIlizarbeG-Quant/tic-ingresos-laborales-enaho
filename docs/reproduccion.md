# Reproducción

Están disponibles el código, la documentación, las tablas agregadas, cinco logs históricos revisados y 14 figuras agregadas en PNG y SVG. Las instrucciones que leen `resultados/tablas/` pueden ejecutarse con los archivos incluidos. La [galería](../figuras/README.md) enlaza los archivos publicados. Las bases locales y las cuatro figuras con valores individuales se conservan fuera del repositorio. El programa puede reconstruir las 18 figuras originales al utilizar las bases locales.

## Figuras con resultados agregados

Ejecute `python python/graficos_enaho.py` desde la raíz del proyecto. El programa encuentra las tablas en `resultados/tablas/` y escribe en `figuras/python/`. Los argumentos `--tablas` y `--salida` permiten utilizar otras carpetas. Se generan dos asociaciones TIC, tres figuras por tipo de trabajador, la sensibilidad educativa integrada y la comparación de coeficientes MCO-Heckman: siete figuras en total.

Con `--datos-privados /ruta/a/bases` se añaden once figuras. Se necesitan las bases 08E y 10, que se guardan fuera del repositorio. Se preservan los valores de los coeficientes y los intervalos exportados por Stata. El ajuste de rectas bivariadas para la dispersión es descriptivo. Los residuos parciales educativos se calculan con los coeficientes existentes y la matriz de regresores de la base, sin volver a estimar los seis modelos.

Para la densidad de probabilidades de selección se reutilizan las predicciones y se aplica un kernel gaussiano con `h = 0.9 min(s, RIQ/1.349) n^(-1/5)`. Esta elección explícita puede producir una curva distinta de la figura original de Stata. Las otras cuatro densidades del ingreso se trazan directamente con los 400 valores exportados en `densidades_tic.csv`.

## Datos originales y Stata

Coloque las descargas originales del INEI en una carpeta privada y señale esa ubicación en `stata/00_configuracion.do`. El master espera módulos 200, 300, 400, 500 y Sumaria del periodo 2023–2025. La validación complementaria utiliza módulos 200, 400 y 500 de 2022. Hay alternativas de nombres `enaho01-` y `enaho01a-` en las comprobaciones del código. Conserve el nombre de la descarga y revise el bloque de entrada correspondiente.

El master comienza extrayendo versiones reducidas de los módulos 300, 400 y 500 de 2025. También extrae la validación de 2022. Las bases reducidas ya preparadas permiten trabajar en etapas posteriores, pero una ejecución íntegra del master necesita los originales que lee su primer bloque.

Abra Stata en la carpeta raíz del repositorio y ejecute:

```stata
do "stata/00_configuracion.do"
do "$ENAHO_REPO/stata/master_enaho_2023_2025.do"
do "$ENAHO_REPO/stata/10_Heckman_estimacion_y_pruebas.do"
```

El master ya contiene las etapas 07 a 08E. Sus archivos individuales se incluyen para revisar o repetir una etapa después de construir sus entradas. La etapa 08C canónica es la versión `integrada`, que incorpora la figura de sensibilidad.

Se sustituyeron las rutas personales por tres macros configurables. Las reglas de selección, variables, regresiones y contrastes del código aportado se conservaron. Las copias organizadas no se han ejecutado en Stata en este entorno.

## Comprobaciones de Python

El programa comprueba tamaños de muestra, número de conglomerados, número de usuarios, orden de los intervalos y conciliación del R² de seis modelos educativos. Escribe `verificacion_reconstruccion.json`, que registra las comprobaciones y si se dispuso de las bases privadas.
