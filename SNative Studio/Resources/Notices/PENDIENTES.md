# Avisos y redistribución

## Avisos ya presentes

Los textos verificados están en las carpetas hermanas de este documento. Cada uno conserva el titular de su archivo. La MIT de SNative Studio no los cubre. El índice está en `README.md`.

## Avisos pendientes de verificar

Estos componentes no tienen, en el equipo, un texto de licencia que corresponda a la versión exacta que usa el traductor o el extractor. No se ha copiado la licencia de otra versión en su lugar.

| Componente | Versión requerida | Qué hay en local | Qué falta |
|---|---|---|---|
| LibHac | 0.19.0, commit `cd4004af194a51712812c680f0a028ba9152c0f8` | El nupkg local, de 651221 bytes, coincide con el tamaño del catálogo de NuGet. Contiene el nuspec, `LibHac.dll`, `LibHac.xml` y la firma. No hay archivo de licencia. El ensamblado solo lleva `Copyright © 2018-2022 Alex Barney` | El texto de la licencia de ese commit. Sigue pendiente |

Gommon 2.8.1.2, Humanizer.Core 3.0.10, MsgPack.Cli 1.0.1, Microsoft.IO.RecyclableMemoryStream 3.0.1 y el texto zlib de deko3d ya tienen copia verificada en las carpetas hermanas. Python y spirv-cross no van dentro de la aplicación: no hay una distribución de Python elegida, y el binario de spirv-cross sigue fuera del paquete. Su Apache-2.0 ya está copiado. Los textos MIT alternativos de las cabeceras solo harían falta si más adelante se redistribuye ese binario y se quiere ofrecer la alternativa.

Tampoco se empaquetan las fuentes de prueba que `fontTools` menciona bajo SIL Open Font License 1.1 en `LICENSE.external`. La rueda instalada no contiene archivos `.ttf` ni `.otf`. Ese archivo de fuentes no se ha copiado aquí.

## LibHac 0.19.0: fuentes consultadas

El paquete no se copia dentro de SNative Studio. `dotnet build` lo restaura en el Mac del usuario. El aviso falta para acompañar esa dependencia de compilación; no es un archivo que el instalador redistribuya hoy.

La declaración verificada del paquete 0.19.0 es esta:

- `license type="expression"`: `MIT`
- `licenseUrl`: `https://licenses.nuget.org/MIT`
- `copyright`: `Copyright © 2018-2022 Alex Barney`
- `projectUrl`: `https://github.com/Thealexbarney/LibHac`
- `repository` commit: `cd4004af194a51712812c680f0a028ba9152c0f8`
- autores: Alex Barney
- versión: 0.19.0

Eso está en el nuspec local y en el catálogo `https://api.nuget.org/v3/catalog0/data/2025.05.23.11.10.28/libhac.0.19.0.json`, creado el 20 de octubre de 2023. El catálogo también usa la expresión MIT y la misma URL genérica. Esa página es el texto SPDX de MIT, no un archivo escrito para este commit.

El repositorio, el tag `v0.19.0`, el commit y las rutas `LICENSE` y `LICENSE.md` respondieron 404. La API de licencia del repositorio también. Una captura de 2023 de `raw.githubusercontent.com/Thealexbarney/LibHac/master/LICENSE` no existe en Wayback. Versiones antiguas del catálogo apuntaban a `blob/master/LICENSE`, pero ese archivo ya no se puede leer. No se ha usado el MIT de otro proyecto del mismo autor ni el de una versión anterior.

## Dependencias que todavía no se redistribuyen

Python, el SDK de .NET, XcodeGen, zstd, spirv-cross y el nupkg de LibHac pueden estar instalados en el Mac, pero esta fase no los copia dentro de la aplicación. LibHac 0.19.0 está en la caché NuGet de este equipo; su archivo de licencia sigue sin localizarse, así que el paquete no se da por redistribuible.

## Requisitos que permanecen fuera del instalador

Xcode, el SDK de iOS, `xcrun`, el compilador Metal, `make` y `zip` los aporta el Mac del usuario. SNative Studio no los descarga. La fuente Arial Unicode del sistema tampoco se redistribuye.

## Decisión confirmada

La copia distribuible del script ya puede recibir `SNATIVE_TOOL_PATH`. El checkout de nxnative no cambia. `Contents/Resources/Tools/` sigue vacío y el nupkg de LibHac no se ha copiado. Las licencias de la tabla anterior siguen pendientes; el modo sin conexión de NuGet no se ha probado.

Un paquete local sin firmar puede construir el procedimiento de instalación. No redistribuye Python, .NET, XcodeGen, zstd, spirv-cross ni LibHac, y no queda autorizado para publicación mientras esta tabla siga abierta. Generar una IPA en este Mac y firmarla con un perfil de desarrollo para un dispositivo autorizado no cierra ninguna fila de la tabla ni autoriza la distribución.
