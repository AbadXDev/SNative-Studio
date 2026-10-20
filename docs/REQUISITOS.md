# Requisitos

Abrir SNative Studio y generar una IPA no piden lo mismo. La versión 0.1.0 declara macOS 14 como destino de despliegue. El binario de Release incluye los cortes `arm64` y `x86_64`, pero generar una IPA en un Mac Intel no está probado: el traductor `dmsh_xlate` incluido es solo `arm64`.

## Para abrir la aplicación

- macOS 14 o posterior. En un Mac con un sistema anterior, macOS rechaza el arranque porque el binario declara ese mínimo. No se ha cambiado el destino a Monterey ni a Big Sur.
- Un Mac Apple Silicon para el flujo que se ha probado. El corte `x86_64` de la interfaz no se ha ejecutado.
- No hace falta el checkout de nxnative si la aplicación trae `Contents/Resources/Engine` completo.

## Para generar una IPA

Hace falta todo lo anterior y, además, en el propio Mac:

- Un NSP base del que el usuario tenga derecho a disponer, y `prod.keys`. La actualización es opcional. Esos archivos no vienen con la aplicación.
- Una carpeta de salida con permiso de escritura.
- Python 3, con los módulos `lz4.block`, `capstone` y `fontTools`.
- .NET SDK 10.
- El paquete `libhac.0.19.0.nupkg`, en `Engine/local-nuget` o en `~/.nuget/packages/libhac/0.19.0/`. La aplicación no lo descarga. La ejecución usa la caché `~/Library/Application Support/SNative Studio/nuget`, que puede estar vacía aunque el diagnóstico haya visto `~/.nuget`. La restauración sin red no está probada.
- Xcode, con `xcodebuild`, el SDK de iOS, `xcrun` y el compilador Metal.
- XcodeGen, zstd, spirv-cross, `make` y `zip`.

Si falta un requisito obligatorio, Generar IPA permanece desactivado. Swift y Homebrew se muestran y no bloquean.

El motor empaquetado tiene que contener a la vez `scripts/build_ipa_from_nsp.py`, `dm/tools/nx_extract/Program.cs` y `dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate`. Si `Contents/Resources/Engine` existe y le falta uno, la aplicación se detiene y no busca otro checkout.

Xcode 27.1, el que hay en el equipo de desarrollo, solo arranca en macOS 26.6 o posterior. Por eso un Mac en Monterey no puede usar ese Xcode para generar la IPA, aunque más adelante la interfaz llegara a abrirse. Las versiones y los comandos de comprobación están en `docs/DEPENDENCIAS.md`.
