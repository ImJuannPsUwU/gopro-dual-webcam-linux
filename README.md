# GoPro Dual Webcam Linux

Use a compatible GoPro as **two independent virtual webcams on Linux** — one for OBS and one for Discord/video calls — with robust automatic reconnection and optional zoom/crop on only one output.

> **Tested setup:** GoPro HERO12 Black, 1080p30 webcam mode, Nobara Linux (Fedora-based).
>
> Other models supported by the upstream GoPro webcam approach may work, but this repository has not been validated on every model or distribution.

## Why this exists

The excellent [`jschmid1/gopro_as_webcam_on_linux`](https://github.com/jschmid1/gopro_as_webcam_on_linux) project makes a GoPro usable as a Linux webcam and now also supports a crop option for its V4L2 output.

This project solves a slightly different use case:

```text
GoPro USB webcam stream
          |
        FFmpeg
          |
        split
       /     \
      /       \
     v         v
/dev/video42  /dev/video43
  GoPro OBS   GoPro Discord
  unchanged   optional crop/zoom
```

That means OBS can receive the full Narrow/Linear frame while Discord receives a tighter framing **at the same time**, without using OBS Virtual Camera and without decoding the GoPro stream twice.

It also installs a `systemd` monitor that detects the GoPro USB network interface, starts webcam mode through the GoPro HTTP API, and restarts cleanly after disconnect/reconnect.

## Features

- Two V4L2 loopback cameras:
  - `/dev/video42` — `GoPro OBS`
  - `/dev/video43` — `GoPro Discord`
- One GoPro UDP input and one FFmpeg process.
- Independent processing for the Discord branch.
- Linear and Narrow presets.
- Narrow + ~1.39× centered Discord zoom preset.
- Automatic GoPro detection by USB vendor ID.
- Automatic IPv4 wait and GoPro API startup.
- Robust FFmpeg termination after disconnect.
- `systemd` automatic restart.
- No OBS Virtual Camera required.
- No Python, Cargo, CMake, venv, or custom FFmpeg build required on the tested Nobara setup.

## Presets

| Script | GoPro FOV | OBS output | Discord output |
|---|---|---|---|
| `gopro-linear-dual.sh` | Linear | Full Linear | Full Linear |
| `gopro-narrow-dual.sh` | Narrow | Full Narrow | Full Narrow |
| `gopro-narrow-zoom-dual.sh` | Narrow | Full Narrow | Narrow + centered ~1.39× zoom |

The third preset is the recommended/default setup for a desk webcam when Discord otherwise shows too much of the room.

## Requirements

Runtime commands used by the scripts include:

- `systemctl`
- `udevadm`
- `modprobe`
- `ip`
- `curl`
- `ffmpeg`
- `awk`
- `grep`
- `v4l2loopback`

`v4l-utils` is recommended for diagnostics.

### Nobara / Fedora-based systems

On the tested Nobara installation, the basic user-space dependencies are:

```bash
sudo dnf install curl ffmpeg-free v4l-utils
```

Nobara currently provides `v4l2loopback` as a built-in/distribution kernel module. Check it first:

```bash
modinfo v4l2loopback
```

If that command cannot find the module on a future release, search the distribution repositories:

```bash
dnf search v4l2loopback
```

Install the Nobara/Fedora-provided module package for your release rather than compiling it manually whenever possible.

### Ubuntu / Debian-based systems

The upstream project documents packages similar to:

```bash
sudo apt install ffmpeg v4l2loopback-dkms curl v4l-utils
```

Package names may vary by release.

## GoPro setup

On the camera, set the USB connection mode to **GoPro Connect**, not MTP/file transfer.

The scripts use:

- webcam resolution: `1080`
- UDP port: `8554`
- GoPro webcam HTTP API
- V4L2 pixel format: `yuv420p`

If the firewall blocks the stream, allow UDP 8554. With `firewalld`:

```bash
sudo firewall-cmd --add-port=8554/udp --permanent
sudo firewall-cmd --reload
```

## Installation

Clone this repository and choose one preset:

```bash
git clone https://github.com/ImJuannPsUwU/gopro-dual-webcam-linux.git
cd gopro-dual-webcam-linux
```

Recommended:

```bash
sudo bash scripts/gopro-narrow-zoom-dual.sh
```

Or:

```bash
sudo bash scripts/gopro-narrow-dual.sh
```

Or:

```bash
sudo bash scripts/gopro-linear-dual.sh
```

The installer creates:

```text
/etc/modprobe.d/gopro-webcam-dual.conf
/etc/modules-load.d/gopro-webcam-dual.conf
/usr/local/bin/gopro-webcam-monitor
/etc/systemd/system/gopro-webcam-monitor.service
```

Then it enables and starts:

```text
gopro-webcam-monitor.service
```

## Verify

Connect and power on the GoPro, then run:

```bash
v4l2-ctl --list-devices
```

You should see something similar to:

```text
GoPro OBS:
    /dev/video42

GoPro Discord:
    /dev/video43
```

Service status:

```bash
systemctl status gopro-webcam-monitor.service
```

Live logs:

```bash
journalctl -u gopro-webcam-monitor.service -f
```

## OBS

Add a **Video Capture Device (V4L2)** and choose:

```text
GoPro OBS
```

The OBS branch is not cropped by the zoom preset, so you can crop/scale it differently per scene.

## Discord

Choose:

```text
GoPro Discord
```

With the zoom preset, Discord receives the tighter 16:9 image directly. OBS does not need to be running.

## Change the Discord zoom

In `scripts/gopro-narrow-zoom-dual.sh`, find:

```bash
crop=w='trunc(iw*0.72/2)*2':h='trunc(ih*0.72/2)*2'
```

Change **both** `0.72` values.

Approximate relationship:

```text
zoom ≈ 1 / crop_fraction
```

| Crop fraction | Approx. zoom |
|---:|---:|
| 1.00 | 1.00× |
| 0.90 | 1.11× |
| 0.80 | 1.25× |
| 0.72 | 1.39× |
| 0.67 | 1.49× |
| 0.60 | 1.67× |
| 0.50 | 2.00× |

Lower number = more zoom.

Keep the same value for width and height to preserve the 16:9 aspect ratio. Leave:

```text
scale=1920:1080
```

unchanged if you only want to modify zoom.

## Change FOV

The tested preset values are:

```text
FOV=4  -> Linear
FOV=2  -> Narrow
```

The upstream implementation currently maps:

```text
0 = Wide
2 = Narrow
3 = SuperView
4 = Linear
```

## Switch presets

Running another preset replaces the installed monitor/service configuration.

For example:

```bash
sudo bash scripts/gopro-linear-dual.sh
```

If `/dev/video42` and `/dev/video43` already exist, the installer avoids unloading `v4l2loopback` unnecessarily.

## Uninstall

Any preset can remove the custom service/configuration:

```bash
sudo bash scripts/gopro-narrow-zoom-dual.sh uninstall
```

This removes this project's service and module configuration. It does **not** remove FFmpeg, curl, or the distribution's `v4l2loopback` package.

## Troubleshooting

### The GoPro only appears as storage / MTP

Set:

```text
Preferences -> Connections -> USB Connection -> GoPro Connect
```

A firmware update may be required if that option is missing.

### `/dev/video42` or `/dev/video43` does not exist

Check:

```bash
modinfo v4l2loopback
lsmod | grep v4l2loopback
v4l2-ctl --list-devices
```

Then restart:

```bash
sudo systemctl restart gopro-webcam-monitor.service
```

If the module cannot be unloaded while reinstalling, close OBS, Discord, browsers, and any other program using a loopback device.

### Webcam mode starts but there is no video

Watch the service:

```bash
journalctl -u gopro-webcam-monitor.service -f
```

Then check:

- the GoPro USB network interface has IPv4;
- UDP 8554 is allowed;
- FFmpeg is running;
- the camera is still connected and powered.

### Discord was opened before the camera

Some applications enumerate cameras only at startup. Close/reopen Discord after the virtual camera is actively receiving frames.

## Does this require the upstream `gopro` script?

No. These presets are self-contained and directly perform the webcam API + FFmpeg flow.

The upstream repository is credited because its Linux GoPro webcam work, API usage, FFmpeg approach, documentation, and community troubleshooting were important foundations/reference material for this project.

If you only need **one** virtual GoPro webcam, the upstream project is simpler and should be your first choice.

## Tested behavior

Known-good combination used to create this project:

- GoPro HERO12 Black
- firmware 2.20
- 1080p30 webcam stream
- Narrow FOV
- `/dev/video42` for OBS
- `/dev/video43` for Discord
- Discord crop fraction `0.72` (~1.39×)
- Nobara Linux
- distro FFmpeg (`ffmpeg-free`)
- distro `v4l2loopback`

The firmware version is documented as a reference, not a requirement.

## Attribution and license

This project is licensed under the **Apache License 2.0**.

It builds on concepts and implementation patterns from [`jschmid1/gopro_as_webcam_on_linux`](https://github.com/jschmid1/gopro_as_webcam_on_linux), which is also Apache-2.0 licensed. See [`ATTRIBUTION.md`](ATTRIBUTION.md).

This is an independent community project and is **not affiliated with or endorsed by GoPro, Inc.** GoPro and HERO are trademarks of their respective owner(s).

## Spanish documentation

See [`README.es.md`](README.es.md).
