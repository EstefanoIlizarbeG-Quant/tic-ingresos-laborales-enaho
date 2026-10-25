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
