# SNative Studio

SNative Studio es una aplicación nativa de macOS, desarrollada con SwiftUI por AbadX. La versión 0.1.0 ofrece una interfaz para generar una IPA sin firmar en el propio Mac. La aplicación instalada usa el motor incluido en `Contents/Resources/Engine`. Un checkout de nxnative solo se usa si esa carpeta no existe.

No es una distribución oficial de nxnative. No está afiliada, patrocinada ni respaldada por Nintendo ni por quienes desarrollan nxnative. No incluye juegos, NSP ni `prod.keys`. El aviso completo está en `docs/AVISO-LEGAL.md`.

## Versión experimental

La publicación actual es una versión de pruebas, no una distribución general. El instalador adjunto al release de GitHub está **sin firma y sin notarización**. macOS puede advertir o impedir abrirlo. La firma y la notarización quedan aplazadas para una versión futura.

- El proyecto es independiente. No hay afiliación oficial con Nintendo ni con quienes desarrollan nxnative.
- No distribuye juegos, archivos NSP ni claves. El usuario solo debe usar contenido que esté autorizado a utilizar.
- Abrir la aplicación requiere macOS 14 o posterior.
- Generar una IPA está orientado a Apple Silicon. Ese flujo no se ha probado en un Mac Intel.
- No se garantiza compatibilidad con todos los Mac, juegos o versiones de las herramientas.

## Documentación

- `docs/REQUISITOS.md`: abrir la aplicación y generar una IPA.
- `docs/INSTALACION.md`: instalación, configuración y construcción.
- `docs/DEPENDENCIAS.md`: herramientas, versiones vistas y comprobación.
- `docs/EQUIPO-DE-PRUEBAS.md`: qué se ha ejecutado y qué no.
- `docs/SOLUCION-DE-PROBLEMAS.md`: fallos ya vistos.
- `docs/LICENCIAS-Y-CREDITOS.md`: atribuciones. El inventario de empaquetado sigue en `docs/dependencias-empaquetado.md`.

## Versión 0.1.0

La aplicación, en el código de esta versión:

- Guarda proyectos con la ruta del NSP base, la actualización si se indica, la ruta de `prod.keys`, la carpeta de salida y, si se escribe, el nombre de la IPA.
- No guarda el contenido de `prod.keys`.
- Usa el motor integrado en `Contents/Resources/Engine` cuando esa copia está completa. Un checkout externo solo se usa si esa carpeta no existe.
- Ejecuta `scripts/build_ipa_from_nsp.py` y muestra las fases, el registro y la cancelación.
- Comprueba herramientas y módulos en el equipo, sin instalarlos. Si falta uno obligatorio, Generar IPA permanece desactivado.
- Recuerda los proyectos en este Mac. Esa lista no forma parte del repositorio.

Generar una IPA, firmarla, instalarla y ejecutar el juego son cuatro pasos distintos. Esta versión solo hace el primero. No firma ni instala la IPA, no descarga juegos ni herramientas y no incluye archivos de juego.

El usuario debe disponer legítimamente de sus propios NSP y de su archivo `prod.keys`. Esos archivos no se publican con SNative Studio.

## Requisitos que declara el proyecto

- Destino de despliegue: macOS 14.
- Swift 6.
- Un Xcode capaz de abrir este proyecto. El proyecto no declara una versión mínima de Xcode.

Esta copia no se ha compilado en otro equipo. Abrir el proyecto aquí no demuestra que la compilación funcione en cualquier Mac.

## Construir la aplicación

1. Abre `SNative Studio.xcodeproj`.
2. Elige el esquema compartido «SNative Studio».
3. La configuración Debug sirve para ejecutar desde Xcode. Release es la que entra en un paquete local.

Desde la raíz del repositorio, las pruebas y Release usan carpetas de derivados fuera del proyecto:

```sh
xcodebuild test -project "SNative Studio.xcodeproj" -scheme "SNative Studio" -configuration Debug -destination "platform=macOS"
xcodebuild -project "SNative Studio.xcodeproj" -scheme "SNative Studio" -configuration Release -destination "platform=macOS" build
```

La fase de copia del motor corre en ambas configuraciones. `scripts/build_local_pkg.sh` deja un candidato local de Release sin firmar. No sustituye los paquetes de prueba anteriores y no está listo para distribución pública. La diferencia entre prueba local, candidato y paquete notarizado está en `docs/INSTALACION.md`.

## Generar una IPA desde la aplicación instalada

1. Abre SNative Studio y espera a que la pantalla Herramientas termine la comprobación.
2. Crea un proyecto con el NSP base, el `prod.keys` y una carpeta de salida escribible. La actualización es opcional.
3. Pulsa Generar IPA. Si la IPA prevista ya existe, la aplicación pide confirmación antes de sustituirla.

La aplicación lanza el script del motor con el NSP, `-k` para `prod.keys`, `-o` para la IPA y `--progress lines`. El directorio de trabajo es la copia escribible del motor, no el interior de `SNative Studio.app`. El registro de esa ejecución aparece en la pantalla Compilación y se puede copiar. No se guarda como archivo de la aplicación.

La IPA resultante no está firmada. Copiarla a un iPhone, confiar en un desarrollador o abrir el juego son pasos posteriores y no los hace SNative Studio.

## Dónde quedan los archivos

| Qué | Dónde |
|---|---|
| Proyectos de la aplicación | `~/Library/Application Support/com.abadx.SNativeStudio/projects.json` |
| Copia escribible del motor | `~/Library/Application Support/SNative Studio/engine-work/<identificador del proyecto>/source` |
| `obj` y `bin` de MSBuild | `.../engine-work/<identificador>/msbuild/obj` y `msbuild/bin` |
| Temporales del proceso y `DOTNET_CLI_HOME` | `.../engine-work/<identificador>/tmp` y `~/Library/Application Support/SNative Studio/dotnet-home` |
| Caché NuGet de la aplicación | `~/Library/Application Support/SNative Studio/nuget` |
| Juego extraído, sombreadores y registros del script | `<carpeta del NSP>/<identificador del título>_build/`, en `extract/`, `shader/` y `logs/` |
| IPA | La carpeta de salida del proyecto |

`Directory.Build.props` se escribe solo en la raíz de `source/` antes de que MSBuild evalúe `**/*.cs`. Añade `obj/**;bin/**` a `DefaultItemExcludes`. No desactiva la generación de atributos del ensamblado. Así `nx_extract` no vuelve a compilar dos veces los atributos y no escribe dentro del bundle.

Un checkout externo no se copia y no recibe ese archivo. El checkout original de nxnative no se modifica.

## Firma de desarrollo, instalación y ejecución

SNative Studio termina cuando el archivo IPA existe. Para instalarlo en un iPhone autorizado hace falta un paso aparte:

1. Extraer `Payload/*.app`.
2. Firmar esa copia con un certificado Apple Development y un perfil de aprovisionamiento que ya incluya el dispositivo. El archivo IPA original puede quedar sin firmar.
3. Instalar el `.app` firmado con las herramientas de Xcode, por ejemplo `xcrun devicectl device install app`.
4. Si iOS lo pide, confiar en el desarrollador en Ajustes.

Esa firma no es la de la aplicación de macOS ni una notarización. Ejecutar el juego es otro paso: abrirlo en el dispositivo. Los diagnósticos del juego, si los hay, quedan en `Documents/log.txt` de esa aplicación, no en el registro de SNative Studio.

En este Mac se generó una IPA de Super Mario Bros. Wonder, se firmó una copia temporal con un perfil de desarrollo ya existente y se instaló en un iPhone con modo de desarrollador. El juego llegó al menú y se jugaron dos mundos. Eso no demuestra un Mac limpio, una firma de distribución ni que el paquete público esté listo.

## Registros cuando falla la compilación

- La pantalla Compilación muestra la salida del script. El botón de copiar lleva ese texto al portapapeles. No hay un `log.txt` de SNative Studio.
- El script escribe cada paso en `<carpeta del NSP>/<identificador>_build/logs/`. El de `nx_extract` es `logs/nx_extract_build.log`.
- Si el error es de MSBuild, los archivos generados están en `msbuild/obj` de la copia de trabajo, no en `SNative Studio.app`.
- Si el juego ya instalado falla, el dato útil es `Documents/log.txt` dentro de la aplicación del dispositivo.

## Pruebas hechas y pendientes

En este equipo la suite terminó con 67 pruebas aprobadas y 0 fallos, y la configuración Release compiló. La última pasada repitió ese resultado. Una compilación aislada de `nx_extract`, con las mismas rutas que usa la aplicación, terminó con código 0 y sin el error de atributos duplicados. La generación, la firma de desarrollo y la partida local descritas arriba también se completaron.

Siguen sin hacerse: la restauración de LibHac sin red, una IPA en un Mac limpio, la firma Developer ID, la notarización y una instalación del paquete en otro equipo. El ejecutable Release de SNative Studio contiene `arm64` y `x86_64`. `dmsh_xlate` es solo `arm64`, y en este Mac las herramientas externas medidas también lo son. No se ha ejecutado el flujo en un Mac Intel, así que la primera distribución prevista es Apple Silicon. El detalle está en `docs/dependencias-empaquetado.md`.

## nxnative

La aplicación compilada incluye una copia del motor en `Contents/Resources/Engine`. nxnative sigue siendo un proyecto aparte, con su propia licencia MIT y con las licencias de sus componentes de terceros. El README de ese proyecto publica el repositorio `https://github.com/seedds/nxnative`.

Esa copia tiene que contener a la vez:

- `scripts/build_ipa_from_nsp.py`
- `dm/tools/nx_extract/Program.cs`
- `dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate`

Si `Contents/Resources/Engine` existe y le falta uno de esos tres archivos, la aplicación se detiene y no usa otro checkout. Si esa carpeta no existe, la búsqueda sube desde la ruta del código fuente usada al compilar, el paquete, el ejecutable, el directorio de trabajo y el primer argumento del proceso. No hay un ajuste de la interfaz para elegir otra carpeta. Un motor dentro de `.app/Contents/` se copia a Application Support antes de compilar, para no escribir en el bundle.

## Herramientas que comprueba, sin instalarlas

La pantalla de herramientas busca estos ejecutables: `xcodebuild`, `swift`, `brew`, `xcodegen`, `zstd`, `spirv-cross`, `dotnet` y `python3`.

Antes de lanzar el script, la compilación exige `python3`, `xcodebuild`, `xcodegen`, `dotnet` con SDK 10, `zstd`, `spirv-cross`, `zip` y `make`. También comprueba que Python pueda importar `lz4.block`, `capstone` y `fontTools`, y que exista el paquete local `libhac.0.19.0.nupkg` en `Engine/local-nuget` o en `~/.nuget/packages`. Si falta algo obligatorio, se detiene. No lo instala. Swift y Homebrew se muestran y no bloquean.

El inventario, las licencias pendientes y lo que falta para un instalador público están en `docs/dependencias-empaquetado.md` y en `SNative Studio/Resources/Notices/PENDIENTES.md`.

## Licencia

El archivo `LICENSE` es la licencia MIT, con copyright de AbadX en 2026. Cubre el código y los archivos propios de SNative Studio que AbadX tiene derecho a licenciar.

No cubre nxnative, sus herramientas ni los componentes de terceros que ese proyecto incorpora. Tampoco cubre los marcos de Apple ni los ejecutables externos que SNative Studio se limita a buscar en el equipo. Cada uno conserva sus propias condiciones. Los créditos están en `docs/LICENCIAS-Y-CREDITOS.md`. El texto de LibHac 0.19.0 sigue sin localizarse.

El canal público para una solicitud legítima de atribución, corrección o retirada es `https://github.com/AbadXDev/SNative-Studio`. No hay un correo privado confirmado.
