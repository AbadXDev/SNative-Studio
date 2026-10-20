# Licencias y créditos

SNative Studio es de AbadX, 2026, licencia MIT, archivo `LICENSE`. Esa licencia no cubre lo demás. Los textos copiados, con su titular, están en `SNative Studio/Resources/Notices/`. El índice de esas carpetas es `Notices/README.md`. Este resumen no sustituye esos archivos.

| Componente | Titular y licencia | Dónde está el texto |
|---|---|---|
| SNative Studio | MIT, copyright 2026 AbadX | `LICENSE` y `Notices/SNative-Studio/LICENSE` |
| nxnative | MIT, copyright 2026 jhaizhou | `Notices/nxnative/LICENSE`. Repositorio https://github.com/seedds/nxnative |
| libvpx | BSD de 3 cláusulas, The WebM Project | `Notices/nxnative/third_party/libvpx/` |
| libdeflate | MIT, Eric Biggers y Google LLC | `Notices/nxnative/third_party/libdeflate/COPYING` |
| stb_vorbis | MIT o la alternativa de dominio público del mismo archivo, Sean Barrett | `Notices/nxnative/third_party/stb_vorbis/LICENSE` |
| Cabeceras Vulkan | Apache-2.0 o MIT, The Khronos Group | `Notices/nxnative/third_party/vulkan-headers/LICENSE.md` |
| Ryujinx | MIT, Ryujinx Team and Contributors | `Notices/nxnative/third_party/ryujinx/LICENSE.txt` |
| Spv.Generator | Permiso de tipo MIT, en el archivo del árbol | `Notices/nxnative/third_party/ryujinx/Spv.Generator-LICENSE` |
| nvn.h | MIT, copyright 2020 h1k421 | `Notices/nxnative/nvn/nvn.h-license.txt` |
| MacNativeGames | MIT, copyright 2026 MacNativeGames contributors | `Notices/nxnative/third_party/macnativegames/LICENSE` |
| deko3d, algoritmo portado en `nvn_tex.c` | zlib, copyright 2018-2020 fincs | `Notices/deko3d/LICENSE` |
| FLIP | BSD de 3 cláusulas, NVIDIA. No hace falta para generar una IPA | `Notices/nxnative/third_party/flip/LICENSE` |
| Gommon 2.8.1.2 | MIT, copyright 2019- Evan Husted | `Notices/gommon-2.8.1.2/LICENSE` |
| Humanizer.Core 3.0.10 | MIT, con los avisos de Inflector y ByteSize del mismo archivo | `Notices/humanizer-core-3.0.10/license.txt` |
| MsgPack.Cli 1.0.1 | Apache-2.0. Copyright 2010-2016 FUJIWARA, Yusuke | `Notices/msgpack-cli-1.0.1/LICENSE.txt` |
| Microsoft.IO.RecyclableMemoryStream 3.0.1 | MIT, copyright 2015-2016 Microsoft | `Notices/recyclablememorystream-3.0.1/LICENSE` |
| System.CodeDom 4.4.0 | MIT y avisos de terceros del paquete | `Notices/system-codedom-4.4.0/` |
| lz4 4.4.5, capstone 5.0.9, fontTools 4.60.2 | BSD, BSD y MIT, respectivamente | `Notices/python/`. No van los binarios ni las fuentes de prueba SIL |
| SDK de .NET 10.0.402 | MIT y `ThirdPartyNotices.txt` | `Notices/dotnet/`. El SDK no va dentro de la aplicación |
| XcodeGen 2.46.0 | MIT, copyright 2018 Yonas Kolb | `Notices/xcodegen-2.46.0/LICENSE`. El binario no va dentro |
| zstd 1.5.7 | BSD, Meta Platforms. La GPL-2 alternativa no se usa | `Notices/zstd-1.5.7/LICENSE`. El binario no va dentro |
| spirv-cross 1.4.363.0 | Apache-2.0 de la fórmula instalada | `Notices/spirv-cross-1.4.363.0/`. El binario no va dentro |

## Pendiente

LibHac 0.19.0, commit `cd4004af194a51712812c680f0a028ba9152c0f8`, autor Alex Barney. El nupkg y el catálogo de NuGet declaran la expresión MIT, el copyright 2018-2022 y la URL genérica `https://licenses.nuget.org/MIT`. El nupkg no contiene un archivo de licencia. El repositorio y ese commit ya no sirven el texto. No se ha inventado uno ni se ha copiado el de otra versión. LibHac no viaja dentro de SNative Studio: `nx_extract` lo restaura al compilar. El aviso sigue abierto en `Notices/PENDIENTES.md`.

Xcode, el SDK de iOS, Metal, `make`, `zip` y la fuente Arial Unicode del sistema no se redistribuyen. No se ha leído el contrato de licencia de Xcode para citarlo.

Las solicitudes de atribución, corrección o retirada van al canal indicado en `docs/AVISO-LEGAL.md`.
