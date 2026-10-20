# Solución de problemas

## La aplicación no abre y macOS pide la versión 14

El destino de despliegue es macOS 14.0. El sistema rechaza el binario en una versión anterior. No es un fallo del corte Intel: el ejecutable Release incluye `x86_64` y `arm64`, y ambos declaran ese mínimo.

## Generar IPA está desactivado

La comprobación de Herramientas no ha terminado, o falta un requisito obligatorio. La pantalla indica cuál. La aplicación no lo instala. Swift y Homebrew pueden faltar sin bloquear. La lista está en `docs/REQUISITOS.md`.

## El motor empaquetado está incompleto

Si existe `Contents/Resources/Engine` y falta el script, `Program.cs` o `dmsh_xlate`, la aplicación se detiene. No usa el checkout de desarrollo como sustituto. Hace falta una aplicación cuyo motor traiga los tres archivos.

## Atributos de ensamblado duplicados en nx_extract

Ese error, `CS0579`, aparecía cuando MSBuild compilaba dos veces los archivos generados. La copia de trabajo escribe `Directory.Build.props` en su raíz y excluye `obj/**` y `bin/**` antes de evaluar las fuentes. No desactiva la generación de atributos. Una compilación aislada posterior terminó con código 0. Los generados quedan en `~/Library/Application Support/SNative Studio/engine-work/<identificador>/msbuild/`, no dentro de la aplicación.

## El registro de la compilación

La pantalla Compilación muestra la salida y permite copiarla. No hay un `log.txt` de SNative Studio. El script escribe en `<carpeta del NSP>/<identificador>_build/logs/`. El de `nx_extract` es `logs/nx_extract_build.log`.

## La IPA no se instala en el iPhone

SNative Studio no firma ni instala. El archivo resultante no está firmado. Para un dispositivo autorizado hace falta extraer `Payload/*.app`, firmar esa copia con un certificado de desarrollo y un perfil que ya incluya el dispositivo, e instalar el `.app` con las herramientas de Xcode. Si iOS lo pide, hay que confiar en el desarrollador en Ajustes. Los diagnósticos del juego, si los hay, quedan en `Documents/log.txt` de esa aplicación.

## No se puede preparar la copia escribible

La aplicación no escribe dentro de `SNative Studio.app`. Si no puede crear la copia en Application Support, Generar IPA se detiene con el aviso de que no se puede preparar una copia escribible.
