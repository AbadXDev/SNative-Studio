# Python para Apple Silicon

Esta nota no elige todavía una distribución y no instala nada.

## Intérprete

- Arquitectura arm64. El paquete previsto de SNative Studio es Apple Silicon.
- Sistema de destino macOS 14 o posterior, el mismo que declara la aplicación.
- No copiar `/usr/bin/python3`. Ese binario pertenece al sistema y su licencia no está preparada para redistribuirlo.
- La distribución tiene que traer su propio texto de licencia. Hasta que ese archivo exista, el intérprete sigue pendiente.
- Las ruedas ya revisadas son de CPython 3.9 (`cpython-39`). lz4 4.4.5 declara `Requires-Python >= 3.9`. Sirve un Python 3.9 de la misma ABI, o un Python más nuevo con ruedas nuevas cuyas licencias haya que volver a leer.

## Módulos de ejecución

- lz4 4.4.5, con `lz4-4.4.5-LICENSE`. La extensión nativa local es solo arm64.
- capstone: la rueda instalada es 5.0.9 y su licencia está copiada. Al importar el módulo, la versión que informa es 5.0.7. Hay que fijar una sola versión antes de empaquetar y repetir la lectura si cambia la rueda.
- fontTools 4.60.2, con su MIT. Hace falta para `make_ext_font.py`.

## Qué no incluir

- `LICENSE.external` y cualquier fuente de prueba Lobster, Noto, STIX o XITS. Están bajo SIL Open Font License 1.1 y no participan en la generación de la IPA.
- La rueda local de fontTools no contiene `.ttf` ni `.otf`. Un empaquetado posterior debe comprobarlo otra vez y excluirlos si aparecen.
