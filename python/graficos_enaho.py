"""Reproduce las figuras de ENAHO con las tablas y bases del proyecto.

Las estimaciones y sus intervalos se leen de las salidas de Stata. Este programa
no vuelve a estimar MCO ni Heckman. Las figuras que requieren microdatos se
generan únicamente cuando se indica una carpeta privada mediante la consola.

Ejemplos, desde la raíz del repositorio:
    python python/graficos_enaho.py
    python python/graficos_enaho.py --datos-privados ../02_privado_no_publicar/originales/bases_dta
"""

from pathlib import Path
from io import BytesIO
import argparse
import json
import os
import re
import xml.etree.ElementTree as ET

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter
import numpy as np
import pandas as pd


AZUL = "#256579"
ROJO = "#a4515b"
GRIS = "#7a858e"
REPO = Path(__file__).resolve().parents[1]


def tabla(carpeta, nombre):
    """Cada tabla canónica tiene una sola ubicación dentro de resultados."""
    candidatos = list(carpeta.rglob(nombre))
    if len(candidatos) != 1:
        raise ValueError(f"Se esperaba una tabla {nombre}; encontradas: {len(candidatos)}")
    return pd.read_csv(candidatos[0], encoding="utf-8-sig")


def intervalos(df):
    valores = df[["b", "li", "ls"]].to_numpy(dtype=float)
    if not np.isfinite(valores).all():
        raise ValueError("Hay coeficientes o límites faltantes en una figura.")
    if not ((valores[:, 1] <= valores[:, 0]) & (valores[:, 0] <= valores[:, 2])).all():
        raise ValueError("Un coeficiente queda fuera de su intervalo exportado.")
    # Transformar ambos extremos evita imponer simetría en la escala porcentual.
    return 100 * np.expm1(valores)


def estilo():
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "axes.titlesize": 12, "axes.labelsize": 10,
                         "figure.facecolor": "white", "axes.spines.top": False,
                         "axes.spines.right": False, "savefig.facecolor": "white",
                         "svg.fonttype": "none"})


def limpiar(ax, eje="x"):
    ax.set_axisbelow(True)
    ax.grid(axis=eje, color="#e7edef", linewidth=.7)
    for spine in ax.spines.values():
        spine.set_color("#a4b0b5")


def guardar(fig, salida, etapa, nombre, nota):
    destino = salida / etapa
    destino.mkdir(parents=True, exist_ok=True)
    fig.subplots_adjust(bottom=.23, top=.86, left=.12, right=.95)
    fig.text(.04, .035, nota, ha="left", va="bottom", fontsize=8, color="#45555d", linespacing=1.5)
    for extension in ("png", "svg"):
        buffer = BytesIO()
        fig.savefig(buffer, format=extension, dpi=220, bbox_inches="tight", pad_inches=.2)
        contenido = buffer.getvalue()
        if extension == "svg":
            ET.fromstring(contenido)
        temporal = destino / f".{nombre}.{extension}.tmp"
        with temporal.open("wb") as handle:
            handle.write(contenido)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporal, destino / f"{nombre}.{extension}")
    plt.close(fig)


def forest(ax, df, etiquetas, porcentual=True, colores=None):
    arr = intervalos(df) if porcentual else df[["b", "li", "ls"]].to_numpy(float)
    y = np.arange(len(df))
    for j, ((b, li, ls), pos) in enumerate(zip(arr, y)):
        color = colores[j] if colores else AZUL
        ax.errorbar(b, pos, xerr=[[b-li], [ls-b]], fmt="o", color=color,
                    capsize=3, linewidth=1.5, markersize=5)
    ax.set_yticks(y, etiquetas)
    ax.set_ylim(len(df)-.6, -.6)
    ax.axvline(0, color=GRIS, linestyle="--", linewidth=.9)
    if porcentual:
        ax.xaxis.set_major_formatter(PercentFormatter(100))
    limpiar(ax)


def figuras_agregadas(datos, salida, controles):
    # 08D: coeficientes a la intensidad de referencia del modelo lineal.
    d = tabla(datos, "asociaciones_TIC_IC.csv")
    if len(d) != 4:
        raise ValueError("Se esperan cuatro asociaciones TIC.")
    fig, ax = plt.subplots(figsize=(11, 5.9))
    forest(ax, d, ["Uso: formales", "Uso: informales", "Actividad adicional: formales", "Actividad adicional: informales"],
           colores=[AZUL, ROJO, AZUL, ROJO])
    ax.set_title("Dos márgenes TIC e ingreso laboral", pad=17)
    ax.set_xlabel("Diferencia porcentual condicional e IC del 95 %")
    guardar(fig, salida, "08D_TIC", "03_asociaciones_TIC_IC",
            "Uso: usuario a la intensidad de referencia frente a no usuario del mismo grupo.\n"
            "Actividad: una actividad adicional entre usuarios. N = 18 065; 772 conglomerados.\n"
            "Modelo con educación lineal. Asociaciones condicionales.")

    d = tabla(datos, "brechas_TIC_IC.csv")
    fig, ax = plt.subplots(figsize=(11, 5.3))
    forest(ax, d, ["Usuario informal frente\na usuario formal", "Usuario informal frente\na no usuario formal"], colores=[ROJO, ROJO])
    ax.set_xlabel("Diferencia porcentual condicional e IC del 95 %")
    ax.set_title("Comparaciones entre grupos laborales", pad=17)
    guardar(fig, salida, "08D_TIC", "04_brechas_TIC_IC",
            "Usuarios evaluados a la intensidad de referencia. N = 18 065; 772 conglomerados.\n"
            "El segundo intervalo incluye cero. Los intervalos proceden de Stata.")

    # 08E: conservar exactamente el modelo Lineal utilizado por el .do.
    d = tabla(datos, "asociaciones_tipo.csv")
    d = d[d.modelo.eq("Lineal")]
    if len(d) != 8:
        raise ValueError("Se esperan ocho asociaciones por tipo de trabajador.")
    fig, axes = plt.subplots(1, 2, figsize=(12, 6.0))
    for ax, margen, titulo in zip(axes, ["Uso", "Intensidad"], ["Uso de computadora", "Actividad adicional entre usuarios"]):
        for inf, color, label, offset in [(0, AZUL, "Formales", -.065), (1, ROJO, "Informales", .065)]:
            sub = d[d.margen.eq(margen) & d.informalidad.eq(inf)].sort_values("tipo")
            arr = intervalos(sub)
            ax.errorbar(sub.tipo.to_numpy()+offset, arr[:, 0],
                        yerr=np.stack([arr[:, 0]-arr[:, 1], arr[:, 2]-arr[:, 0]]),
                        fmt="o", color=color, capsize=3, label=label)
        ax.set_title(titulo)
        ax.set_xticks([1, 2], ["Dependientes", "Empleadores /\nindependientes"])
        ax.set_xlim(.65, 2.35)
        ax.axhline(0, color=GRIS, linewidth=.8)
        ax.yaxis.set_major_formatter(PercentFormatter(100))
        ax.legend(frameon=False)
        limpiar(ax, "y")
    axes[0].set_ylabel("Diferencia porcentual condicional")
    guardar(fig, salida, "08E_tipo_trabajador", "01_Asociaciones_TIC_por_tipo",
            "IC individuales del 95 %. Modelo lineal; N = 18 065; 772 conglomerados.\n"
            "Uso a la intensidad de referencia. Intensidad entre usuarios; centro fijo del modelo.")

    d = tabla(datos, "diferencias_tipo.csv")
    d = d[d.modelo.eq("Lineal")].sort_values("orden")
    fig, ax = plt.subplots(figsize=(11.5, 5.7))
    forest(ax, d, ["Uso: formales", "Uso: informales", "Actividad: formales", "Actividad: informales"], porcentual=False)
    ax.set_xlabel("Coeficiente de empleadores/independientes menos dependientes")
    ax.set_title("Diferencias TIC entre tipos de trabajador", pad=17)
    guardar(fig, salida, "08E_tipo_trabajador", "02_Diferencias_TIC_por_tipo",
            "Diferencias en puntos logarítmicos e IC individuales del 95 %.\n"
            "Los valores p originales y ajustados por Holm se conservan en diferencias_tipo.csv.")

    d = tabla(datos, "densidades_tic.csv").sort_values("e8_grid")
    if len(d) != 400 or (d[["e8_f0", "e8_f1", "e8_i0", "e8_i1"]] < 0).any().any():
        raise ValueError("Revisar la rejilla o las densidades exportadas.")
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.8), sharex=True, sharey=True)
    for ax, prefijo, titulo in zip(axes, ["f", "i"], ["Empleo formal", "Empleo informal"]):
        ax.plot(d.e8_grid, d[f"e8_{prefijo}0"], color=GRIS, label="No usa")
        ax.plot(d.e8_grid, d[f"e8_{prefijo}1"], color=AZUL, label="Usa")
        ax.set_title(titulo)
        ax.set_xlabel("Log ingreso horario a precios de 2025")
        ax.legend(frameon=False)
        limpiar(ax, "y")
    axes[0].set_ylabel("Densidad")
    guardar(fig, salida, "08E_tipo_trabajador", "03_Distribuciones_ingreso_TIC",
            "Curvas calculadas en Stata: kernel gaussiano, ancho común y 400 puntos de evaluación.\n"
            "Se conservan las densidades exportadas. Descriptivos sin ponderadores ni controles.")

    # 08C: la figura integrada compara el uso entre las tres formas educativas.
    d = tabla(datos, "contrastes_TIC_educacion.csv")
    modelos = ["M2_Lineal", "M2_Cuadratica", "M2_Tramos"]
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.7), sharex=True, sharey=True)
    for ax, contraste, titulo, color in zip(axes, ["Uso_formal", "Uso_informal"], ["Trabajadores formales", "Trabajadores informales"], [AZUL, ROJO]):
        sub = d[d.contraste.eq(contraste)].set_index("modelo").loc[modelos].reset_index()
        forest(ax, sub, ["Lineal", "Cuadrática", "Por tramos"], colores=[color]*3)
        ax.set_title(titulo)
        ax.set_xlabel("Asociación del uso e IC del 95 %")
        ax.set_xlim(0, max(40, float(intervalos(sub)[:, 2].max())+3))
    guardar(fig, salida, "08C_educacion", "05_Sensibilidad_educacion",
            "Usuario a la intensidad de referencia frente a no usuario del mismo grupo.\n"
            "N = 18 065 en cada especificación. Inferencia agrupada por 772 conglomerados.")

    # 10: comparar las ecuaciones de ingreso, excluyendo la ecuación de selección.
    d = tabla(datos, "coeficientes_heckman.csv")
    terminos = ["educ_years", "experiencia_potencial", "1.mujer", "1.casado", "1.jefe_hogar"]
    etiquetas = ["Educación", "Experiencia potencial", "Mujer", "Casado", "Jefe del hogar"]
    fig, ax = plt.subplots(figsize=(10.5, 6.0))
    for modelo, metodo, color, offset in [("O_Ambas", "MCO", AZUL, -.10), ("H_Ambas", "Heckman", ROJO, .10)]:
        sub = d[d.modelo.eq(modelo) & (d.metodo.eq("MCO") | d.ecuacion.eq("ln_ing_hora_real2025"))]
        sub = sub.set_index("termino").loc[terminos]
        vals = sub[["b", "li", "ls"]].to_numpy(float)
        ax.errorbar(vals[:, 0], np.arange(5)+offset,
                    xerr=np.stack([vals[:, 0]-vals[:, 1], vals[:, 2]-vals[:, 0]]),
                    fmt="o", color=color, capsize=3, label=metodo)
    ax.set_yticks(np.arange(5), etiquetas)
    ax.invert_yaxis()
    ax.axvline(0, color=GRIS, linewidth=.9)
    ax.set_title("Mincer: MCO y Heckman", pad=17)
    ax.set_xlabel("Coeficiente e intervalo del 95 % en log ingreso")
    ax.legend(frameon=False, loc="upper left")
    limpiar(ax)
    guardar(fig, salida, "10_Heckman", "03_Coeficientes_MCO_Heckman",
            "Ambos modelos utilizan los mismos 18 069 seleccionados y controles.\n"
            "772 conglomerados. Esta comparación gráfica conserva los intervalos exportados.")
    controles["figuras_solo_con_tablas"] = 7


def base_privada(carpeta, nombre):
    candidatos = list(carpeta.rglob(nombre))
    if len(candidatos) != 1:
        raise ValueError(f"Se esperaba una base privada {nombre}; encontradas: {len(candidatos)}")
    return pd.read_stata(candidatos[0], convert_categoricals=False)


def columna_termino(df, termino):
    """Expandir los términos exportados por Stata con las mismas bases."""
    if termino == "_cons":
        return np.ones(len(df))
    if "#" in termino:
        factores = [columna_termino(df, t) for t in termino.split("#")]
        return np.prod(factores, axis=0)
    if termino.startswith("c."):
        return df[termino[2:]].to_numpy(float)
    match = re.fullmatch(r"(\d+)\.(\w+)", termino)
    if match:
        return df[match.group(2)].eq(int(match.group(1))).to_numpy(float)
    return df[termino].to_numpy(float)


def figuras_mco(datos, privados, salida, controles):
    d = base_privada(privados, "base_mco_complemento_etapa08E.dta").copy()
    if len(d) != 18065 or d.id_conglomerado_marco.nunique() != 772:
        raise ValueError("La base MCO no corresponde a la muestra esperada.")
    y = d.ln_ing_hora_real2025.to_numpy(float)
    usuarios = d[d.tic_uso_pc.eq(1)]
    if len(usuarios) != 7933:
        raise ValueError("Se esperan 7 933 usuarios en MCO.")
    fig, ax = plt.subplots(figsize=(11, 6.2))
    grupos = [d[(d.informal == inf) & (d.tic_uso_pc == usa)] for inf, usa in [(0, 0), (0, 1), (1, 0), (1, 1)]]
    cajas = ax.boxplot([g.ln_ing_hora_real2025 for g in grupos], patch_artist=True,
                       flierprops={"markersize": 1.5, "markeredgewidth": 0, "markerfacecolor": GRIS, "alpha": .28},
                       medianprops={"color": "#172f3b", "linewidth": 1.4}, widths=.48)
    for box, color in zip(cajas["boxes"], [AZUL, AZUL, ROJO, ROJO]):
        box.set_facecolor(color)
        box.set_alpha(.3)
    ax.set_xticks(range(1, 5), [f"{labor}\n{uso}\nN = {len(g):,}" for labor, uso, g in zip(
        ["Formal", "Formal", "Informal", "Informal"], ["No usuario", "Usuario", "No usuario", "Usuario"], grupos)])
    ax.set_title("Ingreso horario por uso de computadora e informalidad", pad=17)
    ax.set_ylabel("Log ingreso horario a precios de 2025")
    limpiar(ax, "y")
    guardar(fig, salida, "08D_TIC", "01_ingreso_cuatro_grupos",
            "N = 18 065. Cajas: percentiles 25 y 75; línea central: mediana.\n"
            "Bigotes hasta 1,5 rangos intercuartiles. Los puntos muestran valores exteriores. Sin controles.")

    # El ajuste de una recta descriptiva no modifica las estimaciones de Stata.
    fig, axes = plt.subplots(1, 2, figsize=(12, 6.2), sharex=True, sharey=True)
    for ax, inf, color, nombre in zip(axes, [0, 1], [AZUL, ROJO], ["Formal", "Informal"]):
        g = usuarios[usuarios.informal.eq(inf)]
        x = g.tic_actividades_usuarios.to_numpy(float)
        yy = g.ln_ing_hora_real2025.to_numpy(float)
        ax.scatter(x, yy, s=5, alpha=.13, color=color, edgecolors="none", rasterized=True)
        pendiente = np.sum((x-x.mean())*(yy-yy.mean())) / np.sum((x-x.mean())**2)
        recta = yy.mean() + pendiente*(np.array([0, 9])-x.mean())
        ax.plot([0, 9], recta, color="#25343e", linewidth=1.5)
        ax.set_title(f"{nombre}: N = {len(g):,}")
        ax.set_xticks(range(10))
        ax.set_xlabel("Número de actividades declaradas")
        limpiar(ax, "y")
    axes[0].set_ylabel("Log ingreso horario a precios de 2025")
    guardar(fig, salida, "08D_TIC", "02_actividades_ingreso_usuarios",
            "Se representan los 7 933 usuarios. Los puntos pueden superponerse.\n"
            "Rectas bivariadas sin controles. Sus pendientes difieren de los coeficientes del MCO con controles.")

    fig = plt.figure(figsize=(12, 7.0))
    for j, inf, color, nombre in [(1, 0, AZUL, "Formal"), (2, 1, ROJO, "Informal")]:
        ax = fig.add_subplot(1, 2, j, projection="3d")
        g = usuarios[usuarios.informal.eq(inf)]
        ax.scatter(g.educ_years, g.tic_actividades_usuarios, g.ln_ing_hora_real2025,
                   color=color, s=3, alpha=.17, edgecolors="none", rasterized=True)
        ax.set_xlabel("Años de educación", labelpad=8)
        ax.set_ylabel("Actividades", labelpad=8)
        ax.set_zlabel("Log ingreso horario", labelpad=9)
        ax.set_zlim(y.min(), y.max())
        ax.set_ylim(0, 9)
        ax.set_title(f"{nombre}: N = {len(g):,}", pad=14)
        ax.view_init(elev=22, azim=-55)
        ax.tick_params(labelsize=8)
    guardar(fig, salida, "08D_TIC", "05_nube_3D_usuarios",
            "Educación, actividades e ingreso observado entre usuarios. Todos los registros, sin muestreo.\n"
            "Figura descriptiva sin superficie de regresión ni otros controles. Ingreso a precios de 2025.")

    # Reconstruir residuos parciales con los coeficientes existentes, sin reestimar.
    coef = tabla(datos, "coeficientes_forma_educacion.csv")
    for nudo in [6, 11, 16]:
        d[f"e_h{nudo}"] = np.maximum(d.educ_years-nudo, 0)
    controles["educacion"] = []
    for modelo, cc in coef.groupby("modelo", sort=False):
        ajuste = np.zeros(len(d))
        componente = np.zeros(len(d))
        for row in cc.itertuples():
            contribucion = row.b * columna_termino(d, row.termino)
            ajuste += contribucion
            if row.termino in {"educ_years", "c.educ_years#c.educ_years", "e_h6", "e_h11", "e_h16"}:
                componente += contribucion
        residuo = y-ajuste
        r2 = 1-np.sum(residuo**2)/np.sum((y-y.mean())**2)
        r2_stata = float(cc.r2.iloc[0])
        if abs(r2-r2_stata) > 1e-6 or abs(residuo.mean()) > 1e-5:
            raise ValueError(f"Los coeficientes y la base no concilian para {modelo}.")
        resumen = pd.DataFrame({"educ_years": d.educ_years, "componente": componente,
                                "parcial": residuo+componente}).groupby("educ_years", as_index=False).mean()
        fig, ax = plt.subplots(figsize=(9.8, 6.2))
        ax.scatter(resumen.educ_years, resumen.parcial, color=AZUL, s=27, label="Media de residuos parciales", zorder=3)
        ax.plot(resumen.educ_years, resumen.componente, color=ROJO, label="Componente estimado")
        ax.set_title(f"{modelo}: componente educativo", pad=17)
        ax.set_xlabel("Años de educación")
        ax.set_ylabel("Componente educativo y residuo parcial")
        ax.legend(frameon=False)
        limpiar(ax, "y")
        guardar(fig, salida, "08C_educacion", f"educacion_{modelo}",
                "Medias por años de educación observados. Reconstrucción con los coeficientes de Stata.\n"
                "Diagnóstico de forma funcional. Se conserva la muestra MCO de 18 065 observaciones.")
        controles["educacion"].append({"modelo": modelo, "r2_reconstruido": float(r2),
                                       "r2_stata": r2_stata, "residuo_medio": float(residuo.mean())})
    controles["MCO"] = {"N": len(d), "usuarios": len(usuarios), "grupos": int(d.id_conglomerado_marco.nunique())}


def densidad_gaussiana(x, grid):
    """Suavizado definido aquí: h = .9 min(s, RIQ/1.349) n^(-1/5)."""
    x = np.asarray(x, dtype=float)
    sd = x.std(ddof=1)
    riq = np.subtract(*np.percentile(x, [75, 25]))/1.349
    escala = min(sd, riq) if riq > 0 else sd
    h = .9 * escala * len(x)**(-.2)
    if not np.isfinite(h) or h <= 0:
        raise ValueError("No se puede calcular una densidad con dispersión nula.")
    resultado = np.zeros(len(grid))
    for inicio in range(0, len(x), 3000):
        z = (grid[:, None]-x[None, inicio:inicio+3000])/h
        resultado += np.exp(-.5*z*z).sum(axis=1)
    return resultado/(len(x)*h*np.sqrt(2*np.pi)), h


def figuras_heckman(privados, salida, controles):
    d = base_privada(privados, "base_heckman_estimacion_etapa10.dta")
    estimacion = d[d.h10_es_Ambas.eq(1)]
    seleccionados = estimacion[estimacion.S_ingreso.eq(1)]
    if len(estimacion) != 28363 or len(seleccionados) != 18069:
        raise ValueError("La muestra principal de Heckman difiere de sus tablas.")
    fig, ax = plt.subplots(figsize=(10.4, 6.1))
    anchos = {}
    for s, color in [(0, ROJO), (1, AZUL)]:
        valores = estimacion.loc[estimacion.S_ingreso.eq(s), "h10_psel_ml"].dropna().to_numpy()
        grid = np.linspace(valores.min(), valores.max(), 500)
        densidad, h = densidad_gaussiana(valores, grid)
        ax.plot(grid, densidad, color=color, label=f"S = {s}")
        anchos[str(s)] = float(h)
    ax.set_xlim(0, 1)
    ax.set_xlabel("Probabilidad estimada de observar ingreso válido")
    ax.set_ylabel("Densidad")
    ax.set_title("Probabilidades de selección estimadas por Heckman", pad=17)
    ax.legend(frameon=False)
    limpiar(ax, "y")
    guardar(fig, salida, "10_Heckman", "01_Probabilidades_seleccion",
            "N = 28 363. Predicciones originales de Stata; reconstrucción con suavizado gaussiano explícito.\n"
            "La curva puede diferir del suavizado del gráfico .gph. El modelo no se vuelve a estimar.")

    fig, ax = plt.subplots(figsize=(10.4, 6.2))
    if seleccionados[["h10_ycond", "h10_residuo_cond"]].isna().any().any():
        raise ValueError("Faltan predicciones condicionales en casos seleccionados.")
    ax.scatter(seleccionados.h10_ycond, seleccionados.h10_residuo_cond, s=4,
               alpha=.15, color=AZUL, edgecolors="none", rasterized=True)
    ax.axhline(0, color=ROJO, linewidth=1)
    ax.set_title("Residuos y media condicional ajustada", pad=17)
    ax.set_xlabel("Log ingreso esperado, condicionado a S = 1")
    ax.set_ylabel("Log ingreso observado menos media condicional")
    limpiar(ax, "y")
    guardar(fig, salida, "10_Heckman", "02_Residuos_condicionales",
            "Se muestran las 18 069 observaciones seleccionadas, sin muestreo de puntos.\n"
            "Se reutilizan las predicciones guardadas de Stata. Diagnóstico descriptivo.")
    controles["Heckman"] = {"base_amplia": len(d), "estimacion": len(estimacion),
                            "seleccionados": len(seleccionados), "anchos_gaussianos": anchos}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tablas", type=Path, default=REPO / "resultados" / "tablas")
    parser.add_argument("--salida", type=Path, default=REPO / "figuras" / "python")
    parser.add_argument("--datos-privados", type=Path,
                        help="Carpeta con las bases 08E y 10. Se conserva fuera de GitHub.")
    args = parser.parse_args()
    estilo()
    controles = {"origen_coeficientes": "Tablas CSV exportadas por Stata", "modelos_reestimados": False}
    figuras_agregadas(args.tablas, args.salida, controles)
    if args.datos_privados:
        figuras_mco(args.tablas, args.datos_privados, args.salida, controles)
        figuras_heckman(args.datos_privados, args.salida, controles)
        controles["figuras_generadas"] = 18
    else:
        controles["figuras_generadas"] = 7
        controles["figuras_que_requieren_bases_privadas"] = 11
    args.salida.mkdir(parents=True, exist_ok=True)
    (args.salida / "verificacion_reconstruccion.json").write_text(json.dumps(controles, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Generadas {controles['figuras_generadas']} figuras PNG y SVG en {args.salida}")
    if not args.datos_privados:
        print("Otras 11 figuras requieren --datos-privados. No se publican microdatos.")


if __name__ == "__main__":
    main()
