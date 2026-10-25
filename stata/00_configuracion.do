version 17.0
* Abrir Stata en la carpeta raiz del repositorio antes de ejecutar este archivo.
global ENAHO_REPO "`c(pwd)'"
global ENAHO_ORIGEN "$ENAHO_REPO/datos/originales"
global ENAHO_TRABAJO "$ENAHO_REPO/datos/trabajo"
global ENAHO_SALIDA "$ENAHO_TRABAJO/Reconstruccion_ENAHO_2023_2025"

* Puede sustituir ENAHO_ORIGEN por su carpeta privada de descargas del INEI.
capture mkdir "$ENAHO_REPO/datos"
capture mkdir "$ENAHO_ORIGEN"
capture mkdir "$ENAHO_TRABAJO"
capture mkdir "$ENAHO_SALIDA"
display "Proyecto: $ENAHO_REPO"
display "Datos originales: $ENAHO_ORIGEN"
display "Resultados de Stata: $ENAHO_SALIDA"
