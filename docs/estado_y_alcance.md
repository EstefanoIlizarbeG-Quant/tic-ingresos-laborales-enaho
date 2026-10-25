# Estado y alcance

## Publicación por bloques

Los dos primeros bloques contienen código, documentación, 27 tablas agregadas y cinco logs históricos revisados. Las figuras se incorporarán en el tercero. La estructura de los CSV, sus valores p y los intervalos disponibles se comprobaron al preparar el segundo bloque. Las comprobaciones de muestras y estimaciones con bases locales corresponden a la preparación previa y se distinguen de una nueva ejecución integral de Stata.

Las tablas CSV y los logs corresponden a estimaciones ya ejecutadas en Stata y aportadas para organizar el proyecto. La reconstrucción Python utiliza esas salidas. No se realizó una nueva estimación MCO o Heckman durante la preparación del repositorio.

## Comprobaciones realizadas

- La base MCO de la etapa 08E contiene 18 065 observaciones, 7 933 usuarios de computadora y 772 conglomerados.
- Las bases de las etapas 08B y 08E coinciden en las 252 columnas que comparten, al ordenar por identificador de observación.
- La base amplia de Heckman conserva 28 476 observaciones. El modelo principal utiliza 28 363 y selecciona 18 069. La muestra difiere de la muestra TIC por sus requisitos.
- Las 27 tablas publicadas se revisaron en cuanto a estructura, valores p e intervalos cuando esas columnas estaban presentes. No se detectaron valores p fuera de [0, 1] ni coeficientes fuera de los límites exportados. Los CSV se conservan sin modificar sus valores.
- Los seis R² educativos se reconstruyeron con sus coeficientes y los datos privados, conciliándolos con las tablas aportadas. Estas comprobaciones no sustituyen la evaluación del modelo.
- Las densidades por uso e informalidad conservan los valores exportados por Stata. La densidad de selección aplica el suavizado explícito descrito en la guía.

## Logs públicos

Los cinco logs corresponden a ejecuciones previas del autor. Sus rutas locales se sustituyeron por macros del proyecto. La copia de la etapa 07 omite dos listados individuales de ingresos extremos y la de Heckman omite un listado de observaciones excluidas de la muestra TIC. Se conservan las instrucciones, las estimaciones y los resultados agregados. Los originales permanecen en el archivo privado.

## Interpretación

El coeficiente de uso se evalúa a la intensidad de referencia que fija el centrado del modelo. La asociación de un usuario con cero actividades requiere una combinación distinta. Los porcentajes utilizan `100*(exp(b)-1)`, transformando también cada límite del intervalo.

Las comparaciones entre formas educativas, ponderaciones y tipos de trabajador son ejercicios de sensibilidad. La estimación de Heckman depende de supuestos sobre la selección y de sus restricciones. Los resultados se presentan como trabajo de investigación en revisión.

## Pendientes de ejecución

La ejecución íntegra del master requiere los módulos originales indicados en la guía y un entorno Stata. Las bases preparadas recibidas permiten reconstruir las figuras actuales. Debe documentarse cualquier cambio posterior en datos, muestra, inferencia o especificaciones.

Los microdatos, listados de observaciones, identificadores de seguimiento y documentos de tesis se conservan en privado. Esta entrega incluye código, documentación y resultados agregados. Las figuras corresponden al tercer bloque de publicación.
