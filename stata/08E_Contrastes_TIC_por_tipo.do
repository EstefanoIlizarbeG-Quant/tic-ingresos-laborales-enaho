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
