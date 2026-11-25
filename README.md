# AccessQR — Backend

API REST del sistema de control de ingreso y salida mediante códigos QR.
Proyecto formativo, ficha 3410645 — Centro de Biotecnología Agropecuaria, Mosquera.

> **Prototipo académico.** Se demuestra únicamente con datos ficticios. No está
> desplegado en producción ni instalado en una portería real.

---

## Qué hace

Expone 23 rutas que cubren el registro de usuarios, su revisión y aprobación, la
generación y reposición de códigos QR, el registro de entradas y salidas, la
gestión de visitantes y las consultas de historial y reportes.

La característica de diseño más importante es que **la aplicación nunca toca las
tablas directamente**: toda la lógica vive en procedimientos almacenados, y la
cuenta de base de datos que usa el backend solo tiene permiso para ejecutarlos y
para leer cuatro vistas.

## Tecnologías

| Herramienta | Versión | Para qué |
|---|---|---|
| Python | 3.14.5 | Lenguaje |
| Flask | 3.1.3 | Servidor web |
| flask-cors | 6.0.5 | Permitir el consumo desde el frontend |
| PyMySQL | 1.2.3 | Conexión con MariaDB |
| bcrypt | 5.0.0 | Hash de contraseñas |
| PyJWT | 2.15.1 | Tokens de sesión del personal |
| qrcode + Pillow | 8.2 / 13.0.0 | Imagen del código QR en base64 |
| python-dotenv | 1.2.4 | Variables de entorno |
| MariaDB | 10.4.32 | Base de datos (vía XAMPP) |

## Estructura

```
accessqr_backend/
├── app.py                 Crea la aplicación y registra los Blueprints
├── config.py              Lee el archivo .env
├── db.py                  Conexión, llamada a procedimientos y traducción de errores
├── seguridad.py           Hash de contraseñas, tokens JWT y control de rol
├── qr_util.py             Generación del token y de la imagen del QR
├── requirements.txt
├── .env.example
├── test_validaciones.py   Pruebas unitarias de las validaciones
├── database/
│   ├── accessqr.sql                   Esquema completo con datos de demostración
│   ├── usuarios_accessqr.example.sql  Plantilla de la cuenta de la aplicación
│   └── LEEME.txt
└── routes/
    ├── utilidades.py      Validación de los datos de entrada
    ├── auth.py            Inicio de sesión y verificación de sesión
    ├── publicas.py        Registro, consulta y reposición del QR
    ├── gestion.py         Revisar, aprobar, rechazar, reabrir y cambiar estado
    ├── acceso.py          Escaneo y visitantes
    ├── consultas.py       Indicadores, dentro, movimientos, historial y reportes
    └── administradores.py Cuentas de personal
```

---

## Instalación

Requisitos previos: Python 3.14 o superior, XAMPP con MariaDB, y Git.

### 1. Clonar e instalar dependencias

```bash
git clone https://github.com/haider-castaneda/accessqr_backend.git
cd accessqr_backend
python -m venv venv
```

Activar el entorno virtual:

```bash
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux o macOS
```

Debe verse `(venv)` al inicio de la línea. Luego:

```bash
pip install -r requirements.txt
```

### 2. Crear la base de datos

1. Encender **MySQL** desde el panel de XAMPP y abrir phpMyAdmin.
2. Crear una base de datos vacía llamada `accessqr`.
3. Entrar en esa base y, en la pestaña **Importar**, cargar `database/accessqr.sql`.
4. Copiar `database/usuarios_accessqr.example.sql` como `usuarios_accessqr.sql`,
   cambiar la contraseña de ejemplo por una propia, e importarlo desde la pestaña
   **Importar** a nivel de servidor (no dentro de la base).

El archivo `usuarios_accessqr.sql` está en `.gitignore` a propósito: contiene una
contraseña y no debe subirse al repositorio.

### 3. Configurar las variables de entorno

```bash
copy .env.example .env       # Windows
cp .env.example .env         # Linux o macOS
```

Editar `.env` y poner valores reales:

```
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=accessqr
DB_USER=accessqr_app
DB_PASSWORD=la_contraseña_que_pusiste_en_el_paso_2
JWT_SECRET=una_cadena_larga_y_aleatoria_propia
```

`JWT_SECRET` no puede quedar vacío: la aplicación se niega a arrancar sin él.
Para generar uno:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

El archivo `.env` nunca se sube al repositorio.

### 4. Arrancar

```bash
flask --app app run --debug
```

Queda escuchando en `http://127.0.0.1:5000`.

---

## Comprobar que funciona

`GET /api/salud` responde `{"estado": "ok"}`, pero **solo comprueba que Flask está
vivo**: no toca la base de datos. Para verificar la conexión real, hacer una
petición que consulte la base, por ejemplo iniciar sesión:

```
POST http://127.0.0.1:5000/api/login
Content-Type: application/json

{ "usuario": "1070998877", "contrasena": "Prueba2026" }
```

Debe responder 200 con un token. Si responde "No se pudo conectar con la base de
datos", revisar que MySQL esté encendido y que `DB_PASSWORD` coincida con la que
se puso al importar el archivo de cuentas.

## Pruebas unitarias

Comprueban las funciones de validación sin necesidad de base de datos ni servidor:

```bash
pip install pytest
python -m pytest -v
```

Necesitan que exista el archivo `.env`, porque `config.py` se carga al importar.

---

## Datos de demostración

El archivo `accessqr.sql` incluye **una sola cuenta ficticia** de administrador
para poder entrar la primera vez:

| Documento | Contraseña | Rol |
|---|---|---|
| 1070998877 | Prueba2026 | administrador |

Cámbiala antes de cualquier uso que no sea una demostración:

```bash
python -c "import seguridad; print(seguridad.cifrar_contrasena('TuClaveNueva'))"
```

y pegar el resultado en la columna `contrasena_hash` de esa fila.

Todos los datos que se usen para probar el sistema deben ser ficticios. El
proyecto declara en su documentación que no se utilizan datos personales reales
durante la demostración, en coherencia con la Ley 1581 de 2012.

## Seguridad

- Las contraseñas se guardan cifradas con bcrypt, nunca en texto plano.
- El token del código QR lo genera el servidor con `secrets.token_hex(16)`; las
  rutas devuelven la imagen del QR, nunca el token en texto.
- Cada petición protegida vuelve a comprobar contra la base de datos que la
  cuenta siga activa y conserve su rol, de modo que desactivar a alguien tiene
  efecto inmediato y no hay que esperar a que venza su sesión.
- La cuenta `accessqr_app` no puede leer ni modificar las tablas: solo ejecutar
  procedimientos y leer vistas.

## Autores

Edison Alejandro López Mojica y Haider Santiago Castañeda Contreras.
Ficha 3410645 — Tecnólogo en Análisis y Desarrollo de Software.
