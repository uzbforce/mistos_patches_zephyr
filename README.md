# mistos-patches-zephyr

MistOS 5.2 / Android 17 (`cp2a`) sources for the **Redmi Note 17 4G**
(codename `zephyr`, SM6225-AF / bengal). This is the MistOS counterpart of
`lineage_patches_zephyr`: the device/vendor/platform repos live in `../repos`,
and this directory holds every ROM-source patch applied on top of a fresh
MistOS checkout plus the helpers that reproduce the tree.

```
repos/                                   # the repos themselves (source of truth)
                                         # contains .find-ignore, which makes
                                         # Soong's Finder prune it instead of
                                         # defining every module a second time
  android_device_xiaomi_zephyr           -> device/xiaomi/zephyr
  android_vendor_xiaomi_zephyr           -> vendor/xiaomi/zephyr
  zephyr-kernel                          -> device/xiaomi/zephyr-kernel
  kernel_xiaomi_zephyr                   -> kernel/xiaomi/zephyr
  android_hardware_qcom-caf_common       -> hardware/qcom-caf/common
  android_hardware_qcom-caf_sm6225_*     -> hardware/qcom-caf/sm6225/*
  android_device_qcom_sepolicy_vndr_sm6225 -> device/qcom/sepolicy_vndr/sm6225
mistos-patches-zephyr/
  patches/                               # mirrors the checkout layout
  apply.sh                               # applies patches/ to a checkout
  capture.sh                             # captures a project diff as a patch
  setup-tree.sh                          # copies repos/ into a fresh checkout
```

## Reproducing a fresh build

```bash
repo init -u https://github.com/Project-Mist-OS/manifest -b 17.0
repo sync -c -j8
# repos/ and mistos-patches-zephyr/ must be next to each other
# (run setup first, before the first mka, so materialized copies are used)
./mistos-patches-zephyr/setup-tree.sh /path/to/mistos-5.2
source build/envsetup.sh
lunch lineage_zephyr-cp2a-userdebug
mka bacon
```

`setup-tree.sh` materializes the repos as **real directories**, not symlinks:
Soong's file scanner (`out/.module_paths/AndroidProducts.mk.list`) skips
symlinked directories, and the product then cannot be found at all. It also
creates the link files that `repo sync` normally makes from the platform
manifest (`hardware/qcom/Android.mk`, `device/qcom/sepolicy_vndr/SEPolicy.mk`,
the `sm6225` pickup makefiles/blueprints). It deliberately does **not** add
`zephyr` or `uzbforce` to `mist-maintainers`: this is an unofficial build, and
because the device is absent from `mist.devices`, `version.mk` labels it
`UNOFFICIAL`. Official status is assigned by the MistOS maintainers, not by a
local setup script.

The product intentionally keeps the `lineage_` prefix: MistOS' envsetup only
strips `lineage_` when it derives `LINEAGE_BUILD`, and `version.mk` matches that
against `mist-maintainers/mist.devices` and puts it in `LINEAGE_VERSION`.

## Signing keys

`BoardConfig.mk` signs AVB with `vendor/lineage-priv/keys/avb.pem`. The working
build reused the key set from the Lineage checkout; `setup-tree.sh` copies a
`keys/` directory next to it when present, otherwise it generates a local
4096-bit AVB key (signatures then differ from the existing Lineage build, but
the image is complete). For an OTA that upgrades an existing install, reuse the
original `vendor/lineage-priv/keys`.

## MistOS configuration (in `repos/android_device_xiaomi_zephyr`)

`lineage_zephyr.mk` now carries the MistOS product settings:

| Setting | Value | Why |
|---|---|---|
| `WITH_GMS` | `true` | full GMS/Play/SetupWizard from MistOS' `vendor/gms` (`MIST_PACKAGE_TYPE=GAPPS`); the Lineage-side `vendor/gapps` inherit was removed |
| `TARGET_ENABLE_BLUR` | `true` | background blur, `ro.surface_flinger.supports_background_blur=1` |
| `MISTOS_MAINTAINER` | `uzbforce` | `ro.mistos.maintainer` |
| `TARGET_DEFAULT_PIXEL_LAUNCHER` | `true` | Quick Switch, see below |
| `LINEAGE_BUILD` / device | `zephyr` | via the `lineage_zephyr` product name |

### Quick Switch does not replace the Mist launcher

`TARGET_DEFAULT_PIXEL_LAUNCHER := true` only sets
`persist.sys.default_launcher=1` and `persist.sys.quickswitch_pixel_shipped=1`
in `vendor/lineage/config/mist.mk`. `common_mobile.mk` always installs
`Launcher3QuickStep`, and `vendor/gms/gms_full.mk` adds `NexusLauncherRelease`
on top. Both launchers are shipped and the Quick Switch preference switches
between them, so enabling it is safe.

### Bypass charging

`BoardConfig.mk` sets `lineage_health charging_control_supports_bypass=true`
alongside the existing `input_suspend` toggle paths
(`/sys/class/qcom-battery/input_suspend`, enabled `0`, disabled `1`). The health
HAL then reports `BYPASS` and Settings can drive it.

### About phone

`AboutPhoneData.java` reads `ro.mist.{soc,platform,display,screen,battery,camera,front}`.
`configs/properties/product.prop` sets:

```
ro.mist.soc=Snapdragon® 6s Gen 2
ro.mist.platform=SM6225-AF
ro.mist.display=1080 x 2396 px, 120 Hz
ro.mist.screen=6.99" AMOLED
ro.mist.battery=7700 mAh
ro.mist.camera=50MP
ro.mist.front=16MP
```

`ro.mist.codename` is owned by `version.mk` (`MIST_CODENAME`) and must not be
duplicated.

The values live in `product.prop` because `PRODUCT_*PROPERTIES` is a make word
list: a value containing spaces is split there and the installed prop keeps only
the first word. The 1226 build shipped `ro.mist.display=1080`,
`ro.mist.soc=Snapdragon®`, and so on for exactly that reason. `product.prop` is
installed verbatim, so the full strings (including the space in `6.99" AMOLED`)
survive. Do not quote the values; the quote characters would be stored too.

## Patches

`patches/` is applied in filename order by `apply.sh`; every patch is validated
with `git apply --check` and already-present patches are skipped.

Kept from the Lineage 24.0 set because they are device/generic, not
Lineage-feature, fixes: recovery/vold/libbase standard-library includes,
Soong build UI, tinyalsa enum text, qcom sepolicy prebuilt-dir/Tango/genfscon
fixes, codec2/OMX (`frameworks/av`), the framework device fixes (StorageManager
transcoding thread, IMS `isMiuiRom` stub, VoLTE slot, shade occlusion, UDFPS,
face provider), Wi-Fi multi-STA hint (AIDL and legacy), protobuf/display-info
shims, FOD `extCmd`, thermal ramp, audio `libqcompostprocbundle`, Dialer
proximity, `system/sepolicy` labeling test, `tools/extract-utils` symlink
names, `vendor/lineage` kernel-generator undefined variables, QTI power AIDL
declaration, QTI vibrator trigger setup, and the kernel/techpack/DTS patches.

Dropped as Lineage-specific:

* `packages/apps/Launcher3/0001-respect-the-live-window-blur-state.patch` —
  Lineage Launcher3 blur surfaces; Mist ships its own Launcher3 and the patch
  does not apply. Mist's blur is enabled through `TARGET_ENABLE_BLUR`.
* `packages/apps/Settings` Lineage series — its display blur preference and
  `DISABLE_WINDOW_BLURS` UI are Lineage-specific. Only the
  `EnableVerboseVendorLoggingPreferenceController` ANR fix was kept, re-captured
  against Mist (`getService()` instead of the blocking
  `waitForDeclaredService()`).

Mist's own `frameworks/base` already contains the Paranoid Sense face provider,
the keyguard top-indication section and the face bouncer callbacks, so the
Lineage face hunks that conflicted were dropped; the adapted
`frameworks/base/0001-zephyr-framework-fixes.patch` contains only the changes
that were genuinely missing from Mist.

`system/vold` was re-captured against Mist's `IdleMaint.cpp` (different include
context). `capture.sh <project> "<subject>"` regenerates a series after an edit.

## Build type

`zephyr` is not listed in `mist-maintainers/mist.devices`, so
`vendor/lineage/config/version.mk` sets `MIST_BUILD_TYPE := UNOFFICIAL`. The
zip filename, `ro.mist.buildtype`, and `ro.mist.version` all carry that value.
`MISTOS_MAINTAINER := uzbforce` is only builder credit; it does not make the
build official.

Earlier artifacts with `-OFFICIAL` in the name were produced while this tree
still registered `zephyr`/`uzbforce` in `mist-maintainers`. They must not be
published or distributed as official MistOS builds. Rebuilds from this tree
produce `UNOFFICIAL` images.

### Vanilla variant

`WITH_GMS` defaults to `true`, so the normal build remains GAPPS. Set
`WITH_GMS=false` for VANILLA. The 2026-11-24 vanilla build was produced in the
existing `out/` tree:

```bash
export WITH_GMS=false
source build/envsetup.sh
lunch lineage_zephyr-cp2a-userdebug
mka installclean   # remove GMS-installed files from the GAPPS build
mka bacon
```

A clean `OUT_DIR=out-vanilla` build currently fails in Lineage's
`generated_kernel_includes` generator: its sbox manifest omits
`kernel/.../scripts/Makefile.extrawarn` and `bionic/.../clean_header.py`.
Reusing the already-generated headers from `out/` works; the separate output
tree needs that generator fixed before it can be built from scratch.

## Current state

Both OTAs are UNOFFICIAL, 2026-11-24, `cp2a-userdebug`:

```text
out/target/product/zephyr/MistOS-5.2-Stable-17.0-GAPPS-20261124-1403-zephyr-UNOFFICIAL.zip   (3.0 GB)
out/target/product/zephyr/MistOS-5.2-Stable-17.0-VANILLA-20261124-1502-zephyr-UNOFFICIAL.zip  (1.9 GB)
```

`ro.mist.buildtype=UNOFFICIAL`; the two packages differ by
`ro.mist.packagetype`. The GAPPS images in `out/` were replaced by the vanilla
build, but the GAPPS OTA zip is preserved. Build logs:
`../../mist-build.log` and `../../mist-build-vanilla-inout.log`.
