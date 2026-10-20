# Equipo de pruebas

Solo se anota lo que se ha ejecutado. Una medición de arquitectura no equivale a haber arrancado el flujo en ese equipo.

## Mac de desarrollo

- Apple Silicon, `arm64`. Darwin 27. No hay Rosetta: `arch -x86_64 /usr/bin/true` falla.
- Xcode 27.1. El SDK de macOS es 27.0 y el de iOS es 27.1. Xcode declara macOS 26.6 como mínimo para abrirse.
- La suite de SNative Studio y la configuración Release se han ejecutado en este Mac. El número exacto de la última pasada está en el README, en «Pruebas hechas y pendientes».
- Una compilación aislada de `nx_extract`, con las rutas de la aplicación y la caché NuGet ya llena, terminó con código 0 y sin el error de atributos duplicados. Apareció el aviso `NU1900` al no poder leer el índice de vulnerabilidades. Eso no prueba el modo sin conexión de la aplicación.
- Se generó una IPA local de un título ya soportado. Fuera de SNative Studio se firmó una copia temporal con un perfil de desarrollo ya existente y se instaló en un iPhone autorizado, con modo de desarrollador. El juego llegó al menú y se jugaron dos mundos. El archivo IPA de origen no se modificó. Eso no demuestra un Mac limpio ni una firma de distribución.
- El ejecutable Release de la interfaz contiene `arm64` y `x86_64`, con mínimo macOS 14.0. El corte `x86_64` no se ha ejecutado.
- `dmsh_xlate` es `arm64`. El SDK de .NET local solo tiene el host `osx-arm64`. XcodeGen, zstd, spirv-cross, lz4 y capstone medidos aquí también son `arm64`.

## Lo que no se ha probado

- Un Mac Intel. El instalador local v3 llegó a instalarse en uno, y macOS rechazó el arranque porque la aplicación pide la versión 14. No se anotó la versión exacta de ese sistema. No se generó una IPA allí.
- macOS 12 Monterey y macOS 11 Big Sur. El análisis del proyecto está hecho; no se compiló con otro destino ni se abrió la aplicación en esos sistemas.
- Un Mac limpio, sin el checkout de desarrollo y sin las herramientas ya instaladas aquí.
- La restauración de LibHac sin red.
- Firma Developer ID, notarización y grapado. En este Mac no hay certificado Developer ID Application ni Developer ID Installer.
