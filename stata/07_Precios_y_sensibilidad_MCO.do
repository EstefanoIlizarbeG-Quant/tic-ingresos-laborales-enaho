* Copia preparada para el repositorio. Solo se adaptaron las rutas locales.
* Ejecutar antes 00_configuracion.do desde la raiz del repositorio.
if "$ENAHO_REPO" == "" {
    display as error "Ejecute primero stata/00_configuracion.do desde la raiz del proyecto."
    exit 198
}
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
