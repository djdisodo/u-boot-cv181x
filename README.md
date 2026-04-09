# u-boot-cv181x (nFPM + GitHub Actions)

This repository builds `fip.bin` for SG2002/CV181x boards, packages it with
`nfpm` as an Alpine `.apk`, uploads to Cloudflare R2, then triggers index
generation webhook CI.

## What this repo builds

- Source: upstream `https://github.com/u-boot/u-boot.git`
- Tag selection: latest monthly stable tag (`vYYYY.MM`, non-`-rc`) by default
- Board patch: `0001-sg2002-milkv-duo256m-distroboot.patch`
- Output artifact: `fip.bin`
- Package content: `/root/fip.bin`

## Local build

Dependencies on Debian/Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y \
  bc bison build-essential device-tree-compiler flex \
  libgnutls28-dev libssl-dev python3 swig \
  gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
```

Build:

```sh
./ci/build_fip.sh
```

Outputs:

- `out/sg2002-milkv-duo256m/fip.bin`
- `out/sg2002-milkv-duo256m/u-boot.bin`
- `out/sg2002-milkv-duo256m/build.env`

Package with nFPM:

```sh
nfpm --version
source out/sg2002-milkv-duo256m/build.env
export PKG_NAME=u-boot-sg2002-milkv-duo256m-distroboot
export PKG_VERSION="$VERSION"
export PKG_RELEASE="$RELEASE"
export APK_SIGNING_KEY_FILE=/path/to/apk-signing.rsa
export APK_SIGNING_KEY_NAME=djdisodo@gmail.com.rsa.pub
mkdir -p dist
apk_target="dist/alpine/v3.23/main/riscv64/${PKG_NAME}-${PKG_VERSION}-r${PKG_RELEASE}.apk"
nfpm pkg --packager apk --config nfpm.yaml \
  --target "${apk_target}"
```

Package output (release suffix is recipe commit hash):

- `dist/alpine/v3.23/main/riscv64/u-boot-sg2002-milkv-duo256m-distroboot-<version>-r<recipe-tag-or-commit>.apk`

Override upstream tag:

```sh
UBOOT_TAG=v2026.04 ./ci/build_fip.sh
```

## GitHub Actions workflow

Workflow file: `.github/workflows/build-package-upload.yml`

Pipeline:

1. Build U-Boot and `fip.bin`
2. Build `.apk` via `nfpm`
3. Upload package to Cloudflare R2
4. Trigger webhook for
   `https://github.com/djdisodo/ci-indexbuild`

Triggers:

1. On every recipe tag push (`push.tags`)
2. Nightly cron (`schedule`) that checks latest upstream U-Boot monthly tag
3. Manual (`workflow_dispatch`)

Nightly behavior:

1. Resolve latest upstream U-Boot monthly tag
2. Resolve latest recipe tag in this repo and check it out
3. Compare upstream tag with repository variable `LATEST_UPSTREAM_UBOOT_TAG`
4. Skip build if unchanged, otherwise build/upload/webhook and update marker

### Required GitHub Secrets

- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_ACCOUNT_ID`
- `R2_BUCKET`
- `APK_SIGNING_KEY` (APK private key)
- `APK_SIGNING_KEY_NAME` (repo variable preferred; secret fallback)
- `INDEXBUILD_WEBHOOK_URL`
- `INDEXBUILD_WEBHOOK_TOKEN`

## Package metadata

`nfpm.yaml` defines the package payload and metadata. CI injects:

- `PKG_NAME`
- `PKG_VERSION`
- `PKG_RELEASE`
- `APK_SIGNING_KEY_FILE`
- `APK_SIGNING_KEY_NAME`

`PKG_VERSION` = U-Boot monthly tag (`v` prefix removed).

`PKG_RELEASE` = recipe tag at `HEAD` if present, otherwise recipe commit hash.
