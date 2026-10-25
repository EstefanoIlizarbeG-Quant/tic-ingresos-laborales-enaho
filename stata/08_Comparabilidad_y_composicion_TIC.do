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
