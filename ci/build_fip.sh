#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
recipe_commit="$(git -C "$repo_root" rev-parse --short=12 HEAD)"
recipe_tag="$(git -C "$repo_root" tag --points-at HEAD | sort -V | tail -n1)"

board="sg2002-milkv-duo256m"
defconfig="sg2002_milkv_duo256m_defconfig"
patch_file="$repo_root/0001-sg2002-milkv-duo256m-distroboot.patch"
uboot_repo="https://github.com/u-boot/u-boot.git"

work_dir="$repo_root/.work"
out_root="$repo_root/out"
out_dir="$out_root/$board"

jobs="$(nproc)"
arch="riscv"
cross_compile="riscv64-linux-gnu-"

fsbl_bin="$repo_root/cv181x.bin"
ddr_param_bin="$repo_root/ddr_param.bin"
rtos_bin="$repo_root/cvirtos.bin"
opensbi_bin="$repo_root/fw_dynamic.bin"
fiptool_py="$repo_root/fiptool"

if [[ -z ${UBOOT_TAG+x} ]]; then
	UBOOT_TAG="$(
		git ls-remote --tags --refs "$uboot_repo" 'refs/tags/v20[0-9][0-9].[0-9][0-9]' \
		| awk '{print $2}' \
		| sed 's#refs/tags/##' \
		| grep -E '^v[0-9]{4}\.[0-9]{2}$' \
		| sort -V \
		| tail -n1
	)"
elif [[ -z "$UBOOT_TAG" ]]; then
	UBOOT_TAG="$(
		git ls-remote --tags --refs "$uboot_repo" 'refs/tags/v20[0-9][0-9].[0-9][0-9]' \
		| awk '{print $2}' \
		| sed 's#refs/tags/##' \
		| grep -E '^v[0-9]{4}\.[0-9]{2}$' \
		| sort -V \
		| tail -n1
	)"
fi

if [[ -z "$UBOOT_TAG" ]]; then
	echo "failed to resolve upstream monthly u-boot tag" >&2
	exit 1
fi

version="${UBOOT_TAG#v}"
src_dir="$work_dir/u-boot-$version"
build_dir="$src_dir/build"

rm -rf "$src_dir" "$out_dir"
mkdir -p "$work_dir" "$out_dir"

echo "u-boot: cloning $UBOOT_TAG"
git clone --depth 1 --branch "$UBOOT_TAG" "$uboot_repo" "$src_dir"
uboot_commit="$(git -C "$src_dir" rev-parse --short=12 HEAD)"
release_raw="$recipe_commit"
if [[ -n "$recipe_tag" ]]; then
	release_raw="$recipe_tag"
fi
release="$(printf '%s' "$release_raw" | sed 's/[^A-Za-z0-9._-]/-/g')"

echo "u-boot: applying board patch"
patch -d "$src_dir" -p1 < "$patch_file"

echo "u-boot: building $defconfig"
make -C "$src_dir" O="$build_dir" ARCH="$arch" CROSS_COMPILE="$cross_compile" "$defconfig"

"$src_dir/scripts/config" --file "$build_dir/.config" \
	-d EFI_LOADER \
	-d CMD_BOOTEFI_HELLO_COMPILE \
	-d CMD_BOOTEFI_SELFTEST \
	-d POSITION_INDEPENDENT

make -C "$src_dir" O="$build_dir" ARCH="$arch" CROSS_COMPILE="$cross_compile" olddefconfig
make -C "$src_dir" O="$build_dir" ARCH="$arch" CROSS_COMPILE="$cross_compile" -j"$jobs"

echo "fip: packing $out_dir/fip.bin"
python3 "$fiptool_py" \
	--fsbl "$fsbl_bin" \
	--ddr_param "$ddr_param_bin" \
	--opensbi "$opensbi_bin" \
	--uboot "$build_dir/u-boot.bin" \
	--rtos "$rtos_bin" \
	"$out_dir/fip.bin"

install -m0644 "$build_dir/u-boot.bin" "$out_dir/u-boot.bin"

cat > "$out_dir/build.env" <<-EOF
BOARD=$board
DEFCONFIG=$defconfig
UBOOT_REPO=$uboot_repo
UBOOT_TAG=$UBOOT_TAG
UBOOT_COMMIT=$uboot_commit
RECIPE_COMMIT=$recipe_commit
RECIPE_TAG=$recipe_tag
VERSION=$version
RELEASE=$release
ARCH=$arch
CROSS_COMPILE=$cross_compile
PKG_NAME=u-boot-$board-distroboot
EOF

echo "done: $out_dir/fip.bin"
