# Dependencias para empaquetar SNative Studio

Los avisos cuyo texto y versión ya se pudieron comprobar están copiados en `SNative Studio/Resources/Notices/`. Lo que sigue sin texto de la versión exacta está en `Notices/PENDIENTES.md`. Este documento no sustituye esos archivos.

Xcode trata `SNative Studio` como carpeta sincronizada y copiaría cada `LICENSE` al mismo sitio de `Resources/`. Por eso `project.pbxproj` excluye del destino los archivos de `Resources/Notices/`. La fase `bundle_engine.sh` es la que los instala, conservando las carpetas. Un aviso nuevo tiene que añadirse a esa exclusión; si no, la compilación se detiene por dos comandos que producen el mismo archivo.

Documento de planificación. No copia binarios ni cambia el código. La licencia MIT de SNative Studio, copyright 2026 AbadX, cubre solo lo propio de esta aplicación. nxnative y cada componente de terceros conservan su copyright y su licencia.

La evidencia sale de archivos locales: el checkout de nxnative, las ruedas de Python ya instaladas, el SDK de .NET ya instalado, las fórmulas de Homebrew ya instaladas y los paquetes NuGet ya presentes en la caché. No se descargó nada para esta revisión.

Arquitectura medida en los binarios locales: Apple Silicon (`arm64`), salvo donde se indica otra cosa. No hay aquí un juego de binarios Intel listo para redistribuir.

## Qué interviene en una IPA

En ejecución, dentro del flujo de `scripts/build_ipa_from_nsp.py`:

- El código de nxnative, incluido `dm/third_party` que el host compila.
- Python, con `lz4`, `capstone` y `fontTools`.
- El SDK de .NET 10, para `dotnet build` de `nx_extract` y para ejecutar `dmsh_xlate`.
- LibHac 0.19.0, restaurado por ese `dotnet build`.
- XcodeGen, zstd, spirv-cross y el traductor `dmsh_xlate` con sus DLL.
- Xcode en el Mac del usuario: `xcodebuild`, el SDK de iOS, el compilador Metal y `make`.
- `zip`, del sistema.
- La fuente del sistema que el script copia desde `System/Library/Fonts/Supplemental/Arial Unicode.ttf`. No se redistribuye.

Solo en la pantalla de herramientas, y no en la generación: Swift y Homebrew.

No forman parte del paquete: NSP, `prod.keys`, IPA y el directorio generado `dm/ios/Gen`.

## Inventario

| Componente | Versión local | Papel | Licencia y aviso que hay que llevar | Arquitectura | Estado |
|---|---|---|---|---|---|
| SNative Studio | 0.1.0 | Aplicación | MIT, copyright 2026 AbadX, archivo `LICENSE` | La del proyecto, destino macOS 14 | Verificado para el código propio |
| nxnative | El checkout local; `LICENSE` con copyright 2026 jhaizhou | Motor | Texto MIT completo de ese `LICENSE`, sin sustituirlo por el de AbadX | Código fuente | Verificado |
| libvpx | v1.17.0, según `dm/third_party/README.md` | Decodifica VP9 al compilar el host | `libvpx/LICENSE` (BSD de 3 cláusulas, copyright 2010 The WebM Project authors) y `libvpx/PATENTS` | Fuentes | Verificado |
| libdeflate | Commit indicado en el README de terceros | Descompresión en el host | `libdeflate/COPYING` (MIT; copyright 2016 Eric Biggers y 2024 Google LLC) | Fuentes | Verificado |
| stb_vorbis | 1.22, según el README de terceros | Audio Vorbis | `stb_vorbis/LICENSE`: MIT, copyright 2017 Sean Barrett, o la alternativa de dominio público del mismo archivo. Hay que conservar el texto que permite elegir | Fuentes | Verificado |
| Cabeceras Vulkan | 1.4.363, según el README de terceros | Vulkan sobre Metal | `vulkan-headers/LICENSE.md`: Apache-2.0 o MIT, copyright 2015-2026 The Khronos Group Inc. | Fuentes | Verificado |
| Ryujinx, Ryujinx.Common, Ryujinx.Graphics.Shader | 1.3.2 en el README; ensamblados `1.0.0` en `dmsh_xlate.deps.json` | Traducción de sombreadores | `ryujinx/LICENSE.txt` (MIT, copyright Ryujinx Team and Contributors) | Fuentes y DLL arm64 del traductor | Verificado el texto del repositorio |
| Spv.Generator | En el árbol de Ryujinx; `1.0.0` en el deps | Generación SPIR-V | `ryujinx/src/Spv.Generator/LICENSE` (permiso tipo MIT; el archivo no trae una línea de copyright propia) | Fuentes y DLL | Verificado el texto; el copyright concreto de ese subproyecto queda en ese archivo |
| nvn.h | Cabecera del árbol | NVN | MIT en el propio encabezado, copyright 2020 h1k421 | Fuente | Verificado |
| Adaptaciones MacNativeGames | Según el README de terceros | Fragmentos en el host y en el traductor | `macnativegames/LICENSE` (MIT, copyright 2026 MacNativeGames contributors) | Fuentes | Verificado |
| Algoritmo deko3d en `nvn_tex.c` | Portado, no el árbol completo | Tamaño de texturas | `Notices/deko3d/LICENSE`: zlib, copyright 2018-2020 fincs. Archivo leído en `https://github.com/devkitPro/deko3d/blob/4c3cf370ce0ed7efae182da381cf900e16be27af/LICENSE`. El comentario del port ya lo marca como versión alterada. No se ha fijado el commit de `dk_image.cpp` del que salió el algoritmo | Fuente | Texto verificado. El aviso debe viajar con el motor |
| FLIP | No registrado en el directorio | Solo verificación de imagen, no la IPA | `flip/LICENSE` (BSD de 3 cláusulas, copyright 2020-2025 NVIDIA CORPORATION & AFFILIATES) | Fuentes | Verificado, y no hace falta empaquetarlo para generar una IPA |
| Python | Intérprete del sistema 3.9.6 | Ejecuta el script | No hay en el equipo una distribución oficial de Python con su texto de licencia listo para redistribuir. El intérprete del sistema no se copia | Binario universal del sistema | Pendiente. Hace falta una compilación redistribuible y su licencia |
| lz4 | Rueda 4.4.5 | Módulo `lz4.block` | `lz4-4.4.5.dist-info/licenses/LICENSE`: BSD de 3 cláusulas, copyright 2012-2013 Steeve Morin. Los metadatos nombran a Jonathan Underwood como autor del paquete; ese nombre no aparece en el texto de licencia | Extensiones nativas arm64 | Verificado el texto de la rueda. La extensión nativa es solo arm64 |
| capstone | Metadatos de la rueda 5.0.9; el módulo importado informa 5.0.7 | Desensamblado | `capstone-5.0.9.dist-info/LICENSE.TXT`: BSD de 3 cláusulas, copyright 2013 COSEINC. Hay que conservar el aviso y no usar los nombres para promocionar el producto | Biblioteca arm64 | Verificado el texto de la rueda 5.0.9. La diferencia de versión queda pendiente de fijar la rueda que se empaquete |
| fontTools | 4.60.2 | Fuentes del icono de botones | `fonttools-4.60.2.dist-info/licenses/LICENSE`: MIT, copyright 2017 Just van Rossum | Extensiones universales x86_64 y arm64, más Python | Verificado el MIT de la biblioteca |
| Fuentes de prueba de fontTools | Las que lista `LICENSE.external` | No las usa la generación | SIL Open Font License 1.1, con nombres reservados (Lobster, Noto, STIX, XITS) | — | No redistribuir esas fuentes. El empaquetado debe excluirlas |
| SDK de .NET | 10.0.402 | Compila `nx_extract` y carga el traductor | `LICENSE.txt` del SDK: MIT, copyright .NET Foundation and Contributors. También está `ThirdPartyNotices.txt` (1451 líneas). Hay que copiarlo entero | `dotnet` arm64 | Verificado el MIT y la existencia del archivo de avisos. Cada aviso interno no se ha vuelto a leer línea por línea |
| LibHac | 0.19.0, commit citado en el nuspec `cd4004af194a51712812c680f0a028ba9152c0f8` | Lee NSP dentro de `nx_extract` | El nuspec declara `license` MIT y copyright 2018-2022 Alex Barney. El nupkg no contiene un archivo de licencia | Paquete en caché; arquitectura no medida | Pendiente el texto MIT completo. La expresión del nuspec no basta para acompañar la distribución |
| Gommon | 2.8.1.2, commit del nuspec `222084874ac473e02f27faeb10e540f926702976` | DLL del traductor | `Notices/gommon-2.8.1.2/LICENSE`: MIT, copyright 2019- Evan Husted. El `content/LICENSE` del nupkg 2.8.1.2 tiene el mismo texto; solo cambian los retornos de carro. Repositorio `https://github.com/GreemDev/Gommon` | DLL IL junto al traductor | Verificado para 2.8.1.2 |
| Humanizer.Core | 3.0.10, commit del nuspec `90f0cb1d7427635f38b46350bb1dc5fca2164f2d`, tag `v3.0.10` | DLL y recursos de idioma | `Notices/humanizer-core-3.0.10/license.txt`. MIT de .NET Foundation and Contributors, más los avisos MIT de Inflector y ByteSize que van en el mismo archivo. El nupkg no incluye ese archivo. `https://github.com/Humanizr/Humanizer/blob/v3.0.10/license.txt` | DLL IL junto al traductor | Verificado. Hay que copiar el archivo entero, incluidos los dos avisos adicionales |
| MsgPack.Cli | 1.0.1, tag del repositorio `1.0.1` | DLL del traductor | `Notices/msgpack-cli-1.0.1/LICENSE.txt`: Apache-2.0 completo. En ese tag no hay `NOTICE` ni `NOTICE.txt`. El nuspec conserva `Copyright 2010-2016 FUJIWARA, Yusuke`. El nupkg no trae la licencia. `https://github.com/msgpack/msgpack-cli/blob/1.0.1/LICENSE.txt` | DLL IL junto al traductor | Verificado. Hay que llevar el texto Apache-2.0 y el aviso de copyright del nuspec |
| Microsoft.IO.RecyclableMemoryStream | 3.0.1, commit del nuspec `e29a28387da9018fa9605a1dcb3f7a0435aa9974`, tag `v3.0.1` | DLL del traductor | `Notices/recyclablememorystream-3.0.1/LICENSE`: MIT, copyright 2015-2016 Microsoft. El tag y el commit tienen el mismo archivo. No hay `NOTICE`. El nupkg no trae el texto. `https://github.com/microsoft/Microsoft.IO.RecyclableMemoryStream/blob/v3.0.1/LICENSE` | DLL IL junto al traductor | Verificado |
| System.CodeDom | 4.4.0, igual en el deps y en la caché | DLL del traductor | El nupkg contiene `LICENSE.TXT` (MIT, copyright .NET Foundation and Contributors) y `THIRD-PARTY-NOTICES.TXT` | DLL junto al traductor | Verificado que esos dos archivos están en el paquete. Hay que copiar ambos |
| dmsh_xlate | Ejecutable arm64; runtime `net10.0` | Traduce sombreadores | El programa forma parte de nxnative. Sus DLL de terceros van con las filas de arriba | arm64 | El ejecutable se puede incluir con el MIT de nxnative. Las DLL siguen las filas correspondientes |
| XcodeGen | 2.46.0 | Genera el proyecto de la IPA | `LICENSE` de la fórmula: MIT, copyright 2018 Yonas Kolb | arm64 | Verificado |
| zstd | 1.5.7 | Descomprime recursos | `LICENSE` de la fórmula: BSD, copyright Meta Platforms, Inc. and affiliates. También hay `COPYING`, GPL-2. Para redistribuir el binario se usa el texto BSD y se conserva su aviso. No se elige la GPL | arm64 | Verificado el texto BSD y la existencia de la GPL alternativa |
| spirv-cross | 1.4.363.0 | Traduce SPIR-V a MSL | `LICENSE` de la fórmula: Apache-2.0. No hay un archivo `NOTICE` en esa fórmula. El apéndice del texto trae el marcador genérico de copyright, no un titular concreto | arm64 | Verificado el texto Apache-2.0. Falta un NOTICE solo si la versión original lo tenía y no viajó en la fórmula; eso no se ha comprobado fuera de la fórmula instalada |
| Xcode, `xcodebuild`, SDK de iOS, Metal, `make` | Xcode 27.1 en este equipo | Compilan la IPA y el host | No se ha abierto el contrato de licencia de Xcode | Los binarios de `xcodebuild` y `make` del sistema son universales | No se copian. La cita legal que lo prohíbe queda pendiente de leer ese contrato |
| `zip` | Herramienta del sistema | Empaqueta la IPA | No se ha leído una licencia aparte | Universal | No hace falta redistribuirlo |
| Swift y Homebrew | Aparecen en la pantalla de herramientas | No generan la IPA | — | — | No empaquetar |
| Arial Unicode | Ruta fija del sistema en `build_ipa.sh` | El script la copia al construir la IPA | No se ha leído una licencia de esa fuente | Fuente del Mac del usuario | No redistribuir |

`dotnet build` de `dm/tools/nx_extract/nx_extract.csproj` referencia LibHac 0.19.0. En el checkout no hay `nuget.config` ni `packages.lock.json`. Sin un origen local, la restauración puede salir a la red. El paquete futuro tiene que llevar el nupkg y un `NuGet.config` que apunte solo a esa carpeta.

## Avisos que todavía hay que obtener

- El archivo de licencia de LibHac 0.19.0 en el commit `cd4004af194a51712812c680f0a028ba9152c0f8`. El nupkg no lo contiene. El nuspec y el catálogo de NuGet declaran la expresión MIT y el copyright 2018-2022 Alex Barney, con la URL genérica `https://licenses.nuget.org/MIT`. El repositorio ya no sirve ese commit. El detalle de las fuentes está en `Notices/PENDIENTES.md`. LibHac no viaja dentro de la aplicación: se restaura al compilar.
- Licencia de la distribución de Python que se elija, si algún día se incluye el intérprete. Hoy no va en la aplicación. La rueda de capstone sigue con metadatos 5.0.9 y módulo 5.0.7.
- Copia íntegra de `ThirdPartyNotices.txt` del SDK y de `THIRD-PARTY-NOTICES.TXT` de System.CodeDom, sin resumirlos, solo si esos componentes se redistribuyen. El SDK no va en la aplicación. System.CodeDom sí viaja con el traductor y sus dos textos ya están en `Notices/system-codedom-4.4.0/`.
- Un NOTICE de spirv-cross 1.4.363.0, solo si más adelante se empaqueta el binario y el tag original lo publica. La fórmula instalada no lo tiene. El binario no está en la aplicación, así que los textos MIT alternativos de las cabeceras no son una obligación del paquete actual.

## Redistribución no confirmada

- Intérprete de Python del sistema.
- LibHac, mientras no aparezca el archivo de licencia del commit 0.19.0.
- Fuentes de prueba SIL de fontTools.
- Arial Unicode y cualquier otro archivo del sistema.
- Xcode, el SDK de iOS, Metal y `make`.
- NSP, claves, IPA y `dm/ios/Gen`.
- Binarios Intel de .NET, XcodeGen, zstd, spirv-cross, dmsh_xlate, lz4 y capstone: no están en este equipo.

## Auditoría del flujo real

La generación entra por `scripts/build_ipa_from_nsp.py`. Ese archivo, no la pantalla, fija los requisitos:

| Componente | Obligatorio | Dónde se usa | Detección | Compatibilidad |
|---|---|---|---|---|
| Motor en `Contents/Resources/Engine` | Sí | Directorio de trabajo del proceso | Los tres archivos de `EngineLocator`. Incompleto: error, sin otro checkout | La copia del bundle |
| Python 3 | Sí | Intérprete del script y de las herramientas `.py` | `python3` | El script no fija un mínimo. lz4 4.4.5 pide 3.9 o posterior |
| lz4, capstone, fontTools | Sí | `check_prereqs` importa `lz4.block`, `capstone` y `fontTools` | Importación con ese Python | Las ruedas ya leídas |
| .NET SDK 10 | Sí | `dotnet build` de `dm/tools/nx_extract` | `dotnet --version`. Si hay varios, se elige el primero cuyo número mayor es 10 | `nx_extract.csproj` pide `net10.0`. `dmsh_xlate.runtimeconfig.json` pide `net10.0` |
| LibHac 0.19.0 | Sí | Única `PackageReference` de `nx_extract.csproj` | Archivo `libhac.0.19.0.nupkg` en `Engine/local-nuget` o en la caché del usuario | No se ha ejecutado `dotnet restore`. Una caché vacía no se ha probado |
| Xcode y `xcodebuild` | Sí | `check_prereqs` y `dm/ios/tools/build_ipa.sh` | Ejecutable `xcodebuild`, no el nombre de una aplicación | El script no fija un número de Xcode |
| SDK de iOS y Metal | Sí | `xcrun -sdk iphoneos metal` y `metallib` en `dm/ios/tools/ios_metal.py` | `xcrun --sdk iphoneos --show-sdk-path` y `xcrun --find metal` | El comando de compilación lleva `-mios-version-min=18.0`. El README de nxnative pide iOS 26 en el dispositivo. No se ha generado una IPA para contrastarlo |
| `xcrun` | Sí | Invocado por la cadena Metal | `/usr/bin` u otra ruta de la lista | Forma parte de Xcode |
| XcodeGen | Sí | `xcodegen generate` en `build_ipa.sh` | Ejecutable | Sin mínimo en el script |
| zstd | Sí | `check_prereqs` y `shader_split.py` (`zstd -d`) | Ejecutable | Sin mínimo. Los diccionarios de algunos juegos importan `compression.zstd`, de Python 3.14; eso no se exige para el resto |
| spirv-cross | Sí | `dmsh_build.py` y `vk_shaders.py` | Ejecutable | `--version` no imprime una versión usable |
| dmsh_xlate | Sí | `XLATE` en `dmsh_build.py`. Las DLL van junto al ejecutable | El ejecutable dentro del motor | Runtime `net10.0`. No se ha vuelto a ejecutar en esta fase |
| make | Sí | `make` del host en `build_ipa_from_nsp.py` | Ejecutable | El script lo asocia a Xcode |
| zip | Sí | `zip` en `build_ipa.sh` | Ejecutable | Herramienta de macOS |
| Swift, Homebrew | No | No los llama `check_prereqs` | Ejecutable | Su ausencia no bloquea |

El orden de búsqueda es `Contents/Resources/Tools`, después `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `~/.dotnet` y `/usr/local/share/dotnet`, y al final los demás directorios que ya estén en el `PATH` del proceso. Homebrew no es obligatorio. Una instalación solo se acepta si el ejecutable existe; una aplicación llamada Xcode no basta.

## PATH de la copia distribuible

El checkout original hace esto y no se modifica:

```python
TOOL_PATHS = ['/opt/homebrew/bin', '/usr/local/bin', '/usr/local/share/dotnet', os.path.expanduser('~/.dotnet')]
PATH = TOOL_PATHS + PATH_actual
```

`shutil.which` se detiene en el primer ejecutable. Por eso una herramienta de `Contents/Resources/Tools` perdería frente a un binario ya presente en Homebrew o en `~/.dotnet`.

`scripts/prepare_distributable_script.py` aplica el arreglo solo a la copia que `bundle_engine.sh` acaba de escribir. Exige el shebang, las dos líneas anteriores una sola vez y finales de línea Unix. Si el texto no coincide, no escribe. Si la raíz de esa copia contiene `.git`, tampoco escribe: el checkout queda fuera. Cada compilación vuelve a copiar el script original y repite el arreglo.

La copia antepone los directorios de `SNATIVE_TOOL_PATH` a `TOOL_PATHS` y después conserva el `PATH` del proceso. Así siguen encontrándose `xcodebuild`, `xcrun`, `make` y `zip`. La variable no existe para un checkout externo. El `PATH` de la sesión del usuario no cambia y no se tocan el resto de variables.

Si un directorio antepuesto contiene un `dotnet` cuya cifra mayor no es 10 y más adelante hay un SDK 10, ese directorio pasa a quedar justo detrás del SDK 10. Sus otras herramientas siguen en el camino de búsqueda. Si `SNATIVE_TOOL_PATH` está vacía, la copia no consulta `dotnet --version` y se comporta como el original.

## Herramientas empaquetadas

`Contents/Resources/Tools/` queda reservada. Esta fase no copia binarios.

Cuando una herramienta compatible esté ahí, el orden es:

1. `Tools/bin`, `Tools/python/bin`, `Tools/dotnet` y `Tools`.
2. Las ubicaciones habituales y el resto del `PATH` del proceso.
3. Si no aparece, la pantalla Herramientas muestra la instrucción. No instala nada.

Solo entran en `SNATIVE_TOOL_PATH` las herramientas que el diagnóstico ya aceptó y que viven dentro de `Tools`, y solo cuando el motor resuelto es el de `Contents/Resources/Engine`. Una herramienta del sistema que haya ganado por versión, como un SDK 10 frente a un `dotnet` empaquetado incompatible, no se sustituye. Xcode y el SDK de iOS siguen resolviéndose en el Mac del usuario.

## Copia escribible del motor

Cuando el motor resuelto está dentro de `.app/Contents/`, `EngineWorkCopy` lo copia a `~/Library/Application Support/SNative Studio/engine-work/<identificador del proyecto>/source` antes de lanzar el script. Un sello con la ruta de origen y el tamaño y la fecha del script reutiliza esa copia. El checkout externo no se copia.

En cada preparación, también si el sello coincide, la copia recibe `Directory.Build.props` en su raíz. MSBuild importa ese archivo antes de evaluar los elementos. El archivo añade `obj/**;bin/**` a `DefaultItemExcludes` y no desactiva `GenerateAssemblyInfo` ni `GenerateTargetFrameworkAttribute`. Además se eliminan, solo dentro de la copia, `dm/tools/nx_extract/obj` y `dm/tools/nx_extract/bin`.

El proceso recibe, solo para esa ejecución, `NUGET_PACKAGES`, `TMPDIR`, `TEMP`, `TMP`, `DOTNET_CLI_HOME`, `BaseIntermediateOutputPath`, `MSBuildProjectExtensionsPath` y `BaseOutputPath`. Esas rutas están bajo `~/Library/Application Support/SNative Studio/` y no bajo `SNative Studio.app`. `make` y `xcodebuild` escriben en la copia porque el script descubre el motor desde su propio archivo.

## NuGet en la copia distribuible

No se ha ejecutado `dotnet restore` para vaciar la caché, no se ha copiado `libhac.0.19.0.nupkg` y no hay `NuGet.config` en la copia. La compilación sin conexión no está verificada.

El diagnóstico acepta el nupkg de `Engine/local-nuget` o el de `~/.nuget/packages/libhac/0.19.0/`. La ejecución, en cambio, pone `NUGET_PACKAGES` en `~/Library/Application Support/SNative Studio/nuget`. Esa carpeta puede estar vacía aunque el diagnóstico haya visto la caché de `~/.nuget`. En ese caso `dotnet build` puede intentar la red. Una compilación aislada de `nx_extract` que apuntó `NUGET_PACKAGES` a la caché ya llena terminó con código 0; al no poder leer el índice de vulnerabilidades de NuGet apareció el aviso `NU1900`, sin impedir la compilación. Eso no prueba el modo sin conexión de la aplicación.

`nx_extract.csproj` pide LibHac 0.19.0 y el checkout no tiene `nuget.config`. Cuando una fase posterior incluya el paquete, la preparación sería solo en la copia del motor:

- `Engine/local-nuget/libhac.0.19.0.nupkg`.
- Un `NuGet.config` de esa copia, con los orígenes remotos desactivados y un único origen en `local-nuget`. No se crea ahora y no se escribe en el checkout.
- `NUGET_PACKAGES` en una carpeta escribible del usuario, fuera de la aplicación, porque el bundle puede no admitir escritura.
- Si el nupkg no está ni en esa carpeta ni en la caché del usuario, el diagnóstico bloquea la compilación antes de lanzar el script. No se inicia una restauración para descubrirlo.

## Diagnóstico en la aplicación

La pantalla Herramientas clasifica cada requisito y no instala nada. Un componente solo aparece como «Incluida en SNative Studio» cuando el archivo está dentro de `Contents/Resources/Tools` o el motor resuelto es el de `Contents/Resources/Engine`. La aplicación compilada por este proyecto incluye el motor en `Contents/Resources/Engine`. `Contents/Resources/Tools` sigue vacío: Python, .NET y el resto de herramientas externas no se han empaquetado.

| Requisito | Clasificación | Qué se detecta | Si falta |
|---|---|---|---|
| nxnative | Obligatoria | Los tres archivos que ya usa `EngineLocator`: el script, `Program.cs` y `dmsh_xlate`. Una carpeta `Engine` incompleta no cae a otro checkout | Texto manual. No hay descarga ni comando |
| Python 3 | Obligatoria | Ejecutable `python3` | Instrucciones. No se ha elegido distribución, así que no hay comando ni página añadida |
| lz4, capstone, fontTools | Obligatoria | Importación con el `python3` detectado | `python3 -m pip install lz4 capstone fonttools`, el comando del README de nxnative, solo si `python3` ya está. Si no está, el comando no se ofrece |
| Xcode, `xcodebuild` | Obligatoria | Ejecutable | Instalación manual y la ficha https://apps.apple.com/app/xcode/id497799835, enlazada desde el README de nxnative |
| SDK de iOS | Obligatoria | `xcrun --sdk iphoneos --show-sdk-path` | Misma ficha de Xcode. No se descarga el SDK |
| Metal | Obligatoria | `xcrun --find metal` | Misma ficha de Xcode |
| make | Obligatoria | Ejecutable. El script lo asocia a Xcode | Misma ficha de Xcode |
| XcodeGen, zstd, spirv-cross | Obligatoria | Ejecutable. spirv-cross no imprime versión; si el binario está en el Cellar de Homebrew, se muestra ese número | `brew install xcodegen`, `brew install zstd` o `brew install spirv-cross` solo cuando Homebrew está detectado. Si no lo está, se explica y no se copia el comando |
| .NET | Obligatoria. El script pide el SDK 10 | `dotnet --version`. Una versión cuya cifra mayor no es 10 queda como incompatible | `brew install --cask dotnet-sdk`, del README, solo con Homebrew detectado. El comando no fija la versión 10 y no se ha comprobado qué instala el cask |
| zip | Obligatoria | Ejecutable | Instrucciones. Es la herramienta de macOS; no hay comando de instalación en el README |
| Swift | Opcional | Ejecutable | No impide generar la IPA |
| Homebrew | Opcional | Ejecutable | Página https://brew.sh. No se copia un instalador |

«Volver a comprobar» repite la detección. La comprobación en vivo corre fuera de la interfaz. Los botones copian un comando al portapapeles o abren una página; no lanzan Terminal, no usan `sudo` y no instalan paquetes.

Al abrir la aplicación, el diagnóstico corre fuera de la interfaz. Generar IPA queda desactivado mientras esa comprobación no ha terminado y mientras falte un requisito obligatorio: el motor, Python 3 y sus módulos, Xcode, el SDK de iOS, Metal, make, XcodeGen, .NET SDK 10, LibHac 0.19.0, zstd, spirv-cross o zip. No se lanza `dotnet restore` para descubrirlo. Swift y Homebrew no bloquean. El plan de compilación sigue rechazando, además, la ausencia de `python3`, `xcodebuild`, `xcodegen`, `dotnet`, `zstd`, `spirv-cross`, `zip`, `make` o de los módulos.

## Instalador local de prueba

El paquete instala solo `SNative Studio.app` en `/Applications`. Dentro van la aplicación Release, el motor en `Contents/Resources/Engine` y los avisos en `Contents/Resources/Notices`, con sus carpetas. No van `.git`, `dm/ios/Gen`, NSP, IPA, `prod.keys`, Python, el SDK de .NET, XcodeGen, zstd, spirv-cross, Homebrew ni `Contents/Resources/Tools`.

`scripts/build_local_pkg.sh` hace, por este orden:

1. Compila el esquema en Release. La fase de Xcode ya ejecuta `bundle_engine.sh`.
2. Vuelve a ejecutar `bundle_engine.sh` sobre los recursos de esa aplicación.
3. Comprueba el motor, `dmsh_xlate` y sus DLL, los avisos anidados y la preparación de `SNATIVE_TOOL_PATH`.
4. Rechaza claves, juegos, herramientas externas y licencias aplanadas.
5. Genera con `pkgbuild` un paquete sin scripts en `/tmp/SNativeStudio-Local-Package/`. El identificador del candidato es `com.abadx.SNativeStudio.local-candidate` y el nombre por defecto es `SNative-Studio-0.1.0-release-candidate-unsigned.pkg`. Si ese archivo ya existe, el script se detiene. No sustituye los paquetes `local-test` anteriores.
6. Si `PackageInfo` ha registrado `Engine/dm/ios/Sources` como bundle, quita esa entrada y vuelve a empaquetar. El archivo `Info.plist` sigue en la carga: lo necesita la generación de la IPA. Después comprueba el destino `/Applications`, la ausencia de scripts y que la carga contiene el motor y los avisos.

El script no llama a `installer`, no escribe en `/Applications`, `/usr/local` ni `~/.dotnet`, y no cambia el `PATH`. Copiar la aplicación a `/Applications` pedirá administrador cuando alguien lo instale, porque esa carpeta está protegida. El paquete no ejecuta ningún comando de instalación de herramientas.

La configuración Release tiene `CODE_SIGNING_ALLOWED = NO`, `CODE_SIGN_IDENTITY` vacío, `DEVELOPMENT_TEAM` vacío, sandbox desactivado y hardened runtime desactivado. No se ha cambiado. El binario Release queda con la firma ad hoc que añade el enlazador: no tiene equipo, no sella los recursos y no es Developer ID. En este Mac hay dos identidades Apple Development y una Apple Distribution. No hay Developer ID Application ni Developer ID Installer. Apple Distribution no sustituye a Developer ID Installer. No se ha firmado ni se ha enviado nada a notarización.

La copia del motor excluye `obj/`, `bin/`, `dm/host/gen/`, `dm/ios/DmIOS.xcodeproj/`, `dm/ios/Gen/` y `xcuserdata/`. Esos directorios pueden existir en el checkout de desarrollo y contienen cachés; `nx_extract/obj` de este Mac incluye rutas absolutas del equipo. El checkout no se borra ni se modifica. `dm/ios/Sources/Info.plist` sí viaja, porque el proyecto de la IPA lo usa. El candidato local quita del `PackageInfo` el registro de esa carpeta como bundle anidado, sin borrar el archivo. El ejecutable Release es universal, `x86_64` y `arm64`; no se ha fijado una sola arquitectura.

Un instalador público necesitaría, además de cerrar las licencias pendientes:

1. Firmar `SNative Studio.app` con un certificado Developer ID Application. En este Mac no hay esa identidad. Las identidades Apple Development y Apple Distribution que sí hay no sirven para un paquete público de macOS.
2. Activar hardened runtime y sellar los recursos. Release sigue con `CODE_SIGNING_ALLOWED = NO` y la firma ad hoc del enlazador.
3. Firmar el `.pkg` con Developer ID Installer. Apple Distribution no lo sustituye.
4. Enviar el paquete con `notarytool` y grapar el ticket con `stapler`. No se ha hecho.
5. Comprobar en un Mac limpio que el instalador no trata `Engine/dm/ios/Sources` como otra aplicación. El candidato local ya no deja esa carpeta registrada en `PackageInfo`, y el `Info.plist` sigue dentro del motor. Esa comprobación de instalación no se ha hecho.
6. Probar en un Mac limpio, sin el checkout de desarrollo y sin las herramientas ya instaladas en este equipo: que la aplicación arranque, que Herramientas marque ausente lo que falte, que Generar IPA no se active, y que con las herramientas externas instaladas la copia de trabajo quede fuera del bundle.

El paquete local no está listo para distribución pública. Quedan avisos sin texto de la versión exacta, no está firmado ni notarizado, y no se ha probado en un Mac limpio. En este equipo el diagnóstico encuentra las herramientas del sistema; eso no demuestra que un Mac sin ellas pueda generar una IPA.

## Arquitecturas

Medido en este Mac Apple Silicon, sin Rosetta. No se ha arrancado el flujo en hardware Intel. Un binario universal de la interfaz no vuelve universal al motor.

| Componente | Qué se midió | Clasificación |
|---|---|---|
| SNative Studio Release | `lipo` muestra `x86_64` y `arm64`. El proyecto no fija `ARCHS`; Release hereda `arm64 x86_64` y `ONLY_ACTIVE_ARCH = NO`. Destino macOS 14. Debug usa `ONLY_ACTIVE_ARCH = YES` | Compatible según la configuración. El corte `x86_64` no se ha ejecutado |
| Código Swift, C y Metal de la aplicación | Se compilan con el SDK de macOS del Xcode local | La aplicación resultante es el binario de arriba. No se ha probado en Intel |
| `dmsh_xlate` | Mach-O `arm64`. Viaja dentro del motor | Requiere una variante Intel para un Mac Intel. No existe en este árbol |
| DLL del traductor | Ensamblados IL: Gommon, Humanizer, MsgPack, RecyclableMemoryStream, System.CodeDom, Ryujinx y Spv.Generator | El IL no fija la CPU. Hace falta un `dotnet` de la arquitectura del Mac para cargarlo. No se ha probado con un runtime Intel |
| `nx_extract` | El proyecto es C# `net10.0`. `EngineWorkCopy` solo elige rutas | La compilación produce IL. Se probó en este Mac con el SDK `arm64`. No se ha compilado con un SDK Intel |
| .NET SDK 10.0.402 local | `~/.dotnet/dotnet` es `arm64` | Hace falta el SDK de cada arquitectura. El de Intel no está en este equipo |
| Python del sistema 3.9.6 | `lipo` muestra `x86_64`, `arm64e` y `arm64e.x1` | El intérprete del sistema trae corte Intel. No se ha ejecutado en un Mac Intel y no se redistribuye |
| lz4 4.4.5 y capstone | Extensiones nativas `arm64` | Requieren una rueda de la arquitectura del Mac. Las de este equipo no sirven en Intel |
| fontTools 4.60.2 | Extensiones universales `x86_64` y `arm64` | Compatible según el binario. No se ha importado bajo Intel |
| XcodeGen 2.46.0, zstd 1.5.7, spirv-cross 1.4.363.0 | En `/opt/homebrew/bin`, los tres `arm64` | Cada uno necesita el binario de su arquitectura. No van dentro de la aplicación |
| Xcode 27.1 y `xcodebuild` | `xcodebuild` de este Xcode es `arm64`. Cruzó `x86_64` al enlazar SNative Studio | Puede generar el corte Intel de la interfaz desde Apple Silicon. No demuestra que un Xcode Intel genere la IPA |
| Metal | El `metal` encontrado es universal `x86_64` y `arm64` | Compatible según el binario. No se ha usado en Intel |
| `make`, `zip`, `xcrun` | Binarios del sistema con corte `x86_64` y cortes Apple Silicon | Presentes como herramientas del sistema. No se han ejecutado en Intel |
| Rutas | El script original busca `/opt/homebrew/bin` y `/usr/local/bin`, y también `~/.dotnet` y `/usr/local/share/dotnet`. En este Mac existe `/opt/homebrew` y no `/usr/local/Homebrew` | La búsqueda contempla los dos prefijos de Homebrew. Solo se ha recorrido el de Apple Silicon |

`dmsh_xlate` es una aplicación de .NET 10 que depende del runtime instalado. El ejecutable que lanza `dmsh_build.py` es un apphost Mach-O solo `arm64`, con mínimo macOS 12. Enlaza `libSystem` y `libc++`. Las DLL de al lado son IL. Este SDK solo trae el paquete de host `osx-arm64`; no hay `osx-x64`, ni Rosetta, así que no se ha producido ni ejecutado un apphost Intel. Volver a publicar el traductor puede cambiar la huella de las DLL que comprueba la cadena de sombreadores. XcodeGen, zstd, spirv-cross, lz4 y capstone de este Mac también son `arm64`.

La primera distribución debe ser para Apple Silicon. La interfaz Release ya contiene `x86_64` y `arm64`, pero con el traductor actual no genera una IPA en un Mac Intel. Una segunda variante exigiría un apphost `osx-x64`, el SDK y las herramientas nativas de esa arquitectura, y una prueba en hardware Intel. No se ha cambiado `ARCHS` ni el destino macOS 14.

## Pruebas registradas en este equipo

La suite de SNative Studio terminó con 67 pruebas aprobadas. Release compiló. `nx_extract` se compiló aparte, sobre una copia con las rutas de la aplicación, con código 0 y sin `CS0579`. Una IPA local de un título ya soportado se generó, se firmó fuera de la aplicación con un perfil de desarrollo y se jugó en un iPhone autorizado hasta el menú y dos mundos. No se repitió esa IPA en esta auditoría. No se ha demostrado la restauración sin red ni un Mac limpio.

El usuario debe tener, fuera de la aplicación: Python 3 con lz4, capstone y fontTools; .NET SDK 10; el nupkg de LibHac 0.19.0 en su caché o, más adelante, en `Engine/local-nuget`; Xcode con `xcodebuild`, el SDK de iOS, `xcrun` y Metal; XcodeGen; zstd; spirv-cross; make y zip. La aplicación los detecta, explica para qué sirven y ofrece un comando o un enlace solo cuando ese dato ya está verificado. No los instala. Si falta uno obligatorio, Generar IPA permanece desactivado.
