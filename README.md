# SNative Studio

SNative Studio es una aplicación nativa de macOS, desarrollada con SwiftUI por AbadX. La versión 0.1.0 ofrece una interfaz para generar una IPA en el propio equipo usando un checkout local de nxnative.

No es una distribución oficial de nxnative. No está afiliada con Nintendo ni con quienes desarrollan nxnative.

## Versión 0.1.0

La aplicación, en el código de esta versión:

- Guarda proyectos con la ruta del NSP base, la actualización si se indica, la ruta de `prod.keys`, la carpeta de salida y, si se escribe, el nombre de la IPA.
- No guarda el contenido de `prod.keys`.
- Busca un checkout local de nxnative y ejecuta su script `scripts/build_ipa_from_nsp.py`.
- Muestra las fases y el registro, y permite cancelar la ejecución.
- Comprueba herramientas y módulos en el equipo, sin instalarlos.
- Recuerda los proyectos en este Mac. Esa lista no forma parte del repositorio.

Esta versión no firma ni instala la IPA. No descarga juegos ni herramientas y no incluye archivos de juego.

El usuario debe disponer legítimamente de sus propios NSP, de su archivo `prod.keys` y de un checkout de nxnative. Esos archivos no se publican con SNative Studio.

## Requisitos que declara el proyecto

- Destino de despliegue: macOS 14.
- Swift 6.
- Un Xcode capaz de abrir este proyecto. El proyecto no declara una versión mínima de Xcode.

Esta copia no se ha compilado en otro equipo. Abrir el proyecto aquí no demuestra que la compilación funcione en cualquier Mac.

## Abrir el proyecto

1. Abre `SNative Studio.xcodeproj`.
2. Elige el esquema compartido «SNative Studio».
3. Ejecuta la configuración Debug desde Xcode.

## nxnative

SNative Studio no contiene el código, los binarios ni las dependencias de nxnative. nxnative es un proyecto aparte, con su propia licencia MIT y con las licencias de sus componentes de terceros. El README de ese proyecto publica el repositorio `https://github.com/seedds/nxnative`.

Para generar una IPA, la aplicación busca un checkout que tenga a la vez:

- `scripts/build_ipa_from_nsp.py`
- `dm/tools/nx_extract/Program.cs`
- `dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate`

La búsqueda parte de la ruta del código fuente usada al compilar, del paquete de la aplicación, del ejecutable, del directorio de trabajo y del primer argumento del proceso, y sube por los directorios padre. No hay un ajuste de la interfaz para elegir otra carpeta.

## Herramientas que comprueba, sin instalarlas

La pantalla de herramientas busca estos ejecutables: `xcodebuild`, `swift`, `brew`, `xcodegen`, `zstd`, `spirv-cross`, `dotnet` y `python3`.

Antes de lanzar el script, la compilación exige `python3`, `xcodebuild`, `xcodegen`, `dotnet`, `zstd`, `spirv-cross`, `zip` y `make`. También comprueba que Python pueda importar `lz4.block`, `capstone` y `fontTools`. Si falta algo, se detiene. No lo instala.

## Licencia

El archivo `LICENSE` es la licencia MIT, con copyright de AbadX en 2026. Cubre el código y los archivos propios de SNative Studio que AbadX tiene derecho a licenciar.

No cubre nxnative, sus herramientas ni los componentes de terceros que ese proyecto incorpora. Tampoco cubre los marcos de Apple ni los ejecutables externos que SNative Studio se limita a buscar en el equipo. Cada uno conserva sus propias condiciones.
