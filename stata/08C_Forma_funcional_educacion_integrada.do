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
