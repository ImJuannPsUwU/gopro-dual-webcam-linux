# GoPro Dual Webcam Linux

Convierte una GoPro compatible en **dos cámaras virtuales independientes en Linux**: una para OBS y otra para Discord/videollamadas, con reconexión automática robusta y zoom/recorte opcional únicamente en una de las salidas.

> **Configuración probada:** GoPro HERO12 Black, webcam 1080p30 y Nobara Linux (basado en Fedora).
>
> Otros modelos compatibles con el método webcam de GoPro/Linux podrían funcionar, pero no han sido probados aquí uno por uno.

## ¿Qué añade este proyecto?

El excelente proyecto [`jschmid1/gopro_as_webcam_on_linux`](https://github.com/jschmid1/gopro_as_webcam_on_linux) permite usar la GoPro como webcam en Linux y actualmente incluso admite crop en su salida.

Este repositorio resuelve un caso distinto:

```text
GoPro por USB
     |
   FFmpeg
     |
    split
   /     \
  v       v
video42  video43
 OBS     Discord
normal   zoom opcional
```

Así OBS puede recibir el cuadro completo mientras Discord recibe simultáneamente un encuadre más cerrado, **sin OBS Virtual Camera y sin decodificar dos veces la GoPro**.

También instala un monitor de `systemd` que detecta la interfaz USB de la GoPro, espera su IPv4, activa webcam por API y se recupera de desconexiones.

## Presets incluidos

| Script | FOV | OBS | Discord |
|---|---|---|---|
| `gopro-linear-dual.sh` | Linear | Linear completo | Linear completo |
| `gopro-narrow-dual.sh` | Narrow | Narrow completo | Narrow completo |
| `gopro-narrow-zoom-dual.sh` | Narrow | Narrow completo | Narrow + zoom centrado ~1.39× |

El tercero es el preset recomendado para escritorio.

## Dependencias en Nobara/Fedora

En la configuración probada, las dependencias de espacio de usuario son:

```bash
sudo dnf install curl ffmpeg-free v4l-utils
```

Nobara actualmente proporciona `v4l2loopback` como módulo del kernel integrado/proporcionado por la distribución. Compruébalo primero:

```bash
modinfo v4l2loopback
```

Si una versión futura no lo encuentra, busca el paquete correspondiente:

```bash
dnf search v4l2loopback
```

Siempre que sea posible, usa el módulo empaquetado por Nobara/Fedora en lugar de compilarlo manualmente.

No fue necesario compilar FFmpeg, usar Python, Cargo, CMake ni crear entornos virtuales.

## Configuración de la GoPro

En la cámara usa **GoPro Connect** como modo USB, no MTP/transferencia de archivos.

La configuración incluida utiliza:

```text
1080p30
UDP 8554
yuv420p
```

Si `firewalld` bloquea el vídeo:

```bash
sudo firewall-cmd --add-port=8554/udp --permanent
sudo firewall-cmd --reload
```

## Instalación

```bash
git clone https://github.com/ImJuannPsUwU/gopro-dual-webcam-linux.git
cd gopro-dual-webcam-linux
```

Preset recomendado:

```bash
sudo bash scripts/gopro-narrow-zoom-dual.sh
```

Después conecta/enciende la GoPro y comprueba:

```bash
v4l2-ctl --list-devices
```

Deberían aparecer:

```text
GoPro OBS:
    /dev/video42

GoPro Discord:
    /dev/video43
```

Logs:

```bash
journalctl -u gopro-webcam-monitor.service -f
```

Estado:

```bash
systemctl status gopro-webcam-monitor.service
```

## OBS

Usa `GoPro OBS` (`/dev/video42`) como dispositivo V4L2.

En el preset con zoom, esta rama queda intacta para que OBS pueda hacer su propio recorte por escena.

## Discord

Selecciona `GoPro Discord` (`/dev/video43`).

En el preset `narrow-zoom`, Discord ya recibe el zoom directo y OBS ni siquiera necesita estar abierto.

## Modificar el zoom

En:

```text
scripts/gopro-narrow-zoom-dual.sh
```

busca:

```bash
crop=w='trunc(iw*0.72/2)*2':h='trunc(ih*0.72/2)*2'
```

Cambia **los dos `0.72`**.

| Fracción | Zoom aprox. |
|---:|---:|
| 1.00 | 1.00× |
| 0.80 | 1.25× |
| 0.72 | 1.39× |
| 0.67 | 1.49× |
| 0.60 | 1.67× |
| 0.50 | 2.00× |

Menor número = más zoom.

Mantén el mismo valor en ancho y alto. Si solo quieres cambiar el zoom, no cambies:

```text
scale=1920:1080
```

## FOV

Valores usados:

```text
FOV=4  -> Linear
FOV=2  -> Narrow
```

El upstream actualmente contempla:

```text
0 = Wide
2 = Narrow
3 = SuperView
4 = Linear
```

## Desinstalar

```bash
sudo bash scripts/gopro-narrow-zoom-dual.sh uninstall
```

Quita el servicio y la configuración creada por estos scripts, pero no elimina los paquetes del sistema.

## ¿Necesito instalar primero el GitHub original?

No. Los tres presets incluidos son autónomos.

El proyecto original está acreditado porque fue una referencia/fundamento importante para el método webcam de GoPro en Linux, uso de API, FFmpeg y V4L2.

Si solo necesitas **una** webcam virtual sin la salida dual, el proyecto original es una opción más simple.

## Autor

Creado y mantenido por [@ImJuannPsUwU](https://github.com/ImJuannPsUwU) en GitHub.

Si este proyecto te funcionó o te gustó, también puedes seguirme en Twitch: [@ImJuanPsUwU](https://www.twitch.tv/imjuanps) 💜

## Licencia y créditos

Apache License 2.0.

Este repositorio se basa en ideas y patrones del proyecto [`jschmid1/gopro_as_webcam_on_linux`](https://github.com/jschmid1/gopro_as_webcam_on_linux), también Apache-2.0. Consulta [`ATTRIBUTION.md`](ATTRIBUTION.md).

Proyecto comunitario independiente, sin afiliación ni respaldo de GoPro, Inc. GoPro y HERO son marcas de sus respectivos propietarios.
