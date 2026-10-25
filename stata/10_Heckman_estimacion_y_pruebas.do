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
set scheme s2color

* ETAPA 10. HECKMAN-MINCER: ESTIMACION, PRUEBAS Y SENSIBILIDAD.
* Ejecutar TODO el archivo. La etapa 09 previa no es obligatoria.
* Insumos: la base amplia conservada, nunca la base recortada de MCO.
* Se conservan todas las filas en la copia de salida.
* S_ingreso mantiene la definicion original de ingreso horario valido.
* Los modelos estudian seleccion hacia observar ese ingreso, que combina
* ocupacion, categoria remunerada y disponibilidad de ingreso y horas.
* No identifica separadamente participacion laboral y falta de reporte.
*
* Principal: maxima verosimilitud sin pesos, VCE agrupada por marco.
* Comparaciones predefinidas: exclusiones separadas, candidatas en ingreso,
* educacion cuadratica, situacion laboral conocida, pesos y bloque productivo.
* Las restricciones de exclusion requieren justificacion economica.
* Su significancia en seleccion o su insignificancia en ingreso no las valida.
* La VCE agrupada no elimina los supuestos distribucionales del modelo.
* Heckman tampoco resuelve automaticamente el rechazo de RESET en MCO.
*
* Esta etapa compara la ecuacion Mincer. La extension TIC se evaluara
* despues de revisar convergencia, seleccion y las exclusiones candidatas.
* Dos pasos con inferencia agrupada se reserva para una etapa posterior:
* requeriria bootstrap de conglomerados que reestime las dos etapas.
*
* Documentacion primaria:
* https://www.stata.com/manuals/rheckman.pdf
* https://www.stata.com/manuals/rheckmanpostestimation.pdf
* https://www.stata.com/manuals/rnlcom.pdf

local salida "$ENAHO_SALIDA"
local resultados "`salida'/Heckman_etapa10"
capture mkdir "`resultados'"

* Preferir la preparacion 09 si existe; luego precios 07; luego base amplia.
local archivo "`salida'/base_heckman_preparada_etapa09.dta"
capture confirm file "`archivo'"
if _rc != 0 {
    local archivo "`salida'/base_heckman_precios2025_etapa07.dta"
    capture confirm file "`archivo'"
    if _rc != 0 local archivo "`salida'/base_heckman_2023_2025.dta"
}
confirm file "`archivo'"
capture log close etapa10
log using "`resultados'/10_Heckman_estimacion_y_pruebas.log", text replace name(etapa10)
display "INSUMO: `archivo'"
use "`archivo'", clear
capture drop h10_*

* 1. AUDITORIA Y PRECIOS. No se cambia la seleccion ni se imputa ingreso.
assert _N == 28476
local n_base = _N
isid anio conglome vivienda hogar codperso
isid id_observacion
assert universo_demografico == 1
assert inrange(edad, 14, 65)
assert inlist(anio, 2023, 2024, 2025)
assert inlist(S_ingreso, 0, 1)
assert S_ingreso == !missing(y_log_ingreso_hora)
assert !missing(id_conglomerado_marco)
assert fac500a > 0 & !missing(fac500a)
assert inlist(hay_menor6, 0, 1)
assert menores6_completo == 1
assert hay_menor6 == (n_menor6 > 0)
assert ingreso_no_laboral_hh >= 0 & !missing(ingreso_no_laboral_hh)
assert abs(ingreso_no_laboral_hh - (ingtrahd + ingtexhd + ingrenhd)) < 1e-6
* Ingreso no laboral: transferencias nacionales, del exterior y rentas
* anualizadas del hogar. INGTPRHD/INGTPUHD no se suman nuevamente.

generate double h10_deflactor = .
replace h10_deflactor = 111.04911316666666 / 115.36565525000002 if anio == 2023
replace h10_deflactor = 113.65953791666665 / 115.36565525000002 if anio == 2024
replace h10_deflactor = 1 if anio == 2025

capture confirm variable ln_ing_hora_real2025
if _rc != 0 generate double ln_ing_hora_real2025 = y_log_ingreso_hora - ln(h10_deflactor)
capture confirm variable ingreso_nolaboral_real2025
if _rc != 0 generate double ingreso_nolaboral_real2025 = ingreso_no_laboral_hh / h10_deflactor
capture confirm variable ln_nolaboral_real2025
if _rc != 0 generate double ln_nolaboral_real2025 = ln(1 + ingreso_nolaboral_real2025)

assert S_ingreso == !missing(ln_ing_hora_real2025)
assert abs(ln_ing_hora_real2025 - (y_log_ingreso_hora - ln(h10_deflactor))) < 1e-8 if S_ingreso == 1
assert abs(ingreso_nolaboral_real2025 - ingreso_no_laboral_hh / h10_deflactor) < 1e-6
assert abs(ln_nolaboral_real2025 - ln(1 + ingreso_nolaboral_real2025)) < 1e-8
assert abs(experiencia2 - experiencia_potencial^2) < 1e-6 if !missing(experiencia2, experiencia_potencial)
tabulate anio S_ingreso, missing
tabulate ocu500 S_ingreso, missing

* 2. MUESTRAS: solo banderas; ninguna eliminacion permanente.
generate byte h10_z = !missing(educ_years, experiencia_potencial, experiencia2, mujer, casado, jefe_hogar, anio, mes_num, hay_menor6, ln_nolaboral_real2025, id_conglomerado_marco)
generate byte h10_w = !missing(educ_years, experiencia_potencial, experiencia2, mujer, casado, jefe_hogar, sector10, ocupacion10_final, anio, mes_num)
generate byte h10_mincer = h10_z == 1 & (S_ingreso == 0 | (S_ingreso == 1 & h10_w == 1))
generate byte h10_estado = h10_mincer == 1 & situacion_laboral_definida == 1
generate double h10_educ2 = educ_years^2
assert h10_mincer == muestra_heckman_mincer
assert h10_estado == muestra_heckman_estado_definido
quietly count if h10_mincer == 1
assert r(N) == 28363
quietly count if h10_mincer == 1 & S_ingreso == 1
assert r(N) == 18069
quietly count if h10_mincer == 1 & S_ingreso == 0
assert r(N) == 10294
quietly count if h10_estado == 1
assert r(N) == 28212
quietly count if muestra_salario_controles_final == 1
assert r(N) == 18065
assert h10_mincer == 1 if muestra_salario_controles_final == 1

display _newline "MUESTRA MINCER: 28 363 = 18 069 seleccionados + 10 294 no seleccionados"
tabulate anio S_ingreso if h10_mincer == 1, missing
display "SENSIBILIDAD CON SITUACION LABORAL DEFINIDA"
tabulate anio S_ingreso if h10_estado == 1, missing
display "CUATRO SELECCIONADOS ADICIONALES RESPECTO DEL MCO CON INFORMALIDAD Y TIC"
list anio id_observacion informal tic_modelo_valida motivo_exclusion_mco if h10_mincer == 1 & S_ingreso == 1 & muestra_salario_controles_final == 0, noobs
tabulate hay_menor6 S_ingreso if h10_mincer == 1, column
tabstat ingreso_nolaboral_real2025 ln_nolaboral_real2025 n_menor6 if h10_mincer == 1, by(S_ingreso) statistics(n mean sd p50 min max) columns(statistics)

local personales "c.educ_years c.experiencia_potencial c.experiencia2 ib0.mujer ib0.casado ib0.jefe_hogar"
local temporales "ib2023.anio ib1.mes_num"
local productivas "ib1.sector10 ib0.ocupacion10_final"
local candidatas "ib0.hay_menor6 c.ln_nolaboral_real2025"
local W_base "`personales' `productivas' `temporales'"
local Z_base "`personales' `temporales'"
display "REFERENCIAS: hombre; no casado; no jefe; agropecuario/pesca; militar; 2023; enero."
display "En el principal, hay_menor6 entra en Z y se omite de W; los hogares con menores se conservan."

* 3. REPORTES NATIVOS. No requiere outreg2 ni paquetes externos.
tempname HC HT HM HP
postfile `HC' str24 modelo str12 metodo str32 ecuacion str64 termino double b se p li ls N grupos using "`resultados'/coeficientes_heckman.dta", replace
postfile `HT' str24 modelo str64 prueba str8 tipo double estadistico gl1 gl2 p int rc using "`resultados'/pruebas_heckman.dta", replace
postfile `HM' str24 modelo str12 metodo byte ponderado int rc double N N_selec N_no_selec grupos convergencia rango loglik r2 rho sigma kappa using "`resultados'/resumen_modelos_heckman.dta", replace
postfile `HP' str24 modelo str16 parametro str28 metodo_ic double b se p li ls using "`resultados'/parametros_heckman.dta", replace

capture program drop h10_coef
program define h10_coef
    args handle modelo metodo
    tempname B V bb ss pp ll uu crit df
    matrix `B' = e(b)
    matrix `V' = e(V)
    local terminos : colnames `B'
    local ecuaciones : coleq `B'
    scalar `crit' = invnormal(0.975)
    if "`metodo'" == "MCO" {
        scalar `df' = e(df_r)
        scalar `crit' = invttail(`df', 0.025)
    }
    forvalues j = 1/`=colsof(`B')' {
        local termino : word `j' of `terminos'
        local ecuacion : word `j' of `ecuaciones'
        scalar `bb' = `B'[1, `j']
        scalar `ss' = sqrt(`V'[`j', `j'])
        if `ss' > 0 & !missing(`ss') {
            scalar `pp' = 2 * normal(-abs(`bb' / `ss'))
            if "`metodo'" == "MCO" scalar `pp' = 2 * ttail(`df', abs(`bb' / `ss'))
            scalar `ll' = `bb' - `crit' * `ss'
            scalar `uu' = `bb' + `crit' * `ss'
            post `handle' ("`modelo'") ("`metodo'") ("`ecuacion'") ("`termino'") (`bb') (`ss') (`pp') (`ll') (`uu') (e(N)) (e(N_clust))
        }
    }
end

capture program drop h10_resumen
program define h10_resumen
    args handle modelo metodo ponderado
    quietly count if e(sample) & S_ingreso == 1
    local ns = r(N)
    quietly count if e(sample) & S_ingreso == 0
    local nn = r(N)
    local cv = 1
    local rr = .
    local rh = .
    local sg = .
    local kp = .
    if "`metodo'" == "MCO" local rr = e(r2)
    if inlist("`metodo'", "Probit", "Heckman") local cv = e(converged)
    if "`metodo'" == "Heckman" {
        local rh = e(rho)
        local sg = e(sigma)
        local kp = e(lambda)
    }
    post `handle' ("`modelo'") ("`metodo'") (`ponderado') (0) (e(N)) (`ns') (`nn') (e(N_clust)) (`cv') (e(rank)) (e(ll)) (`rr') (`rh') (`sg') (`kp')
end

* 4. PROBIT DIAGNOSTICO: relevancia y efectos marginales de candidatas.
probit S_ingreso `Z_base' `candidatas' if h10_mincer == 1, vce(cluster id_conglomerado_marco)
assert e(converged) == 1
assert e(N) == 28363
assert e(N_clust) == 772
assert e(sample) == h10_mincer
estimates store P_Ambas
estimates save "`resultados'/P_Ambas.ster", replace
h10_coef `HC' P_Ambas Probit
h10_resumen `HM' P_Ambas Probit 0
test 1.hay_menor6
post `HT' ("P_Ambas") ("Menores en probit") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)
test ln_nolaboral_real2025
post `HT' ("P_Ambas") ("Ingreso no laboral en probit") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)
test 1.hay_menor6 ln_nolaboral_real2025
post `HT' ("P_Ambas") ("Candidatas conjuntamente en probit") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)
margins, dydx(hay_menor6 ln_nolaboral_real2025)
tempname AM
matrix `AM' = r(table)
local ame_terms : colnames `AM'
forvalues j = 1/`=colsof(`AM')' {
    local termino : word `j' of `ame_terms'
    if `AM'[2, `j'] > 0 & !missing(`AM'[2, `j']) {
        post `HC' ("P_Ambas") ("AME") ("Probabilidad_S1") ("`termino'") (`AM'[1, `j']) (`AM'[2, `j']) (`AM'[4, `j']) (`AM'[5, `j']) (`AM'[6, `j']) (e(N)) (e(N_clust))
    }
}
predict double h10_psel_probit if h10_mincer == 1, pr

* Asociaciones directas condicionales de ambas candidatas entre seleccionados.
* Este diagnostico no prueba exogeneidad ni valida restricciones de exclusion.
regress ln_ing_hora_real2025 `W_base' `candidatas' if h10_mincer == 1 & S_ingreso == 1, vce(cluster id_conglomerado_marco)
assert e(N) == 18069
estimates store O_Candidatas
estimates save "`resultados'/O_Candidatas.ster", replace
h10_coef `HC' O_Candidatas MCO
h10_resumen `HM' O_Candidatas MCO 0
test 1.hay_menor6 ln_nolaboral_real2025
post `HT' ("O_Candidatas") ("Candidatas en MCO seleccionado: diagnostico") ("F") (r(F)) (r(df)) (r(df_r)) (r(p)) (0)

* 5. NUEVE ESPECIFICACIONES PREDEFINIDAS Y SU MCO COMPARABLE.
* Ambas: ambas candidatas en Z y ninguna en W.
* Menores / NoLaboral: cada candidata por separado en Z.
* NoLabEnY / MenorEnY: permitir relacion directa de una candidata con Y;
* la otra queda excluida de la ecuacion de resultado.
* Cuadratica: educacion cuadratica en W y Z.
* Estado: retirar del dominio de estimacion la situacion laboral indefinida.
* Ponderado: fac500a positivo; misma muestra; sensibilidad de estimando y VCE.
* SinProductivas: omitir sector y ocupacion manteniendo la muestra fija.

local principal_ok = 0
local fallidos = 0
foreach nombre in Ambas Menores NoLaboral NoLabEnY MenorEnY Cuadratica Estado Ponderado SinProductivas {
    local W "`W_base'"
    local Z "`Z_base' `candidatas'"
    local excluidos "1.hay_menor6 ln_nolaboral_real2025"
    local muestra "h10_mincer"
    local pesos ""
    local ponderado = 0
    if "`nombre'" == "Menores" {
        local Z "`Z_base' ib0.hay_menor6"
        local excluidos "1.hay_menor6"
    }
    if "`nombre'" == "NoLaboral" {
        local Z "`Z_base' c.ln_nolaboral_real2025"
        local excluidos "ln_nolaboral_real2025"
    }
    if "`nombre'" == "NoLabEnY" {
        local W "`W_base' c.ln_nolaboral_real2025"
        local excluidos "1.hay_menor6"
    }
    if "`nombre'" == "MenorEnY" {
        local W "`W_base' ib0.hay_menor6"
        local excluidos "ln_nolaboral_real2025"
    }
    if "`nombre'" == "Cuadratica" {
        local W "`W_base' c.h10_educ2"
        local Z "`Z_base' c.h10_educ2 `candidatas'"
    }
    if "`nombre'" == "Estado" local muestra "h10_estado"
    if "`nombre'" == "Ponderado" {
        local pesos "[pweight=fac500a]"
        local ponderado = 1
    }
    if "`nombre'" == "SinProductivas" local W "`personales' `temporales'"

    quietly count if `muestra' == 1
    local nt = r(N)
    quietly count if `muestra' == 1 & S_ingreso == 1
    local ns = r(N)
    local nn = `nt' - `ns'
    display _newline "ESPECIFICACION: `nombre'"
    display "W: `W'"
    display "Z: `Z'"
    display "CANDIDATAS EXCLUIDAS DE W: `excluidos'"
    display "Muestra total: `nt'; seleccionados: `ns'; no seleccionados: `nn'."

    * MCO usa exactamente los seleccionados que debera conservar Heckman.
    regress ln_ing_hora_real2025 `W' if `muestra' == 1 & S_ingreso == 1 `pesos', vce(cluster id_conglomerado_marco)
    assert e(N) == `ns'
    assert e(N_clust) == 772
    assert e(sample) == (`muestra' == 1 & S_ingreso == 1)
    estimates store O_`nombre'
    estimates save "`resultados'/O_`nombre'.ster", replace
    h10_coef `HC' O_`nombre' MCO
    h10_resumen `HM' O_`nombre' MCO `ponderado'
    if "`nombre'" == "Cuadratica" {
        test h10_educ2
        post `HT' ("O_`nombre'") ("Educacion cuadratica en MCO") ("F") (r(F)) (r(df)) (r(df_r)) (r(p)) (0)
    }

    capture noisily heckman ln_ing_hora_real2025 `W' if `muestra' == 1 `pesos', select(S_ingreso = `Z') vce(cluster id_conglomerado_marco) difficult iterate(200)
    local rc = _rc
    if `rc' != 0 {
        post `HM' ("H_`nombre'") ("Heckman") (`ponderado') (`rc') (`nt') (`ns') (`nn') (772) (0) (.) (.) (.) (.) (.) (.)
        display as error "H_`nombre' devolvio r(`rc'). Se registra y se conserva el MCO comparable."
        local fallidos = `fallidos' + 1
        continue
    }
    if e(converged) != 1 {
        estimates save "`resultados'/H_`nombre'_no_convergente.ster", replace
        post `HM' ("H_`nombre'") ("Heckman") (`ponderado') (430) (e(N)) (e(N_selected)) (e(N_nonselected)) (e(N_clust)) (0) (e(rank)) (e(ll)) (.) (e(rho)) (e(sigma)) (e(lambda))
        display as error "H_`nombre' no convergio: queda registrado como no utilizable."
        local fallidos = `fallidos' + 1
        continue
    }
    assert e(N) == `nt'
    assert e(N_selected) == `ns'
    assert e(N_nonselected) == `nn'
    assert e(N_clust) == 772
    assert e(sample) == (`muestra' == 1)
    generate byte h10_es_`nombre' = e(sample)
    estimates store H_`nombre'
    estimates save "`resultados'/H_`nombre'.ster", replace
    h10_coef `HC' H_`nombre' Heckman
    h10_resumen `HM' H_`nombre' Heckman `ponderado'
    if "`nombre'" == "Ambas" local principal_ok = 1

    * Wald de independencia: atanh(rho)=0 equivale a rho=0.
    * Su VCE es la misma VCE agrupada de la estimacion. No usar lrtest.
    test _b[/athrho] = 0
    local p_rho = r(p)
    post `HT' ("H_`nombre'") ("Independencia de ecuaciones: rho=0") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)

    * Relevancia en seleccion de las candidatas excluidas de W.
    local restricciones ""
    foreach variable of local excluidos {
        local restricciones "`restricciones' ([S_ingreso]`variable' = 0)"
    }
    test `restricciones'
    post `HT' ("H_`nombre'") ("Candidatas excluidas: relevancia en seleccion") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)

    if "`nombre'" == "Cuadratica" {
        test [ln_ing_hora_real2025]h10_educ2
        post `HT' ("H_`nombre'") ("Educacion cuadratica en resultado") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)
        test [S_ingreso]h10_educ2
        post `HT' ("H_`nombre'") ("Educacion cuadratica en seleccion") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)
    }
    if "`nombre'" == "NoLabEnY" {
        test [ln_ing_hora_real2025]ln_nolaboral_real2025
        post `HT' ("H_`nombre'") ("Ingreso no laboral en resultado") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)
    }
    if "`nombre'" == "MenorEnY" {
        test [ln_ing_hora_real2025]1.hay_menor6
        post `HT' ("H_`nombre'") ("Menores en resultado") ("Wald") (r(chi2)) (r(df)) (.) (r(p)) (0)
    }

    * Rho/sigma: IC transformando los IC de sus parametros no acotados.
    * Kappa=rho*sigma: IC delta. Kappa multiplica la razon de Mills;
    * la razon de Mills y su coeficiente son magnitudes diferentes.
    tempname a s cr rho_b rho_se rho_li rho_ls sig_b sig_se sig_li sig_ls KP
    scalar `a' = _b[/athrho]
    scalar `s' = _b[/lnsigma]
    scalar `cr' = invnormal(0.975)
    scalar `rho_b' = tanh(`a')
    scalar `rho_se' = (1 - tanh(`a')^2) * _se[/athrho]
    scalar `rho_li' = tanh(`a' - `cr' * _se[/athrho])
    scalar `rho_ls' = tanh(`a' + `cr' * _se[/athrho])
    scalar `sig_b' = exp(`s')
    scalar `sig_se' = exp(`s') * _se[/lnsigma]
    scalar `sig_li' = exp(`s' - `cr' * _se[/lnsigma])
    scalar `sig_ls' = exp(`s' + `cr' * _se[/lnsigma])
    post `HP' ("H_`nombre'") ("rho") ("Transformacion_atanh") (`rho_b') (`rho_se') (`p_rho') (`rho_li') (`rho_ls')
    post `HP' ("H_`nombre'") ("sigma") ("Transformacion_log") (`sig_b') (`sig_se') (.) (`sig_li') (`sig_ls')
    nlcom (kappa: tanh(_b[/athrho]) * exp(_b[/lnsigma]))
    matrix `KP' = r(table)
    post `HP' ("H_`nombre'") ("kappa") ("Delta") (`KP'[1,1]) (`KP'[2,1]) (`KP'[4,1]) (`KP'[5,1]) (`KP'[6,1])
    if abs(e(rho)) >= 0.98 {
        display as error "REVISAR: |rho| >= 0.98 en H_`nombre'. Convergencia no acredita estabilidad."
    }
}
postclose `HC'
postclose `HT'
postclose `HM'
postclose `HP'

* 6. PREDICCIONES Y DOS GRAFICOS DIAGNOSTICOS DEL PRINCIPAL.
* Se grafica la probabilidad de seleccion y residuos de la MEDIA
* CONDICIONAL en seleccionados. Los puntos no se recortan.
* Esos residuos no tienen que ser normales tras la seleccion.
* No se usa Shapiro/QQ como prueba de la normalidad conjunta latente.
if `principal_ok' == 1 {
    estimates restore H_Ambas
    predict double h10_psel_ml if h10_es_Ambas == 1, psel
    predict double h10_mills_ml if h10_es_Ambas == 1, mills
    predict double h10_ycond if h10_es_Ambas == 1 & S_ingreso == 1, ycond
    generate double h10_residuo_cond = ln_ing_hora_real2025 - h10_ycond if h10_es_Ambas == 1 & S_ingreso == 1
    assert !missing(h10_psel_ml, h10_mills_ml) if h10_es_Ambas == 1
    assert !missing(h10_ycond, h10_residuo_cond) if h10_es_Ambas == 1 & S_ingreso == 1
    tabstat h10_psel_ml h10_mills_ml if h10_es_Ambas == 1, by(S_ingreso) statistics(n mean sd min p1 p5 p50 p95 p99 max) columns(statistics)
    count if h10_es_Ambas == 1 & h10_psel_ml < 0.01
    count if h10_es_Ambas == 1 & h10_psel_ml > 0.99 & !missing(h10_psel_ml)

    twoway (kdensity h10_psel_ml if h10_es_Ambas == 1 & S_ingreso == 0, lcolor(maroon)) (kdensity h10_psel_ml if h10_es_Ambas == 1 & S_ingreso == 1, lcolor(navy)), title("Probabilidad estimada de observar ingreso valido") xtitle("Probabilidad de seleccion") ytitle("Densidad") xlabel(0(0.2)1) legend(order(1 "S = 0" 2 "S = 1") rows(1)) note("Heckman-Mincer principal. Total: 28 363 observaciones." "Las curvas son un diagnostico descriptivo de las predicciones.") graphregion(color(white)) name(h10_prob, replace)
    graph export "`resultados'/01_Probabilidades_seleccion.png", width(3200) replace
    graph save "`resultados'/01_Probabilidades_seleccion.gph", replace

    twoway (scatter h10_residuo_cond h10_ycond if h10_es_Ambas == 1 & S_ingreso == 1, msize(vtiny) mcolor(navy%15)), title("Residuos y media condicional ajustada") xtitle("Log ingreso esperado, condicionado a S = 1") ytitle("Log ingreso observado menos media condicional") yline(0, lcolor(maroon)) legend(off) note("Se muestran las 18 069 observaciones seleccionadas. Todos los puntos." "La figura complementa la revision; no prueba validez de las exclusiones.") graphregion(color(white)) name(h10_resid, replace)
    graph export "`resultados'/02_Residuos_condicionales.png", width(3200) replace
    graph save "`resultados'/02_Residuos_condicionales.gph", replace
}

* 7. EXPORTAR Y MOSTRAR LOS RESULTADOS. CSV conserva los numeros sin redondear.
foreach nombre in coeficientes_heckman pruebas_heckman resumen_modelos_heckman parametros_heckman {
    preserve
    use "`resultados'/`nombre'.dta", clear
    if "`nombre'" == "resumen_modelos_heckman" {
        generate byte alerta_rho = abs(rho) >= 0.98 if metodo == "Heckman" & !missing(rho)
        label variable alerta_rho "Diagnostico: |rho| >= 0.98; revisar estabilidad"
        save "`resultados'/`nombre'.dta", replace
        format rho sigma kappa %10.5f
        list modelo metodo ponderado rc N N_selec N_no_selec grupos convergencia alerta_rho rho sigma kappa, sepby(metodo) noobs
    }
    if "`nombre'" == "pruebas_heckman" {
        format estadistico p %12.6f
        list, sepby(modelo) noobs
    }
    if "`nombre'" == "parametros_heckman" {
        format b se p li ls %12.6f
        list, sepby(modelo) noobs
    }
    export delimited using "`resultados'/`nombre'.csv", replace
    restore
}

* 8. GRAFICO DE COEFICIENTES CON IC: MCO Y HECKMAN, MISMA MUESTRA.
* No es un contraste formal de igualdad entre estimadores.
if `principal_ok' == 1 {
    preserve
    use "`resultados'/coeficientes_heckman.dta", clear
    keep if inlist(modelo, "O_Ambas", "H_Ambas")
    keep if metodo == "MCO" | (metodo == "Heckman" & ecuacion == "ln_ing_hora_real2025")
    generate byte h10_orden = .
    replace h10_orden = 5 if termino == "educ_years"
    replace h10_orden = 4 if termino == "experiencia_potencial"
    replace h10_orden = 3 if termino == "1.mujer"
    replace h10_orden = 2 if termino == "1.casado"
    replace h10_orden = 1 if termino == "1.jefe_hogar"
    keep if !missing(h10_orden)
    assert _N == 10
    generate double h10_posicion = h10_orden + cond(metodo == "MCO", 0.12, -0.12)
    twoway (rcap li ls h10_posicion if metodo == "MCO", horizontal lcolor(navy)) (scatter h10_posicion b if metodo == "MCO", mcolor(navy) msymbol(O)) (rcap li ls h10_posicion if metodo == "Heckman", horizontal lcolor(maroon)) (scatter h10_posicion b if metodo == "Heckman", mcolor(maroon) msymbol(D)), title("Mincer: MCO y Heckman") xtitle("Coeficiente e intervalo del 95% en log ingreso") ytitle("") ylabel(1 "Jefe del hogar" 2 "Casado" 3 "Mujer" 4 "Experiencia potencial" 5 "Educacion", angle(0)) xline(0, lcolor(gs10)) legend(order(2 "MCO" 4 "Heckman") rows(1)) note("Ambos modelos: mismos 18 069 seleccionados y controles." "Inferencia agrupada por 772 conglomerados del marco.") graphregion(color(white)) name(h10_compara, replace)
    graph export "`resultados'/03_Coeficientes_MCO_Heckman.png", width(3200) replace
    graph save "`resultados'/03_Coeficientes_MCO_Heckman.gph", replace
    restore
}

* 9. GUARDAR TODA LA BASE AMPLIA CON BANDERAS Y PREDICCIONES.
assert _N == `n_base'
assert S_ingreso == !missing(ln_ing_hora_real2025)
isid anio conglome vivienda hogar codperso
sort anio conglome vivienda hogar codperso
save "`salida'/base_heckman_estimacion_etapa10.dta", replace
display _newline "ETAPA 10 FINALIZADA. BASE CONSERVADA: 28 476 observaciones."
display "Modelos Heckman con error o sin convergencia: `fallidos'."
display "Principal estimado y convergente: `principal_ok'."
display "Revisar tambien rho, IC, relevancia, estabilidad y supuestos de exclusion."
display "Los resultados no convierten las asociaciones TIC previas en efectos causales."
display "Archivos: `resultados'"
log close etapa10
