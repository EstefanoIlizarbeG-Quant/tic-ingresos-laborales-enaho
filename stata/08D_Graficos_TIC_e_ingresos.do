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
