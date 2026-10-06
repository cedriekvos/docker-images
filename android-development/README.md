# `android-development` container

A self-contained, per-project Docker setup for Android development with Claude Code. The image carries the JDK, the Android SDK and Claude Code, so building, testing and installing on a phone all happen inside the container. The host only needs Docker.

## Layout

```
docker/android-development/
├── Dockerfile       # Ubuntu + JDK + Android SDK + Gradle + Claude Code, non-root user matching host UID/GID
├── compose.yml      # one service: `android` (one-shot, --rm on exit)
├── README.md
└── bin/
    ├── build-docker.sh     # build the image
    ├── start-docker.sh     # run Claude Code, or any other command, in the container
    ├── remove-docker.sh    # tear down image + home volume
    └── _common.sh          # shared by the three scripts
```

## Usage

```sh
# Build once (or after editing the Dockerfile)
docker/android-development/bin/build-docker.sh

# Launch an interactive Claude session in the project root
docker/android-development/bin/start-docker.sh

# While that session runs: a shell or a one-off command in the same container
docker/android-development/bin/start-docker.sh bash
docker/android-development/bin/start-docker.sh ./gradlew assembleDebug

# Tear everything down (deletes login, history, Gradle caches and the debug keystore!)
docker/android-development/bin/remove-docker.sh
```

Run the scripts as yourself. They call `sudo docker` on their own when your user is not allowed to talk to the Docker daemon.

## What is in the image

Versions are build arguments. Change the defaults in the `Dockerfile`, or pass `--build-arg NAME=value` to `build-docker.sh`.

| Build arg | Default | Sets |
|---|---|---|
| `JDK_VERSION` | `21` | JDK that runs Gradle |
| `ANDROID_PLATFORM` | `36` | SDK platform; must match the project's `compileSdk` |
| `ANDROID_BUILD_TOOLS` | `36.0.0` | build-tools version the project's Android Gradle Plugin asks for |
| `CMDLINE_TOOLS_BUILD` | `13114758` | `sdkmanager` release |
| `GRADLE_VERSION` | `9.8.0` | standalone Gradle, only used for `gradle wrapper` |

`ANDROID_PLATFORM` is the suffix of the SDK package name, so Android 17 is `37.0`, not `37`; `sdkmanager --list` shows the valid names. `platform-tools` (`adb`) is always installed.

## Claude Code updates

Claude Code is installed in the home directory, so the copy that runs lives in the `home` volume and updates itself there. An update that was downloaded during a session takes effect at the next start.

Docker fills the volume from the image only once, when the volume is new. Rebuilding the image afterwards does not change Claude Code in an existing project. If an update ever goes wrong, open a shell with `start-docker.sh bash` and run `claude update`, or reinstall with `curl -fsSL https://claude.ai/install.sh | bash`.

## Running the app on a phone

`adb` reaches the phone over Wi-Fi debugging (Android 11+). The phone and the host have to be on the same network, and that network must let devices talk to each other.

Pair once, under *Developer options → Wireless debugging → Pair device with pairing code*:

```sh
adb pair <phone-ip>:<pairing-port>
```

At the start of every session, connect with the port shown on the main *Wireless debugging* screen, then install:

```sh
adb connect <phone-ip>:<port>
./gradlew installDebug
```

The pairing is kept in the `home` volume. The connection is not: the port changes whenever wireless debugging restarts, and automatic discovery does not cross the Docker network, so the address has to be typed in.

## Starting a new project

There is no Android Studio and no project wizard here: ask Claude to scaffold the project, or write the Gradle files by hand. `gradle wrapper --gradle-version <version>` generates `./gradlew`; use that for everything afterwards. Keep `compileSdk` in line with `ANDROID_PLATFORM`.

## How it isolates per project

The scripts derive a unique compose project name from the dir above `docker/`:

```
/home/you/notes-app/docker/android-development/  →  notes-app-android-development
```

That name covers the container, the image, the network and the `home` volume, so two projects don't share login state, caches or signing keys. If two projects share a basename, set `ANDROID_DEV_PROJECT_ID` before running the scripts.

## What gets mounted

| Host | Container | Why |
|---|---|---|
| `../..` (the project root containing `docker/`) | `/workspace` | Your code, live |
| `home` (named volume) | `/home/dev` | Claude Code with its login + history, Gradle caches (`~/.gradle`), adb keys and debug keystore (`~/.android`) |
| `~/.config/git/config` | `/etc/gitconfig` (read-only) | Your git name, email and settings; added by `start-docker.sh` when the file exists |

## Not included

- **Emulator.** Use a real phone. An emulator in a container needs `/dev/kvm`, a system image of several GB and a display or `-no-window`; none of that is set up.
- **Android Studio.** No layout or Compose preview, profiler or visual debugger. Everything goes through Gradle, `adb` and Claude.
- **USB debugging.** The container has no access to the host's USB devices. To use a cable anyway, mount `/dev/bus/usb` into the service in `compose.yml` and add `device_cgroup_rules: ["c 189:* rmw"]`; that exposes every USB device on the host, not just the phone.
- **NDK and CMake.** Add them to the `sdkmanager` line in the `Dockerfile` if the project has native code.
- **Git credentials.** Commits made in the container carry your name and email, but there are no SSH keys or tokens inside. Push from the host.

## Caveats

- **One container per project.** A second `start-docker.sh` joins the running container; its sessions end when the first command exits.
- **SDK versions are baked in.** If Gradle downloads an SDK package at the start of every session, set the matching build argument and rebuild.
- **The debug keystore lives in the `home` volume.** After `remove-docker.sh`, builds are signed with a new key and the phone refuses to update the app until the old install is removed.
- **Don't build the same checkout on the host.** A `local.properties` with a host `sdk.dir` overrides the SDK in the container.
- **Host git settings can misfire.** Commit signing, a custom editor or pager and credential helpers rely on programs and keys the container doesn't have. Override them inside with `git config --global`, for example `git config --global commit.gpgsign false`; that is stored in the `home` volume.
- **UID is baked into the image.** Rebuild if your `id -u` changes.
