# Restaurar LibHac sin red

`dm/tools/nx_extract/nx_extract.csproj` referencia el paquete NuGet LibHac 0.19.0. El checkout no tiene `nuget.config` ni `packages.lock.json`. Un `dotnet build` puede buscar el paquete en la red.

La versión empaquetada, no el checkout original de nxnative, necesitaría:

1. Copiar el nupkg local `libhac.0.19.0.nupkg` a una carpeta de solo lectura dentro del motor empaquetado, por ejemplo `local-nuget/`.
2. Añadir, solo en esa copia del motor, un `nuget.config` en su raíz:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="snative-local" value="local-nuget" />
  </packageSources>
</configuration>
```

`<clear />` quita el origen público. La ruta es relativa a ese `nuget.config`.

3. Dejar la caché de paquetes en un directorio escribible del usuario, no dentro de la aplicación instalada. La aplicación ya pone `NUGET_PACKAGES` en `~/Library/Application Support/SNative Studio/nuget`. El diagnóstico, en cambio, mira `~/.nuget/packages`. Una caché personal llena no llena la carpeta de la aplicación.
4. Compilar `nx_extract` con el SDK de .NET ya empaquetado y con ese único origen.
5. Comprobar, cuando se construya el paquete, que la restauración no abre la red. Si el SDK 10 intenta una auditoría de paquetes, hay que desactivarla en la copia empaquetada. Eso no se ha probado aquí. Una compilación aislada contra una caché ya llena avisó `NU1900` al no alcanzar el índice de vulnerabilidades y aun así terminó; no equivale a una restauración sin red desde la carpeta de la aplicación.

El nupkg de 0.19.0 declara el ensamblado para `net7.0` y el proyecto pide `net10.0`. No se cambia el proyecto. El nupkg no incluye un archivo de licencia. El nuspec y el catálogo de NuGet declaran la expresión MIT y `Copyright © 2018-2022 Alex Barney`, y enlazan el texto SPDX genérico. El archivo de ese commit no se ha recuperado, así que el aviso sigue pendiente. LibHac no se copia al bundle.

Gommon, Humanizer, MsgPack.Cli, RecyclableMemoryStream y System.CodeDom no se restauran al generar una IPA si `dmsh_xlate` viaja ya compilado. Sus avisos siguen haciendo falta junto al traductor. System.CodeDom 4.4.0 sí tiene sus textos en `system-codedom-4.4.0/`.
