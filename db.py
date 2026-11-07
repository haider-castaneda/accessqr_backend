import re
import pymysql
import config


def conectar():
    return pymysql.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        database=config.DB_NAME,
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor,
    )

def llamar_procedimiento(nombre, args=()):
    if not re.fullmatch(r'sp_[a-z_]+', nombre):
        raise ValueError('Nombre de procedimiento no válido')
    conexion = None
    try:
        conexion = conectar()
        with conexion.cursor() as cursor:
            cursor.callproc(nombre, args)
            filas = list(cursor.fetchall())
            while cursor.nextset():
                pass
        conexion.commit()
        return filas
    except pymysql.MySQLError as error:
        if conexion:
            conexion.rollback()
        raise traducir_error(error)
    finally:
        if conexion:
            conexion.close()

VISTAS_PERMITIDAS = {
    'v_usuarios',
    'v_usuarios_pendientes',
    'v_usuarios_dentro',
    'v_administradores',
}


def consultar_vista(vista, filtros=None):
    if vista not in VISTAS_PERMITIDAS:
        raise ValueError('Vista no permitida')
    sql = f'SELECT * FROM {vista}'
    valores = []
    if filtros:
        condiciones = []
        for columna, valor in filtros.items():
            if not re.fullmatch(r'[a-z_]+', columna):
                raise ValueError('Columna no válida')
            condiciones.append(f'{columna} = %s')
            valores.append(valor)
        sql += ' WHERE ' + ' AND '.join(condiciones)
    conexion = None
    try:
        conexion = conectar()
        with conexion.cursor() as cursor:
            cursor.execute(sql, valores)
            return list(cursor.fetchall())
    except pymysql.MySQLError as error:
        raise traducir_error(error)
    finally:
        if conexion:
            conexion.close()

class ErrorBD(Exception):
    def __init__(self, mensaje, codigo=400):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo


def traducir_error(error):
    codigo = error.args[0] if error.args else 0
    mensaje = error.args[1] if len(error.args) > 1 else str(error)
    if codigo == 1644:
        return ErrorBD(mensaje, 400)
    if codigo == 1062:
        return ErrorBD('Ya existe un registro con esos datos', 409)
    if codigo in (1045, 2002, 2003, 1049):
        return ErrorBD('No se pudo conectar con la base de datos', 500)
    print('Error de base de datos:', codigo, mensaje)
    return ErrorBD('Error en la base de datos', 500)
