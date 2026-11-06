from __future__ import annotations

import argparse
import csv
import gzip
import os
import random
import shutil
import subprocess
import time
from contextlib import contextmanager
from pathlib import Path

from psycopg_pool import ConnectionPool
from faker import Faker


ROOT = Path(__file__).resolve().parent
CATALOGOS = ROOT / "catalogos"

# Prefijos válidos de CUIT argentino (persona jurídica)
CUIT_PREFIXES = (20, 23, 24, 27, 30, 33, 34)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Carga catálogos semilla y datos masivos en Bodegas del Atuel (Etapa 3)."
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=int(os.getenv("SEED", "42")),
        help="Semilla aleatoria (default: env SEED o 42)",
    )
    parser.add_argument(
        "--masivo",
        action="store_true",
        help="Ejecuta carga masiva de datos (clientes, comprobantes, renglones).",
    )
    parser.add_argument(
        "--clientes",
        type=int,
        default=int(os.getenv("SEED_CLIENTES", "20000")),
        help="Cantidad de clientes a generar (default 20000).",
    )
    parser.add_argument(
        "--comprobantes",
        type=int,
        default=int(os.getenv("SEED_COMPROBANTES", "150000")),
        help="Cantidad de comprobantes a generar (default 150000).",
    )
    return parser.parse_args()


def medir_tiempo(nombre: str):
    """Context manager para medir y reportar el tiempo de un bloque."""
    inicio = time.perf_counter()

    class _Cronometro:
        def __enter__(self):
            return self

        def __exit__(self, *exc):
            print(f"[{nombre}] {time.perf_counter() - inicio:.4f} segundos")

    return _Cronometro()


@contextmanager
def pool_owner():
    """Pool de conexiones como owner desde variables de entorno."""
    pool = ConnectionPool(
        conninfo=(
            f"host={os.getenv('DB_HOST', 'localhost')} "
            f"port={int(os.getenv('DB_PORT', '5432'))} "
            f"dbname={os.getenv('POSTGRES_DB', 'bodegas')} "
            f"user={os.getenv('POSTGRES_USER', 'bodegas_owner')} "
            f"password={os.getenv('POSTGRES_PASSWORD', '')}"
        ),
        open=False,
        min_size=1,
        max_size=3,
    )
    pool.open()
    try:
        yield pool
    finally:
        pool.close()


def asegurar_provincia_mendoza(pool) -> int:
    """Crea la provincia Mendoza si no existe y devuelve su id_provincia."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO provincia (nombre) VALUES ('Mendoza') "
                "ON CONFLICT (nombre) DO NOTHING "
                "RETURNING id_provincia;"
            )
            fila = cur.fetchone()
            if fila is not None:
                id_provincia = fila[0]
            else:
                cur.execute(
                    "SELECT id_provincia FROM provincia WHERE nombre = 'Mendoza';"
                )
                id_provincia = cur.fetchone()[0]
            conn.commit()
            return id_provincia


def leer_csv(nombre_archivo: str) -> list[dict]:
    """Lee un archivo CSV y devuelve lista de diccionarios."""
    ruta = CATALOGOS / nombre_archivo
    with ruta.open(encoding="utf-8") as f:
        lector = csv.DictReader(f)
        return [dict(fila) for fila in lector]


def cargar_cepas(pool) -> int:
    """Carga cepas desde catalogos/cepas.csv."""
    filas = leer_csv("cepas.csv")
    datos = [(f["nombre"], f["tipo"]) for f in filas if f.get("nombre")]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO cepa (nombre, tipo) VALUES (%s, %s) "
                "ON CONFLICT (nombre) DO NOTHING;",
                datos,
            )
            conn.commit()
    return len(datos)


def cargar_maridajes(pool) -> int:
    """Carga maridajes desde catalogos/maridajes.csv."""
    filas = leer_csv("maridajes.csv")
    datos = [(f["nombre"], float(f["temperatura_servicio_c"])) for f in filas if f.get("nombre")]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO maridaje (nombre, temperatura_servicio) VALUES (%s, %s) "
                "ON CONFLICT (nombre) DO NOTHING;",
                datos,
            )
            conn.commit()
    return len(datos)


def cargar_departamentos_mendoza(pool, id_provincia: int) -> int:
    """Carga departamentos de Mendoza desde catalogos/departamentos_mendoza.csv."""
    filas = leer_csv("departamentos_mendoza.csv")
    datos = [(id_provincia, f["departamento"]) for f in filas if f.get("departamento")]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO departamento (id_provincia, nombre) VALUES (%s, %s) "
                "ON CONFLICT (id_provincia, nombre) DO NOTHING;",
                datos,
            )
            conn.commit()
    return len(datos)


def cargar_localidades(pool, id_provincia: int) -> int:
    """Carga localidades de Mendoza desde catalogos/localidades.csv."""
    filas = leer_csv("localidades.csv")
    datos = [
        (id_provincia, f["nombre"], f["codigo_postal"])
        for f in filas
        if f.get("nombre") and f.get("codigo_postal")
    ]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO localidad (id_provincia, nombre, codigo_postal, encargado_regional) "
                "VALUES (%s, %s, %s, %s) "
                "ON CONFLICT (id_provincia, nombre, codigo_postal) DO NOTHING;",
                [(d[0], d[1], d[2], "Encargado " + d[1]) for d in datos],
            )
            conn.commit()
    return len(datos)


# Orden de dependencias: tablas sin FK primero, luego las que dependen de provincia.
FUNCIONES_CARGA = [
    ("cepas", cargar_cepas),
    ("maridajes", cargar_maridajes),
    ("departamentos_mendoza", cargar_departamentos_mendoza),
    ("localidades", cargar_localidades),
]


def contar_filas(pool, tabla: str) -> int:
    """Devuelve el conteo de filas de una tabla."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {tabla};")
            return cur.fetchone()[0]


def main() -> None:
    args = parse_args()
    rng = random.Random(args.seed)
    fake = Faker("es_AR")
    Faker.seed(args.seed)

    print(f"Semilla: {args.seed}")
    print("=" * 60)
    print("ETAPA 3 - PASO 1: Carga de catálogos desde CSV (anexo B)")
    print("=" * 60)

    with pool_owner() as pool:
        # 1. Asegurar provincia Mendoza (dependencia de departamento y localidad)
        id_provincia = asegurar_provincia_mendoza(pool)
        print(f"Provincia Mendoza id_provincia={id_provincia} (listada para catálogos)")

        # 2. Cargar cada catálogo en orden de dependencias
        resultados = {}
        for nombre, func in FUNCIONES_CARGA:
            with medir_tiempo(nombre):
                if nombre in ("departamentos_mendoza", "localidades"):
                    cantidad = func(pool, id_provincia)
                else:
                    cantidad = func(pool)
            resultados[nombre] = cantidad
            print(f"  OK: {nombre} -> {cantidad} filas")

        # 3. Consultas de control: conteo por tabla (catálogos)
        print("\n" + "=" * 60)
        print("CONSULTAS DE CONTROL - conteo de filas por tabla (catálogos)")
        print("=" * 60)
        tablas_control = ["provincia", "cepa", "maridaje", "departamento", "localidad"]
        for tabla in tablas_control:
            n = contar_filas(pool, tabla)
            print(f"  {tabla:<20} {n:>6} filas")

    if args.masivo:
        print("\n" + "=" * 60)
        print("ETAPA 3 - PASO 3: Carga masiva de datos (Faker, semilla fija)")
        print("=" * 60)
        ejecutar_masivo(args, rng, fake)


def ejecutar_masivo(args, rng, fake) -> None:
    """Orquesta la carga masiva: maestros, clientes, stock, comprobantes/renglones,
    actualización de totales, reactivación de triggers y consultas de control."""
    with pool_owner() as pool:
        # 0. Datos maestros (volumen bajo)
        print("\n--- Datos maestros ---")
        with medir_tiempo("bodegas"):
            bodegas = [1]  # placeholder si ya existen
            # Leer bodegas existentes o cargar pocas
            nb = contar_filas(pool, "bodega")
            if nb == 0:
                nb = cargar_bodegas(pool, rng, fake, n=8)
            cur_bodegas = None
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT id_bodega FROM bodega;")
                    bodegas = [r[0] for r in cur.fetchall()]
            print(f"  Bodegas: {len(bodegas)}")

        with medir_tiempo("departamentos"):
            nd = contar_filas(pool, "departamento")
            id_deps = []
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT id_departamento FROM departamento;")
                    id_deps = [r[0] for r in cur.fetchall()]
            print(f"  Departamentos: {len(id_deps)}")

        with medir_tiempo("fincas"):
            nf = contar_filas(pool, "finca")
            if nf == 0:
                nf = cargar_fincas(pool, rng, fake, id_deps, n=12)
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT id_finca FROM finca;")
                    fincas = [r[0] for r in cur.fetchall()]
            print(f"  Fincas: {len(fincas)}")

        with medir_tiempo("parcelas"):
            np_ = contar_filas(pool, "parcela")
            if np_ == 0:
                with pool.connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute("SELECT id_cepa FROM cepa;")
                        cepas = [r[0] for r in cur.fetchall()]
                np_ = cargar_parcelas(pool, rng, fake, fincas, cepas, n_por_finca=4)
            print(f"  Parcelas: {np_}")

        with medir_tiempo("vinos"):
            nv = contar_filas(pool, "vino")
            if nv == 0:
                nv = len(cargar_vinos(pool, rng, fake, bodegas, n=60))
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT cod_vino FROM vino;")
                    vinos = [r[0] for r in cur.fetchall()]
            print(f"  Vinos: {len(vinos)}")

        with medir_tiempo("salas"):
            ns = contar_filas(pool, "sala_venta")
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT id_localidad FROM localidad;")
                    localidades = [r[0] for r in cur.fetchall()]
                    cur.execute("SELECT id_sala FROM sala_venta;")
                    salas = [r[0] for r in cur.fetchall()]
            if ns == 0:
                salas = cargar_salas(pool, rng, fake, localidades, n=10)
            print(f"  Salas: {len(salas)}")

        with medir_tiempo("empleados"):
            ne = contar_filas(pool, "empleado")
            if ne == 0:
                ne = cargar_empleados(pool, rng, fake, salas, n=40)
            print(f"  Empleados: {ne}")

        with medir_tiempo("transportistas"):
            nt = contar_filas(pool, "transportista")
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT cod_transportista FROM transportista;")
                    transportistas = [r[0] for r in cur.fetchall()]
            if nt == 0:
                transportistas = cargar_transportistas(pool, rng, fake, localidades, n=6)
            print(f"  Transportistas: {len(transportistas)}")

        # 1. Clientes masivos (20.000) + subtipos
        print("\n--- Clientes masivos ---")
        deshabilitar_triggers(pool)
        with medir_tiempo("clientes"):
            nc = cargar_clientes_masivo(pool, rng, fake, localidades, n=args.clientes)
        print(f"  Clientes insertados: {nc}")

        # 2. Stock inicial
        print("\n--- Stock inicial ---")
        cargar_stock_inicial(pool, rng, vinos, salas)

        # 3. Comprobantes y renglones masivos (150.000 / 500.000+)
        print("\n--- Comprobantes y renglones masivos ---")
        with medir_tiempo("comprobantes_renglones"):
            ncomp, nreng = cargar_comprobantes_renglones_masivo(
                pool, rng, fake,
                clientes=_fetch_col(pool, "SELECT id_cliente FROM cliente;"),
                salas=salas, vinos=vinos,
                n_comprobantes=args.comprobantes,
            )
        print(f"  Comprobantes: {ncomp}, Renglones: {nreng}")

        # 4. Actualizar totales y stock
        print("\n--- Actualizar totales y stock ---")
        actualizar_totales_y_stock(pool)

        # 5. Rehabilitar triggers
        print("\n--- Reactivando triggers ---")
        habilitar_triggers(pool)

        # 6. Consultas de control finales
        print("\n" + "=" * 60)
        print("CONSULTAS DE CONTROL - conteo final por tabla")
        print("=" * 60)
        tablas_final = [
            "provincia", "departamento", "localidad", "bodega", "finca", "cepa",
            "parcela", "vino", "sala_venta", "empleado", "transportista",
            "cliente", "socio", "distribuidor", "exportador",
            "stock_deposito", "stock_sala", "comprobante", "renglon_comprobante",
        ]
        total_masivo = 0
        for tabla in tablas_final:
            n = contar_filas(pool, tabla)
            print(f"  {tabla:<28} {n:>8} filas")
            if tabla in ("cliente", "comprobante", "renglon_comprobante"):
                total_masivo += n
        print(f"\n  Filas en tablas masivas (cliente+comprobante+renglon_comprobante): {total_masivo}")

        # 7. Volcado de la base cargada
        print("\n--- Generando dump_completo.sql.gz ---")
        generar_dump_completo()

        print("\nCarga masiva finalizada.")


def _fetch_col(pool, sql: str) -> list:
    """Ejecuta una consulta SELECT de una columna y devuelve la lista de valores."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            return [r[0] for r in cur.fetchall()]




# ---------------------------------------------------------------------------
# Gestión de triggers para carga masiva (Etapa 3, Paso 3+)
# Durante la carga histórica se deshabilitan los triggers que chocan con
# inserciones masivas y se vuelven a habilitar al terminar.
# ---------------------------------------------------------------------------

TRIGGERS_DESHABILITAR = [
    "trg_coherencia_cliente_subtipo",
    "trg_validar_stock_venta",
    "trg_descontar_stock_y_calcular_totales",
    "trg_bloquear_renglones_ingreso",
    "trg_bloquear_renglones_transferencia",
    "trg_fecha_confeccion_transferencia",
    "trg_auditoria_precio_vino",
]


def deshabilitar_triggers(pool) -> None:
    """Deshabilita triggers de tablas clave para carga masiva histórica."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            for t in TRIGGERS_DESHABILITAR:
                cur.execute(
                    "ALTER TABLE %s DISABLE TRIGGER %s;"
                    % ({"trg_coherencia_cliente_subtipo": "cliente",
                        "trg_validar_stock_venta": "renglon_comprobante",
                        "trg_descontar_stock_y_calcular_totales": "renglon_comprobante",
                        "trg_bloquear_renglones_ingreso": "renglon_ingreso",
                        "trg_bloquear_renglones_transferencia": "renglon_transferencia",
                        "trg_fecha_confeccion_transferencia": "transferencia",
                        "trg_auditoria_precio_vino": "vino"}[t], t)
                )
        conn.commit()
    print("  Triggers deshabilitados para carga masiva.")


def habilitar_triggers(pool) -> None:
    """Vuelve a habilitar los triggers tras la carga masiva."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            for t in TRIGGERS_DESHABILITAR:
                cur.execute(
                    "ALTER TABLE %s ENABLE TRIGGER %s;"
                    % ({"trg_coherencia_cliente_subtipo": "cliente",
                        "trg_validar_stock_venta": "renglon_comprobante",
                        "trg_descontar_stock_y_calcular_totales": "renglon_comprobante",
                        "trg_bloquear_renglones_ingreso": "renglon_ingreso",
                        "trg_bloquear_renglones_transferencia": "renglon_transferencia",
                        "trg_fecha_confeccion_transferencia": "transferencia",
                        "trg_auditoria_precio_vino": "vino"}[t], t)
                )
        conn.commit()
    print("  Triggers habilitados nuevamente.")


# ---------------------------------------------------------------------------
# Datos maestros (volumen bajo, triggers habilitados)
# ---------------------------------------------------------------------------

def cargar_bodegas(pool, rng, fake, n: int = 8) -> int:
    filas = []
    for _ in range(n):
        filas.append((
            f"{rng.choice(CUIT_PREFIXES)}{rng.randint(10000000, 99999999)}{rng.randint(0, 9)}",
            fake.company(),
            fake.street_address(),
        ))
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO bodega (cuit, razon_social, domicilio) VALUES (%s, %s, %s) "
                "ON CONFLICT (cuit) DO NOTHING;",
                filas,
            )
        conn.commit()
    return len(filas)


def cargar_fincas(pool, rng, fake, id_departamentos: list, n: int = 12) -> int:
    filas = []
    for _ in range(n):
        filas.append((
            rng.choice(id_departamentos),
            fake.company() + " Finca",
            round(rng.uniform(50, 500), 2),
        ))
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO finca (id_departamento, nombre, superficie_ha) VALUES (%s, %s, %s) "
                "ON CONFLICT DO NOTHING;",
                filas,
            )
        conn.commit()
    return len(filas)


def cargar_parcelas(pool, rng, fake, fincas: list, cepas: list, n_por_finca: int = 4) -> int:
    filas = []
    for id_finca in fincas:
        for nro in range(1, n_por_finca + 1):
            filas.append((
                id_finca,
                nro,
                rng.choice(cepas),
                round(rng.uniform(5, 50), 2),
                rng.randint(2010, 2023),
            ))
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO parcela (id_finca, nro_parcela, id_cepa, superficie_ha, anio_plantacion) "
                "VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;",
                filas,
            )
        conn.commit()
    return len(filas)


def cargar_vinos(pool, rng, fake, bodegas: list, n: int = 60) -> list:
    tipos = ["tinto", "blanco", "rosado", "espumante"]
    volumenes = [187, 375, 750, 1000, 1500, 3000]
    nombres = ["Malbec Reserva", "Cabernet Sauvignon", "Chardonnay", "Torrontés",
               "Bonarda", "Syrah", "Merlot", "Tempranillo", "Pinot Noir", "Chenin Blanc"]
    usados = set()
    cod_vinos = []
    with pool.connection() as conn:
        with conn.cursor() as cur:
            for _ in range(n):
                nombre = f"{rng.choice(nombres)} {rng.randint(2018, 2024)}"
                anada = rng.randint(2018, 2024)
                volumen = rng.choice(volumenes)
                clave = (nombre, anada, volumen)
                sufijo = 1
                nombre_base = nombre
                while clave in usados:
                    nombre = f"{nombre_base} Ed {sufijo}"
                    clave = (nombre, anada, volumen)
                    sufijo += 1
                usados.add(clave)
                cur.execute(
                    "INSERT INTO vino (id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING cod_vino;",
                    (rng.choice(bodegas), nombre, rng.choice(tipos), anada,
                     volumen, round(rng.uniform(5.0, 20.0), 2),
                     round(rng.uniform(3000, 30000), 2)),
                )
                cod_vinos.append(cur.fetchone()[0])
        conn.commit()
    return cod_vinos


def cargar_salas(pool, rng, fake, localidades: list, n: int = 10) -> list:
    ids = []
    for _ in range(n):
        id_loc = rng.choice(localidades)
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre) "
                    "VALUES (%s, %s, %s, %s) RETURNING id_sala;",
                    (id_loc, fake.street_address(), str(rng.randint(1, 500)),
                     rng.choice(["lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo"])),
                )
                ids.append(cur.fetchone()[0])
        conn.commit()
    return ids


def cargar_empleados(pool, rng, fake, salas: list, n: int = 40) -> int:
    filas = []
    for _ in range(n):
        filas.append((
            rng.choice(salas),
            f"{rng.choice(CUIT_PREFIXES)}{rng.randint(10000000, 99999999)}{rng.randint(0, 9)}",
            fake.first_name(), fake.last_name(),
            fake.date_between(start_date="-10y", end_date="today"),
            round(rng.uniform(200000, 800000), 2),
        ))
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO empleado (id_sala, cuit, nombre, apellido, fecha_ingreso, salario) "
                "VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT (cuit) DO NOTHING;",
                filas,
            )
        conn.commit()
    return len(filas)


def cargar_transportistas(pool, rng, fake, localidades: list, n: int = 6) -> list:
    ids = []
    for _ in range(n):
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO transportista (razon_social, cuit, email, telefono, domicilio) "
                    "VALUES (%s, %s, %s, %s, %s) RETURNING cod_transportista;",
                    (fake.company(),
                     f"{rng.choice(CUIT_PREFIXES)}{rng.randint(10000000, 99999999)}{rng.randint(0, 9)}",
                     fake.email(), fake.phone_number(), fake.street_address()),
                )
                ids.append(cur.fetchone()[0])
            conn.commit()
    return ids


# ---------------------------------------------------------------------------
# Carga masiva (triggers DESHABILITADOS durante la carga)
# ---------------------------------------------------------------------------

def cargar_clientes_masivo(pool, rng, fake, localidades: list, n: int = 20000,
                           lote: int = 5000) -> int:
    """Inserta clientes y sus filas de subtipo (socio/distribuidor/exportador)."""
    tipos = ["socio", "distribuidor", "exportador"]
    tipos_doc = ["DNI", "CUIT", "CUIL", "PASAPORTE"]
    descuentos = {"socio": 10, "distribuidor": 20, "exportador": 30}
    paises = ["Chile", "Brasil", "Uruguay", "EE.UU.", "España", "Italia"]
    zonas = ["Norte", "Sur", "Este", "Oeste", "Centro"]
    total = 0
    with pool.connection() as conn:
        with conn.cursor() as cur:
            for ini in range(0, n, lote):
                fin = min(ini + lote, n)
                filas_cliente = []
                filas_socio = []
                filas_dist = []
                filas_exp = []
                for _ in range(ini, fin):
                    tipo = rng.choice(tipos)
                    nombre = fake.name()
                    tipo_doc = rng.choice(tipos_doc)
                    nro_doc = f"{rng.randint(10000000, 99999999)}"
                    direccion = fake.street_address()
                    id_loc = rng.choice(localidades)
                    fecha_alta = fake.date_between(start_date="-5y", end_date="today")
                    desc = descuentos[tipo]
                    filas_cliente.append((tipo, nombre, tipo_doc, nro_doc, direccion,
                                          id_loc, fecha_alta, desc))
                cur.execute("SELECT COALESCE(MAX(id_cliente), 0) FROM cliente;")
                max_antes = cur.fetchone()[0]
                cur.executemany(
                    "INSERT INTO cliente (tipo_cliente, nombre_razon_social, tipo_doc, nro_doc, "
                    "direccion, id_localidad, fecha_alta, descuento) VALUES (%s,%s,%s,%s,%s,%s,%s,%s) ",
                    filas_cliente,
                )
                cur.execute(
                    "SELECT id_cliente, tipo_cliente FROM cliente "
                    "WHERE id_cliente > %s ORDER BY id_cliente LIMIT %s;",
                    (max_antes, fin - ini),
                )
                ids_tipos = cur.fetchall()
                for id_cliente, tipo in ids_tipos:
                    if tipo == "socio":
                        filas_socio.append((id_cliente,))
                    elif tipo == "distribuidor":
                        filas_dist.append((id_cliente, rng.choice(zonas),
                                            f"HAB-{rng.randint(1000,9999)}"))
                    else:
                        filas_exp.append((id_cliente, rng.choice(paises)))
                if filas_socio:
                    cur.executemany(
                        "INSERT INTO socio (id_cliente) VALUES (%s) ON CONFLICT DO NOTHING;",
                        filas_socio,
                    )
                if filas_dist:
                    cur.executemany(
                        "INSERT INTO distribuidor (id_cliente, zona_cobertura, nro_habilitacion) "
                        "VALUES (%s,%s,%s) ON CONFLICT DO NOTHING;",
                        filas_dist,
                    )
                if filas_exp:
                    cur.executemany(
                        "INSERT INTO exportador (id_cliente, pais_destino) VALUES (%s,%s) "
                        "ON CONFLICT DO NOTHING;",
                        filas_exp,
                    )
                conn.commit()
                total += (fin - ini)
                print(f"    clientes {ini}-{fin} de {n}")
    return total


def cargar_stock_inicial(pool, rng, vinos: list, salas: list) -> None:
    """Carga stock_deposito y stock_sala con cantidades iniciales."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            filas_dep = [(cod_vino, rng.randint(5000, 50000)) for cod_vino in vinos]
            cur.executemany(
                "INSERT INTO stock_deposito (cod_vino, cantidad) VALUES (%s,%s) "
                "ON CONFLICT (cod_vino) DO UPDATE SET cantidad = EXCLUDED.cantidad;",
                filas_dep,
            )
            filas_sala = []
            for id_sala in salas:
                for cod_vino in vinos:
                    filas_sala.append((id_sala, cod_vino, rng.randint(500, 5000)))
            cur.executemany(
                "INSERT INTO stock_sala (id_sala, cod_vino, cantidad) VALUES (%s,%s,%s) "
                "ON CONFLICT (id_sala, cod_vino) DO UPDATE SET cantidad = EXCLUDED.cantidad;",
                filas_sala,
            )
        conn.commit()
    print(f"  Stock inicial: {len(vinos)} vinos en depósito, {len(salas)} salas.")


def cargar_comprobantes_renglones_masivo(pool, rng, fake, clientes: list, salas: list,
                                         vinos: list, n_comprobantes: int = 150000,
                                         lote: int = 5000) -> tuple:
    """Inserta comprobantes y sus renglones en lotes, con triggers deshabilitados.
    Devuelve (n_comprobantes, n_renglones)."""
    descuentos = {"socio": 10, "distribuidor": 20, "exportador": 30}
    total_comp = 0
    total_reng = 0
    with pool.connection() as conn:
        with conn.cursor() as cur:
            # Precargar precios de vinos y tipos de cliente (evita consultas por renglón)
            cur.execute("SELECT cod_vino, precio FROM vino;")
            precios = {cv: float(p) for cv, p in cur.fetchall()}
            cur.execute("SELECT id_cliente, tipo_cliente FROM cliente;")
            tipos_cliente = {cid: tc for cid, tc in cur.fetchall()}

            for ini in range(0, n_comprobantes, lote):
                fin = min(ini + lote, n_comprobantes)
                filas_comp = []
                for _ in range(ini, fin):
                    id_cliente = rng.choice(clientes)
                    id_sala = rng.choice(salas)
                    fecha = fake.date_between(start_date="-1y", end_date="today")
                    filas_comp.append((fecha, id_cliente, id_sala, 0, 0, 0))
                cur.execute("SELECT COALESCE(MAX(nro_comprobante), 0) FROM comprobante;")
                max_comp_antes = cur.fetchone()[0]
                cur.executemany(
                    "INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total) "
                    "VALUES (%s,%s,%s,%s,%s,%s) ",
                    filas_comp,
                )
                cur.execute(
                    "SELECT nro_comprobante, id_sala FROM comprobante "
                    "WHERE nro_comprobante > %s ORDER BY nro_comprobante LIMIT %s;",
                    (max_comp_antes, fin - ini),
                )
                comps = cur.fetchall()
                filas_reng = []
                for nro_comp, id_sala in comps:
                    n_reng = rng.randint(1, 4)
                    tc = tipos_cliente.get(id_cliente, "socio")
                    desc_pct = descuentos.get(tc, 10)
                    # Vinos sin repetición dentro del mismo comprobante (PK compuesta)
                    vinos_comp = rng.sample(vinos, min(n_reng, len(vinos)))
                    for cod_vino in vinos_comp:
                        cantidad = rng.randint(1, 6)
                        precio = precios[cod_vino]
                        subtotal = round(cantidad * precio * (1 - desc_pct / 100), 2)
                        filas_reng.append((nro_comp, cod_vino, cantidad, precio,
                                           desc_pct, subtotal))
                cur.executemany(
                    "INSERT INTO renglon_comprobante "
                    "(nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal) "
                    "VALUES (%s,%s,%s,%s,%s,%s);",
                    filas_reng,
                )
                conn.commit()
                total_comp += (fin - ini)
                total_reng += len(filas_reng)
                print(f"    comprobantes {ini}-{fin} de {n_comprobantes} (renglones: {total_reng})")
    return total_comp, total_reng


def actualizar_totales_y_stock(pool) -> None:
    """Recalcula totales de comprobantes y ajusta stock_sala tras carga masiva."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            # Recalcular subtotal y total de cada comprobante desde sus renglones
            cur.execute("""
                UPDATE comprobante c
                SET subtotal = sub.suma,
                    total = sub.suma
                FROM (
                    SELECT nro_comprobante, SUM(subtotal) AS suma
                    FROM renglon_comprobante
                    GROUP BY nro_comprobante
                ) sub
                WHERE c.nro_comprobante = sub.nro_comprobante;
            """)
            # Descontar stock de sala según lo vendido (sin permitir negativo)
            cur.execute("""
                UPDATE stock_sala s
                SET cantidad = GREATEST(s.cantidad - r.vendido, 0)
                FROM (
                    SELECT id_sala, cod_vino, SUM(cantidad) AS vendido
                    FROM renglon_comprobante rc
                    JOIN comprobante c ON c.nro_comprobante = rc.nro_comprobante
                    GROUP BY id_sala, cod_vino
                ) r
                WHERE s.id_sala = r.id_sala AND s.cod_vino = r.cod_vino;
            """)
        conn.commit()
    print("  Totales de comprobantes y stock de sala actualizados.")


# ---------------------------------------------------------------------------
# Volcado de la base cargada (Etapa 3, Paso 3, punto 8)
# ---------------------------------------------------------------------------

def generar_dump_completo() -> str:
    """Ejecuta pg_dump de la base completa y la comprime a dump_completo.sql.gz.
    Devuelve la ruta del archivo generado."""
    salida = Path("dump_completo.sql.gz")
    env = dict(os.environ)
    # pg_dump necesita la contraseña sin prompt
    env["PGPASSWORD"] = env.get("POSTGRES_PASSWORD", env.get("OWNER_DB_PASSWORD", ""))
    cmd = [
        "pg_dump",
        "-h", env.get("DB_HOST", "localhost"),
        "-p", str(env.get("DB_PORT", "5432")),
        "-U", env.get("POSTGRES_USER", env.get("OWNER_DB_USER", "bodegas_owner")),
        "-d", env.get("POSTGRES_DB", "bodegas"),
        "--no-owner", "--no-privileges",
    ]
    print(f"  Generando volcado: {cmd[6]}@{cmd[2]}:{cmd[4]}/{cmd[8]} ...")
    with subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as proc:
        with gzip.open(salida, "wb") as gz:
            shutil.copyfileobj(proc.stdout, gz)
        _, err = proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError(f"pg_dump falló: {err.decode(errors='replace')}")
    print(f"  Volcado generado: {salida.resolve()} ({salida.stat().st_size / 1024:.1f} KB)")
    return str(salida)


if __name__ == "__main__":
    main()
