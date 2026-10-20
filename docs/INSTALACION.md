# Instalación

La versión 0.1.0 publicada como experimental adjunta un instalador sin firma y sin notarización. No es una distribución general. macOS puede advertir o impedir abrirlo. Los archivos `.pkg` locales anteriores tampoco están notarizados.

## Qué hay hoy

| Paquete | Qué es |
|---|---|
| `SNative-Studio-0.1.0-local-test-unsigned.pkg` y el de nombre `v3` | Pruebas anteriores del procedimiento. No son el lanzamiento. |
| `SNative-Studio-0.1.0-release-candidate-unsigned.pkg` | Candidato local de Release, sin firma. Lo genera `scripts/build_local_pkg.sh` y no lo instala. |
| Paquete firmado con Developer ID y notarizado | No existe. Faltan el certificado Developer ID Application, el certificado Developer ID Installer y el envío a notarización. |

El identificador del candidato local es `com.abadx.SNativeStudio.local-candidate`. El de la aplicación es `com.abadx.SNativeStudio`. Instalar el candidato pediría administrador porque el destino es `/Applications`. El script no ejecuta `installer` y no escribe en `/Applications`.

## Configuración inicial

1. Abre SNative Studio y espera a que la pantalla Herramientas termine la comprobación.
2. Instala fuera de la aplicación lo que esa pantalla marque como obligatorio. Los comandos están en `docs/DEPENDENCIAS.md`. La aplicación no los instala.
3. Crea un proyecto con el NSP base, `prod.keys` y una carpeta de salida. La actualización es opcional.
4. Pulsa Generar IPA. Si el archivo previsto ya existe, la aplicación pide confirmación antes de sustituirlo.

La aplicación no guarda el contenido de `prod.keys`. Los proyectos quedan en `~/Library/Application Support/com.abadx.SNativeStudio/projects.json`.

## Dónde trabaja

El motor incluido se copia a `~/Library/Application Support/SNative Studio/engine-work/<identificador del proyecto>/source`. `obj`, `bin`, los temporales y la caché NuGet de la aplicación también quedan bajo `~/Library/Application Support/SNative Studio/`, fuera de `SNative Studio.app`. El juego extraído y los registros del script quedan en `<carpeta del NSP>/<identificador del título>_build/`.

Un checkout externo solo se usa si la carpeta `Contents/Resources/Engine` no existe. Ese checkout no se copia y no se modifica.

## Construir desde el código

Hace falta Xcode y un checkout de nxnative junto al repositorio, en `../nxnative`, o la variable `NXNATIVE_SRC`. Desde la raíz:

```sh
xcodebuild test -project "SNative Studio.xcodeproj" -scheme "SNative Studio" -configuration Debug -destination "platform=macOS"
xcodebuild -project "SNative Studio.xcodeproj" -scheme "SNative Studio" -configuration Release -destination "platform=macOS" build
```

`scripts/build_local_pkg.sh` compila Release y deja el candidato sin firmar en `/tmp/SNativeStudio-Local-Package/`. Si ese nombre ya existe, el script se detiene y no lo sustituye. El origen del motor es `../nxnative` o la variable `NXNATIVE_SRC`. El script no usa una ruta fija del equipo de desarrollo.

## Firma y notarización

Estos pasos quedan fuera del script. No se han ejecutado:

1. Conseguir un certificado Developer ID Application y otro Developer ID Installer. Las identidades Apple Development y Apple Distribution de este Mac no sirven para un instalador público.
2. Firmar `SNative Studio.app` con Developer ID Application, activar el runtime reforzado y sellar los recursos. La configuración Release sigue sin firma.
3. Firmar el `.pkg` con Developer ID Installer.
4. Enviar ese paquete con `notarytool` y grapar el ticket con `stapler`.
5. Instalar el paquete ya firmado en un Mac distinto del de desarrollo y comprobar que la aplicación abre. Esa instalación no se ha hecho.

El aviso de LibHac 0.19.0 sigue en `SNative Studio/Resources/Notices/PENDIENTES.md`. Este documento no lo da por resuelto.
