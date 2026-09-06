# Contributing

Contributions are welcome.

Please keep the project focused on the dual-output Linux webcam use case.

## Before submitting a change

1. Keep `/dev/video42` as the OBS output and `/dev/video43` as the Discord output unless there is a strong compatibility reason to change the defaults.
2. Avoid changing the stable GoPro detection/reconnect path when a feature can be added only to one output branch.
3. Validate Bash syntax:

   ```bash
   bash -n scripts/*.sh
   ```

4. Clearly state:
   - Linux distribution/version;
   - GoPro model and firmware;
   - FFmpeg version;
   - `v4l2loopback` version;
   - whether OBS and Discord were both tested.
5. Do not claim support for hardware you have not tested.

## License

By contributing, you agree that your contribution can be distributed under Apache License 2.0.
