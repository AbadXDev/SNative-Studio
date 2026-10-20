# Dependencias

La aplicación las busca y no las instala. El inventario de licencias, arquitecturas y empaquetado está en `docs/dependencias-empaquetado.md`. Esta página es la lista para preparar un Mac.

Las versiones de la columna «Vista aquí» son las medidas en el Mac de desarrollo. No son un máximo ni una promesa para otro equipo. `Contents/Resources/Tools/` sigue vacío: Python, .NET, XcodeGen, zstd y spirv-cross no viajan dentro de la aplicación.

| Herramienta | Para qué | Vista aquí | Comprobación | Origen |
|---|---|---|---|---|
| Python 3 | Ejecuta el script del motor | 3.9.6 del sistema | `python3 --version` | El sistema. No se copia `/usr/bin/python3` |
| lz4 | Módulo `lz4.block` | rueda 4.4.5 | `python3 -c "import lz4.block"` | https://pypi.org/project/lz4/ |
| capstone | Desensamblado | metadatos 5.0.9; el módulo importado informa 5.0.7 | `python3 -c "import capstone"` | https://pypi.org/project/capstone/ |
| fontTools | Fuentes del icono de botones | 4.60.2 | `python3 -c "import fontTools"` | https://pypi.org/project/fonttools/ |
| .NET SDK | Compila `nx_extract` y carga `dmsh_xlate` | SDK 10.0.402, runtime de host 10.0.13, solo `osx-arm64` | `dotnet --version` | https://dotnet.microsoft.com/download/dotnet/10.0 |
| LibHac | Lee el NSP dentro de `nx_extract` | 0.19.0 en la caché NuGet de este Mac. No va dentro de la aplicación | Existe `libhac.0.19.0.nupkg` en `~/.nuget/packages/libhac/0.19.0/` o en `Engine/local-nuget` | https://www.nuget.org/packages/LibHac/0.19.0 |
| Xcode | `xcodebuild`, SDK de iOS y Metal | 27.1. Exige macOS 26.6 para arrancar | `xcodebuild -version` | https://apps.apple.com/app/xcode/id497799835 |
| SDK de iOS | Compila la IPA | 27.1 | `xcrun --sdk iphoneos --show-sdk-path` | Incluido con Xcode |
| Metal | Compila sombreadores | El `metal` de este Xcode | `xcrun --find metal` | Incluido con Xcode |
| make y zip | Host y empaquetado de la IPA | Herramientas del sistema | `make -v` y `zip -v` | macOS y Xcode |
| XcodeGen | Genera el proyecto de la IPA | 2.46.0 | `xcodegen --version` | https://github.com/yonaskolb/XcodeGen |
| zstd | Descomprime recursos | 1.5.7 | `zstd --version` | https://github.com/facebook/zstd |
| spirv-cross | Traduce SPIR-V a MSL | 1.4.363.0. `--version` termina con código 1 y muestra el uso | `spirv-cross --version` | https://github.com/KhronosGroup/SPIRV-Cross |
| nxnative | Motor | El checkout local, licencia MIT copyright 2026 jhaizhou | Los tres archivos de `Contents/Resources/Engine` | https://github.com/seedds/nxnative |

Si Homebrew está presente, la pantalla Herramientas puede copiar `brew install xcodegen`, `brew install zstd`, `brew install spirv-cross` o `brew install --cask dotnet-sdk`. Ese último comando no fija el SDK 10 y no se ha comprobado qué instala el cask. Sin Homebrew, la aplicación no inventa el comando. Los módulos de Python, cuando `python3` ya está, se indican con `python3 -m pip install lz4 capstone fonttools`.

Swift y Homebrew aparecen en la pantalla y no bloquean la generación.

`dmsh_xlate` viaja con el motor. En este árbol es un ejecutable `arm64` que necesita el runtime de .NET 10. Las DLL de al lado son IL. No hay un apphost `osx-x64` en este equipo.
