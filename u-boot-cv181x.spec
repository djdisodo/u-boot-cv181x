%global flavor %{?build_flavor:%{build_flavor}}%{!?build_flavor:sg2002_milkv_duo256m}

%if "%{flavor}" == "sg2002_milkv_duo256m"
%global uboot_defconfig sg2002_milkv_duo256m_defconfig
%global uboot_dtb sg2002-milkv-duo256m.dtb
%global board_tag sg2002-milkv-duo256m
%endif

%if "%{flavor}" == "cv1800b_milkv_duo"
%global uboot_defconfig milkv_duo_defconfig
%global uboot_dtb cv1800b-milkv-duo.dtb
%global board_tag cv1800b-milkv-duo
%endif

%if "%{flavor}" != "sg2002_milkv_duo256m" && "%{flavor}" != "cv1800b_milkv_duo"
%{error:Unsupported build flavor '%{flavor}'. Extend _multibuild and flavor mapping in spec.}
%endif

%global _lto_cflags %{nil}

Name:           u-boot-cv181x
Version:        0
Release:        0
Summary:        U-Boot binaries for CV181x/SG2002 boards (OBS multibuild)
License:        GPL-2.0-only
URL:            https://github.com/u-boot/u-boot
Source0:        u-boot-%{version}.tar.xz
Patch0:         0001-sg2002-milkv-duo256m-distroboot.patch
BuildRequires:  bc
BuildRequires:  bison
BuildRequires:  dtc
BuildRequires:  flex
BuildRequires:  gcc
BuildRequires:  libuuid-devel
BuildRequires:  make
BuildRequires:  openssl-devel
BuildRequires:  python3
BuildRequires:  python3-devel
BuildRequires:  swig
ExclusiveArch:  riscv64

%description
This package builds board-specific U-Boot binaries from upstream U-Boot using
OBS multibuild flavors for CV181x/SG2002 targets.

%prep
%autosetup -p1 -n u-boot-%{version}

%build
export KBUILD_BUILD_USER=obs
export KBUILD_BUILD_HOST=obs

make O=build %{uboot_defconfig}
make O=build -j%{?_smp_build_ncpus}

%install
install -d %{buildroot}%{_datadir}/u-boot/%{board_tag}
install -Dm0644 build/u-boot.bin %{buildroot}%{_datadir}/u-boot/%{board_tag}/u-boot.bin
install -Dm0644 build/u-boot-nodtb.bin %{buildroot}%{_datadir}/u-boot/%{board_tag}/u-boot-nodtb.bin
install -Dm0644 build/u-boot.dtb %{buildroot}%{_datadir}/u-boot/%{board_tag}/u-boot.dtb
install -Dm0644 build/arch/riscv/dts/%{uboot_dtb} %{buildroot}%{_datadir}/u-boot/%{board_tag}/%{uboot_dtb}
install -Dm0755 build/tools/mkimage %{buildroot}%{_bindir}/mkimage-%{board_tag}

install -Dm0644 Licenses/gpl-2.0.txt %{buildroot}%{_licensedir}/%{name}/GPL-2.0.txt

cat > %{buildroot}%{_datadir}/u-boot/%{board_tag}/build-info.txt << EOF
flavor=%{flavor}
defconfig=%{uboot_defconfig}
dtb=%{uboot_dtb}
EOF

%files
%license %{_licensedir}/%{name}/GPL-2.0.txt
%{_bindir}/mkimage-%{board_tag}
%dir %{_datadir}/u-boot
%{_datadir}/u-boot/%{board_tag}

%changelog
