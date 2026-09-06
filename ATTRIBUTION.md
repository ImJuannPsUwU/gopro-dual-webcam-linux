# Attribution

## Upstream project

This repository was created after using and studying:

- **Project:** `jschmid1/gopro_as_webcam_on_linux`
- **Repository:** https://github.com/jschmid1/gopro_as_webcam_on_linux
- **License:** Apache License 2.0
- **Author/maintainer shown by GitHub:** Joshua Schmid (`jschmid1`)

The upstream project provides the core Linux GoPro webcam approach and documentation around:

- the GoPro USB network interface;
- webcam-mode HTTP API calls;
- UDP port 8554;
- FFmpeg piping into V4L2 loopback devices;
- resolution/FOV selection;
- systemd/udev automation concepts;
- troubleshooting and firewall guidance.

## What is different here

The files in this repository are community modifications/extensions and carry notices accordingly. Additions include:

- two simultaneous `v4l2loopback` devices (`/dev/video42` and `/dev/video43`);
- one FFmpeg input split into independent OBS/Discord branches;
- per-output processing (Discord-only crop/zoom);
- a reconnect monitor that intentionally terminates FFmpeg after USB disconnect;
- `systemd` `Restart=always` recovery;
- GoPro interface discovery by USB vendor ID;
- presets tested on Nobara Linux with a HERO12 Black.

The repository does **not** redistribute the upstream `gopro` executable/script as a dependency.

## Apache-2.0 compliance

The upstream project is Apache-2.0 licensed. This repository:

- includes a copy of Apache License 2.0 in `LICENSE`;
- preserves upstream attribution here;
- marks community-modified/extended script files with a prominent notice;
- uses Apache-2.0 for this repository as well.

## Trademark notice

GoPro and HERO are trademarks of GoPro, Inc. This is an independent community project and is not affiliated with, sponsored by, or endorsed by GoPro, Inc.
