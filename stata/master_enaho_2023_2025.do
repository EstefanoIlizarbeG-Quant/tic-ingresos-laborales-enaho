* Copia preparada para el repositorio. Solo se adaptaron las rutas locales.
* Ejecutar antes 00_configuracion.do desde la raiz del repositorio.
if "$ENAHO_REPO" == "" {
    display as error "Ejecute primero stata/00_configuracion.do desde la raiz del proyecto."
    exit 198
}
version 17.0
clear all
set more off

local origen ///
    "$ENAHO_ORIGEN"

local salida "$ENAHO_TRABAJO"

capture log close extraccion25
log using "`salida'\Extraccion_modulos_2025.log", ///
    text replace name(extraccion25)


* 1. COMPROBAR LOS TRES ARCHIVOS ORIGINALES

foreach modulo in 300 400 500 {
    confirm file "`origen'\enaho01a-2025-`modulo'.dta"
}


* 2. MODULO 300: EDUCACION Y TIC

use "`origen'\enaho01a-2025-300.dta", clear
rename *, lower

local n300 = _N

keep conglome vivienda hogar codperso ///
    p301a p301b p301c ///
    p314a p314d p314b_2 ///
    p316_1 p316_2 p316_3 p316_4 ///
    p316_5 p316_6 p316_7 p316_8 ///
    p316_9 p316_10 p316_11 p316_12 ///
    p316b ///
    p316c1 p316c2 p316c3 p316c4 p316c5 ///
    p316c6 p316c7 p316c8 p316c9 p316c10

assert _N == `n300'
isid conglome vivienda hogar codperso

compress

save "`salida'\enaho2025_300_reconstruccion.dta", replace

display "Modulo 300: registros conservados = " _N


* 3. MODULO 400: SEGUROS Y FINANCIAMIENTO

use "`origen'\enaho01a-2025-400.dta", clear
rename *, lower

local n400 = _N

keep conglome vivienda hogar codperso ///
    p4191 p4192 p4193 p4194 ///
    p4195 p4196 p4197 p4198 ///
    p419a1 p419a2 p419a3 p419a4 ///
    p419a5 p419a6 p419a7 p419a8

assert _N == `n400'
isid conglome vivienda hogar codperso

compress

save "`salida'\enaho2025_400_reconstruccion.dta", replace

display "Modulo 400: registros conservados = " _N


* 4. MODULO 500: EMPLEO, INFORMALIDAD, INGRESOS Y HORAS

use "`origen'\enaho01a-2025-500.dta", clear
rename *, lower

local n500 = _N

local conservar ///
    conglome vivienda hogar codperso ///
    ocu500 p505r4 p506r4 p507 ///
    p510 p510a1 p510b p511a p512a p512b ///
    p513t p518 p519 p520 ///
    i513t i518 i520 ///
    i524a1 i524e1 i530a ///
    i538a1 i538e1 i541a ///
    fac500a

* Conservar medidas oficiales y metadatos si existen.
* Registrar su disponibilidad sin crear valores artificiales.

foreach v in ocupinf emplpsec ///
    nconglome sub_conglome dominio estrato ubigeo mes {

    capture confirm variable `v'

    if _rc == 0 {
        local conservar `conservar' `v'
        display "`v': presente y conservada"
    }
    else {
        display "`v': ausente en el archivo original"
    }
}

keep `conservar'

assert _N == `n500'
isid conglome vivienda hogar codperso

compress

save "`salida'\enaho2025_500_reconstruccion.dta", replace

display "Modulo 500: registros conservados = " _N

log close extraccion25













version 17.0
clear all
set more off

local origen ///
    "$ENAHO_ORIGEN"

local salida "$ENAHO_TRABAJO"

capture log close validacion22
log using "`salida'/Extraccion_validacion_2022.log", ///
    text replace name(validacion22)


foreach modulo in 200 400 500 {

    local prefijo "enaho01a"

    if `modulo' == 200 {
        local prefijo "enaho01"
    }

    * Primero buscar el nombre original.
    local archivo ///
        "`origen'/`prefijo'-2022-`modulo'.dta"

    capture confirm file "`archivo'"

    * Si no existe, buscar la copia con (1).
    if _rc != 0 {
        local archivo ///
            "`origen'/`prefijo'-2022-`modulo'(1).dta"
    }

    display _newline "Archivo que se abrira:"
    display "`archivo'"

    confirm file "`archivo'"

    use "`archivo'", clear
    rename *, lower

    local n_original = _N


    * MODULO 200: DEMOGRAFIA Y UNIVERSO

    if `modulo' == 200 {

        keep conglome vivienda hogar codperso ///
            dominio ubigeo estrato mes ///
            p203 p204 p207 p208a p209
    }


    * MODULO 400: SEGUROS Y FINANCIAMIENTO

    if `modulo' == 400 {

        keep conglome vivienda hogar codperso ///
            p4191 p4192 p4193 p4194 ///
            p4195 p4196 p4197 p4198 ///
            p419a1 p419a2 p419a3 p419a4 ///
            p419a5 p419a6 p419a7 p419a8
    }


    * MODULO 500: INFORMALIDAD

    if `modulo' == 500 {

        confirm variable ocupinf emplpsec

        keep conglome vivienda hogar codperso ///
            ocu500 p505r4 p506r4 p507 ///
            p510 p510a1 p510b ///
            p511a p512a p512b ///
            ocupinf emplpsec fac500a

        tabulate ocupinf, missing
        tabulate emplpsec, missing
    }


    * CONSERVAR TODAS LAS OBSERVACIONES

    assert _N == `n_original'

    assert !missing(conglome, vivienda, hogar, codperso)
    isid conglome vivienda hogar codperso

    compress

    save ///
        "`salida'/enaho2022_`modulo'_validacion.dta", ///
        replace

    display "Registros conservados del modulo `modulo':"
    count
}

log close validacion22












version 17.0
clear all
set more off


* ============================================================
* ETAPA 1: BASE MAESTRA, COMPOSICION DEL HOGAR Y SUMARIA
* No se eliminan personas ni observaciones con valores perdidos.
* ============================================================


* 1. DIRECTORIOS

local origen ///
    "$ENAHO_ORIGEN"

local descargas ///
    "$ENAHO_TRABAJO"

local salida ///
    "`descargas'/Reconstruccion_ENAHO_2023_2025"

* Crear la carpeta si todavia no existe.
capture mkdir "`salida'"

* Si esta ruta no existe o no es accesible, Stata se detendra aqui.
cd "`salida'"

capture log close etapa01

log using "`salida'/01_Base_maestra.log", ///
    text replace name(etapa01)


* 2. COMPROBAR LOS ARCHIVOS ANTES DE COMENZAR

foreach y in 2023 2024 2025 {

    * Modulo 200: buscar nombre original y despues nombre con (1).
    local archivo200 ///
        "`origen'/enaho01-`y'-200.dta"

    capture confirm file "`archivo200'"

    if _rc != 0 {
        local archivo200 ///
            "`origen'/enaho01-`y'-200(1).dta"
    }

    confirm file "`archivo200'"

    display "Modulo 200 de `y': `archivo200'"

    * Sumaria: buscar nombre original y despues nombre con (1).
    local archivosum ///
        "`origen'/sumaria-`y'.dta"

    capture confirm file "`archivosum'"

    if _rc != 0 {
        local archivosum ///
            "`origen'/sumaria-`y'(1).dta"
    }

    confirm file "`archivosum'"

    display "Sumaria de `y': `archivosum'"
}


* 3. ARCHIVOS TEMPORALES Y VARIABLES NECESARIAS

tempfile acumulada composicion sumaria_anual

local variables200 ///
    conglome vivienda hogar codperso ///
    ubigeo dominio estrato mes ///
    p201p p203 p204 p207 p208a p209 ///
    p215 p216 p217 nconglome sub_conglome

local variablessum ///
    conglome vivienda hogar ///
    mieperho totmieho percepho ///
    ingtrahd ingtexhd ingrenhd ingtprhd ingtpuhd ///
    inghog1d inghog2d ld pobreza factor07

* Contador para comprobar que el apilado conserve todas las filas.
local n_esperado = 0


* 4. PREPARAR CADA ANIO

foreach y in 2023 2024 2025 {

    display _newline "PREPARACION DEL ANIO `y'"

    local archivo200 ///
        "`origen'/enaho01-`y'-200.dta"

    capture confirm file "`archivo200'"

    if _rc != 0 {
        local archivo200 ///
            "`origen'/enaho01-`y'-200(1).dta"
    }

    use "`archivo200'", clear

    rename *, lower

    local n_original = _N
    local n_esperado = `n_esperado' + `n_original'

    keep `variables200'

    * Elegir columnas no debe modificar el numero de filas.
    assert _N == `n_original'

    * Verificar la llave individual dentro del anio.
    assert !missing(conglome, vivienda, hogar, codperso)

    isid conglome vivienda hogar codperso

    * P201P se conserva como cadena, sin convertirlo a numero.
    confirm string variable p201p

    generate int anio = `y'

    isid anio conglome vivienda hogar codperso


    * --------------------------------------------------------
    * 4.1. COMPOSICION DEL HOGAR
    * Se calcula con el modulo 200 completo, antes de cualquier
    * restriccion por edad, ambito o situacion laboral.
    * --------------------------------------------------------

    preserve

        generate byte n_miembros = ///
            (p204 == 1)

        generate byte n_menor6 = ///
            (p204 == 1 & inrange(p208a, 0, 5))

        generate byte n_menor14 = ///
            (p204 == 1 & inrange(p208a, 0, 13))

        generate byte n_mayor64 = ///
            (p204 == 1 & inrange(p208a, 65, 98))

        generate byte n_hijos_jefe = ///
            (p204 == 1 & p203 == 3)

        * Permite detectar hogares cuyos miembros tienen edad perdida.
        generate byte n_edad_faltante = ///
            (p204 == 1 & missing(p208a))

        collapse (sum) ///
            n_miembros n_menor6 n_menor14 ///
            n_mayor64 n_hijos_jefe n_edad_faltante, ///
            by(anio conglome vivienda hogar)

        isid anio conglome vivienda hogar

        save "`composicion'", replace

    restore

    merge m:1 anio conglome vivienda hogar ///
        using "`composicion'", ///
        assert(match) nogen

    assert _N == `n_original'

    isid anio conglome vivienda hogar codperso


    * --------------------------------------------------------
    * 4.2. INCORPORAR SUMARIA POR HOGAR
    * --------------------------------------------------------

    local archivosum ///
        "`origen'/sumaria-`y'.dta"

    capture confirm file "`archivosum'"

    if _rc != 0 {
        local archivosum ///
            "`origen'/sumaria-`y'(1).dta"
    }

    preserve

        use "`archivosum'", clear

        rename *, lower

        keep `variablessum'

        assert !missing(conglome, vivienda, hogar)

        isid conglome vivienda hogar

        generate int anio = `y'

        isid anio conglome vivienda hogar

        save "`sumaria_anual'", replace

    restore

    merge m:1 anio conglome vivienda hogar ///
        using "`sumaria_anual'", ///
        keep(master match) generate(merge_sumaria)

    tabulate merge_sumaria, missing

    * En los archivos enviados todos los hogares tienen coincidencia.
    * Si esto cambia, detenerse y revisar: no eliminar los casos.
    assert merge_sumaria == 3

    assert _N == `n_original'

    isid anio conglome vivienda hogar codperso


    * --------------------------------------------------------
    * 4.3. APILAR LOS ANIOS SIN ELIMINAR OBSERVACIONES
    * --------------------------------------------------------

    if `y' != 2023 {
        append using "`acumulada'"
    }

    save "`acumulada'", replace
}


* 5. VERIFICAR LA BASE APILADA

assert _N == `n_esperado'

assert !missing(anio, conglome, vivienda, hogar, codperso)

isid anio conglome vivienda hogar codperso

display _newline "OBSERVACIONES NACIONALES CONSERVADAS"

count
tabulate anio


* 6. CREAR IDENTIFICADORES DESPUES DEL APILADO
* Esto evita reutilizar numeraciones creadas separadamente por anio.

egen long id_observacion = ///
    group(anio conglome vivienda hogar codperso)

label variable id_observacion ///
    "Identificador unico de observacion persona-anio"

isid id_observacion


egen long id_hogar_anio = ///
    group(anio conglome vivienda hogar)

label variable id_hogar_anio ///
    "Identificador de hogar dentro del anio"


* Grupo del marco sin incluir anio.
* Su continuidad entre anios se auditara en la muestra analitica.
egen long id_conglomerado_marco = ///
    group(nconglome sub_conglome)

label variable id_conglomerado_marco ///
    "Grupo del marco basado en nconglome y sub_conglome"

* P201P permanece en la base para auditar identidad entre anios.
* No se supone que repetir una llave de vivienda identifique
* automaticamente a la misma persona.


* 7. MARCAR EL UNIVERSO DEMOGRAFICO SIN FILTRAR LA BASE

generate byte miembro_hogar = ///
    (p204 == 1) if !missing(p204)

generate byte edad_14_65 = ///
    inrange(p208a, 14, 65) if !missing(p208a)

generate byte ambito_lima_callao = ///
    (dominio == 8 & ///
     inlist(substr(ubigeo, 1, 4), "1501", "0701")) ///
    if !missing(dominio, ubigeo)

generate byte universo_demografico = ///
    (miembro_hogar == 1 & ///
     edad_14_65 == 1 & ///
     ambito_lima_callao == 1)

label variable miembro_hogar ///
    "Miembro del hogar segun P204"

label variable edad_14_65 ///
    "Edad entre 14 y 65 anios"

label variable ambito_lima_callao ///
    "Ambito definido: dominio 8 y provincias Lima/Callao"

label variable universo_demografico ///
    "Miembro de 14-65 anios dentro del ambito"


* 8. AUDITAR EL UNIVERSO Y LA COBERTURA

display _newline "UNIVERSO DEMOGRAFICO POR ANIO"

tabulate anio if universo_demografico == 1

* No se exige que P201P sea unico por anio en toda la base nacional.
* Esa comprobacion se hara en el universo y muestra correspondientes.
assert !missing(id_conglomerado_marco) ///
    if universo_demografico == 1

display "COBERTURA DE SUMARIA"

tabulate anio merge_sumaria, missing

display "MIEMBROS DEL AMBITO CON EDAD PERDIDA"

count if miembro_hogar == 1 & ///
    ambito_lima_callao == 1 & missing(p208a)


* 9. ETIQUETAR LA COMPOSICION DEL HOGAR

label variable n_miembros ///
    "Numero de miembros del hogar segun P204"

label variable n_menor6 ///
    "Miembros del hogar de 0 a 5 anios"

label variable n_menor14 ///
    "Miembros del hogar de 0 a 13 anios"

label variable n_mayor64 ///
    "Miembros del hogar de 65 a 98 anios"

label variable n_hijos_jefe ///
    "Miembros registrados como hijos del jefe del hogar"

label variable n_edad_faltante ///
    "Miembros del hogar con edad perdida"


* 10. GUARDAR LA BASE MAESTRA DE LA ETAPA 1

assert _N == `n_esperado'

isid anio conglome vivienda hogar codperso

sort anio conglome vivienda hogar codperso

compress

save "`salida'/base_maestra_etapa01.dta", replace

* Confirmar que el archivo requerido por la etapa 2 existe.
confirm file "`salida'/base_maestra_etapa01.dta"

display _newline "ETAPA 1 TERMINADA"

display "Archivo creado:"
display "`salida'/base_maestra_etapa01.dta"

log close etapa01





















version 17.0
clear all
set more off


* ============================================================
* ETAPA 2: INTEGRACION DE LOS MODULOS 300, 400 Y 500
* Se conservan todas las observaciones de la base maestra.
* Se mantienen los valores perdidos.
* ============================================================


* 1. DIRECTORIOS

local origen ///
    "$ENAHO_ORIGEN"

local descargas ///
    "$ENAHO_TRABAJO"

local salida ///
    "`descargas'/Reconstruccion_ENAHO_2023_2025"

cd "`salida'"

confirm file "`salida'/base_maestra_etapa01.dta"

capture log close etapa02

log using "`salida'/02_Integracion_modulos.log", ///
    text replace name(etapa02)


* 2. COMPROBAR TODOS LOS ARCHIVOS DE ORIGEN

foreach modulo in 300 400 500 {

    foreach y in 2023 2024 2025 {

        if `y' != 2025 {

            local archivo ///
                "`origen'/enaho01a-`y'-`modulo'.dta"

            capture confirm file "`archivo'"

            if _rc != 0 {
                local archivo ///
                    "`origen'/enaho01a-`y'-`modulo'(1).dta"
            }
        }
        else {

            * Copias reducidas: conservan todas las filas originales.
            local archivo ///
                "`descargas'/enaho2025_`modulo'_reconstruccion.dta"
        }

        confirm file "`archivo'"

        display "Archivo verificado: `archivo'"
    }
}


* 3. ABRIR Y VERIFICAR LA BASE MAESTRA

tempfile maestra

use "`salida'/base_maestra_etapa01.dta", clear

assert !missing(anio, conglome, vivienda, hogar, codperso)

isid anio conglome vivienda hogar codperso

isid id_observacion

local n_maestra = _N

display _newline "FILAS DE LA BASE MAESTRA: `n_maestra'"

tabulate anio

save "`maestra'", replace


* 4. VARIABLES DE EDUCACION Y TIC: MODULO 300

local variables300 ///
    p301a p301b p301c ///
    p314a p314d p314b_2 ///
    p316_1 p316_2 p316_3 p316_4 ///
    p316_5 p316_6 p316_7 p316_8 ///
    p316_9 p316_10 p316_11 p316_12 ///
    p316b ///
    p316c1 p316c2 p316c3 p316c4 p316c5 ///
    p316c6 p316c7 p316c8 p316c9 p316c10


* 5. VARIABLES DE SALUD: MODULO 400
* Se conservan afiliacion y forma de obtencion del seguro.

local variables400 ///
    p4191 p4192 p4193 p4194 ///
    p4195 p4196 p4197 p4198 ///
    p419a1 p419a2 p419a3 p419a4 ///
    p419a5 p419a6 p419a7 p419a8


* 6. VARIABLES DE EMPLEO, INFORMALIDAD E INGRESOS: MODULO 500

local variables500 ///
    ocu500 p505r4 p506r4 p507 ///
    p510 p510a1 p510b p511a p512a p512b ///
    p513t p518 p519 p520 ///
    i513t i518 i520 ///
    i524a1 i524e1 i530a ///
    i538a1 i538e1 i541a ///
    fac500a


* 7. PREPARAR E INCORPORAR CADA MODULO

foreach modulo in 300 400 500 {

    tempfile pool_modulo

    display _newline "PREPARACION DEL MODULO `modulo'"

    foreach y in 2023 2024 2025 {

        * Localizar el archivo correspondiente.
        if `y' != 2025 {

            local archivo ///
                "`origen'/enaho01a-`y'-`modulo'.dta"

            capture confirm file "`archivo'"

            if _rc != 0 {
                local archivo ///
                    "`origen'/enaho01a-`y'-`modulo'(1).dta"
            }
        }
        else {

            local archivo ///
                "`descargas'/enaho2025_`modulo'_reconstruccion.dta"
        }

        confirm file "`archivo'"

        display _newline "Archivo utilizado: `archivo'"

        use "`archivo'", clear

        rename *, lower

        local n_original = _N

        display "Filas del archivo de origen: `n_original'"

        * Verificar la llave individual.
        assert !missing(conglome, vivienda, hogar, codperso)

        isid conglome vivienda hogar codperso


        * ----------------------------------------------------
        * 7.1. CONSERVAR LAS VARIABLES NECESARIAS
        * ----------------------------------------------------

        if `modulo' == 300 {

            keep conglome vivienda hogar codperso ///
                `variables300'
        }

        if `modulo' == 400 {

            keep conglome vivienda hogar codperso ///
                `variables400'
        }

        if `modulo' == 500 {

            * Disponibilidad significa que la columna existe
            * en el archivo de origen. No significa que todos
            * sus registros tengan una respuesta observada.

            capture confirm variable ocupinf

            if _rc != 0 {

                generate byte ocupinf = .

                generate byte disponible_ocupinf = 0
            }
            else {

                confirm numeric variable ocupinf

                generate byte disponible_ocupinf = 1
            }

            capture confirm variable emplpsec

            if _rc != 0 {

                generate byte emplpsec = .

                generate byte disponible_emplpsec = 0
            }
            else {

                confirm numeric variable emplpsec

                generate byte disponible_emplpsec = 1
            }

            keep conglome vivienda hogar codperso ///
                `variables500' ///
                ocupinf emplpsec ///
                disponible_ocupinf disponible_emplpsec

            label variable disponible_ocupinf ///
                "Columna OCUPINF presente en el archivo de origen"

            label variable disponible_emplpsec ///
                "Columna EMPLPSEC presente en el archivo de origen"
        }

        * Seleccionar columnas no debe eliminar filas.
        assert _N == `n_original'

        generate int anio = `y'

        isid anio conglome vivienda hogar codperso


        * ----------------------------------------------------
        * 7.2. APILAR LOS TRES ANIOS DEL MODULO
        * ----------------------------------------------------

        if `y' != 2023 {
            append using "`pool_modulo'"
        }

        save "`pool_modulo'", replace
    }


    * --------------------------------------------------------
    * 7.3. VERIFICAR EL MODULO APILADO
    * --------------------------------------------------------

    isid anio conglome vivienda hogar codperso

    display _newline "FILAS DEL MODULO `modulo' POR ANIO"

    tabulate anio


    * --------------------------------------------------------
    * 7.4. INCORPORAR EL MODULO A LA MAESTRA
    * --------------------------------------------------------

    use "`maestra'", clear

    merge 1:1 anio conglome vivienda hogar codperso ///
        using "`pool_modulo'", ///
        keep(master match) generate(merge`modulo')

    * La base del modulo 200 define las filas de la maestra.
    * Se conservan sus registros tengan o no coincidencia.
    * No se agregan filas exclusivas del archivo using.

    assert _N == `n_maestra'

    isid anio conglome vivienda hogar codperso

    isid id_observacion


    * --------------------------------------------------------
    * 7.5. AUDITAR LA COBERTURA
    * --------------------------------------------------------

    display _newline "COBERTURA NACIONAL DEL MODULO `modulo'"

    tabulate anio merge`modulo', missing

    display "COBERTURA EN EL UNIVERSO DEMOGRAFICO"

    tabulate anio merge`modulo' ///
        if universo_demografico == 1, missing

    * Con los archivos revisados, todo el universo demografico
    * encuentra coincidencia en los tres modulos.
    * Si esta prueba falla, revisar antes de continuar.
    assert merge`modulo' == 3 ///
        if universo_demografico == 1

    save "`maestra'", replace
}


* 8. VERIFICAR LAS TRES INTEGRACIONES

assert _N == `n_maestra'

isid anio conglome vivienda hogar codperso

isid id_observacion

foreach modulo in 300 400 500 {

    assert inlist(merge`modulo', 1, 3)

    assert merge`modulo' == 3 ///
        if universo_demografico == 1
}


* 9. EXAMINAR LA SITUACION LABORAL SIN EXCLUIR REGISTROS

display _newline "SITUACION LABORAL EN EL UNIVERSO DEMOGRAFICO"

tabulate anio ocu500 ///
    if universo_demografico == 1, missing

display "OCUPADOS DEL UNIVERSO DEMOGRAFICO"

tabulate anio ///
    if universo_demografico == 1 & ocu500 == 1

* Mantener visibles los casos con codigo 0 o valor perdido.
* Su tratamiento se definira al construir la seleccion.
* No asignarlos automaticamente a no participantes.

display "CASOS CON OCU500 IGUAL A CERO"

tabulate anio ///
    if universo_demografico == 1 & ocu500 == 0

display "CASOS CON OCU500 PERDIDO"

count if universo_demografico == 1 & missing(ocu500)


* 10. REVISAR DISPONIBILIDAD Y VALORES OFICIALES

display _newline "DISPONIBILIDAD DE OCUPINF"

tabulate anio disponible_ocupinf ///
    if universo_demografico == 1, missing

display "DISPONIBILIDAD DE EMPLPSEC"

tabulate anio disponible_emplpsec ///
    if universo_demografico == 1, missing

display "OCUPINF ENTRE OCUPADOS DEL UNIVERSO"

tabulate anio ocupinf ///
    if universo_demografico == 1 & ocu500 == 1, missing

display "EMPLPSEC ENTRE OCUPADOS DEL UNIVERSO"

tabulate anio emplpsec ///
    if universo_demografico == 1 & ocu500 == 1, missing


* 11. GUARDAR LA BASE MAESTRA DE LA ETAPA 2

assert _N == `n_maestra'

isid anio conglome vivienda hogar codperso

isid id_observacion

sort anio conglome vivienda hogar codperso

compress

save "`salida'/base_maestra_etapa02.dta", replace

confirm file "`salida'/base_maestra_etapa02.dta"

display _newline "ETAPA 2 TERMINADA"

display "Archivo creado:"
display "`salida'/base_maestra_etapa02.dta"

display "Filas conservadas: `n_maestra'"

log close etapa02














version 17.0
clear all
set more off


* ============================================================
* ETAPA 3: INFORMALIDAD V7 + CIERRE V8
* Validacion contra OCUPINF en 2022 y 2023.
* No se eliminan observaciones.
* 2022 se trabaja por separado de la muestra 2023-2025.
* ============================================================


* 1. DIRECTORIOS Y ARCHIVOS

local descargas ///
    "$ENAHO_TRABAJO"

local salida ///
    "`descargas'/Reconstruccion_ENAHO_2023_2025"

cd "`salida'"

confirm file "`salida'/base_maestra_etapa02.dta"

foreach modulo in 200 400 500 {

    confirm file ///
        "`descargas'/enaho2022_`modulo'_validacion.dta"
}

capture log close etapa03

log using "`salida'/03_Informalidad_validacion.log", ///
    text replace name(etapa03)


* 2. DEFINIR UN PROGRAMA CON LAS MISMAS REGLAS PARA TODOS LOS ANIOS

capture program drop construir_informalidad_v8

program define construir_informalidad_v8

    version 17.0

    foreach v in ocu500 ocupinf merge400 ///
        p506r4 p507 p510 p510a1 p512a p512b ///
        p4191 p4192 p4193 p4194 ///
        p4195 p4196 p4197 p4198 ///
        p419a1 p419a2 p419a3 p419a4 ///
        p419a5 p419a6 p419a7 p419a8 {

        confirm numeric variable `v'
    }


    * --------------------------------------------------------
    * 2.1. MEDIDA OFICIAL EN CODIFICACION 0/1
    * OCUPINF: 1 informal, 2 formal.
    * --------------------------------------------------------

    generate byte ocupinf01 = ///
        (ocupinf == 1) ///
        if ocu500 == 1 & inlist(ocupinf, 1, 2)

    label variable ocupinf01 ///
        "Empleo informal oficial: 1 informal, 0 formal"


    * --------------------------------------------------------
    * 2.2. SEGURO FINANCIADO POR EL CENTRO DE TRABAJO
    * Reproduce la construccion utilizada en tus archivos.
    * --------------------------------------------------------

    egen byte n_p419_validas = rownonmiss( ///
        p4191 p4192 p4193 p4194 ///
        p4195 p4196 p4197 p4198)

    generate byte seguro_centro_any = .

    replace seguro_centro_any = 0 ///
        if ocu500 == 1 & merge400 == 3 & ///
        n_p419_validas == 8

    foreach v of varlist ///
        p419a1 p419a2 p419a3 p419a4 ///
        p419a5 p419a6 p419a7 p419a8 {

        replace seguro_centro_any = 1 ///
            if ocu500 == 1 & merge400 == 3 & `v' == 1
    }

    label variable seguro_centro_any ///
        "Alguna afiliacion financiada por el centro de trabajo"


    * --------------------------------------------------------
    * 2.3. DIVISION CIIU Y RAMA EXTRACTIVA
    * --------------------------------------------------------

    generate int ciiu2 = floor(p506r4 / 100) ///
        if ocu500 == 1 & !missing(p506r4)

    generate byte rama_extractiva = ///
        inrange(ciiu2, 1, 9) ///
        if ocu500 == 1 & !missing(ciiu2)

    label variable ciiu2 ///
        "Division CIIU obtenida de P506R4"

    label variable rama_extractiva ///
        "Divisiones CIIU 01-09 segun regla previa"


    * --------------------------------------------------------
    * 2.4. TAMANO: P512B CON RESPALDO DE P512A
    * --------------------------------------------------------

    generate byte tam_le30_v7 = .
    generate byte tam_gt30_v7 = .

    replace tam_le30_v7 = 1 ///
        if ocu500 == 1 & inrange(p512b, 1, 30)

    replace tam_gt30_v7 = 0 ///
        if ocu500 == 1 & inrange(p512b, 1, 30)

    replace tam_le30_v7 = 0 ///
        if ocu500 == 1 & p512b > 30 & p512b < 9998

    replace tam_gt30_v7 = 1 ///
        if ocu500 == 1 & p512b > 30 & p512b < 9998

    replace tam_le30_v7 = 1 ///
        if ocu500 == 1 & missing(tam_le30_v7) & p512a == 1

    replace tam_gt30_v7 = 0 ///
        if ocu500 == 1 & missing(tam_gt30_v7) & p512a == 1

    replace tam_le30_v7 = 0 ///
        if ocu500 == 1 & missing(tam_le30_v7) & ///
        inlist(p512a, 3, 4, 5)

    replace tam_gt30_v7 = 1 ///
        if ocu500 == 1 & missing(tam_gt30_v7) & ///
        inlist(p512a, 3, 4, 5)

    * P512A == 2 no permite resolver el umbral de 30
    * cuando no existe un numero exacto utilizable.

    label variable tam_le30_v7 ///
        "Unidad con 30 trabajadores o menos, V7"

    label variable tam_gt30_v7 ///
        "Unidad con mas de 30 trabajadores, V7"


    * --------------------------------------------------------
    * 2.5. SECTOR INSTITUCIONAL: REGLAS V7
    * Se conserva el orden de las reglas originales.
    * --------------------------------------------------------

    generate byte hogar_mercado_v7 = .

    replace hogar_mercado_v7 = 1 ///
        if ocu500 == 1 & inlist(p507, 5, 7)

    replace hogar_mercado_v7 = 0 ///
        if ocu500 == 1 & p507 == 6

    replace hogar_mercado_v7 = 0 ///
        if ocu500 == 1 & inlist(p507, 3, 4) & ///
        inlist(p510, 1, 2, 3, 4, 5)

    replace hogar_mercado_v7 = 0 ///
        if ocu500 == 1 & inrange(p507, 1, 4) & p510a1 == 1

    * Empleadores e independientes.

    replace hogar_mercado_v7 = 1 ///
        if ocu500 == 1 & inlist(p507, 1, 2) & ///
        inlist(p510a1, 2, 3) & rama_extractiva == 1

    replace hogar_mercado_v7 = 1 ///
        if ocu500 == 1 & inlist(p507, 1, 2) & ///
        inlist(p510a1, 2, 3) & rama_extractiva == 0 & ///
        tam_le30_v7 == 1

    replace hogar_mercado_v7 = 0 ///
        if ocu500 == 1 & inlist(p507, 1, 2) & ///
        inlist(p510a1, 2, 3) & rama_extractiva == 0 & ///
        tam_gt30_v7 == 1

    * Empleados y obreros de empresas privadas u otros.

    replace hogar_mercado_v7 = 1 ///
        if ocu500 == 1 & inlist(p507, 3, 4) & ///
        inlist(p510, 6, 7) & inlist(p510a1, 2, 3) & ///
        rama_extractiva == 1

    replace hogar_mercado_v7 = 1 ///
        if ocu500 == 1 & inlist(p507, 3, 4) & ///
        inlist(p510, 6, 7) & inlist(p510a1, 2, 3) & ///
        rama_extractiva == 0 & tam_le30_v7 == 1

    replace hogar_mercado_v7 = 0 ///
        if ocu500 == 1 & inlist(p507, 3, 4) & ///
        inlist(p510, 6, 7) & inlist(p510a1, 2, 3) & ///
        rama_extractiva == 0 & tam_gt30_v7 == 1

    label variable hogar_mercado_v7 ///
        "Sector institucional de hogares productores, V7"


    * --------------------------------------------------------
    * 2.6. SECTOR INFORMAL: REGLAS V7
    * --------------------------------------------------------

    generate byte sector_inf_v7 = .

    replace sector_inf_v7 = 0 ///
        if ocu500 == 1 & hogar_mercado_v7 == 0

    replace sector_inf_v7 = 1 ///
        if ocu500 == 1 & hogar_mercado_v7 == 1 & ///
        rama_extractiva == 1

    replace sector_inf_v7 = 1 ///
        if ocu500 == 1 & hogar_mercado_v7 == 1 & ///
        rama_extractiva == 0 & p510a1 == 3

    replace sector_inf_v7 = 0 ///
        if ocu500 == 1 & hogar_mercado_v7 == 1 & ///
        rama_extractiva == 0 & inlist(p510a1, 1, 2)

    label variable sector_inf_v7 ///
        "Sector informal reconstruido, V7"


    * --------------------------------------------------------
    * 2.7. EMPLEO INFORMAL: REGLAS V7
    * --------------------------------------------------------

    generate byte informal_v7 = .

    replace informal_v7 = 1 ///
        if ocu500 == 1 & sector_inf_v7 == 1

    replace informal_v7 = 1 ///
        if ocu500 == 1 & inlist(p507, 5, 7)

    replace informal_v7 = 0 ///
        if ocu500 == 1 & inlist(p507, 1, 2) & ///
        sector_inf_v7 == 0

    replace informal_v7 = 1 ///
        if ocu500 == 1 & inlist(p507, 3, 4) & ///
        sector_inf_v7 == 0 & seguro_centro_any == 0

    replace informal_v7 = 0 ///
        if ocu500 == 1 & inlist(p507, 3, 4) & ///
        sector_inf_v7 == 0 & seguro_centro_any == 1

    replace informal_v7 = 1 ///
        if ocu500 == 1 & p507 == 6 & seguro_centro_any == 0

    replace informal_v7 = 0 ///
        if ocu500 == 1 & p507 == 6 & seguro_centro_any == 1


    * --------------------------------------------------------
    * 2.8. CIERRE V8: SOLO COMPLETA CASOS PERDIDOS EN V7
    * --------------------------------------------------------

    clonevar informal_v8 = informal_v7

    replace informal_v8 = 1 ///
        if ocu500 == 1 & missing(informal_v8) & ///
        inlist(p507, 3, 4, 6) & seguro_centro_any == 0

    replace informal_v8 = 0 ///
        if ocu500 == 1 & missing(informal_v8) & ///
        inlist(p507, 1, 2) & p510a1 == 2 & ///
        rama_extractiva == 0

    replace informal_v8 = 0 ///
        if ocu500 == 1 & missing(informal_v8) & ///
        inlist(p507, 3, 4) & p510a1 == 2 & ///
        rama_extractiva == 0 & seguro_centro_any == 1

    clonevar informal = informal_v8

    generate byte recuperado_v8 = ///
        (missing(informal_v7) & !missing(informal_v8)) ///
        if ocu500 == 1

    generate byte informal_no_clasificable = ///
        missing(informal) if ocu500 == 1

    label define informal_recon ///
        0 "Empleo formal" 1 "Empleo informal", replace

    foreach v in ocupinf01 informal_v7 informal_v8 informal {
        label values `v' informal_recon
    }

    label variable informal_v7 ///
        "Empleo informal reconstruido, V7"

    label variable informal_v8 ///
        "Empleo informal reconstruido, cierre V8"

    label variable informal ///
        "Empleo informal para el analisis: reglas V7 y V8"

    label variable recuperado_v8 ///
        "Clasificacion recuperada por el cierre V8"

    label variable informal_no_clasificable ///
        "Ocupado sin clasificacion de informalidad"

    * V8 debe conservar todas las clasificaciones observadas de V7.
    assert informal_v8 == informal_v7 ///
        if !missing(informal_v7)

    assert inlist(informal, 0, 1) if !missing(informal)

    * La formalidad no se define para personas no ocupadas.
    assert missing(informal) if ocu500 != 1

end


* 3. PROGRAMA PARA DOCUMENTAR LA VALIDACION
* La concordancia se calcula entre casos con ambas medidas.
* La cobertura usa todo el universo indicado en la llamada.

capture program drop validar_informalidad

program define validar_informalidad

    version 17.0

    syntax [if], TITULO(string)

    marksample touse

    tempvar comun

    generate byte `comun' = ///
        `touse' & !missing(ocupinf01, informal)

    quietly count if `touse'
    local ntotal = r(N)

    quietly count if `touse' & !missing(ocupinf01)
    local noficial = r(N)

    quietly count if `touse' & !missing(informal)
    local nclasificado = r(N)

    quietly count if `comun'
    local ncomun = r(N)

    quietly count if `comun' & informal != ocupinf01
    local ndiferencias = r(N)

    display _newline "`titulo'"

    display "N del universo:        " %12.0fc `ntotal'
    display "N con medida oficial:  " %12.0fc `noficial'
    display "N clasificado por V8:  " %12.0fc `nclasificado'
    display "N con ambas medidas:   " %12.0fc `ncomun'
    display "N de discrepancias:    " %12.0fc `ndiferencias'

    if `ntotal' > 0 {

        display "Cobertura V8 (%):      " ///
            %9.4f (100 * `nclasificado' / `ntotal')
    }

    if `ncomun' > 0 {

        tabulate ocupinf01 informal if `comun', row col

        display "Concordancia (%):      " ///
            %9.4f (100 * (1 - `ndiferencias' / `ncomun'))
    }

end


* 4. RECONSTRUIR INFORMALIDAD EN LA MAESTRA 2023-2025

use "`salida'/base_maestra_etapa02.dta", clear

local n_maestra = _N

isid anio conglome vivienda hogar codperso

isid id_observacion

construir_informalidad_v8

assert _N == `n_maestra'


* 5. AUDITAR CLASIFICACION EN EL UNIVERSO DE LA TESIS

display _newline "INFORMALIDAD V7 ENTRE OCUPADOS DEL AMBITO"

tabulate anio informal_v7 ///
    if universo_demografico == 1 & ocu500 == 1, missing

display "INFORMALIDAD V8 ENTRE OCUPADOS DEL AMBITO"

tabulate anio informal ///
    if universo_demografico == 1 & ocu500 == 1, missing

display "CLASIFICACIONES RECUPERADAS POR V8"

tabulate anio recuperado_v8 ///
    if universo_demografico == 1 & ocu500 == 1, missing

display "OCUPADOS DEL AMBITO SIN CLASIFICACION"

sort anio conglome vivienda hogar codperso

list anio conglome vivienda hogar codperso ///
    p507 p510 p510a1 p512a p512b ///
    rama_extractiva seguro_centro_any ///
    ocupinf01 informal_v7 informal ///
    if universo_demografico == 1 & ///
    ocu500 == 1 & missing(informal), ///
    noobs sepby(anio)


* 6. VALIDACION DE 2023: NACIONAL Y AMBITO DE LA TESIS

validar_informalidad ///
    if anio == 2023 & p204 == 1 & ///
    inrange(p208a, 14, 65) & ocu500 == 1, ///
    titulo("VALIDACION 2023: NACIONAL, MIEMBROS OCUPADOS 14-65")

validar_informalidad ///
    if anio == 2023 & universo_demografico == 1 & ///
    ocu500 == 1, ///
    titulo("VALIDACION 2023: AMBITO DE LA TESIS")


* 7. GUARDAR LA MAESTRA 2023-2025 SIN EXCLUIR FILAS

assert _N == `n_maestra'

isid anio conglome vivienda hogar codperso

isid id_observacion

sort anio conglome vivienda hogar codperso

compress

save "`salida'/base_maestra_etapa03.dta", replace


* 8. RECONSTRUIR POR SEPARADO LA BASE DE VALIDACION DE 2022
* Se utilizan las copias reducidas que conservan todas las filas.

use "`descargas'/enaho2022_200_validacion.dta", clear

rename *, lower

local n_2022 = _N

assert !missing(conglome, vivienda, hogar, codperso)

isid conglome vivienda hogar codperso

generate int anio = 2022

foreach modulo in 400 500 {

    merge 1:1 conglome vivienda hogar codperso ///
        using "`descargas'/enaho2022_`modulo'_validacion.dta", ///
        keep(master match) generate(merge`modulo')

    assert _N == `n_2022'

    isid anio conglome vivienda hogar codperso

    tabulate merge`modulo', missing
}

construir_informalidad_v8


* 9. VALIDACION DE 2022: NACIONAL Y MISMO AMBITO GEOGRAFICO

validar_informalidad ///
    if p204 == 1 & inrange(p208a, 14, 65) & ocu500 == 1, ///
    titulo("VALIDACION 2022: NACIONAL, MIEMBROS OCUPADOS 14-65")

validar_informalidad ///
    if p204 == 1 & inrange(p208a, 14, 65) & ///
    ocu500 == 1 & dominio == 8 & ///
    inlist(substr(ubigeo, 1, 4), "1501", "0701"), ///
    titulo("VALIDACION 2022: MISMO AMBITO DE LA TESIS")

assert _N == `n_2022'

isid anio conglome vivienda hogar codperso

sort anio conglome vivienda hogar codperso

compress

save "`salida'/base_validacion_informalidad_2022.dta", replace


* 10. VOLVER A LA MAESTRA DE LA TESIS

use "`salida'/base_maestra_etapa03.dta", clear

assert _N == `n_maestra'

isid anio conglome vivienda hogar codperso

isid id_observacion

display _newline "ETAPA 3 TERMINADA"

display "Base maestra 2023-2025:"
display "`salida'/base_maestra_etapa03.dta"

display "Base separada de validacion 2022:"
display "`salida'/base_validacion_informalidad_2022.dta"

display "Filas conservadas en la maestra: `n_maestra'"

log close etapa03






















version 17.0
clear all
set more off


* ============================================================
* ETAPA 4: TIC, INGRESOS, CONTROLES Y AUDITORIA DE LA MUESTRA
* Se conservan todas las filas de la maestra.
* No se filtran observaciones por valores perdidos.
* ============================================================


* 1. DIRECTORIOS Y BASE DE ENTRADA

local salida ///
    "$ENAHO_SALIDA"

cd "`salida'"

confirm file "`salida'/base_maestra_etapa03.dta"

capture log close etapa04

log using "`salida'/04_Variables_muestra.log", ///
    text replace name(etapa04)

use "`salida'/base_maestra_etapa03.dta", clear

local n_maestra = _N

isid anio conglome vivienda hogar codperso

isid id_observacion


* 2. MARCAR LOS OCUPADOS DEL AMBITO SIN FILTRAR FILAS

generate byte ocupado_ambito = ///
    (universo_demografico == 1 & ocu500 == 1)

label variable ocupado_ambito ///
    "Miembro ocupado de 14-65 anios dentro del ambito"

display _newline "OCUPADOS DEL AMBITO"

tabulate anio if ocupado_ambito == 1


* 3. TIC: MARGEN EXTENSIVO

generate byte tic_uso_pc = .

replace tic_uso_pc = 1 if p316b == 1

replace tic_uso_pc = 0 if p316b == 2

label variable tic_uso_pc ///
    "Uso de computadora, laptop, tableta o similar: ultimos 3 meses"


* 4. TIC: LAS NUEVE ACTIVIDADES ENTRE USUARIOS

forvalues j = 1/9 {

    generate byte act`j' = .

    replace act`j' = 1 ///
        if p316b == 1 & p316c`j' == 1

    replace act`j' = 0 ///
        if p316b == 1 & p316c`j' == 2
}

label variable act1 "Copiar o mover archivos o carpetas"
label variable act2 "Utilizar herramientas de copiar y pegar"
label variable act3 "Enviar correos con archivos adjuntos"
label variable act4 "Utilizar formulas en una hoja de calculo"
label variable act5 "Conectar e instalar nuevos dispositivos"
label variable act6 "Descargar, instalar y configurar software"
label variable act7 "Crear presentaciones electronicas"
label variable act8 "Transferir archivos entre dispositivos"
label variable act9 "Redactar un programa informatico"

egen byte n_actividades_validas = ///
    rownonmiss(act1-act9)

egen byte tic_actividades_usuarios = ///
    rowtotal(act1-act9), missing

* El conteo entre usuarios requiere las nueve respuestas validas.
replace tic_actividades_usuarios = . ///
    if p316b != 1 | n_actividades_validas < 9

label variable n_actividades_validas ///
    "Numero de respuestas validas a las nueve actividades"

label variable tic_actividades_usuarios ///
    "Actividades informaticas declaradas entre usuarios, 0-9"


* 5. TIC: CONTEO AMPLIADO

clonevar tic_actividades_ampliado = ///
    tic_actividades_usuarios

* Cero para no usuarios es una convencion del indicador ampliado.
* No modifica las respuestas originales P316C1-P316C9.
replace tic_actividades_ampliado = 0 ///
    if tic_uso_pc == 0

label variable tic_actividades_ampliado ///
    "Actividades informaticas: conteo ampliado con cero para no usuarios"

generate byte tic_modelo_valida = ///
    !missing(tic_uso_pc, tic_actividades_ampliado)

assert inlist(tic_uso_pc, 0, 1) ///
    if !missing(tic_uso_pc)

assert inrange(tic_actividades_usuarios, 0, 9) ///
    if !missing(tic_actividades_usuarios)

assert tic_actividades_ampliado == 0 ///
    if tic_uso_pc == 0

assert missing(tic_actividades_ampliado) ///
    if missing(tic_uso_pc)

display _newline "COBERTURA TIC ENTRE OCUPADOS DEL AMBITO"

tabulate anio tic_uso_pc ///
    if ocupado_ambito == 1, missing

tabulate p316b n_actividades_validas ///
    if ocupado_ambito == 1, missing


* 6. TIPO DE TRABAJADOR Y FUENTE DE INGRESO

generate byte tipo_trabajador = .

replace tipo_trabajador = 1 ///
    if ocu500 == 1 & inlist(p507, 3, 4, 6)

replace tipo_trabajador = 2 ///
    if ocu500 == 1 & inlist(p507, 1, 2)

replace tipo_trabajador = 3 ///
    if ocu500 == 1 & p507 == 5

replace tipo_trabajador = 4 ///
    if ocu500 == 1 & p507 == 7

label define tipo_trabajador_lab ///
    1 "Dependiente remunerado" ///
    2 "Empleador o independiente" ///
    3 "Familiar no remunerado" ///
    4 "Otra categoria", replace

label values tipo_trabajador tipo_trabajador_lab

generate byte ingreso_categoria_valida = ///
    inlist(tipo_trabajador, 1, 2) if ocu500 == 1


* 7. INGRESO ANUAL DE LA OCUPACION PRINCIPAL

generate double ing_prin_total_anual = .

replace ing_prin_total_anual = i524a1 ///
    if tipo_trabajador == 1

replace ing_prin_total_anual = i530a ///
    if tipo_trabajador == 2

label variable ing_prin_total_anual ///
    "Ingreso anual principal: total dependientes, ganancia independientes"

* Construccion alternativa para sensibilidad.
generate double ing_prin_liquido_anual = .

replace ing_prin_liquido_anual = i524e1 ///
    if tipo_trabajador == 1

replace ing_prin_liquido_anual = i530a ///
    if tipo_trabajador == 2

label variable ing_prin_liquido_anual ///
    "Ingreso anual principal: liquido dependientes, ganancia independientes"

generate byte ingreso_positivo = ///
    (ing_prin_total_anual > 0) ///
    if !missing(ing_prin_total_anual)


* 8. HORAS SEMANALES DE LA OCUPACION PRINCIPAL
* Se usa I513T, como en la construccion anterior.

clonevar horas_prin_sem = i513t

label variable horas_prin_sem ///
    "Horas semanales de la ocupacion principal, I513T"

generate byte horas_positivas = ///
    (horas_prin_sem > 0) if !missing(horas_prin_sem)

generate byte horas_cero = ///
    (horas_prin_sem == 0) if !missing(horas_prin_sem)

generate byte horas_98 = ///
    (horas_prin_sem == 98) if !missing(horas_prin_sem)


* 9. INGRESO POR HORA Y LOGARITMOS
* Se reproduce la conversion anterior: ingreso anual / (52 * horas).
* No se aplica un ajuste adicional por LD en esta construccion.

generate double ing_hora_total = ///
    ing_prin_total_anual / (52 * horas_prin_sem) ///
    if ocu500 == 1 & ///
    !missing(ing_prin_total_anual, horas_prin_sem) & ///
    ing_prin_total_anual > 0 & horas_prin_sem > 0

generate double y_log_ingreso_hora = ///
    ln(ing_hora_total) ///
    if !missing(ing_hora_total) & ing_hora_total > 0

generate double ing_hora_liquido = ///
    ing_prin_liquido_anual / (52 * horas_prin_sem) ///
    if ocu500 == 1 & ///
    !missing(ing_prin_liquido_anual, horas_prin_sem) & ///
    ing_prin_liquido_anual > 0 & horas_prin_sem > 0

generate double ln_ing_hora_liquido = ///
    ln(ing_hora_liquido) ///
    if !missing(ing_hora_liquido) & ing_hora_liquido > 0

label variable ing_hora_total ///
    "Ingreso laboral por hora de la ocupacion principal"

label variable y_log_ingreso_hora ///
    "Log ingreso laboral por hora de la ocupacion principal"

label variable ing_hora_liquido ///
    "Ingreso laboral liquido/neto por hora de la ocupacion principal"

label variable ln_ing_hora_liquido ///
    "Log ingreso laboral liquido/neto por hora"


* 10. CONTROLES PERSONALES

clonevar edad = p208a

generate byte mujer = ///
    (p207 == 2) if inlist(p207, 1, 2)

generate byte casado = ///
    (p209 == 2) if inrange(p209, 1, 6)

generate byte jefe_hogar = ///
    (p203 == 1) if !missing(p203)

generate byte autoempleado = ///
    (p507 == 2) if ocu500 == 1 & !missing(p507)

label variable mujer "Mujer"
label variable casado "Estado civil: casado"
label variable jefe_hogar "Jefe del hogar"
label variable autoempleado "Trabajador independiente"


* 11. ANIOS DE EDUCACION
* Se reproduce la regla utilizada en tu construccion anterior.

generate double educ_years = .

replace educ_years = 0 if inlist(p301a, 1, 2)

replace educ_years = p301c ///
    if p301a == 3 & inrange(p301c, 1, 5)

replace educ_years = p301b ///
    if p301a == 3 & missing(educ_years) & ///
    inrange(p301b, 0, 5)

replace educ_years = 6 if p301a == 4

replace educ_years = 6 + p301b ///
    if p301a == 5 & inrange(p301b, 1, 4)

replace educ_years = 11 if p301a == 6

replace educ_years = 11 + p301b ///
    if inlist(p301a, 7, 8, 9, 10) & ///
    inrange(p301b, 1, 7)

replace educ_years = 16 + p301b ///
    if p301a == 11 & inrange(p301b, 1, 4)

* Basica especial y respuestas no utilizables quedan perdidas.
* No se les asigna automaticamente cero anios.

label variable educ_years ///
    "Anos de educacion segun regla de construccion"


* 12. EXPERIENCIA POTENCIAL

generate double experiencia_raw = ///
    edad - educ_years - 6 ///
    if !missing(edad, educ_years)

generate double experiencia_potencial = ///
    max(experiencia_raw, 0) ///
    if !missing(experiencia_raw)

generate double experiencia2 = ///
    experiencia_potencial^2 ///
    if !missing(experiencia_potencial)

label variable experiencia_raw ///
    "Edad menos anos de educacion menos seis"

label variable experiencia_potencial ///
    "Experiencia potencial, con limite inferior de cero"

label variable experiencia2 ///
    "Experiencia potencial al cuadrado"


* 13. SECTOR ECONOMICO EN DIEZ GRUPOS
* CIIU2 ya fue construido en la etapa 3 para ocupados.

generate byte sector10 = .

replace sector10 = 1 if inrange(ciiu2, 1, 3)
replace sector10 = 2 if inrange(ciiu2, 5, 9)
replace sector10 = 3 if inrange(ciiu2, 10, 33)
replace sector10 = 4 if inrange(ciiu2, 35, 39)
replace sector10 = 5 if inrange(ciiu2, 41, 43)
replace sector10 = 6 if inrange(ciiu2, 45, 47)
replace sector10 = 7 if inrange(ciiu2, 49, 56)
replace sector10 = 8 if inrange(ciiu2, 58, 82)
replace sector10 = 9 if inrange(ciiu2, 84, 88)
replace sector10 = 10 if inrange(ciiu2, 90, 99)

label define sector10_lab ///
    1 "Agropecuario y pesca" ///
    2 "Mineria" ///
    3 "Manufactura" ///
    4 "Servicios publicos y residuos" ///
    5 "Construccion" ///
    6 "Comercio" ///
    7 "Transporte, alojamiento y comida" ///
    8 "Informacion, finanzas y servicios empresariales" ///
    9 "Administracion publica, educacion y salud" ///
    10 "Otros servicios", replace

label values sector10 sector10_lab

label variable sector10 "Sector economico en diez grupos"


* 14. GRUPO OCUPACIONAL CORREGIDO
* Los codigos militares pueden estar almacenados sin cero inicial.

generate byte ocupacion10_final = .

replace ocupacion10_final = 0 ///
    if ocu500 == 1 & inrange(p505r4, 100, 999)

replace ocupacion10_final = floor(p505r4 / 1000) ///
    if ocu500 == 1 & inrange(p505r4, 1000, 9999)

label define ocupacion10_lab ///
    0 "Ocupaciones militares" ///
    1 "Directores y gerentes" ///
    2 "Profesionales cientificos e intelectuales" ///
    3 "Tecnicos y profesionales de nivel medio" ///
    4 "Personal de apoyo administrativo" ///
    5 "Trabajadores de servicios y vendedores" ///
    6 "Agricultores y trabajadores agropecuarios calificados" ///
    7 "Oficiales, operarios y artesanos" ///
    8 "Operadores de instalaciones y maquinas" ///
    9 "Ocupaciones elementales", replace

label values ocupacion10_final ocupacion10_lab

label variable ocupacion10_final ///
    "Gran grupo ocupacional, incluido grupo militar"


* 15. MES NUMERICO PARA EFECTOS FIJOS

capture confirm string variable mes

if _rc == 0 {
    generate byte mes_num = real(mes)
}
else {
    generate byte mes_num = mes
}

label variable mes_num "Mes de entrevista, numerico"

assert inrange(mes_num, 1, 12) ///
    if universo_demografico == 1


* 16. MARCAR LA MUESTRA BASICA Y LA MUESTRA CON CONTROLES
* Estas variables son indicadores. No eliminan filas.

generate byte controles_base_final = ///
    !missing(educ_years, experiencia_potencial, experiencia2, ///
    mujer, casado, jefe_hogar, sector10, ///
    ocupacion10_final, anio, mes_num)

generate byte muestra_salario_basica = ///
    (ocupado_ambito == 1 & ///
    ingreso_categoria_valida == 1 & ///
    ingreso_positivo == 1 & horas_positivas == 1 & ///
    !missing(y_log_ingreso_hora, informal) & ///
    tic_modelo_valida == 1)

generate byte muestra_salario_controles_final = ///
    (muestra_salario_basica == 1 & controles_base_final == 1)

label variable muestra_salario_basica ///
    "Elegible para muestra principal antes de controles"

label variable muestra_salario_controles_final ///
    "Elegible para muestra MCO principal con controles completos"


* 17. CENTRAR ACTIVIDADES EN LA MEDIA DE USUARIOS DE LA MUESTRA MCO
* Se calcula una sola referencia para todo el periodo.
* La misma referencia queda disponible en la base amplia.

quietly summarize tic_actividades_usuarios ///
    if muestra_salario_controles_final == 1 & ///
    tic_uso_pc == 1, meanonly

if r(N) == 0 {
    display as error "No hay usuarios validos para calcular la referencia."
    error 2000
}

scalar media_actividades_usuarios = r(mean)

generate double media_actividades_referencia = ///
    media_actividades_usuarios

generate double actividades_centradas = .

replace actividades_centradas = 0 ///
    if tic_uso_pc == 0

replace actividades_centradas = ///
    tic_actividades_usuarios - media_actividades_usuarios ///
    if tic_uso_pc == 1 & !missing(tic_actividades_usuarios)

label variable media_actividades_referencia ///
    "Media de actividades entre usuarios de la muestra MCO completa"

label variable actividades_centradas ///
    "Actividades centradas en media de usuarios; cero para no usuarios"

assert tic_modelo_valida == ///
    !missing(tic_uso_pc, actividades_centradas)

display _newline "MEDIA UTILIZADA PARA CENTRAR ACTIVIDADES"

display %21.15f media_actividades_usuarios


* 18. AJUSTE P1-P99 ANUAL PARA SENSIBILIDAD
* Percentiles calculados entre ocupados del ambito con ingreso
* horario observado, antes de exigir TIC y controles completos.

bysort anio: egen float p1_ing_hora = ///
    pctile(ing_hora_total) if ocupado_ambito == 1, p(1)

bysort anio: egen float p99_ing_hora = ///
    pctile(ing_hora_total) if ocupado_ambito == 1, p(99)

generate byte extremo_bajo = ///
    (ing_hora_total < p1_ing_hora) ///
    if ocupado_ambito == 1 & ///
    !missing(ing_hora_total, p1_ing_hora)

generate byte extremo_alto = ///
    (ing_hora_total > p99_ing_hora) ///
    if ocupado_ambito == 1 & ///
    !missing(ing_hora_total, p99_ing_hora)

generate double ing_hora_w_1_99 = ///
    ing_hora_total if ocupado_ambito == 1

replace ing_hora_w_1_99 = p1_ing_hora ///
    if extremo_bajo == 1

replace ing_hora_w_1_99 = p99_ing_hora ///
    if extremo_alto == 1

generate double y_log_ingreso_hora_w = ///
    ln(ing_hora_w_1_99) ///
    if !missing(ing_hora_w_1_99) & ing_hora_w_1_99 > 0

label variable ing_hora_w_1_99 ///
    "Ingreso por hora ajustado a p1-p99 anual del ambito"

label variable y_log_ingreso_hora_w ///
    "Log ingreso por hora ajustado a p1-p99 anual"

generate byte muestra_sin_horas98 = ///
    (muestra_salario_controles_final == 1 & horas_98 == 0)


* 19. VARIABLE DE COMPOSICION PARA PREPARAR HECKMAN
* Los componentes de ingreso no laboral permanecen en la maestra.
* Su agregacion y la ecuacion de seleccion se revisaran despues.

generate byte hay_menor6 = ///
    (n_menor6 > 0) if !missing(n_menor6)

label variable hay_menor6 ///
    "Presencia de al menos un miembro menor de seis anios"


* 20. MOTIVO SECUENCIAL DE EXCLUSION DE LA MUESTRA MCO
* Fuera de los ocupados del ambito, esta variable queda perdida.
* Dentro del universo: 0 = incluido, 1-6 = primer motivo.

generate byte motivo_exclusion_mco = 0 ///
    if ocupado_ambito == 1

replace motivo_exclusion_mco = 1 ///
    if motivo_exclusion_mco == 0 & ///
    ingreso_categoria_valida != 1

replace motivo_exclusion_mco = 2 ///
    if motivo_exclusion_mco == 0 & ///
    ingreso_positivo != 1

replace motivo_exclusion_mco = 3 ///
    if motivo_exclusion_mco == 0 & ///
    horas_positivas != 1

replace motivo_exclusion_mco = 4 ///
    if motivo_exclusion_mco == 0 & missing(informal)

replace motivo_exclusion_mco = 5 ///
    if motivo_exclusion_mco == 0 & tic_modelo_valida != 1

replace motivo_exclusion_mco = 6 ///
    if motivo_exclusion_mco == 0 & controles_base_final != 1

label define motivo_mco_lab ///
    0 "Incluido en muestra MCO" ///
    1 "Categoria fuera de la definicion de ingreso" ///
    2 "Ingreso principal perdido o no positivo" ///
    3 "Horas perdidas o no positivas" ///
    4 "Informalidad sin clasificacion" ///
    5 "Medicion TIC incompleta" ///
    6 "Controles incompletos", replace

label values motivo_exclusion_mco motivo_mco_lab

label variable motivo_exclusion_mco ///
    "Primer motivo de exclusion de la muestra MCO"

assert muestra_salario_controles_final == ///
    (motivo_exclusion_mco == 0) if ocupado_ambito == 1


* 21. REGISTRO DE CONTEOS Y EXCLUSIONES

display _newline "INGRESO HORARIO OBSERVADO ENTRE OCUPADOS"

count if ocupado_ambito == 1 & ///
    !missing(y_log_ingreso_hora)

display "MUESTRA BASICA ANTES DE CONTROLES"

tabulate anio if muestra_salario_basica == 1

display "MUESTRA CON CONTROLES COMPLETOS"

tabulate anio if muestra_salario_controles_final == 1

display "USUARIOS EN LA MUESTRA CON CONTROLES"

count if muestra_salario_controles_final == 1 & ///
    tic_uso_pc == 1

display "PRIMER MOTIVO DE EXCLUSION"

tabulate motivo_exclusion_mco ///
    if ocupado_ambito == 1, missing

display "MOTIVOS POR ANIO"

tabulate anio motivo_exclusion_mco ///
    if ocupado_ambito == 1, missing

display "MOTIVOS POR CONDICION DE INFORMALIDAD"

tabulate motivo_exclusion_mco informal ///
    if ocupado_ambito == 1, missing

display "EXCLUSIONES INICIALES"

count if ocupado_ambito == 1 & ///
    inrange(motivo_exclusion_mco, 1, 5)

display "EXCLUSIONES ADICIONALES POR CONTROLES"

count if ocupado_ambito == 1 & motivo_exclusion_mco == 6

display "TOTAL DE EXCLUSIONES"

count if ocupado_ambito == 1 & ///
    inrange(motivo_exclusion_mco, 1, 6)

display "REGISTROS CON CONTROLES INCOMPLETOS DESPUES DE LA MUESTRA BASICA"

list anio conglome vivienda hogar codperso ///
    p301a p301b p301c educ_years ///
    mujer casado jefe_hogar sector10 ocupacion10_final ///
    if motivo_exclusion_mco == 6, noobs


* 22. DESCRIPTIVOS DE LA MUESTRA MARCADA, SIN FILTRAR LA BASE

tabstat ing_hora_total y_log_ingreso_hora ///
    ing_hora_w_1_99 y_log_ingreso_hora_w ///
    horas_prin_sem educ_years experiencia_potencial ///
    if muestra_salario_controles_final == 1, ///
    by(anio) statistics(n mean sd min max)

tabstat tic_actividades_usuarios ///
    if muestra_salario_controles_final == 1 & ///
    tic_uso_pc == 1, ///
    statistics(n mean sd min max)


* 23. GUARDAR LA MAESTRA COMPLETA

assert _N == `n_maestra'

isid anio conglome vivienda hogar codperso

isid id_observacion

sort anio conglome vivienda hogar codperso

compress

save "`salida'/base_maestra_etapa04.dta", replace

display _newline "ETAPA 4 TERMINADA"

display "Filas conservadas en la maestra: `n_maestra'"

display "Archivo creado:"
display "`salida'/base_maestra_etapa04.dta"

log close etapa04






















version 17.0
clear all
set more off


* ============================================================
* ETAPA 5: PREPARAR HECKMAN Y SEPARAR LA BASE MCO
*
* Orden:
* 1. Preparar variables en la maestra completa.
* 2. Guardar la maestra completa.
* 3. Guardar la base amplia para Heckman.
* 4. Guardar la tabla de exclusiones.
* 5. Crear la copia MCO.
*
* Los archivos de etapas anteriores permanecen intactos.
* ============================================================


* 1. DIRECTORIOS Y BASE

local salida ///
    "$ENAHO_SALIDA"

cd "`salida'"

confirm file "`salida'/base_maestra_etapa04.dta"

capture log close etapa05

log using "`salida'/05_Separacion_Heckman_MCO.log", ///
    text replace name(etapa05)

use "`salida'/base_maestra_etapa04.dta", clear

local n_maestra = _N

isid anio conglome vivienda hogar codperso

isid id_observacion

quietly count if universo_demografico == 1
local n_universo = r(N)

quietly count if ocupado_ambito == 1
local n_ocupados = r(N)

quietly count if muestra_salario_controles_final == 1
local n_mco = r(N)


* 2. VERIFICAR LA IDENTIDAD ENTRE COMPONENTES DE TRANSFERENCIAS

generate double diferencia_transferencias = ///
    (ingtrahd + ingtexhd) - (ingtprhd + ingtpuhd) ///
    if !missing(ingtrahd, ingtexhd, ingtprhd, ingtpuhd)

label variable diferencia_transferencias ///
    "Transferencias por procedencia menos transferencias publico/privadas"

display _newline "IDENTIDAD ENTRE COMPONENTES DE TRANSFERENCIAS"

summarize diferencia_transferencias ///
    if universo_demografico == 1, detail

assert diferencia_transferencias == 0 ///
    if universo_demografico == 1


* 3. MEDIDA MONETARIA NO LABORAL DEL HOGAR
* Definicion: transferencias monetarias y rentas de propiedad.
* Se exige observar los tres componentes.
* No se agregan nuevamente INGTPRHD e INGTPUHD.

generate double ingreso_no_laboral_hh = ///
    ingtrahd + ingtexhd + ingrenhd ///
    if !missing(ingtrahd, ingtexhd, ingrenhd)

label variable ingreso_no_laboral_hh ///
    "Ingreso no laboral del hogar: transferencias monetarias y rentas"

assert ingreso_no_laboral_hh >= 0 ///
    if universo_demografico == 1 & ///
    !missing(ingreso_no_laboral_hh)

generate double ln_ingreso_no_laboral_hh = ///
    ln(1 + ingreso_no_laboral_hh) ///
    if !missing(ingreso_no_laboral_hh) & ///
    ingreso_no_laboral_hh >= 0

label variable ln_ingreso_no_laboral_hh ///
    "Log(1 + transferencias monetarias y rentas del hogar)"

* Estas variables quedan como candidatas para la seleccion.
* Su exclusion de la ecuacion de ingresos requiere justificacion.


* 4. IDENTIFICAR COMPLETITUD DE LA COMPOSICION DEL HOGAR

generate byte menores6_completo = ///
    (n_edad_faltante == 0) ///
    if !missing(n_edad_faltante)

label variable menores6_completo ///
    "Edades observadas para todos los miembros del hogar"

assert menores6_completo == 1 ///
    if universo_demografico == 1


* 5. DEFINIR SELECCION POR OBSERVACION DEL INGRESO HORARIO
* No depende de la disponibilidad de TIC o informalidad.

generate byte S_ingreso = ///
    !missing(y_log_ingreso_hora) ///
    if universo_demografico == 1

label define seleccion_ingreso_lab ///
    0 "Ingreso horario no observado" ///
    1 "Ingreso horario valido observado", replace

label values S_ingreso seleccion_ingreso_lab

label variable S_ingreso ///
    "Seleccion por observacion del ingreso horario principal"

assert inlist(S_ingreso, 0, 1) ///
    if universo_demografico == 1

assert missing(y_log_ingreso_hora) ///
    if S_ingreso == 0

assert !missing(y_log_ingreso_hora) ///
    if S_ingreso == 1


* 6. DISTINGUIR OBSERVACION DEL INGRESO DE SITUACION LABORAL
* OCU500 == 0 se conserva sin asignarlo a una situacion conocida.

generate byte situacion_laboral_definida = ///
    inlist(ocu500, 1, 2, 3, 4) ///
    if universo_demografico == 1

generate byte S_empleo = ///
    (ocu500 == 1) ///
    if universo_demografico == 1 & ///
    situacion_laboral_definida == 1

label variable situacion_laboral_definida ///
    "OCU500 tiene codigo de situacion laboral 1-4"

label variable S_empleo ///
    "Ocupado segun OCU500; perdido si situacion no definida"

display _newline "SELECCION POR INGRESO OBSERVADO"

tabulate anio S_ingreso ///
    if universo_demografico == 1, missing

display "SITUACION LABORAL Y OBSERVACION DEL INGRESO"

tabulate ocu500 S_ingreso ///
    if universo_demografico == 1, missing

display "REGISTROS CON SITUACION LABORAL NO DEFINIDA"

count if universo_demografico == 1 & ///
    situacion_laboral_definida == 0


* 7. MARCAR DISPONIBILIDAD PARA HECKMAN-MINCER
* La ecuacion de seleccion requiere covariables para S=0 y S=1.
* Los controles productivos se exigen solo para S=1.
* Estos indicadores no eliminan filas.

generate byte controles_seleccion_validos = ///
    !missing(educ_years, experiencia_potencial, experiencia2, ///
    mujer, casado, jefe_hogar, anio, mes_num, ///
    n_menor6, ln_ingreso_no_laboral_hh) & ///
    menores6_completo == 1

generate byte controles_resultado_mincer = ///
    !missing(educ_years, experiencia_potencial, experiencia2, ///
    mujer, casado, jefe_hogar, sector10, ///
    ocupacion10_final, anio, mes_num)

generate byte muestra_heckman_mincer = ///
    (universo_demografico == 1 & ///
    controles_seleccion_validos == 1 & ///
    (S_ingreso == 0 | ///
    (S_ingreso == 1 & controles_resultado_mincer == 1)))

label variable muestra_heckman_mincer ///
    "Disponibilidad de variables para Heckman-Mincer"

* Sensibilidad futura: restringir a situacion laboral definida.
generate byte muestra_heckman_estado_definido = ///
    (muestra_heckman_mincer == 1 & ///
    situacion_laboral_definida == 1)

label variable muestra_heckman_estado_definido ///
    "Sensibilidad: Heckman con OCU500 definido"

display _newline "DISPONIBILIDAD PARA HECKMAN-MINCER"

tabulate anio S_ingreso ///
    if muestra_heckman_mincer == 1, missing

display "CASOS DEL UNIVERSO FUERA DEL INDICADOR DE DISPONIBILIDAD"

count if universo_demografico == 1 & ///
    muestra_heckman_mincer == 0

display "DISPONIBILIDAD RESTRINGIENDO A OCU500 DEFINIDO"

tabulate anio S_ingreso ///
    if muestra_heckman_estado_definido == 1, missing


* 8. CREAR IDENTIFICADORES PARA LAS COMPARACIONES DE INFERENCIA

confirm string variable p201p

assert !missing(p201p, nconglome, sub_conglome) ///
    if universo_demografico == 1

egen long id_persona_p201p = ///
    group(p201p) if universo_demografico == 1

label variable id_persona_p201p ///
    "Grupo basado en P201P; continuidad sujeta a auditoria"

egen long id_hogar_marco = ///
    group(nconglome sub_conglome vivienda hogar) ///
    if universo_demografico == 1

label variable id_hogar_marco ///
    "Llave de hogar y ubicacion del marco sin incluir anio"

assert !missing(id_persona_p201p, id_hogar_marco, ///
    id_conglomerado_marco) if universo_demografico == 1


* 9. GUARDAR LA MAESTRA COMPLETA ANTES DE CUALQUIER FILTRO

assert _N == `n_maestra'

isid anio conglome vivienda hogar codperso

isid id_observacion

sort anio conglome vivienda hogar codperso

compress

save "`salida'/base_maestra_etapa05.dta", replace


* 10. GUARDAR PRIMERO LA BASE AMPLIA PARA HECKMAN
* Solo se restringe al universo demografico del estudio.
* Se mantienen S=0, S=1 y los controles faltantes.

preserve

    keep if universo_demografico == 1

    assert _N == `n_universo'

    isid anio conglome vivienda hogar codperso

    isid anio p201p

    * Verificar correspondencias dentro del universo del estudio.
    bysort conglome: assert ///
        id_conglomerado_marco == id_conglomerado_marco[1]

    bysort p201p: assert ///
        id_conglomerado_marco == id_conglomerado_marco[1]

    foreach v in ubigeo estrato dominio {

        assert !missing(`v')

        bysort id_conglomerado_marco: assert `v' == `v'[1]
    }

    display _newline "BASE AMPLIA PARA HECKMAN"

    count

    tabulate anio S_ingreso, missing

    sort anio conglome vivienda hogar codperso

    save "`salida'/base_heckman_2023_2025.dta", replace

restore

* Confirmar que Heckman ya fue guardada antes de crear la base MCO.
confirm file "`salida'/base_heckman_2023_2025.dta"


* 11. GUARDAR UNA TABLA DE EXCLUSIONES POR ANIO E INFORMALIDAD
* Es un resumen separado; no modifica la maestra.

preserve

    keep if ocupado_ambito == 1

    assert _N == `n_ocupados'

    generate byte informalidad_tabla = informal

    replace informalidad_tabla = 2 ///
        if missing(informalidad_tabla)

    label define informalidad_tabla_lab ///
        0 "Formal" ///
        1 "Informal" ///
        2 "Sin clasificacion", replace

    label values informalidad_tabla informalidad_tabla_lab

    contract anio motivo_exclusion_mco informalidad_tabla, freq(N)

    sort anio motivo_exclusion_mco informalidad_tabla

    save "`salida'/tabla_exclusiones_2023_2025.dta", replace

restore


* 12. CREAR AHORA LA COPIA MCO

keep if muestra_salario_controles_final == 1

assert _N == `n_mco'

isid anio conglome vivienda hogar codperso

isid id_observacion

isid anio p201p

assert S_ingreso == 1

assert !missing(y_log_ingreso_hora, y_log_ingreso_hora_w, ///
    tic_uso_pc, actividades_centradas, informal, ///
    educ_years, experiencia_potencial, experiencia2, ///
    mujer, casado, jefe_hogar, sector10, ///
    ocupacion10_final, anio, mes_num)

assert !missing(fac500a) & fac500a > 0


* 13. AUDITAR REPETICIONES DE P201P EN LA MUESTRA MCO
* Las alertas se documentan. No se eliminan registros por ellas.

bysort id_persona_p201p (anio): ///
    generate byte aud_apariciones_mco = _N

egen byte aud_tag_persona_mco = tag(id_persona_p201p)

bysort id_persona_p201p (anio): ///
    generate byte aud_cambio_sexo = ///
    (p207 != p207[_n-1]) ///
    if _n > 1 & !missing(p207, p207[_n-1])

by id_persona_p201p: ///
    generate byte aud_alerta_edad = ///
    (abs((edad - edad[_n-1]) - (anio - anio[_n-1])) > 1) ///
    if _n > 1 & !missing(edad, edad[_n-1])

bysort id_persona_p201p: ///
    egen byte aud_alerta_sexo_persona = max(aud_cambio_sexo)

bysort id_persona_p201p: ///
    egen byte aud_alerta_edad_persona = max(aud_alerta_edad)

generate byte aud_alguna_alerta_persona = ///
    (aud_alerta_sexo_persona == 1 | ///
    aud_alerta_edad_persona == 1)

display _newline "CODIGOS P201P DISTINTOS EN LA MUESTRA MCO"

count if aud_tag_persona_mco == 1

display "APARICIONES POR CODIGO P201P"

tabulate aud_apariciones_mco ///
    if aud_tag_persona_mco == 1

display "CODIGOS CON CAMBIOS DE SEXO REGISTRADO"

count if aud_tag_persona_mco == 1 & ///
    aud_alerta_sexo_persona == 1

display "CODIGOS CON ALERTAS DE EDAD"

count if aud_tag_persona_mco == 1 & ///
    aud_alerta_edad_persona == 1

display "CODIGOS CON ALGUNA ALERTA"

count if aud_tag_persona_mco == 1 & ///
    aud_alguna_alerta_persona == 1


* 14. CONTAR GRUPOS DE CONGLOMERADO Y HOGAR

egen byte aud_tag_marco_mco = tag(id_conglomerado_marco)

egen byte aud_tag_hogar_mco = tag(id_hogar_marco)

display _newline "GRUPOS DEL MARCO EN LA MUESTRA MCO"

count if aud_tag_marco_mco == 1

display "LLAVES DE HOGAR DEL MARCO EN LA MUESTRA MCO"

count if aud_tag_hogar_mco == 1


* 15. GUARDAR LA BASE MCO

assert _N == `n_mco'

sort anio conglome vivienda hogar codperso

compress

save "`salida'/base_mco_2023_2025.dta", replace

display _newline "MUESTRA MCO GUARDADA"

tabulate anio


* 16. CIERRE

display _newline "ETAPA 5 TERMINADA"

display "Maestra completa: `n_maestra' observaciones"
display "Base amplia Heckman: `n_universo' observaciones"
display "Base MCO: `n_mco' observaciones"

display "Archivos creados:"
display "base_maestra_etapa05.dta"
display "base_heckman_2023_2025.dta"
display "base_mco_2023_2025.dta"
display "tabla_exclusiones_2023_2025.dta"

log close etapa05

















version 17.0
clear all
set more off


* ============================================================
* ETAPA 6: MCO, MODELOS INTERMEDIOS E INFERENCIA
* Todos los modelos utilizan la misma muestra.
* No se modifica ni se sobrescribe la base de datos.
* ============================================================


* 1. DIRECTORIOS Y BASE

local salida ///
    "$ENAHO_SALIDA"

local resultados "`salida'/Estimaciones_MCO"

capture mkdir "`resultados'"

confirm file "`salida'/base_mco_2023_2025.dta"

capture log close etapa06

log using "`resultados'/06_Estimaciones_MCO.log", ///
    text replace name(etapa06)

use "`salida'/base_mco_2023_2025.dta", clear

local n_mco = _N

isid anio conglome vivienda hogar codperso

isid id_observacion

assert muestra_salario_controles_final == 1

assert !missing(y_log_ingreso_hora, y_log_ingreso_hora_w, ///
    tic_uso_pc, actividades_centradas, informal, ///
    educ_years, experiencia_potencial, experiencia2, ///
    mujer, casado, jefe_hogar, sector10, ///
    ocupacion10_final, anio, mes_num, ///
    id_conglomerado_marco, id_persona_p201p, id_hogar_marco)

assert !missing(fac500a) & fac500a > 0


* 2. BLOQUES DE VARIABLES Y REFERENCIAS EXPLICITAS
*
* Mujer: hombre = 0.
* Casado: no casado = 0.
* Jefe: no jefe = 0.
* Informalidad: formal = 0.
* Uso de computadora: no usuario = 0.
* Sector: agropecuario/pesca = 1.
* Ocupacion: militar = 0, como en la especificacion anterior.
* Anio: 2023.
* Mes: enero = 1.

local personales "c.educ_years c.experiencia_potencial c.experiencia2 ib0.mujer ib0.casado ib0.jefe_hogar"

local productivos "ib1.sector10 ib0.ocupacion10_final"

local temporales "ib2023.anio ib1.mes_num"

local tic_sin_interacciones "ib0.informal ib0.tic_uso_pc c.actividades_centradas"

local tic_interacciones "ib0.tic_uso_pc##ib0.informal c.actividades_centradas##ib0.informal"

* Se conserva la media de referencia construida en la etapa 4.
* No se recalcula al ponderar ni al cambiar la especificacion.


* 3. PREPARAR ARCHIVOS DE RESULTADOS

tempname Hcoef Hcontr Htest B V

postfile `Hcoef' ///
    str24 modelo ///
    str32 inferencia ///
    str32 dependiente ///
    str64 termino ///
    byte ponderado omitido ///
    double b se p li ls N r2 grupos ///
    using "`resultados'/coeficientes_MCO.dta", replace

postfile `Hcontr' ///
    str24 modelo ///
    str32 inferencia ///
    str40 contraste ///
    double b se p li ls N ///
    using "`resultados'/contrastes_MCO.dta", replace

postfile `Htest' ///
    str24 modelo ///
    str32 inferencia ///
    str32 prueba ///
    double F gl_num gl_den p N ///
    using "`resultados'/pruebas_MCO.dta", replace


* 4. ESTIMAR LOS MODELOS PREDEFINIDOS

foreach modelo in ///
    M1_Mincer I1_Informal I2_TIC M2_Principal ///
    R1_SinProductivos R2_Ajustado ///
    R3_P201P R4_Hogar R5_Ponderado R6_Robusto {

    local dependiente "y_log_ingreso_hora"

    local regresores ///
        "`personales' `productivos' `temporales'"

    local pesos ""

    local ponderado = 0

    local vce "cluster id_conglomerado_marco"

    local inferencia "Cluster marco"


    * Mincer mas informalidad.
    if "`modelo'" == "I1_Informal" {

        local regresores ///
            "`regresores' ib0.informal"
    }


    * Mincer, informalidad y TIC sin interacciones.
    if "`modelo'" == "I2_TIC" {

        local regresores ///
            "`regresores' `tic_sin_interacciones'"
    }


   * Principal y sus variantes.

if !inlist("`modelo'", "M1_Mincer", "I1_Informal", "I2_TIC") {

    local regresores "`personales' `productivos' `temporales' `tic_interacciones'"
}

    * Principal sin controles de sector y ocupacion.
    if "`modelo'" == "R1_SinProductivos" {

        local regresores ///
            "`personales' `temporales' `tic_interacciones'"
    }


    * Resultado ajustado a p1-p99.
    if "`modelo'" == "R2_Ajustado" {

        local dependiente "y_log_ingreso_hora_w"
    }


    * Inferencia alternativa agrupada por codigo P201P.
    if "`modelo'" == "R3_P201P" {

        local vce "cluster id_persona_p201p"

        local inferencia "Cluster P201P"
    }


    * Inferencia alternativa agrupada por hogar del marco.
    if "`modelo'" == "R4_Hogar" {

        local vce "cluster id_hogar_marco"

        local inferencia "Cluster hogar"
    }


    * Ponderacion con factor de expansion.
    if "`modelo'" == "R5_Ponderado" {

        local pesos "[pweight=fac500a]"

        local ponderado = 1

        local inferencia "Ponderado cluster marco"
    }


    * Errores robustos a heterocedasticidad sin agrupacion.
    if "`modelo'" == "R6_Robusto" {

        local vce "robust"

        local inferencia "Robusto sin agrupacion"
    }


    display _newline "MODELO: `modelo'"
    display "Dependiente: `dependiente'"
    display "Inferencia: `inferencia'"

    regress `dependiente' `regresores' `pesos', ///
        vce(`vce') level(95)

    * Comprobar que los cambios no provengan de otra muestra.
    assert e(N) == `n_mco'

    estimates store `modelo'

    estimates save ///
        "`resultados'/`modelo'.ster", replace


    * --------------------------------------------------------
    * 4.1. GUARDAR COEFICIENTES, ERRORES E INTERVALOS
    * --------------------------------------------------------

    matrix `B' = e(b)

    matrix `V' = e(V)

    local nombres : colnames `B'

    local j = 0

    local grupos = .

    if "`vce'" != "robust" {
        local grupos = e(N_clust)
    }

    foreach termino of local nombres {

        local j = `j' + 1

        local bcoef = el(`B', 1, `j')

        local secoef = sqrt(el(`V', `j', `j'))

        * Referencias o terminos omitidos presentan SE igual a cero.
        local omitido = (`secoef' == 0)

        local pcoef = .
        local lic = .
        local lsc = .

        if `secoef' > 0 & `secoef' < . {

            local pcoef = ///
                2 * ttail(e(df_r), abs(`bcoef' / `secoef'))

            local critico = invttail(e(df_r), 0.025)

            local lic = `bcoef' - `critico' * `secoef'

            local lsc = `bcoef' + `critico' * `secoef'
        }

        post `Hcoef' ///
            ("`modelo'") ///
            ("`inferencia'") ///
            ("`dependiente'") ///
            ("`termino'") ///
            (`ponderado') (`omitido') ///
            (`bcoef') (`secoef') (`pcoef') (`lic') (`lsc') ///
            (e(N)) (e(r2)) (`grupos')
    }


    * --------------------------------------------------------
    * 4.2. PRUEBAS Y CONTRASTES EN MODELOS CON INTERACCIONES
    * --------------------------------------------------------

    if !inlist("`modelo'", ///
        "M1_Mincer", "I1_Informal", "I2_TIC") {

        * H0: ambos margenes TIC entre formales son cero.
        test ///
            (1.tic_uso_pc = 0) ///
            (actividades_centradas = 0)

        post `Htest' ///
            ("`modelo'") ("`inferencia'") ///
            ("TIC entre formales") ///
            (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N))


        * H0: no existe heterogeneidad por informalidad.
        test ///
            (1.tic_uso_pc#1.informal = 0) ///
            (1.informal#c.actividades_centradas = 0)

        post `Htest' ///
            ("`modelo'") ("`inferencia'") ///
            ("Heterogeneidad por informalidad") ///
            (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N))


        * H0: todo el bloque TIC es cero.
        test ///
            (1.tic_uso_pc = 0) ///
            (actividades_centradas = 0) ///
            (1.tic_uso_pc#1.informal = 0) ///
            (1.informal#c.actividades_centradas = 0)

        post `Htest' ///
            ("`modelo'") ("`inferencia'") ///
            ("Bloque TIC completo") ///
            (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N))


        * Beta_u + delta_u:
        * Usuario informal en intensidad media versus
        * no usuario informal, manteniendo los controles.
        lincom ///
            1.tic_uso_pc + 1.tic_uso_pc#1.informal, level(95)

        post `Hcontr' ///
            ("`modelo'") ("`inferencia'") ///
            ("U entre informales") ///
            (r(estimate)) (r(se)) (r(p)) ///
            (r(lb)) (r(ub)) (e(N))


        * Beta_a + delta_a:
        * Una actividad adicional entre usuarios informales.
        lincom ///
            actividades_centradas + ///
            1.informal#c.actividades_centradas, level(95)

        post `Hcontr' ///
            ("`modelo'") ("`inferencia'") ///
            ("Actividad entre informales") ///
            (r(estimate)) (r(se)) (r(p)) ///
            (r(lb)) (r(ub)) (e(N))


        * Theta + delta_u:
        * Informal versus formal, ambos usuarios en la
        * intensidad de referencia.
        lincom ///
            1.informal + 1.tic_uso_pc#1.informal, level(95)

        post `Hcontr' ///
            ("`modelo'") ("`inferencia'") ///
            ("Brecha informal-formal entre usuarios") ///
            (r(estimate)) (r(se)) (r(p)) ///
            (r(lb)) (r(ub)) (e(N))


        * Theta + beta_u + delta_u:
        * Usuario informal en intensidad media versus
        * no usuario formal, manteniendo los controles.
        lincom ///
            1.informal + 1.tic_uso_pc + ///
            1.tic_uso_pc#1.informal, level(95)

        post `Hcontr' ///
            ("`modelo'") ("`inferencia'") ///
            ("Usuario informal vs no usuario formal") ///
            (r(estimate)) (r(se)) (r(p)) ///
            (r(lb)) (r(ub)) (e(N))
    }
}


* 5. CERRAR LOS ARCHIVOS DE RESULTADOS

postclose `Hcoef'

postclose `Hcontr'

postclose `Htest'


* 6. COMPARAR LAS ESPECIFICACIONES POR BLOQUES

display _newline "MODELOS INTERMEDIOS Y PRINCIPAL"

estimates table ///
    M1_Mincer I1_Informal I2_TIC M2_Principal, ///
    keep(educ_years experiencia_potencial experiencia2 ///
         1.informal 1.tic_uso_pc actividades_centradas ///
         1.tic_uso_pc#1.informal ///
         1.informal#c.actividades_centradas) ///
    b(%9.4f) se(%9.4f) stats(N r2)


display _newline "SENSIBILIDAD A CONTROLES PRODUCTIVOS Y RESULTADO AJUSTADO"

estimates table ///
    M2_Principal R1_SinProductivos R2_Ajustado, ///
    keep(1.informal 1.tic_uso_pc actividades_centradas ///
         1.tic_uso_pc#1.informal ///
         1.informal#c.actividades_centradas) ///
    b(%9.4f) se(%9.4f) stats(N r2)


display _newline "COMPARACION DE INFERENCIA Y PONDERACION"

estimates table ///
    M2_Principal R3_P201P R4_Hogar R5_Ponderado R6_Robusto, ///
    keep(1.informal 1.tic_uso_pc actividades_centradas ///
         1.tic_uso_pc#1.informal ///
         1.informal#c.actividades_centradas) ///
    b(%9.4f) se(%9.4f) stats(N r2)


* 7. DEJAR ACTIVO EL MODELO PRINCIPAL

estimates restore M2_Principal

assert e(N) == `n_mco'

display _newline "ETAPA 6 TERMINADA"

display "Resultados guardados en:"
display "`resultados'"

display "Archivos:"
display "06_Estimaciones_MCO.log"
display "coeficientes_MCO.dta"
display "contrastes_MCO.dta"
display "pruebas_MCO.dta"
display "Estimaciones de cada modelo en archivos .ster"

log close etapa06















version 17.0
clear all
set more off
set level 95

* ETAPA 07: precios comunes y sensibilidad de MCO.
* Ejecutar el archivo completo, no lineas aisladas con macros locales.
* No requiere paquetes externos ni conexion a Internet.
* No sobrescribe las bases de las etapas anteriores.
* Las restricciones de sensibilidad usan if; la base MCO conserva sus filas.

local salida "$ENAHO_SALIDA"
local resultados "`salida'/Auditoria_MCO_etapa07"
capture mkdir "`resultados'"

confirm file "`salida'/base_mco_2023_2025.dta"
confirm file "`salida'/base_heckman_2023_2025.dta"
capture log close etapa07
log using "`resultados'/07_Precios_y_sensibilidad_MCO.log", text replace name(etapa07)

* 1. IPC GENERAL DE LIMA METROPOLITANA, FUENTE INEI/BCRP.
* Serie PN38705PM, indice diciembre de 2021 = 100.
* URL de consulta y API; valores descargados el 13 de octubre de 2026:
* https://estadisticas.bcrp.gob.pe/estadisticas/series/mensuales/indice-de-precios-indice-dic-2021-100
* https://estadisticas.bcrp.gob.pe/estadisticas/series/api/PN38705PM/json/2023-1/2025-12/esp
* Metodologia: INEI, Evolucion de la pobreza monetaria 2016-2025,
* capitulo VIII, pp. 393-396. Las bases anuales estandarizan a precios
* promedio de su propio anio. Aqui se realiza la conversion entre anios.
* No se vuelve a aplicar una correccion por el mes de entrevista.
* Se usa el IPC general para la medida agregada de ingreso laboral.

clear
input int anio byte mes_ipc double ipc_mensual
2023 1 108.704764
2023 2 109.024924
2023 3 110.391537
2023 4 111.005592
2023 5 111.358436
2023 6 111.188314
2023 7 111.623134
2023 8 112.042985
2023 9 112.061363
2023 10 111.700024
2023 11 111.517885
2023 12 111.970400
2024 1 111.991911
2024 2 112.616278
2024 3 113.753010
2024 4 113.694232
2024 5 113.591104
2024 6 113.729392
2024 7 113.998099
2024 8 114.322048
2024 9 114.050464
2024 10 113.944279
2024 11 114.051561
2024 12 114.172077
2025 1 114.065534
2025 2 114.279991
2025 3 115.205841
2025 4 115.572272
2025 5 115.507003
2025 6 115.655637
2025 7 115.923300
2025 8 115.586828
2025 9 115.599718
2025 10 115.484549
2025 11 115.612485
2025 12 115.894705
end
isid anio mes_ipc
bysort anio: assert _N == 12
assert ipc_mensual > 0 & !missing(ipc_mensual)
save "`resultados'/ipc_mensual_fuente.dta", replace

collapse (mean) ipc_promedio=ipc_mensual, by(anio)
quietly summarize ipc_promedio if anio == 2025, meanonly
local ipc2025 = r(mean)
generate double deflactor_2025 = ipc_promedio / `ipc2025'
generate double multiplicador_2025 = 1 / deflactor_2025
label variable deflactor_2025 "IPC promedio del anio / IPC promedio 2025"
label variable multiplicador_2025 "Multiplicador para expresar a precios promedio 2025"
isid anio
list, noobs
tempfile ipc
save "`ipc'", replace
save "`resultados'/ipc_anual_conversion_2025.dta", replace

* 2. COPIA AMPLIA PARA HECKMAN: SOLO CAMBIO DE UNIDADES MONETARIAS.
* Se conservan seleccionados, no seleccionados y valores perdidos.

use "`salida'/base_heckman_2023_2025.dta", clear
local n_heckman = _N
isid anio conglome vivienda hogar codperso
merge m:1 anio using "`ipc'", assert(match) nogen
assert ld == 1
generate double ing_hora_real2025 = ing_hora_total / deflactor_2025
generate double ln_ing_hora_real2025 = y_log_ingreso_hora - ln(deflactor_2025)
generate double ing_hora_liq_real2025 = ing_hora_liquido / deflactor_2025
generate double ln_ing_liq_real2025 = ln_ing_hora_liquido - ln(deflactor_2025)
generate double ingreso_nolaboral_real2025 = ingreso_no_laboral_hh / deflactor_2025
generate double ln_nolaboral_real2025 = ln(1 + ingreso_nolaboral_real2025)
assert missing(ln_ing_hora_real2025) == missing(y_log_ingreso_hora)
assert S_ingreso == !missing(ln_ing_hora_real2025)
assert _N == `n_heckman'
save "`salida'/base_heckman_precios2025_etapa07.dta", replace
display "Base amplia preservada. No se estima Heckman en esta etapa."
tabulate anio S_ingreso, missing

* 3. COPIA MCO A PRECIOS PROMEDIO DE 2025.

use "`salida'/base_mco_2023_2025.dta", clear
local n_mco = _N
assert `n_mco' == 18065
isid anio conglome vivienda hogar codperso
isid id_observacion
merge m:1 anio using "`ipc'", assert(match) nogen
assert ld == 1
generate double ing_hora_real2025 = ing_hora_total / deflactor_2025
generate double ln_ing_hora_real2025 = y_log_ingreso_hora - ln(deflactor_2025)
generate double ing_hora_aj_real2025 = ing_hora_w_1_99 / deflactor_2025
generate double ln_ing_aj_real2025 = y_log_ingreso_hora_w - ln(deflactor_2025)
generate double ing_hora_liq_real2025 = ing_hora_liquido / deflactor_2025
generate double ln_ing_liq_real2025 = ln_ing_hora_liquido - ln(deflactor_2025)
generate double p1_real2025 = p1_ing_hora / deflactor_2025
generate double p99_real2025 = p99_ing_hora / deflactor_2025
label variable ing_hora_real2025 "Ingreso principal por hora, soles promedio de 2025"
label variable ln_ing_hora_real2025 "Log ingreso principal por hora, precios promedio 2025"
label variable ing_hora_aj_real2025 "Ingreso horario ajustado p1-p99 anual, precios 2025"

* Los limites p1-p99 son los de la etapa 4: no se recalculan aqui.
* Al multiplicar por un mismo factor dentro de cada anio se conserva
* tanto la ordenacion como la identificacion de los extremos.
assert abs(ln_ing_hora_real2025 - ln(ing_hora_real2025)) < 1e-6
assert !missing(ln_ing_hora_real2025, tic_uso_pc, informal, actividades_centradas)
assert inlist(tipo_trabajador, 1, 2)
assert fac500a > 0 & !missing(fac500a)
assert inlist(extremo_bajo, 0, 1) & inlist(extremo_alto, 0, 1)

* Sensibilidades: estas banderas NO eliminan registros de la base.
generate byte s_recorte = extremo_bajo == 0 & extremo_alto == 0
generate byte s_horas5 = horas_prin_sem >= 5 & !missing(horas_prin_sem)
generate byte s_horas10 = horas_prin_sem >= 10 & !missing(horas_prin_sem)
generate byte s_sin98 = horas_prin_sem != 98 & !missing(horas_prin_sem)
generate byte s_liquido_comun = !missing(ln_ing_liq_real2025)
generate byte aud_extremo = extremo_bajo == 1 | extremo_alto == 1 | horas_prin_sem < 5 | horas_prin_sem == 98

* Alternativa TIC sin programacion: misma muestra y media congelada
* entre los usuarios de toda la muestra MCO. La nueva media corresponde
* al indicador de ocho actividades; cambia la referencia de beta_u.
generate byte actividades8 = tic_actividades_usuarios - act9 if tic_uso_pc == 1
assert inrange(actividades8, 0, 8) if tic_uso_pc == 1
quietly summarize actividades8 if tic_uso_pc == 1, meanonly
local media8 = r(mean)
generate double actividades8_centradas = 0 if tic_uso_pc == 0
replace actividades8_centradas = actividades8 - `media8' if tic_uso_pc == 1
generate double media8_referencia = `media8'
assert !missing(actividades8_centradas)
quietly summarize media_actividades_referencia, meanonly
local media9 = r(mean)
assert abs(media_actividades_referencia - `media9') < 1e-10
display "Media de referencia de nueve actividades: " %12.9f `media9'
display "Media de referencia de ocho actividades: " %12.9f `media8'

tabstat ing_hora_total ing_hora_real2025 horas_prin_sem, by(anio) statistics(n mean sd min p1 p50 p99 max) columns(statistics)
foreach bandera in extremo_bajo extremo_alto s_recorte s_horas5 s_horas10 s_sin98 s_liquido_comun {
    display "BANDERA: `bandera'"
    tabulate anio `bandera', missing
    tabulate informal `bandera', missing
}

* Archivo para revisar registros, sin cambiar la base analitica.
preserve
keep if aud_extremo == 1
keep anio conglome vivienda hogar codperso p201p p507 tipo_trabajador informal p513t i513t horas_prin_sem i524a1 i524e1 i530a ing_prin_total_anual ing_hora_total ing_hora_real2025 extremo_bajo extremo_alto
sort anio ing_hora_total
save "`resultados'/registros_extremos_y_horas.dta", replace
restore
preserve
sort ing_hora_total
list anio conglome vivienda hogar codperso p507 ing_prin_total_anual horas_prin_sem ing_hora_total in 1/10, noobs
gsort -ing_hora_total
list anio conglome vivienda hogar codperso p507 ing_prin_total_anual horas_prin_sem ing_hora_total in 1/10, noobs
restore

assert _N == `n_mco'
save "`salida'/base_mco_precios2025_etapa07.dta", replace

* 4. ESPECIFICACION: TODAS LAS CADENAS ENTRE COMILLAS EN UNA LINEA.
* Bases: hombre; no casado; no jefe; formal; no usuario;
* sector agro/pesca = 1; ocupacion militar = 0; 2023; enero.
local personales "c.educ_years c.experiencia_potencial c.experiencia2 ib0.mujer ib0.casado ib0.jefe_hogar"
local productivos "ib1.sector10 ib0.ocupacion10_final"
local temporales "ib2023.anio ib1.mes_num"
local tic9 "ib0.tic_uso_pc##ib0.informal c.actividades_centradas##ib0.informal"
local tic8 "ib0.tic_uso_pc##ib0.informal c.actividades8_centradas##ib0.informal"
local principal "`personales' `productivos' `temporales' `tic9'"

* 5. COMPROBAR LA EQUIVALENCIA DEL CAMBIO DE PRECIOS CON FE ANUALES.
* Se verifican coeficientes y errores de los terminos distintos de
* anio e intercepto. No se afirma equivalencia de los descriptivos.
quietly regress y_log_ingreso_hora `principal', vce(cluster id_conglomerado_marco)
tempname B0 V0 B1 V1
matrix `B0' = e(b)
matrix `V0' = e(V)
quietly regress ln_ing_hora_real2025 `principal', vce(cluster id_conglomerado_marco)
matrix `B1' = e(b)
matrix `V1' = e(V)
local nombres : colnames `B0'
local j = 0
foreach termino of local nombres {
    local j = `j' + 1
    if "`termino'" != "_cons" & strpos("`termino'", ".anio") == 0 {
        assert abs(el(`B0', 1, `j') - el(`B1', 1, `j')) < 1e-8
        assert abs(sqrt(el(`V0', `j', `j')) - sqrt(el(`V1', `j', `j'))) < 1e-8
    }
}
display "Conversion verificada: coeficientes y SE no temporales coinciden."

* 6. ESTIMACIONES Y ARCHIVOS DE REPORTE.
tempname HC HT HX B V
postfile `HC' str24 modelo str64 termino str20 inferencia double b se p li ls N r2 grupos using "`resultados'/coeficientes_sensibilidad.dta", replace
postfile `HT' str24 modelo str40 prueba double F gl1 gl2 p N using "`resultados'/pruebas_sensibilidad.dta", replace
postfile `HX' str24 modelo str64 contraste double b se p li ls N using "`resultados'/contrastes_sensibilidad.dta", replace

foreach modelo in M1_Real I1_Real I2_Real M2_Real Pond_Real P201P_Real Hogar_Real R_SinProductivos R_Ajustado R_Recorte R_Horas5 R_Horas10 R_Sin98 R_TotalComun R_LiquidoComun R_Dependientes R_Independientes R_TIC8 {
    local y "ln_ing_hora_real2025"
    local x "`principal'"
    local condicion "1"
    local pesos ""
    local cluster "id_conglomerado_marco"
    local inferencia "Cluster marco"
    local act "actividades_centradas"
    local centro = `media9'

    if "`modelo'" == "M1_Real" local x "`personales' `productivos' `temporales'"
    if "`modelo'" == "I1_Real" local x "`personales' `productivos' `temporales' ib0.informal"
    if "`modelo'" == "I2_Real" local x "`personales' `productivos' `temporales' ib0.informal ib0.tic_uso_pc c.actividades_centradas"
    if "`modelo'" == "R_SinProductivos" local x "`personales' `temporales' `tic9'"
    if "`modelo'" == "R_Ajustado" local y "ln_ing_aj_real2025"
    if "`modelo'" == "R_Recorte" local condicion "s_recorte == 1"
    if "`modelo'" == "R_Horas5" local condicion "s_horas5 == 1"
    if "`modelo'" == "R_Horas10" local condicion "s_horas10 == 1"
    if "`modelo'" == "R_Sin98" local condicion "s_sin98 == 1"
    if inlist("`modelo'", "R_TotalComun", "R_LiquidoComun") local condicion "s_liquido_comun == 1"
    if "`modelo'" == "R_LiquidoComun" local y "ln_ing_liq_real2025"
    if "`modelo'" == "R_Dependientes" local condicion "tipo_trabajador == 1"
    if "`modelo'" == "R_Independientes" local condicion "tipo_trabajador == 2"
    if "`modelo'" == "Pond_Real" {
        local pesos "[pweight=fac500a]"
        local inferencia "Ponderado marco"
    }
    if "`modelo'" == "P201P_Real" {
        local cluster "id_persona_p201p"
        local inferencia "Cluster P201P"
    }
    if "`modelo'" == "Hogar_Real" {
        local cluster "id_hogar_marco"
        local inferencia "Cluster hogar"
    }
    if "`modelo'" == "R_TIC8" {
        local x "`personales' `productivos' `temporales' `tic8'"
        local act "actividades8_centradas"
        local centro = `media8'
    }

    display _newline "MODELO: `modelo'"
    display "Dependiente: `y'; inferencia: `inferencia'"
    quietly count if `condicion'
    local n_esperado = r(N)
    regress `y' `x' if `condicion' `pesos', vce(cluster `cluster') level(95)
    assert e(N) == `n_esperado'
    estimates store `modelo'
    estimates save "`resultados'/`modelo'.ster", replace
    if "`modelo'" == "M2_Real" generate byte muestra_principal07 = e(sample)

    matrix `B' = e(b)
    matrix `V' = e(V)
    local nombres : colnames `B'
    local j = 0
    foreach termino of local nombres {
        local j = `j' + 1
        local b = el(`B', 1, `j')
        local se = sqrt(el(`V', `j', `j'))
        local p = .
        local li = .
        local ls = .
        if `se' > 0 & `se' < . {
            local p = 2 * ttail(e(df_r), abs(`b' / `se'))
            local critico = invttail(e(df_r), 0.025)
            local li = `b' - `critico' * `se'
            local ls = `b' + `critico' * `se'
        }
        post `HC' ("`modelo'") ("`termino'") ("`inferencia'") (`b') (`se') (`p') (`li') (`ls') (e(N)) (e(r2)) (e(N_clust))
    }

    if !inlist("`modelo'", "M1_Real", "I1_Real", "I2_Real") {
        test (1.tic_uso_pc = 0) (`act' = 0)
        post `HT' ("`modelo'") ("TIC entre formales") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N))
        test (1.tic_uso_pc#1.informal = 0) (1.informal#c.`act' = 0)
        post `HT' ("`modelo'") ("Heterogeneidad por informalidad") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N))
        test (1.tic_uso_pc = 0) (`act' = 0) (1.tic_uso_pc#1.informal = 0) (1.informal#c.`act' = 0)
        post `HT' ("`modelo'") ("Bloque TIC completo") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N))

        lincom 1.tic_uso_pc + 1.tic_uso_pc#1.informal
        post `HX' ("`modelo'") ("U entre informales, intensidad de referencia") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N))
        lincom `act' + 1.informal#c.`act'
        post `HX' ("`modelo'") ("Actividad adicional entre informales") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N))
        lincom 1.informal + 1.tic_uso_pc#1.informal
        post `HX' ("`modelo'") ("Brecha informal-formal entre usuarios") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N))
        lincom 1.informal + 1.tic_uso_pc + 1.tic_uso_pc#1.informal
        post `HX' ("`modelo'") ("Usuario informal vs no usuario formal") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N))

        * Usuarios con cero actividades: referencia observable comun.
        lincom 1.tic_uso_pc - `centro' * `act'
        post `HX' ("`modelo'") ("Usuario formal cero act. vs no usuario formal") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N))
        lincom 1.tic_uso_pc + 1.tic_uso_pc#1.informal - `centro' * (`act' + 1.informal#c.`act')
        post `HX' ("`modelo'") ("Usuario informal cero act. vs no usuario informal") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N))
    }
}
postclose `HC'
postclose `HT'
postclose `HX'

* 7. GUARDAR SIN RESTRINGIR LA BASE A LA ULTIMA ESTIMACION.
assert _N == `n_mco'
assert muestra_principal07 == 1
sort anio conglome vivienda hogar codperso
save "`salida'/base_mco_precios2025_etapa07.dta", replace

preserve
use "`resultados'/coeficientes_sensibilidad.dta", clear
sort modelo termino
export delimited using "`resultados'/coeficientes_sensibilidad.csv", replace
restore
preserve
use "`resultados'/contrastes_sensibilidad.dta", clear
generate double diferencia_pct = 100 * (exp(b) - 1)
generate double li_pct = 100 * (exp(li) - 1)
generate double ls_pct = 100 * (exp(ls) - 1)
label variable diferencia_pct "Diferencia porcentual condicional: 100*(exp(b)-1)"
save "`resultados'/contrastes_sensibilidad.dta", replace
export delimited using "`resultados'/contrastes_sensibilidad.csv", replace
restore
preserve
use "`resultados'/pruebas_sensibilidad.dta", clear
export delimited using "`resultados'/pruebas_sensibilidad.csv", replace
restore

display _newline "ETAPA 07 TERMINADA"
display "MCO conserva `n_mco' observaciones; Heckman conserva `n_heckman'."
display "Resultados: `resultados'"
display "Falta contrastar cuestionarios/filtros TIC y redactar las tablas."
log close etapa07
















version 17.0
clear all
set more off
set level 95

* ETAPA 08: diagnostico de medicion y composicion TIC.
* Este archivo NO certifica la equivalencia de cuestionarios.
* La comprobacion documental de 2025 sigue pendiente.
* No altera la construccion TIC, los centros ni las bases guardadas.
* Ejecutar el do-file completo.

local salida "$ENAHO_SALIDA"
local resultados "`salida'/Auditoria_TIC_etapa08"
capture mkdir "`resultados'"
confirm file "`salida'/base_maestra_etapa04.dta"
confirm file "`salida'/base_mco_precios2025_etapa07.dta"
capture log close etapa08
log using "`resultados'/08_Comparabilidad_TIC.log", text replace name(etapa08)

* 1. COMPARAR UNIVERSOS SIN CAMBIAR FILAS.
use "`salida'/base_maestra_etapa04.dta", clear
local n_maestra = _N
isid anio conglome vivienda hogar codperso
assert _N == 352613

tempname HR HA
postfile `HR' str24 universo int anio double N_total N_uso_valido N_usuarios uso_pct N_usuarios_completos media_A sd_A N_cero N_incompletos using "`resultados'/resumen_tic.dta", replace
postfile `HA' str24 universo int anio byte actividad double N media proporcion_pct using "`resultados'/actividades_por_anio.dta", replace

foreach universo in universo_demografico ocupado_ambito muestra_salario_controles_final {
    local nombre "Demografico"
    if "`universo'" == "ocupado_ambito" local nombre "Ocupados"
    if "`universo'" == "muestra_salario_controles_final" local nombre "MCO"

    foreach y in 2023 2024 2025 {
        quietly count if `universo' == 1 & anio == `y'
        local n_total = r(N)
        quietly summarize tic_uso_pc if `universo' == 1 & anio == `y'
        local n_valido = r(N)
        local uso = 100 * r(mean)
        quietly count if `universo' == 1 & anio == `y' & tic_uso_pc == 1
        local n_usuarios = r(N)
        quietly summarize tic_actividades_usuarios if `universo' == 1 & anio == `y' & tic_uso_pc == 1
        local n_completos = r(N)
        local media = r(mean)
        local sd = r(sd)
        quietly count if `universo' == 1 & anio == `y' & tic_uso_pc == 1 & tic_actividades_usuarios == 0
        local n_cero = r(N)
        local n_incompletos = `n_usuarios' - `n_completos'
        post `HR' ("`nombre'") (`y') (`n_total') (`n_valido') (`n_usuarios') (`uso') (`n_completos') (`media') (`sd') (`n_cero') (`n_incompletos')

        * Denominador comun: usuarios con las nueve actividades validas.
        forvalues j = 1/9 {
            quietly summarize act`j' if `universo' == 1 & anio == `y' & tic_uso_pc == 1 & !missing(tic_actividades_usuarios)
            post `HA' ("`nombre'") (`y') (`j') (r(N)) (r(mean)) (100 * r(mean))
        }
    }
}
postclose `HR'
postclose `HA'

* 2. CODIFICACION Y RESPUESTAS ESTRUCTURALMENTE NO APLICABLES.
display _newline "P316B EN EL UNIVERSO DEMOGRAFICO"
tabulate anio p316b if universo_demografico == 1, missing

egen byte aud_respuestas_c = rownonmiss(p316c1 p316c2 p316c3 p316c4 p316c5 p316c6 p316c7 p316c8 p316c9)
generate byte aud_c_fuera_filtro = 0 if universo_demografico == 1
generate byte aud_c_fuera_codigos = 0 if universo_demografico == 1 & tic_uso_pc == 1
forvalues j = 1/9 {
    replace aud_c_fuera_filtro = 1 if universo_demografico == 1 & p316b == 2 & inlist(p316c`j', 1, 2)
    replace aud_c_fuera_codigos = 1 if universo_demografico == 1 & tic_uso_pc == 1 & !inlist(p316c`j', 1, 2)
    display "CODIGOS DE P316C`j' ENTRE USUARIOS"
    tabulate anio p316c`j' if universo_demografico == 1 & tic_uso_pc == 1, missing
}
display "NO USUARIOS CON RESPUESTAS SI/NO A LAS ACTIVIDADES"
tabulate anio aud_c_fuera_filtro if universo_demografico == 1 & p316b == 2, missing
display "USUARIOS CON ALGUNA ACTIVIDAD INCOMPLETA O FUERA DE 1/2"
tabulate anio aud_c_fuera_codigos if universo_demografico == 1 & tic_uso_pc == 1, missing
assert _N == `n_maestra'

* 3. MOSTRAR LAS MEDIAS Y LOS CAMBIOS ENTRE ANIOS.
preserve
use "`resultados'/resumen_tic.dta", clear
sort universo anio
by universo (anio): generate double cambio_media = media_A - media_A[_n-1] if _n > 1
by universo (anio): generate double cambio_uso_pp = uso_pct - uso_pct[_n-1] if _n > 1
format media_A cambio_media %9.6f
format uso_pct cambio_uso_pp %9.3f
list universo anio N_total N_usuarios uso_pct media_A cambio_media N_incompletos, sepby(universo) noobs
save "`resultados'/resumen_tic.dta", replace
export delimited using "`resultados'/resumen_tic.csv", replace
restore

preserve
use "`resultados'/actividades_por_anio.dta", clear
sort universo actividad anio
by universo actividad (anio): generate double cambio_pp = proporcion_pct - proporcion_pct[_n-1] if _n > 1
format proporcion_pct cambio_pp %9.3f
list actividad anio N proporcion_pct cambio_pp if universo == "MCO", sepby(actividad) noobs
save "`resultados'/actividades_por_anio.dta", replace
export delimited using "`resultados'/actividades_por_anio.csv", replace
restore

* 4. COMPOSICION DE LOS USUARIOS DE LA MUESTRA MCO.
use "`salida'/base_mco_precios2025_etapa07.dta", clear
assert _N == 18065
assert muestra_salario_controles_final == 1
isid id_observacion
assert !missing(tic_actividades_usuarios) if tic_uso_pc == 1
assert !missing(edad, educ_years, mujer, informal, tipo_trabajador, sector10, ocupacion10_final, id_conglomerado_marco)
assert !missing(fac500a) & fac500a > 0
quietly count if tic_uso_pc == 1
local n_usuarios_mco = r(N)
assert `n_usuarios_mco' == 7933

display _newline "COMPOSICION DE USUARIOS POR ANIO"
tabstat edad educ_years mujer informal horas_prin_sem, by(anio) statistics(n mean sd) columns(statistics)
tabstat edad educ_years mujer informal horas_prin_sem if tic_uso_pc == 1, by(anio) statistics(n mean sd) columns(statistics)
tabulate anio tipo_trabajador if tic_uso_pc == 1, row
tabulate anio sector10 if tic_uso_pc == 1, row
tabulate anio ocupacion10_final if tic_uso_pc == 1, row

* Tablas de composicion guardadas con denominador explicitamente definido.
preserve
keep if tic_uso_pc == 1
collapse (count) N=tic_actividades_usuarios (mean) edad_media=edad educ_media=educ_years prop_mujer=mujer prop_informal=informal horas_media=horas_prin_sem prop_autoempleado=autoempleado, by(anio)
save "`resultados'/composicion_usuarios.dta", replace
export delimited using "`resultados'/composicion_usuarios.csv", replace
restore

* 5. DIFERENCIAS ANUALES DE INTENSIDAD ENTRE USUARIOS.
* Regresiones DESCRIPTIVAS: no estiman aprendizaje ni cambios causales.
* Ajustar por controles no certifica invariancia del cuestionario.
local demograficas "c.educ_years c.edad c.edad#c.edad ib0.mujer"
local productivas "ib0.informal ib1.tipo_trabajador ib1.sector10 ib0.ocupacion10_final"
tempname HC
postfile `HC' str24 modelo str24 contraste double b se p li ls N grupos using "`resultados'/contrastes_anio_intensidad.dta", replace

foreach modelo in TIC_Anio TIC_Demograficas TIC_Productivas TIC_Ponderado {
    local regresores "ib2023.anio"
    local pesos ""
    if "`modelo'" == "TIC_Demograficas" local regresores "ib2023.anio `demograficas'"
    if inlist("`modelo'", "TIC_Productivas", "TIC_Ponderado") local regresores "ib2023.anio `demograficas' `productivas'"
    if "`modelo'" == "TIC_Ponderado" local pesos "[pweight=fac500a]"
    display _newline "MODELO DESCRIPTIVO: `modelo'"
    regress tic_actividades_usuarios `regresores' if tic_uso_pc == 1 `pesos', vce(cluster id_conglomerado_marco)
    assert e(N) == `n_usuarios_mco'
    estimates store `modelo'
    estimates save "`resultados'/`modelo'.ster", replace

    lincom 2024.anio
    post `HC' ("`modelo'") ("2024 menos 2023") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
    lincom 2025.anio
    post `HC' ("`modelo'") ("2025 menos 2023") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
    lincom 2025.anio - 2024.anio
    post `HC' ("`modelo'") ("2025 menos 2024") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
}
postclose `HC'

preserve
use "`resultados'/contrastes_anio_intensidad.dta", clear
list, sepby(modelo) noobs
export delimited using "`resultados'/contrastes_anio_intensidad.csv", replace
restore

assert _N == 18065
display _newline "ETAPA 08 ESTADISTICA TERMINADA"
display "No se alteraron las bases ni la medicion TIC principal."
display "Pendiente: formulario e instrucciones de ENAHO 01A de 2025."
display "Las regresiones anuales son descriptivas, no causales."
log close etapa08













version 17.0
clear all
set more off
set level 95

* ETAPA 08B: cierre de diagnosticos MCO antes de Heckman.
* Ejecutar COMPLETO. No requiere paquetes externos.
* Principal sin ponderar, precios promedio de 2025, cluster del marco.
* Las alternativas y alertas son diagnosticas: no cambian la muestra
* principal ni constituyen reglas automaticas para eliminar registros.
* No se ejecuta Heckman ni se modifica su base amplia.

local salida "$ENAHO_SALIDA"
local resultados "`salida'/Diagnosticos_MCO_etapa08B"
capture mkdir "`resultados'"
confirm file "`salida'/base_mco_precios2025_etapa07.dta"
capture log close diagnostico08b
log using "`resultados'/08B_Diagnosticos_MCO.log", text replace name(diagnostico08b)
use "`salida'/base_mco_precios2025_etapa07.dta", clear
assert _N == 18065
assert muestra_salario_controles_final == 1
isid anio conglome vivienda hogar codperso
isid id_observacion
assert !missing(ln_ing_hora_real2025, educ_years, experiencia_potencial, experiencia2, mujer, casado, jefe_hogar, sector10, ocupacion10_final, anio, mes_num, tic_uso_pc, informal, actividades_centradas, id_conglomerado_marco)
local n_original = _N
egen byte d_tag_grupo = tag(id_conglomerado_marco)
quietly count if d_tag_grupo == 1
local grupos_original = r(N)
assert `grupos_original' == 772

local personales "c.educ_years c.experiencia_potencial c.experiencia2 ib0.mujer ib0.casado ib0.jefe_hogar"
local productivas "ib1.sector10 ib0.ocupacion10_final"
local temporales "ib2023.anio ib1.mes_num"
local tic "ib0.tic_uso_pc##ib0.informal c.actividades_centradas##ib0.informal"
local mincer "`personales' `productivas' `temporales'"
local principal "`mincer' `tic'"

* 1. EXPANSION NUMERICA EXPLICITA DE LA MATRIZ DE REGRESORES.
* Solo se utiliza en calculos auxiliares e influencia.
* Base principal: agro/pesca=1; militar=0; 2023; enero.
local sec_original ""
local sec_alternativa ""
forvalues j = 1/10 {
    generate byte d_sector`j' = sector10 == `j'
    if `j' != 1 local sec_original "`sec_original' d_sector`j'"
    if `j' != 6 local sec_alternativa "`sec_alternativa' d_sector`j'"
}
local ocu_original ""
local ocu_alternativa ""
forvalues j = 0/9 {
    generate byte d_ocu`j' = ocupacion10_final == `j'
    if `j' != 0 local ocu_original "`ocu_original' d_ocu`j'"
    if `j' != 9 local ocu_alternativa "`ocu_alternativa' d_ocu`j'"
}
local tiempo_numerico ""
foreach y in 2024 2025 {
    generate byte d_anio`y' = anio == `y'
    local tiempo_numerico "`tiempo_numerico' d_anio`y'"
}
forvalues j = 2/12 {
    generate byte d_mes`j' = mes_num == `j'
    local tiempo_numerico "`tiempo_numerico' d_mes`j'"
}
generate byte d_UI = tic_uso_pc * informal
generate double d_AI = actividades_centradas * informal
quietly summarize experiencia_potencial, meanonly
generate double d_exp_c = experiencia_potencial - r(mean)
generate double d_exp_c2 = d_exp_c^2
local continuas "educ_years experiencia_potencial experiencia2 mujer casado jefe_hogar"
local continuas_c "educ_years d_exp_c d_exp_c2 mujer casado jefe_hogar"
local tic_numericas "tic_uso_pc informal d_UI actividades_centradas d_AI"
local x_mincer "`continuas' `sec_original' `ocu_original' `tiempo_numerico'"
local x_principal "`x_mincer' `tic_numericas'"

* 2. FUNCIONES DE REPORTE.
tempname HV HT HC HP
postfile `HV' str8 modelo str24 parametrizacion str32 variable double vif tolerancia R2_aux N using "`resultados'/vif_diagnostico.dta", replace
postfile `HT' str24 modelo str48 prueba double F gl1 gl2 p N grupos using "`resultados'/pruebas_diagnostico.dta", replace
postfile `HC' str24 modelo str64 termino double b se p li ls N grupos using "`resultados'/coeficientes_diagnostico_MCO.dta", replace
postfile `HP' str8 modelo str24 parametrizacion double N columnas rango max_dif_ajuste max_dif_TIC max_dif_SE_TIC using "`resultados'/parametrizacion_diagnostico.dta", replace

capture program drop dm08_vif
program define dm08_vif
    args handle modelo esquema regresores
    foreach variable of local regresores {
        local otros : list regresores - variable
        quietly regress `variable' `otros'
        local r2 = e(r2)
        local vif = 1 / (1 - `r2')
        post `handle' ("`modelo'") ("`esquema'") ("`variable'") (`vif') (1 / `vif') (`r2') (e(N))
    }
end

capture program drop dm08_coef
program define dm08_coef
    args handle modelo
    tempname B V bb ss pp li ls crit
    matrix `B' = e(b)
    matrix `V' = e(V)
    local terminos : colnames `B'
    local k = colsof(`B')
    scalar `crit' = invttail(e(df_r), 0.025)
    forvalues j = 1/`k' {
        local termino : word `j' of `terminos'
        scalar `bb' = `B'[1, `j']
        scalar `ss' = sqrt(`V'[`j', `j'])
        if `ss' > 0 & !missing(`ss') {
            scalar `pp' = 2 * ttail(e(df_r), abs(`bb' / `ss'))
            scalar `li' = `bb' - `crit' * `ss'
            scalar `ls' = `bb' + `crit' * `ss'
            post `handle' ("`modelo'") ("`termino'") (`bb') (`ss') (`pp') (`li') (`ls') (e(N)) (e(N_clust))
        }
    }
end

* Funciones Mata: estandarizacion solo para mejorar precision numerica.
* X tiene N filas y K columnas, incluyendo intercepto.
* La eliminacion de un grupo usa exactamente los productos cruzados
* de los registros restantes; no es una aproximacion de primer orden.
mata:
real scalar dm08_rango(string scalar lista)
{
    real matrix A
    real rowvector mu, sd
    A = st_data(., tokens(lista))
    mu = mean(A)
    sd = sqrt(diagonal(variance(A)))'
    A = (J(rows(A), 1, 1), (A :- mu) :/ sd)
    return(rank(A))
}

void dm08_grupos(string scalar lista, string scalar dep, string scalar grupo)
{
    real matrix X0, X, Q, A, Xg, info, O, BC, SC
    real colvector y, g, b, bm, yg, xy
    real rowvector mu, sd, idx, jj
    real scalar j, t, lo, hi, k, beta, delta, err
    string rowvector nombres, nucleo
    nombres = tokens(lista)
    nucleo = tokens("tic_uso_pc actividades_centradas informal d_UI d_AI")
    X0 = st_data(., nombres)
    y = st_data(., dep)
    g = st_data(., grupo)
    mu = mean(X0)
    sd = sqrt(diagonal(variance(X0)))'
    X = (J(rows(X0), 1, 1), (X0 :- mu) :/ sd)
    k = cols(X)
    Q = quadcross(X, X)
    xy = quadcross(X, y)
    b = invsym(Q) * xy
    BC = st_matrix("D_Bcore")
    SC = st_matrix("D_SEcore")
    idx = J(1, 5, .)
    for (t=1; t<=5; t++) {
        jj = selectindex(nombres :== nucleo[t])
        idx[t] = jj[1] + 1
    }
    err = 0
    for (t=1; t<=5; t++) {
        err = max((err, abs(b[idx[t], 1] / sd[idx[t]-1] - BC[1, t])))
    }
    st_numscalar("D_error_base", err)
    info = panelsetup(g, 1)
    O = J(rows(info), 19, .)
    for (j=1; j<=rows(info); j++) {
        lo = info[j, 1]
        hi = info[j, 2]
        Xg = X[lo..hi, .]
        yg = y[lo..hi, .]
        A = Q - quadcross(Xg, Xg)
        O[j, 1] = g[lo, 1]
        O[j, 2] = hi - lo + 1
        O[j, 3] = (rank(A) == k)
        if (O[j, 3]) {
            bm = invsym(A) * (xy - quadcross(Xg, yg))
            for (t=1; t<=5; t++) {
                beta = bm[idx[t], 1] / sd[idx[t]-1]
                delta = beta - BC[1, t]
                O[j, 3+t] = beta
                O[j, 8+t] = delta
                O[j, 13+t] = delta / SC[1, t]
            }
            O[j, 19] = max(abs(O[j, 14..18]))
        }
    }
    st_matrix("D_grupos", O)
}
end

* 3. VIF, RANGO E INVARIANCIA ANTE PARAMETRIZACION.
* VIF no es un test con p-valor. No se elimina por umbral mecanico.
* Las referencias alternativas son comercio=6 y ocupacion=9.
* El centrado de experiencia incluye su cuadrado correspondiente.
foreach modelo in M1 M2 {
    local formula "`mincer'"
    local xn "`x_mincer'"
    if "`modelo'" == "M2" {
        local formula "`principal'"
        local xn "`x_principal'"
    }
    display _newline "MODELO ORIGINAL: `modelo'"
    regress ln_ing_hora_real2025 `formula', vce(cluster id_conglomerado_marco)
    assert e(N) == `n_original'
    assert e(N_clust) == `grupos_original'
    estimates store D_`modelo'
    estimates save "`resultados'/`modelo'_Principal.ster", replace
    dm08_coef `HC' `modelo'_Principal
    predict double d_fit_`modelo', xb
    predict double d_res_`modelo', residuals
    estat vif
    if "`modelo'" == "M2" {
        matrix D_Bcore = (_b[1.tic_uso_pc], _b[actividades_centradas], _b[1.informal], _b[1.tic_uso_pc#1.informal], _b[1.informal#c.actividades_centradas])
        matrix D_SEcore = (_se[1.tic_uso_pc], _se[actividades_centradas], _se[1.informal], _se[1.tic_uso_pc#1.informal], _se[1.informal#c.actividades_centradas])
    }
    foreach esquema in Original Bases_alternativas Bases_y_exp_centrada {
        local xr "`continuas' `sec_original' `ocu_original' `tiempo_numerico'"
        if "`esquema'" == "Bases_alternativas" local xr "`continuas' `sec_alternativa' `ocu_alternativa' `tiempo_numerico'"
        if "`esquema'" == "Bases_y_exp_centrada" local xr "`continuas_c' `sec_alternativa' `ocu_alternativa' `tiempo_numerico'"
        if "`modelo'" == "M2" local xr "`xr' `tic_numericas'"
        local k : word count `xr'
        local k = `k' + 1
        quietly regress ln_ing_hora_real2025 `xr', vce(cluster id_conglomerado_marco)
        mata: st_numscalar("D_rango", dm08_rango("`xr'"))
        assert scalar(D_rango) == `k'
        tempvar fitnuevo dif
        quietly predict double `fitnuevo', xb
        quietly generate double `dif' = abs(`fitnuevo' - d_fit_`modelo')
        quietly summarize `dif', meanonly
        local error_fit = r(max)
        assert `error_fit' < 1e-7
        local error_tic = .
        local error_se = .
        if "`modelo'" == "M2" {
            matrix D_Bnuevo = (_b[tic_uso_pc], _b[actividades_centradas], _b[informal], _b[d_UI], _b[d_AI])
            matrix D_SEnuevo = (_se[tic_uso_pc], _se[actividades_centradas], _se[informal], _se[d_UI], _se[d_AI])
            mata: st_numscalar("D_error_TIC", max(abs(st_matrix("D_Bnuevo") :- st_matrix("D_Bcore"))))
            mata: st_numscalar("D_error_SE", max(abs(st_matrix("D_SEnuevo") :- st_matrix("D_SEcore"))))
            local error_tic = scalar(D_error_TIC)
            local error_se = scalar(D_error_SE)
            assert `error_tic' < 1e-7
            assert `error_se' < 1e-7
        }
        post `HP' ("`modelo'") ("`esquema'") (e(N)) (`k') (scalar(D_rango)) (`error_fit') (`error_tic') (`error_se')
        display "VIF AUXILIARES: `modelo' - `esquema'"
        dm08_vif `HV' `modelo' `esquema' "`xr'"
        drop `fitnuevo' `dif'
    }
}
postclose `HV'
postclose `HP'

preserve
use "`resultados'/vif_diagnostico.dta", clear
export delimited using "`resultados'/vif_diagnostico.csv", replace
gsort modelo parametrizacion -vif
by modelo parametrizacion: generate byte d_top = _n <= 6
list modelo parametrizacion variable vif tolerancia if d_top == 1, sepby(modelo parametrizacion) noobs
restore
preserve
use "`resultados'/parametrizacion_diagnostico.dta", clear
list, sepby(modelo) noobs
export delimited using "`resultados'/parametrizacion_diagnostico.csv", replace
restore

* 4. FORMA FUNCIONAL: RESET CON WALD AGRUPADO.
* Se agregan potencias 2, 3 y 4 del ajuste estandarizado.
* Estandarizar no cambia el espacio del contraste, pero mejora
* el calculo. Rechazar no identifica una variable omitida concreta.
foreach modelo in M1 M2 {
    local formula "`mincer'"
    if "`modelo'" == "M2" local formula "`principal'"
    quietly summarize d_fit_`modelo'
    generate double d_zfit_`modelo' = (d_fit_`modelo' - r(mean)) / r(sd)
    forvalues p = 2/4 {
        generate double d_rf`p'_`modelo' = d_zfit_`modelo'^`p'
    }
    regress ln_ing_hora_real2025 `formula' c.d_rf2_`modelo' c.d_rf3_`modelo' c.d_rf4_`modelo', vce(cluster id_conglomerado_marco)
    test d_rf2_`modelo' d_rf3_`modelo' d_rf4_`modelo'
    post `HT' ("`modelo'_RESET") ("Potencias del ajuste: Wald agrupado") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
    dm08_coef `HC' `modelo'_RESET
    estimates save "`resultados'/`modelo'_RESET.ster", replace

    * Sensibilidad especifica: permitir curvatura en educacion.
    regress ln_ing_hora_real2025 `formula' c.educ_years#c.educ_years, vce(cluster id_conglomerado_marco)
    test c.educ_years#c.educ_years
    post `HT' ("`modelo'_Educacion2") ("Educacion al cuadrado") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
    dm08_coef `HC' `modelo'_Educacion2
    estimates save "`resultados'/`modelo'_Educacion2.ster", replace

    * 5. DISPERSION: REGRESION AUXILIAR DE RESIDUOS AL CUADRADO.
    * No se etiqueta como Breusch-Pagan/White clasico.
    * H0: coeficientes de este conjunto de predictores de dispersion=0.
    * Es un diagnostico limitado a esa forma, con Wald agrupado.
    generate double d_e2_`modelo' = d_res_`modelo'^2
    regress d_e2_`modelo' c.d_zfit_`modelo'##c.d_zfit_`modelo' ib0.informal ib0.tic_uso_pc ib2023.anio, vce(cluster id_conglomerado_marco)
    test d_zfit_`modelo' c.d_zfit_`modelo'#c.d_zfit_`modelo' 1.informal 1.tic_uso_pc 2024.anio 2025.anio
    post `HT' ("`modelo'_Dispersion") ("Dispersion: predictores conjuntos") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))

    * Graficos descriptivos por 40 grupos de valores ajustados.
    xtile d_bin_`modelo' = d_fit_`modelo', nq(40)
    preserve
    collapse (count) N=d_res_`modelo' (mean) ajuste=d_fit_`modelo' residuo=d_res_`modelo' residuo2=d_e2_`modelo', by(d_bin_`modelo')
    sort ajuste
    save "`resultados'/residuos_agrupados_`modelo'.dta", replace
    twoway connected residuo ajuste, yline(0, lcolor(gs8)) mcolor(navy) lcolor(navy) title("`modelo': patron de residuos") xtitle("Log ingreso horario predicho") ytitle("Media del residuo por grupo") note("40 grupos de valores ajustados. Grafico descriptivo.") name(d_resgraf, replace)
    graph export "`resultados'/residuos_ajuste_`modelo'.png", width(2000) replace
    twoway connected residuo2 ajuste, mcolor(maroon) lcolor(maroon) title("`modelo': dispersion de residuos") xtitle("Log ingreso horario predicho") ytitle("Media del residuo al cuadrado") note("40 grupos de valores ajustados. Grafico descriptivo.") name(d_dispgraf, replace)
    graph export "`resultados'/dispersion_ajuste_`modelo'.png", width(2000) replace
    restore
}

* Intensidad no lineal entre usuarios: el termino es cero para U=0.
generate double d_A2 = actividades_centradas^2
generate double d_A2I = d_A2 * informal
regress ln_ing_hora_real2025 `principal' c.d_A2 c.d_A2I, vce(cluster id_conglomerado_marco)
test d_A2 d_A2I
post `HT' ("M2_Intensidad2") ("Curvatura de intensidad conjuntamente") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
dm08_coef `HC' M2_Intensidad2
estimates save "`resultados'/M2_Intensidad2.ster", replace

* Sensibilidad de agrupacion de anios: cinco terminos pueden variar
* por anio (informalidad y los cuatro terminos del bloque TIC).
* Se contrasta TIC permitiendo variar tambien la brecha de informalidad.
local year_tic ""
local year_informal ""
foreach y in 2024 2025 {
    generate byte d_U`y' = tic_uso_pc * (anio == `y')
    generate double d_A`y' = actividades_centradas * (anio == `y')
    generate byte d_UI`y' = d_UI * (anio == `y')
    generate double d_AI`y' = d_AI * (anio == `y')
    generate byte d_I`y' = informal * (anio == `y')
    local year_tic "`year_tic' d_U`y' d_A`y' d_UI`y' d_AI`y'"
    local year_informal "`year_informal' d_I`y'"
}
regress ln_ing_hora_real2025 `principal' `year_tic' `year_informal', vce(cluster id_conglomerado_marco)
test `year_tic'
post `HT' ("M2_TICporAnio") ("Igualdad temporal de cuatro terminos TIC") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
test `year_tic' `year_informal'
post `HT' ("M2_TICporAnio") ("Igualdad temporal de TIC e informalidad") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
dm08_coef `HC' M2_TICporAnio
estimates save "`resultados'/M2_TICporAnio.ster", replace
postclose `HT'
postclose `HC'

* 6. INFLUENCIA INDIVIDUAL DEL MODELO PRINCIPAL.
* Reestimacion auxiliar con VCE convencional para habilitar Cook,
* leverage y DFBETA. Coeficientes/ajustes coinciden con el principal.
* No se emplean sus SE para la inferencia de la tesis.
regress ln_ing_hora_real2025 `x_principal'
local k_principal = e(rank)
assert `k_principal' == 43
predict double d_hat, hat
predict double d_cook, cooksd
predict double d_student, rstudent
predict double d_dfbU, dfbeta(tic_uso_pc)
predict double d_dfbA, dfbeta(actividades_centradas)
predict double d_dfbI, dfbeta(informal)
predict double d_dfbUI, dfbeta(d_UI)
predict double d_dfbAI, dfbeta(d_AI)
tempvar fit_aux
predict double `fit_aux', xb
generate double d_dif_ajuste = abs(`fit_aux' - d_fit_M2)
assert d_dif_ajuste < 1e-7
drop `fit_aux'

* Umbrales solo de cribado: no certifican errores de registro.
local umbral_hat = 2 * `k_principal' / `n_original'
local umbral_cook = 4 / `n_original'
local umbral_dfb = 2 / sqrt(`n_original')
generate byte d_alerta_hat = d_hat > `umbral_hat' & !missing(d_hat)
generate byte d_alerta_cook = d_cook > `umbral_cook' & !missing(d_cook)
generate byte d_alerta_residuo = abs(d_student) > 3 & !missing(d_student)
generate byte d_alerta_dfb = 0
foreach v in d_dfbU d_dfbA d_dfbI d_dfbUI d_dfbAI {
    replace d_alerta_dfb = 1 if abs(`v') > `umbral_dfb' & !missing(`v')
}
generate byte d_alerta = d_alerta_hat | d_alerta_cook | d_alerta_residuo | d_alerta_dfb
display _newline "UMBRALES DESCRIPTIVOS: HAT, COOK, DFBETA"
display `umbral_hat' "  " `umbral_cook' "  " `umbral_dfb'
foreach v in d_alerta_hat d_alerta_cook d_alerta_residuo d_alerta_dfb d_alerta {
    tabulate anio `v'
}
preserve
keep if d_alerta == 1
keep id_observacion anio conglome vivienda hogar codperso id_conglomerado_marco informal tic_uso_pc actividades_centradas ing_hora_real2025 horas_prin_sem d_hat d_cook d_student d_dfbU d_dfbA d_dfbI d_dfbUI d_dfbAI d_alerta_hat d_alerta_cook d_alerta_residuo d_alerta_dfb
gsort -d_cook
save "`resultados'/observaciones_alertadas.dta", replace
export delimited using "`resultados'/observaciones_alertadas.csv", replace
list anio conglome vivienda hogar codperso d_hat d_cook d_student in 1/20, noobs
restore

* 7. INFLUENCIA POR CONGLOMERADO: EXCLUIR UNO CADA VEZ.
* Se informan cambios en coeficientes en log puntos y unidades del
* SE agrupado del modelo completo. Esa escala no es un test formal.
* No se modifica permanentemente la muestra ni se recalculan centros.
preserve
sort id_conglomerado_marco
mata: dm08_grupos("`x_principal'", "ln_ing_hora_real2025", "id_conglomerado_marco")
assert scalar(D_error_base) < 1e-7
matrix colnames D_grupos = id_conglomerado_marco N_excl rango_valido b_u b_a theta du da db_u db_a dtheta ddu dda dse_u dse_a dse_theta dse_du dse_da max_cambio_se
clear
svmat double D_grupos, names(col)
assert _N == `grupos_original'
generate double pct_formal = 100 * (exp(b_u) - 1) if rango_valido == 1
generate double pct_informal = 100 * (exp(b_u + du) - 1) if rango_valido == 1
gsort -rango_valido -max_cambio_se
save "`resultados'/influencia_conglomerados.dta", replace
export delimited using "`resultados'/influencia_conglomerados.csv", replace
tabulate rango_valido, missing
summarize b_u b_a theta du da pct_formal pct_informal max_cambio_se
list id_conglomerado_marco N_excl b_u du pct_formal pct_informal max_cambio_se in 1/15, noobs
quietly count if rango_valido != 1
local grupos_sin_rango = r(N)
restore

* 8. REPORTE Y COPIA DE AUDITORIA.
preserve
use "`resultados'/pruebas_diagnostico.dta", clear
list, sepby(modelo) noobs
export delimited using "`resultados'/pruebas_diagnostico.csv", replace
restore
preserve
use "`resultados'/coeficientes_diagnostico_MCO.dta", clear
export delimited using "`resultados'/coeficientes_diagnostico_MCO.csv", replace
restore
assert _N == `n_original'
isid id_observacion
sort anio conglome vivienda hogar codperso
save "`salida'/base_mco_diagnostico_etapa08B.dta", replace
estimates restore D_M2
display _newline "ETAPA 08B TERMINADA"
display "La muestra principal conserva 18065 observaciones y 772 conglomerados."
display "Grupos cuya exclusion pierde rango: `grupos_sin_rango'"
display "VIF, RESET y alertas requieren interpretacion; no son reglas de limpieza."
display "Las bases anteriores y la base amplia para Heckman se conservan."
log close diagnostico08b













version 17.0
clear all
set more off
set level 95

* ETAPA 08C: sensibilidad a la forma funcional de educacion y graficos integrados.
* Motivacion: RESET y educacion al cuadrado en 08B.
* Se reportan todas las formas; no se busca una que "pase" RESET.
* Lineal por tramos: nudos predefinidos en 6, 11 y 16 anios,
* correspondientes a hitos de la construccion educativa de la base.
* No se altera educ_years, experiencia, TIC ni la muestra principal.

local salida "$ENAHO_SALIDA"
local resultados "`salida'/Forma_funcional_etapa08C"
capture mkdir "`resultados'"
confirm file "`salida'/base_mco_precios2025_etapa07.dta"
capture log close forma08c
log using "`resultados'/08C_Forma_funcional.log", text replace name(forma08c)
use "`salida'/base_mco_precios2025_etapa07.dta", clear
assert _N == 18065
assert muestra_salario_controles_final == 1
isid id_observacion
assert !missing(ln_ing_hora_real2025, educ_years, experiencia_potencial, experiencia2, mujer, casado, jefe_hogar, sector10, ocupacion10_final, anio, mes_num, tic_uso_pc, informal, actividades_centradas, id_conglomerado_marco)
local n_base = _N

generate double e_h6 = max(educ_years - 6, 0)
generate double e_h11 = max(educ_years - 11, 0)
generate double e_h16 = max(educ_years - 16, 0)
label variable e_h6 "Max(educacion - 6, 0)"
label variable e_h11 "Max(educacion - 11, 0)"
label variable e_h16 "Max(educacion - 16, 0)"

* Cobertura: identificar los tramos con pocos registros.
tabulate educ_years
tabulate educ_years informal, row
preserve
contract anio educ_years informal, freq(N)
sort anio educ_years informal
save "`resultados'/cobertura_educacion.dta", replace
export delimited using "`resultados'/cobertura_educacion.csv", replace
restore

local personales "c.educ_years c.experiencia_potencial c.experiencia2 ib0.mujer ib0.casado ib0.jefe_hogar"
local productivas "ib1.sector10 ib0.ocupacion10_final"
local temporales "ib2023.anio ib1.mes_num"
local tic "ib0.tic_uso_pc##ib0.informal c.actividades_centradas##ib0.informal"
local mincer "`personales' `productivas' `temporales'"

tempname HT HX HE HC
postfile `HT' str24 modelo str40 prueba double F gl1 gl2 p N r2 grupos using "`resultados'/pruebas_forma_educacion.dta", replace
postfile `HX' str24 modelo str36 contraste double b se p li ls pct pct_li pct_ls N using "`resultados'/contrastes_TIC_educacion.dta", replace
postfile `HE' str24 modelo byte desde hasta double b se p li ls pct pct_li pct_ls using "`resultados'/cambios_educacion.dta", replace
postfile `HC' str24 modelo str64 termino double b se p li ls N r2 grupos using "`resultados'/coeficientes_forma_educacion.dta", replace

capture program drop ec08_coef
program define ec08_coef
    args handle modelo
    tempname B V bb ss pp li ls crit
    matrix `B' = e(b)
    matrix `V' = e(V)
    local terminos : colnames `B'
    local k = colsof(`B')
    scalar `crit' = invttail(e(df_r), 0.025)
    forvalues j = 1/`k' {
        local termino : word `j' of `terminos'
        scalar `bb' = `B'[1, `j']
        scalar `ss' = sqrt(`V'[`j', `j'])
        if `ss' > 0 & !missing(`ss') {
            scalar `pp' = 2 * ttail(e(df_r), abs(`bb' / `ss'))
            scalar `li' = `bb' - `crit' * `ss'
            scalar `ls' = `bb' + `crit' * `ss'
            post `handle' ("`modelo'") ("`termino'") (`bb') (`ss') (`pp') (`li') (`ls') (e(N)) (e(r2)) (e(N_clust))
        }
    }
end

foreach familia in M1 M2 {
    foreach forma in Lineal Cuadratica Tramos {
        local modelo "`familia'_`forma'"
        local formula "`mincer'"
        if "`familia'" == "M2" local formula "`formula' `tic'"
        if "`forma'" == "Cuadratica" local formula "`formula' c.educ_years#c.educ_years"
        if "`forma'" == "Tramos" local formula "`formula' c.e_h6 c.e_h11 c.e_h16"
        display _newline "MODELO: `modelo'"
        regress ln_ing_hora_real2025 `formula', vce(cluster id_conglomerado_marco)
        assert e(N) == 18065
        assert e(N_clust) == 772
        local r2_base = e(r2)
        estimates store `modelo'
        estimates save "`resultados'/`modelo'.ster", replace
        ec08_coef `HC' `modelo'

        if "`forma'" == "Cuadratica" {
            test c.educ_years#c.educ_years
            post `HT' ("`modelo'") ("Educacion al cuadrado") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(r2)) (e(N_clust))
        }
        if "`forma'" == "Tramos" {
            test e_h6 e_h11 e_h16
            post `HT' ("`modelo'") ("Cambios de pendiente conjuntamente") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(r2)) (e(N_clust))
        }

        if "`familia'" == "M2" {
            foreach comparacion in Uso_formal Uso_informal Intensidad_formal Intensidad_informal Brecha_usuarios Informal_usuario_vs_formal_no {
                local expresion "1.tic_uso_pc"
                if "`comparacion'" == "Uso_informal" local expresion "1.tic_uso_pc + 1.tic_uso_pc#1.informal"
                if "`comparacion'" == "Intensidad_formal" local expresion "actividades_centradas"
                if "`comparacion'" == "Intensidad_informal" local expresion "actividades_centradas + 1.informal#c.actividades_centradas"
                if "`comparacion'" == "Brecha_usuarios" local expresion "1.informal + 1.tic_uso_pc#1.informal"
                if "`comparacion'" == "Informal_usuario_vs_formal_no" local expresion "1.informal + 1.tic_uso_pc + 1.tic_uso_pc#1.informal"
                lincom `expresion'
                post `HX' ("`modelo'") ("`comparacion'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (100*(exp(r(estimate))-1)) (100*(exp(r(lb))-1)) (100*(exp(r(ub))-1)) (e(N))
            }
            test 1.tic_uso_pc actividades_centradas
            post `HT' ("`modelo'") ("Bloque TIC entre formales") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(r2)) (e(N_clust))
            test 1.tic_uso_pc#1.informal 1.informal#c.actividades_centradas
            post `HT' ("`modelo'") ("Interacciones TIC e informalidad") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(r2)) (e(N_clust))
        }

        * Cambio discreto de un anio de educacion, manteniendo los
        * demas regresores constantes: f(E+1)-f(E), no solo f'(E).
        foreach e in 5 10 15 18 {
            local expresion "educ_years"
            local hasta = `e' + 1
            if "`forma'" == "Cuadratica" {
                local multiplicador = 2*`e' + 1
                local expresion "educ_years + `multiplicador'*c.educ_years#c.educ_years"
            }
            if "`forma'" == "Tramos" {
                foreach nudo in 6 11 16 {
                    local delta = max(`hasta'-`nudo', 0) - max(`e'-`nudo', 0)
                    if `delta' != 0 local expresion "`expresion' + `delta'*e_h`nudo'"
                }
            }
            lincom `expresion'
            post `HE' ("`modelo'") (`e') (`hasta') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (100*(exp(r(estimate))-1)) (100*(exp(r(lb))-1)) (100*(exp(r(ub))-1))
        }

        * Grafico de componente educativo y residuos parciales.
        * Es diagnostico: no es ingreso observado ni efecto causal.
        tempvar residuo ajuste componente parcial
        predict double `residuo', residuals
        predict double `ajuste', xb
        generate double `componente' = _b[educ_years]*educ_years
        if "`forma'" == "Cuadratica" replace `componente' = `componente' + _b[c.educ_years#c.educ_years]*educ_years^2
        if "`forma'" == "Tramos" replace `componente' = `componente' + _b[e_h6]*e_h6 + _b[e_h11]*e_h11 + _b[e_h16]*e_h16
        generate double `parcial' = `residuo' + `componente'
        preserve
        collapse (count) N=`parcial' (mean) componente=`componente' residuo_parcial=`parcial', by(educ_years)
        sort educ_years
        save "`resultados'/componente_educacion_`modelo'.dta", replace
        twoway (scatter residuo_parcial educ_years, mcolor(navy) msize(small)) (line componente educ_years, lcolor(maroon)), title("`modelo': componente educativo") xtitle("Anios de educacion") ytitle("Componente educativo y residuo parcial") legend(order(1 "Media de residuos parciales" 2 "Componente estimado")) note("Media por anios observados. Diagnostico de forma funcional.") name(ec_graf, replace)
        graph export "`resultados'/educacion_`modelo'.png", width(2000) replace
        graph save ec_graf "`resultados'/educacion_`modelo'.gph", replace
        restore

        * RESET posterior a cada forma: se reporta, no se usa como
        * criterio automatico para seleccionar la especificacion.
        quietly summarize `ajuste'
        tempvar z r2 r3 r4
        generate double `z' = (`ajuste' - r(mean)) / r(sd)
        generate double `r2' = `z'^2
        generate double `r3' = `z'^3
        generate double `r4' = `z'^4
        regress ln_ing_hora_real2025 `formula' c.`r2' c.`r3' c.`r4', vce(cluster id_conglomerado_marco)
        test `r2' `r3' `r4'
        post `HT' ("`modelo'") ("RESET: potencias del ajuste") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (`r2_base') (e(N_clust))
        drop `residuo' `ajuste' `componente' `parcial' `z' `r2' `r3' `r4'
    }
}
postclose `HT'
postclose `HX'
postclose `HE'
postclose `HC'

foreach archivo in pruebas_forma_educacion contrastes_TIC_educacion cambios_educacion coeficientes_forma_educacion {
    preserve
    use "`resultados'/`archivo'.dta", clear
    export delimited using "`resultados'/`archivo'.csv", replace
    if "`archivo'" != "coeficientes_forma_educacion" list, sepby(modelo) noobs
    restore
}

* FIGURA 5: margen extensivo bajo las tres formas educativas.
* Se dibujan los contrastes y los IC del 95% estimados arriba.
local carpeta "`resultados'"
local archivo "`resultados'/contrastes_TIC_educacion.dta"
confirm file "`archivo'"

preserve
use "`archivo'", clear

* 1. Seleccionar los dos contrastes de uso y las tres formas educativas.
keep if inlist(modelo, "M2_Lineal", "M2_Cuadratica", "M2_Tramos")
keep if inlist(contraste, "Uso_formal", "Uso_informal")

assert _N == 6
isid modelo contraste
assert N == 18065
assert !missing(pct, pct_li, pct_ls)
assert pct_li <= pct & pct <= pct_ls

* Los porcentajes y sus intervalos ya fueron calculados en la etapa 08C.
* Comprobar su correspondencia con los contrastes en log puntos.
* Se admite una pequena tolerancia por la precision de almacenamiento.
assert abs(pct - 100 * (exp(b) - 1)) < 1e-4
assert abs(pct_li - 100 * (exp(li) - 1)) < 1e-4
assert abs(pct_ls - 100 * (exp(ls) - 1)) < 1e-4

generate byte fig5_orden = .
replace fig5_orden = 1 if modelo == "M2_Lineal"
replace fig5_orden = 2 if modelo == "M2_Cuadratica"
replace fig5_orden = 3 if modelo == "M2_Tramos"

generate str12 fig5_etiqueta = strtrim(string(pct, "%6.2f")) + "%"

capture graph set window fontface "Times New Roman"

* 2. Construir los paneles con las mismas escalas.
foreach grupo in formal informal {

    if "`grupo'" == "formal" {
        local titulo "Trabajadores formales"
        local color "32 78 115"
    }
    else {
        local titulo "Trabajadores informales"
        local color "151 59 66"
    }

    twoway ///
        (rcap pct_li pct_ls fig5_orden ///
            if contraste == "Uso_`grupo'", ///
            horizontal lcolor("`color'") lwidth(medium)) ///
        (scatter fig5_orden pct ///
            if contraste == "Uso_`grupo'", ///
            msymbol(O) mcolor("`color'") msize(medium) ///
            mlabel(fig5_etiqueta) mlabposition(6) ///
            mlabcolor(black) mlabsize(small)), ///
        title("`titulo'", size(medium) color(black)) ///
        ylabel(1 "Lineal" 2 "Cuadrática" 3 "Por tramos", ///
            angle(horizontal) labsize(medsmall) nogrid) ///
        yscale(reverse range(0.5 3.5)) ///
        ytitle("") ///
        xlabel(10(5)40, grid glcolor(gs15) labsize(small)) ///
        xscale(range(10 40)) ///
        xtitle("Diferencia porcentual e IC del 95%", size(small)) ///
        legend(off) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        scheme(s2color) ///
        name(fig5_`grupo', replace)
}

* 3. Unir los paneles y guardar la figura en PNG y en formato de Stata.
graph combine fig5_formal fig5_informal, ///
    cols(2) xcommon ycommon imargin(small) ///
    title("Asociación del uso de computadora según la forma educativa", ///
        size(medium) color(black)) ///
    note("Usuario con el número promedio de actividades frente a no usuario del mismo grupo." ///
         "N = 18 065 en cada modelo. Errores estándar agrupados por 772 grupos del marco.", ///
         size(small) color(black)) ///
    graphregion(color(white)) ///
    xsize(12) ysize(6) ///
    name(figura5_educacion, replace)

graph export "`carpeta'/05_Sensibilidad_educacion.png", ///
    name(figura5_educacion) width(3000) replace

graph save figura5_educacion ///
    "`carpeta'/05_Sensibilidad_educacion.gph", replace

restore
graph display figura5_educacion

display "Figura guardada en: `carpeta'"

assert _N == `n_base'
isid id_observacion
estimates restore M2_Lineal
display _newline "ETAPA 08C TERMINADA"
display "Se compararon seis modelos sobre las mismas 18065 observaciones."
display "No se sustituyo automaticamente la especificacion principal."
display "Se guardaron seis graficos de componente educativo y la figura 5, en PNG y GPH."
display "Graficos y resultados en: `resultados'"
log close forma08c


















version 17.0
clear all
set more off
set level 95

* ETAPA 08D: figuras centradas en TIC, informalidad e ingresos.
* Usa la base a precios de 2025 y las tablas verificadas de etapa 07.
* No reestima las regresiones. No sustituye la revision pendiente de 08C.
* Los graficos descriptivos no identifican efectos causales.
* Las actividades solo se representan entre usuarios con respuestas validas.

local salida "$ENAHO_SALIDA"
local auditoria "`salida'/Auditoria_MCO_etapa07"
local resultados "`salida'/Graficos_TIC_etapa08D"
confirm file "`salida'/base_mco_precios2025_etapa07.dta"
confirm file "`auditoria'/coeficientes_sensibilidad.dta"
confirm file "`auditoria'/contrastes_sensibilidad.dta"
capture mkdir "`resultados'"
capture log close graficos08d
log using "`resultados'/08D_Graficos_TIC.log", text replace name(graficos08d)

use "`salida'/base_mco_precios2025_etapa07.dta", clear
assert _N == 18065
isid id_observacion
assert !missing(ln_ing_hora_real2025, tic_uso_pc, informal)
count if tic_uso_pc == 1 & !missing(tic_actividades_usuarios)
assert r(N) == 7933
assert inrange(tic_actividades_usuarios, 0, 9) if tic_uso_pc == 1
assert missing(tic_actividades_usuarios) if tic_uso_pc == 0
local lienzo "scheme(s1color) graphregion(color(white)) plotregion(color(white)) xsize(10) ysize(6)"

* 1. Distribucion descriptiva en los cuatro grupos de investigacion.
generate byte g_tic = 1 + tic_uso_pc + 2*informal
label define g08d 1 "Formal: no usa" 2 "Formal: usa" 3 "Informal: no usa" 4 "Informal: usa", replace
label values g_tic g08d
tabulate g_tic
graph box ln_ing_hora_real2025, over(g_tic, label(labsize(small))) box(1, color(navy%35)) marker(1, msize(vtiny) mcolor(navy%20)) title("Ingreso horario por uso de computadora e informalidad", size(medsmall)) ytitle("Log ingreso horario a precios de 2025", size(small)) ylabel(, labsize(small) angle(horizontal)) note("N = 18065. Cajas: mediana y rango intercuartil. Comparacion sin controles.", size(vsmall)) `lienzo' name(g08d_box, replace)
graph export "`resultados'/01_ingreso_cuatro_grupos.png", width(2400) replace
graph save "`resultados'/01_ingreso_cuatro_grupos.gph", replace

* Resumen numerico de las cajas, conservando la base completa en memoria.
preserve
collapse (count) N=ln_ing_hora_real2025 (mean) media_log=ln_ing_hora_real2025 (p25) p25_log=ln_ing_hora_real2025 (p50) mediana_log=ln_ing_hora_real2025 (p75) p75_log=ln_ing_hora_real2025, by(g_tic)
save "`resultados'/resumen_cuatro_grupos.dta", replace
export delimited using "`resultados'/resumen_cuatro_grupos.csv", replace
restore

* 2. Nube completa entre usuarios. lfit es una recta bivariada sin controles.
* No se asignan actividades a no usuarios para este grafico.
label define inf08d 0 "Empleo formal" 1 "Empleo informal", replace
label values informal inf08d
twoway (scatter ln_ing_hora_real2025 tic_actividades_usuarios if tic_uso_pc == 1, msymbol(O) msize(vtiny) mcolor(navy%18)) (lfit ln_ing_hora_real2025 tic_actividades_usuarios if tic_uso_pc == 1, lcolor(maroon) lwidth(medthick)), by(informal, cols(2) title("Actividades informaticas e ingreso entre usuarios", size(medsmall)) note("7933 usuarios: 5028 formales y 2905 informales. Rectas sin controles.", size(vsmall))) xtitle("Numero de actividades declaradas", size(small)) ytitle("Log ingreso horario a precios de 2025", size(small)) xlabel(0(1)9, labsize(small)) ylabel(, labsize(small) angle(horizontal)) legend(order(1 "Observaciones" 2 "Recta descriptiva") position(6) rows(1) size(small)) `lienzo' name(g08d_nube, replace)
graph export "`resultados'/02_actividades_ingreso_usuarios.png", width(2800) replace
graph save "`resultados'/02_actividades_ingreso_usuarios.gph", replace

* Datos de la nube tridimensional: E, A e ingreso observado entre usuarios.
* La figura 3D del paquete se genera fuera de Stata; aqui queda su fuente.
preserve
keep if tic_uso_pc == 1
keep id_observacion anio educ_years tic_actividades_usuarios informal ln_ing_hora_real2025
assert _N == 7933
export delimited using "`resultados'/datos_nube_3D_usuarios.csv", replace
restore

* 3. Asociaciones condicionales de etapa 07 y sus IC del 95%.
* Formal: coeficientes del modelo; informal: combinaciones lincom.
tempfile formales
preserve
use "`auditoria'/coeficientes_sensibilidad.dta", clear
keep if modelo == "M2_Real" & inlist(termino, "1.tic_uso_pc", "actividades_centradas")
assert _N == 2
assert N == 18065 & grupos == 772
generate byte fila = cond(termino == "1.tic_uso_pc", 1, 3)
keep fila b se p li ls N
save "`formales'", replace
use "`auditoria'/contrastes_sensibilidad.dta", clear
keep if modelo == "M2_Real" & inlist(contraste, "U entre informales, intensidad de referencia", "Actividad adicional entre informales")
assert _N == 2
generate byte fila = cond(contraste == "Actividad adicional entre informales", 4, 2)
keep fila b se p li ls N
append using "`formales'"
isid fila
assert N == 18065
generate double pct = 100*(exp(b)-1)
generate double pct_li = 100*(exp(li)-1)
generate double pct_ls = 100*(exp(ls)-1)
generate str60 comparacion = "Uso: formales"
replace comparacion = "Uso: informales" if fila == 2
replace comparacion = "Actividad adicional: formales" if fila == 3
replace comparacion = "Actividad adicional: informales" if fila == 4
sort fila
save "`resultados'/asociaciones_TIC_IC.dta", replace
export delimited using "`resultados'/asociaciones_TIC_IC.csv", replace
list comparacion pct pct_li pct_ls p, noobs
twoway (rcap pct_li pct_ls fila, horizontal lcolor(navy)) (scatter fila pct, msymbol(O) mcolor(navy) msize(medium)), ylabel(1 "Uso: formales" 2 "Uso: informales" 3 "Actividad: formales" 4 "Actividad: informales", labsize(small) angle(horizontal)) yscale(reverse) ytitle("") xtitle("Diferencia porcentual condicional e IC del 95%", size(small)) xline(0, lcolor(gs8) lpattern(dash)) xlabel(, labsize(small)) title("Dos margenes TIC e ingreso laboral", size(medsmall)) legend(off) note("Uso: usuario a intensidad de referencia frente a no usuario del mismo grupo." "Actividad: una actividad adicional entre usuarios. Errores agrupados: 772 conglomerados." "Modelo de etapa 07 con educacion lineal; revision de forma funcional pendiente.", size(vsmall)) `lienzo' name(g08d_ic, replace)
graph export "`resultados'/03_asociaciones_TIC_IC.png", width(2400) replace
graph save "`resultados'/03_asociaciones_TIC_IC.gph", replace
restore

* 4. Comparaciones que responden directamente a la brecha entre grupos.
preserve
use "`auditoria'/contrastes_sensibilidad.dta", clear
keep if modelo == "M2_Real" & inlist(contraste, "Brecha informal-formal entre usuarios", "Usuario informal vs no usuario formal")
assert _N == 2
assert N == 18065
generate byte fila = cond(contraste == "Brecha informal-formal entre usuarios", 1, 2)
generate double pct = 100*(exp(b)-1)
generate double pct_li = 100*(exp(li)-1)
generate double pct_ls = 100*(exp(ls)-1)
sort fila
save "`resultados'/brechas_TIC_IC.dta", replace
export delimited using "`resultados'/brechas_TIC_IC.csv", replace
twoway (rcap pct_li pct_ls fila, horizontal lcolor(maroon)) (scatter fila pct, msymbol(O) mcolor(maroon) msize(medium)), ylabel(1 "Usuario informal vs usuario formal" 2 "Usuario informal vs no usuario formal", labsize(small) angle(horizontal)) yscale(reverse) ytitle("") xtitle("Diferencia porcentual condicional e IC del 95%", size(small)) xline(0, lcolor(gs8) lpattern(dash)) xlabel(, labsize(small)) title("Comparaciones entre grupos laborales", size(medsmall)) legend(off) note("Usuarios a la intensidad de referencia. Controles constantes; asociaciones no causales." "N = 18065. Errores agrupados: 772 conglomerados. Modelo de etapa 07.", size(vsmall)) `lienzo' name(g08d_brechas, replace)
graph export "`resultados'/04_brechas_TIC_IC.png", width(2400) replace
graph save "`resultados'/04_brechas_TIC_IC.gph", replace
restore

assert _N == 18065
isid id_observacion
display _newline "ETAPA 08D TERMINADA"
display "Cuatro figuras 2D y datos de la nube 3D exportados."
display "Se reutilizaron estimaciones de etapa 07. Heckman no se ha estimado."
log close graficos08d















version 17.0
clear all
set more off
set level 95
set linesize 120
set scheme s1color
capture graph set window fontface "Times New Roman"

* ETAPA 08E. MCO POOLED: COMPARACION TIC POR TIPO DE TRABAJADOR.
* Ejecutar el do-file completo. No necesita paquetes externos.
* Muestra fija: 18 065 observaciones persona-anio; 772 conglomerados.
* Grupo 1: empleados, obreros y trabajadores del hogar (dependientes).
* Grupo 2: empleadores e independientes. No equivale a independientes solos.
*
* JUSTIFICACION DE LA ESTIMACION CONJUNTA:
* Ambos tipos pueden compartir conglomerado, hogar o persona entre anios.
* Una VCE conjunta agrupada permite considerar la covarianza entre sus
* coeficientes. No basta comparar significancia de regresiones separadas.
* Todos los controles, el anio y el mes tienen coeficientes por tipo.
* Esto reproduce los ajustes de las regresiones separadas; sus errores
* conjuntos incorporan la covarianza y el ajuste de grados de libertad.
*
* Ocupacion elemental (9) es la referencia comun de ambos tipos.
* La categoria militar existe en dependientes y no existe en el grupo 2.
* Cambiar esa referencia no cambia los coeficientes TIC ni los ajustes.
*
* U = tic_uso_pc; I = informal; A = actividades_centradas; D = 1(tipo=2).
* Las interacciones UI, AI, DU, DA, DI, DUI y DAI se crean explicitamente.
* U e I son binarias 0/1 y se introducen como regresores numericos.
* La intensidad conserva la media global de usuarios, sin recalcular por tipo.
*
* Resultado: log ingreso horario principal, sin recorte, a precios de 2025.
* Principal lineal sin pesos. Sensibilidad: educacion cuadratica y fac500a.
* Las diferencias individuales son cuatro contrastes predefinidos por modelo.
* Se reporta su p original y Holm dentro de cada familia de cuatro.
* Los IC de las figuras son individuales, no simultaneos.
* Los resultados describen asociaciones condicionales.
*
* Referencias tecnicas:
* https://www.stata.com/manuals/rtest.pdf
* https://www.stata.com/manuals/rlincom.pdf
* https://www.stata.com/manuals/rkdensity.pdf

local salida "$ENAHO_SALIDA"
local resultados "`salida'/Complemento_MCO_etapa08E"
local archivo "`salida'/base_mco_precios2025_etapa07.dta"
capture confirm file "`archivo'"
if _rc != 0 local archivo "`salida'/base_mco_2023_2025.dta"
confirm file "`archivo'"
capture mkdir "`resultados'"
capture log close etapa08e
log using "`resultados'/08E_Contrastes_TIC_por_tipo.log", text replace name(etapa08e)
display "INSUMO: `archivo'"
use "`archivo'", clear
capture drop e8_*

* 1. MUESTRA, PRECIOS Y CENTRO FIJO.
assert _N == 18065
local n_base = _N
isid id_observacion
isid anio conglome vivienda hogar codperso
assert muestra_salario_controles_final == 1
assert inlist(anio, 2023, 2024, 2025)
assert inlist(tipo_trabajador, 1, 2)
assert inlist(tic_uso_pc, 0, 1)
assert inlist(informal, 0, 1)
assert !missing(educ_years, experiencia_potencial, experiencia2, mujer, casado, jefe_hogar, sector10, ocupacion10_final, mes_num, actividades_centradas, id_conglomerado_marco)
assert fac500a > 0 & !missing(fac500a)
generate double e8_deflactor = .
replace e8_deflactor = 111.04911316666666 / 115.36565525000002 if anio == 2023
replace e8_deflactor = 113.65953791666665 / 115.36565525000002 if anio == 2024
replace e8_deflactor = 1 if anio == 2025
capture confirm variable ln_ing_hora_real2025
if _rc != 0 generate double ln_ing_hora_real2025 = y_log_ingreso_hora - ln(e8_deflactor)
assert !missing(ln_ing_hora_real2025)
assert abs(ln_ing_hora_real2025 - (y_log_ingreso_hora - ln(e8_deflactor))) < 1e-8
assert missing(tic_actividades_usuarios) if tic_uso_pc == 0
assert inrange(tic_actividades_usuarios, 0, 9) if tic_uso_pc == 1
quietly summarize tic_actividades_usuarios if tic_uso_pc == 1, meanonly
local centro = r(mean)
assert r(N) == 7933
assert abs(`centro' - 6.254632547586033) < 1e-8
assert abs(actividades_centradas - (tic_actividades_usuarios - `centro')) < 1e-6 if tic_uso_pc == 1
assert actividades_centradas == 0 if tic_uso_pc == 0
assert ocupacion10_final != 0 if tipo_trabajador == 2
egen byte e8_tag_marco = tag(id_conglomerado_marco)
quietly count if e8_tag_marco == 1
assert r(N) == 772
quietly count if tipo_trabajador == 1
assert r(N) == 12220
quietly count if tipo_trabajador == 2
assert r(N) == 5845
tabulate tipo_trabajador informal
tabulate tipo_trabajador tic_uso_pc
tabulate tipo_trabajador ocupacion10_final, missing
display "CENTRO FIJO DE ACTIVIDADES: " %12.9f `centro'
display "Referencias: hombre; no casado; no jefe; sector agro/pesca; ocupacion elemental; 2023; enero."

* 2. PRODUCTOS PARA PARAMETRIZAR LA COMPARACION.
generate byte e8_tipo2 = tipo_trabajador == 2
generate byte e8_ui = tic_uso_pc * informal
generate double e8_ai = actividades_centradas * informal
generate byte e8_tu = e8_tipo2 * tic_uso_pc
generate double e8_ta = e8_tipo2 * actividades_centradas
generate byte e8_ti = e8_tipo2 * informal
generate byte e8_tui = e8_tipo2 * tic_uso_pc * informal
generate double e8_tai = e8_tipo2 * actividades_centradas * informal
generate double e8_educ2 = educ_years^2

local controles "c.educ_years c.experiencia_potencial c.experiencia2 ib0.mujer ib0.casado ib0.jefe_hogar ib1.sector10 ib9.ocupacion10_final ib2023.anio ib1.mes_num"
local tic_base "c.tic_uso_pc c.actividades_centradas c.informal c.e8_ui c.e8_ai"
local tic_tipo "c.e8_tu c.e8_ta c.e8_ti c.e8_tui c.e8_tai"

tempname HC HA HD HT HM
postfile `HC' str16 modelo str64 termino double b se p li ls N grupos using "`resultados'/coeficientes_tipo.dta", replace
postfile `HA' str16 modelo byte tipo informalidad str12 margen double b se p li ls pct pct_li pct_ls N grupos centro using "`resultados'/asociaciones_tipo.dta", replace
postfile `HD' str16 modelo byte orden str12 margen byte informalidad str100 expresion double b se p li ls N grupos using "`resultados'/diferencias_tipo.dta", replace
postfile `HT' str16 modelo str60 prueba double F gl1 gl2 p N grupos using "`resultados'/pruebas_tipo.dta", replace
postfile `HM' str16 modelo byte ponderado double N N_dep N_empl_ind grupos rango r2 df_resid using "`resultados'/resumen_modelos_tipo.dta", replace

* 3. TRES ESPECIFICACIONES CON LA MISMA MUESTRA Y VCE.
foreach modelo in Lineal Cuadratica Ponderado {
    local covariables "`controles'"
    local pesos ""
    local ponderado = 0
    if "`modelo'" == "Cuadratica" local covariables "`controles' c.e8_educ2"
    if "`modelo'" == "Ponderado" {
        local pesos "[pweight=fac500a]"
        local ponderado = 1
    }
    display _newline "MODELO: `modelo'"
    regress ln_ing_hora_real2025 ib1.tipo_trabajador##(`covariables') `tic_base' `tic_tipo' `pesos', vce(cluster id_conglomerado_marco)
    assert e(N) == 18065
    assert e(N_clust) == 772
    assert e(df_r) == 771
    assert e(sample) == 1
    estimates store E8_`modelo'
    estimates save "`resultados'/E8_`modelo'.ster", replace
    post `HM' ("`modelo'") (`ponderado') (e(N)) (12220) (5845) (e(N_clust)) (e(rank)) (e(r2)) (e(df_r))

    * Coeficientes: IC t de Stata con los grados de libertad agrupados.
    tempname B V bb ss pp ll uu crit
    matrix `B' = e(b)
    matrix `V' = e(V)
    local terminos : colnames `B'
    scalar `crit' = invttail(e(df_r), 0.025)
    forvalues j = 1/`=colsof(`B')' {
        local termino : word `j' of `terminos'
        scalar `bb' = `B'[1, `j']
        scalar `ss' = sqrt(`V'[`j', `j'])
        if `ss' > 0 & !missing(`ss') {
            scalar `pp' = 2 * ttail(e(df_r), abs(`bb'/`ss'))
            scalar `ll' = `bb' - `crit' * `ss'
            scalar `uu' = `bb' + `crit' * `ss'
            post `HC' ("`modelo'") ("`termino'") (`bb') (`ss') (`pp') (`ll') (`uu') (e(N)) (e(N_clust))
        }
    }

    * Asociaciones para las ocho combinaciones: tipo x informalidad x margen.
    forvalues tipo = 1/2 {
        forvalues inf = 0/1 {
            foreach margen in Uso Intensidad {
                local expresion "tic_uso_pc"
                if "`margen'" == "Uso" {
                    if `inf' == 1 local expresion "`expresion' + e8_ui"
                    if `tipo' == 2 local expresion "`expresion' + e8_tu"
                    if `tipo' == 2 & `inf' == 1 local expresion "`expresion' + e8_tui"
                }
                if "`margen'" == "Intensidad" {
                    local expresion "actividades_centradas"
                    if `inf' == 1 local expresion "`expresion' + e8_ai"
                    if `tipo' == 2 local expresion "`expresion' + e8_ta"
                    if `tipo' == 2 & `inf' == 1 local expresion "`expresion' + e8_tai"
                }
                display "Tipo=`tipo'; informalidad=`inf'; margen=`margen'"
                lincom `expresion'
                post `HA' ("`modelo'") (`tipo') (`inf') ("`margen'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (100*(exp(r(estimate))-1)) (100*(exp(r(lb))-1)) (100*(exp(r(ub))-1)) (e(N)) (e(N_clust)) (`centro')
            }
        }
    }

    * Diferencias: grupo 2 menos grupo 1, en LOG PUNTOS.
    * Exp(diferencia)-1 es una razon de asociaciones, no una diferencia
    * de sus primas porcentuales. La figura de diferencias usa log puntos.
    local orden = 0
    foreach margen in Uso Intensidad {
        forvalues inf = 0/1 {
            local orden = `orden' + 1
            local expresion "e8_tu"
            if "`margen'" == "Uso" & `inf' == 1 local expresion "e8_tu + e8_tui"
            if "`margen'" == "Intensidad" local expresion "e8_ta"
            if "`margen'" == "Intensidad" & `inf' == 1 local expresion "e8_ta + e8_tai"
            lincom `expresion'
            post `HD' ("`modelo'") (`orden') ("`margen'") (`inf') ("`expresion'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
        }
    }

    * Las cuatro diferencias son cero si y solo si estos cuatro
    * coeficientes de interaccion son conjuntamente cero.
    test e8_tu e8_tui e8_ta e8_tai
    local df_conjunto = r(df)
    post `HT' ("`modelo'") ("Igualdad del bloque TIC entre tipos") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
    assert `df_conjunto' == 4
    test e8_tu e8_tui
    post `HT' ("`modelo'") ("Igualdad del margen de uso entre tipos") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
    test e8_ta e8_tai
    post `HT' ("`modelo'") ("Igualdad del margen intensivo entre tipos") (r(F)) (r(df)) (r(df_r)) (r(p)) (e(N)) (e(N_clust))
}
postclose `HC'
postclose `HA'
postclose `HD'
postclose `HT'
postclose `HM'

* 4. VERIFICAR LA EQUIVALENCIA DE LOS AJUSTES CON REGRESIONES SEPARADAS.
* Se comparan predicciones, no se exige igualdad de sus VCE finitas.
estimates restore E8_Lineal
predict double e8_ajuste_conjunto, xb
generate double e8_ajuste_separado = .
forvalues tipo = 1/2 {
    quietly regress ln_ing_hora_real2025 `controles' `tic_base' if tipo_trabajador == `tipo', vce(cluster id_conglomerado_marco)
    predict double e8_ajuste_temporal if tipo_trabajador == `tipo', xb
    replace e8_ajuste_separado = e8_ajuste_temporal if tipo_trabajador == `tipo'
    drop e8_ajuste_temporal
}
assert abs(e8_ajuste_conjunto - e8_ajuste_separado) < 1e-6
display "VERIFICACION: ajustes conjuntos y separados coinciden."
estimates restore E8_Lineal

* 5. AJUSTE HOLM DE CUATRO CONTRASTES POR ESPECIFICACION.
preserve
use "`resultados'/diferencias_tipo.dta", clear
assert !missing(p, b, se, li, ls)
bysort modelo: assert _N == 4
bysort modelo (p orden): generate double p_holm = min(1, (_N - _n + 1)*p)
by modelo: replace p_holm = max(p_holm, p_holm[_n-1]) if _n > 1
assert p_holm >= p - 1e-12
assert inrange(p_holm, 0, 1)
label variable p_holm "Holm: cuatro comparaciones individuales por especificacion"
sort modelo orden
save "`resultados'/diferencias_tipo.dta", replace
restore

* 6. EXPORTAR TABLAS NUMERICAS PARA EL WORD.
foreach tabla in coeficientes_tipo asociaciones_tipo diferencias_tipo pruebas_tipo resumen_modelos_tipo {
    preserve
    use "`resultados'/`tabla'.dta", clear
    export delimited using "`resultados'/`tabla'.csv", replace
    if "`tabla'" == "asociaciones_tipo" {
        format b se pct pct_li pct_ls %10.5f
        format p %12.5g
        list modelo tipo informalidad margen b se p pct pct_li pct_ls, sepby(modelo) noobs
    }
    if "`tabla'" == "diferencias_tipo" {
        format b se li ls %10.5f
        format p p_holm %12.5g
        list modelo margen informalidad b se li ls p p_holm, sepby(modelo) noobs
    }
    if "`tabla'" == "pruebas_tipo" {
        format F %10.5f
        format p %12.5g
        list, sepby(modelo) noobs
    }
    if "`tabla'" == "resumen_modelos_tipo" list, noobs
    restore
}

* 7. ASOCIACIONES: DOS PANELES CON IC DEL 95%, MODELO LINEAL.
preserve
use "`resultados'/asociaciones_tipo.dta", clear
keep if modelo == "Lineal"
assert _N == 8
generate double e8_x = tipo + cond(informalidad == 0, -0.09, 0.09)
local lienzo "graphregion(color(white)) plotregion(color(white))"
foreach margen in Uso Intensidad {
    local titulo "Uso de computadora"
    if "`margen'" == "Intensidad" local titulo "Actividad adicional entre usuarios"
    twoway (rcap pct_li pct_ls e8_x if margen == "`margen'" & informalidad == 0, lcolor(navy)) (scatter pct e8_x if margen == "`margen'" & informalidad == 0, mcolor(navy) msymbol(O)) (rcap pct_li pct_ls e8_x if margen == "`margen'" & informalidad == 1, lcolor(maroon)) (scatter pct e8_x if margen == "`margen'" & informalidad == 1, mcolor(maroon) msymbol(D)), title("`titulo'", size(medsmall)) xtitle("") xlabel(1 "Dependientes" 2 "Empl./indep.", labsize(small)) xscale(range(0.65 2.35)) ytitle("Diferencia porcentual condicional", size(small)) yline(0, lcolor(gs10)) legend(order(2 "Formales" 4 "Informales") rows(1) size(small)) `lienzo' name(e8_`margen', replace)
}
graph combine e8_Uso e8_Intensidad, cols(2) title("Asociaciones TIC por tipo de trabajador", size(medsmall)) note("IC individuales del 95%. Muestra: 18 065; 772 conglomerados del marco." "Uso: usuario frente a no usuario, a la intensidad de referencia." "Intensidad: una actividad adicional entre usuarios. Centro fijo: 6.254633 actividades.", size(vsmall)) graphregion(color(white)) xsize(12) ysize(6) name(e8_asociaciones, replace)
graph export "`resultados'/01_Asociaciones_TIC_por_tipo.png", width(3200) replace
graph save "`resultados'/01_Asociaciones_TIC_por_tipo.gph", replace
restore

* 8. DIFERENCIAS ENTRE TIPOS: LOG PUNTOS, IC INDIVIDUALES.
preserve
use "`resultados'/diferencias_tipo.dta", clear
keep if modelo == "Lineal"
assert _N == 4
twoway (rcap li ls orden, horizontal lcolor(navy)) (scatter orden b, mcolor(navy) msymbol(O)), title("Diferencias TIC entre tipos de trabajador", size(medsmall)) xtitle("Coeficiente de empleadores/independientes menos dependientes", size(small)) ytitle("") ylabel(1 "Uso: formales" 2 "Uso: informales" 3 "Actividad: formales" 4 "Actividad: informales", angle(0) labsize(small)) yscale(reverse) xline(0, lcolor(maroon)) legend(off) note("Diferencias en log puntos. IC individuales del 95%; VCE agrupada por marco." "Los p originales y ajustados por Holm se reportan en diferencias_tipo.dta.", size(vsmall)) graphregion(color(white)) plotregion(color(white)) xsize(10) ysize(6) name(e8_diferencias, replace)
graph export "`resultados'/02_Diferencias_TIC_por_tipo.png", width(3200) replace
graph save "`resultados'/02_Diferencias_TIC_por_tipo.gph", replace
restore

* 9. DISTRIBUCIONES DESCRIPTIVAS. Todos los registros de los cuatro grupos.
* El kernel gaussiano, el ancho y la rejilla son comunes a las cuatro curvas.
* El ancho por defecto se calcula en TODA la muestra y despues se fija.
* Los 400 puntos son evaluaciones de la densidad, no personas seleccionadas.
* Las densidades son no ponderadas y sin controles; cada curva integra a uno.
quietly kdensity ln_ing_hora_real2025, kernel(gaussian) n(400) generate(e8_grid e8_global) nograph
local ancho = r(bwidth)
assert `ancho' > 0 & !missing(`ancho')
display "ANCHO COMUN PARA DENSIDADES: " %12.8f `ancho'
quietly kdensity ln_ing_hora_real2025 if informal == 0 & tic_uso_pc == 0, kernel(gaussian) bwidth(`ancho') at(e8_grid) generate(e8_f0) nograph
quietly kdensity ln_ing_hora_real2025 if informal == 0 & tic_uso_pc == 1, kernel(gaussian) bwidth(`ancho') at(e8_grid) generate(e8_f1) nograph
quietly kdensity ln_ing_hora_real2025 if informal == 1 & tic_uso_pc == 0, kernel(gaussian) bwidth(`ancho') at(e8_grid) generate(e8_i0) nograph
quietly kdensity ln_ing_hora_real2025 if informal == 1 & tic_uso_pc == 1, kernel(gaussian) bwidth(`ancho') at(e8_grid) generate(e8_i1) nograph
assert !missing(e8_f0, e8_f1, e8_i0, e8_i1) if !missing(e8_grid)
generate double e8_ancho = `ancho'
label variable e8_f0 "Formal no usuario"
label variable e8_f1 "Formal usuario"
label variable e8_i0 "Informal no usuario"
label variable e8_i1 "Informal usuario"
twoway (line e8_f0 e8_grid, sort lcolor(gs7)) (line e8_f1 e8_grid, sort lcolor(navy)), title("Empleo formal", size(medsmall)) xtitle("Log ingreso horario a precios de 2025", size(small)) ytitle("Densidad") legend(order(1 "No usa" 2 "Usa") rows(1) size(small)) graphregion(color(white)) plotregion(color(white)) name(e8_dens_formal, replace)
twoway (line e8_i0 e8_grid, sort lcolor(gs7)) (line e8_i1 e8_grid, sort lcolor(navy)), title("Empleo informal", size(medsmall)) xtitle("Log ingreso horario a precios de 2025", size(small)) ytitle("Densidad") legend(order(1 "No usa" 2 "Usa") rows(1) size(small)) graphregion(color(white)) plotregion(color(white)) name(e8_dens_informal, replace)
graph combine e8_dens_formal e8_dens_informal, cols(2) xcommon ycommon title("Distribucion del ingreso y uso de computadora", size(medsmall)) note("Calculos descriptivos sin ponderadores ni controles. Se utilizan las 18 065 observaciones." "Kernel gaussiano y ancho comun; las curvas resumen la distribucion completa.", size(vsmall)) graphregion(color(white)) xsize(12) ysize(6) name(e8_densidades, replace)
graph export "`resultados'/03_Distribuciones_ingreso_TIC.png", width(3200) replace
graph save "`resultados'/03_Distribuciones_ingreso_TIC.gph", replace
preserve
keep e8_grid e8_f0 e8_f1 e8_i0 e8_i1 e8_ancho
keep if !missing(e8_grid)
assert _N == 400
save "`resultados'/densidades_tic.dta", replace
export delimited using "`resultados'/densidades_tic.csv", replace
restore

* 10. GUARDAR COPIA DE TRABAJO. La base principal anterior se conserva.
assert _N == `n_base'
isid id_observacion
sort anio conglome vivienda hogar codperso
save "`salida'/base_mco_complemento_etapa08E.dta", replace
display _newline "ETAPA 08E TERMINADA: 18 065 observaciones; tres especificaciones."
display "Revisar la prueba conjunta, los cuatro contrastes y su sensibilidad."
display "Se generaron tres figuras y las tablas numericas."
display "Resultados: `resultados'"
log close etapa08e
