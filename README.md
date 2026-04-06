# u-boot-cv181x (OBS recipe repo)

This repository contains OBS packaging metadata for CV181x/SG2002 U-Boot
artifacts, using upstream U-Boot source directly.

## Design

- Source: pulled from `https://github.com/u-boot/u-boot.git` via `_service`
- Packaging: this repository only (spec, patches, OBS config)
- Build mode: `_multibuild` flavors

## Current flavors

- `sg2002_milkv_duo256m`
- `cv1800b_milkv_duo`

The `sg2002_milkv_duo256m` flavor carries distroboot preboot behavior:

- load base DTB from FAT: `/dtb/sg2002-milkv-duo256m.dtb`
- apply user overlay from FAT: `/overlays/user.dtbo`
- set `fdt_addr` so extlinux can omit DTB entries
- uses dedicated target config: `sg2002_milkv_duo256m_defconfig`

## Workflow

1. In OBS package directory, run source services:
   - `osc service mr`
2. Commit the refreshed tarball and `_servicedata`.
3. Build all flavors:
   - `osc build --multibuild-package=sg2002_milkv_duo256m`
   - `osc build --multibuild-package=cv1800b_milkv_duo`

## Adding a new board flavor

1. Add flavor name in `_multibuild`.
2. Extend flavor mapping in `u-boot-cv181x.spec`:
   - defconfig
   - installed DTB file name
   - output directory tag
3. Add/adjust patches only if upstream defaults are insufficient.
