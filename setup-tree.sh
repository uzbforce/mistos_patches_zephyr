#!/usr/bin/env bash
# Materialize the zephyr repos into a MistOS checkout and apply the patches.
#
# Usage: ./setup-tree.sh /path/to/mistos-checkout
#
# The repos are copied, not symlinked: Soong's module-path scanner does not
# descend into symlinked directories, so the product would be invisible.
# REPOS_DIR can point at another copy of the repos/ tree (default: ../repos).

set -euo pipefail

root="$(realpath "${1:-${ANDROID_BUILD_TOP:-$PWD}}")"
here="$(cd "$(dirname "$0")" && pwd)"
repos="${REPOS_DIR:-$here/../repos}"

if [ ! -d "$root/build/make" ]; then
    echo "$root does not look like a ROM checkout (no build/make)" >&2
    exit 1
fi
if [ ! -d "$repos" ]; then
    echo "repos directory not found: $repos (set REPOS_DIR)" >&2
    exit 1
fi

copy() {
    local src="$1" dst="$2"
    echo "  $dst"
    mkdir -p "$(dirname "$root/$dst")"
    rm -rf "$root/$dst"
    cp -a --reflink=auto "$repos/$src" "$root/$dst"
}

echo "Copying repos into $root"
copy android_device_xiaomi_zephyr            device/xiaomi/zephyr
copy android_vendor_xiaomi_zephyr            vendor/xiaomi/zephyr
copy zephyr-kernel                           device/xiaomi/zephyr-kernel
copy kernel_xiaomi_zephyr                    kernel/xiaomi/zephyr
copy android_hardware_qcom-caf_common        hardware/qcom-caf/common
copy android_device_qcom_sepolicy_vndr_sm6225 device/qcom/sepolicy_vndr/sm6225
copy android_hardware_qcom-caf_sm6225_audio_agm         hardware/qcom-caf/sm6225/audio/agm
copy android_hardware_qcom-caf_sm6225_audio_pal         hardware/qcom-caf/sm6225/audio/pal
copy android_hardware_qcom-caf_sm6225_audio_primary-hal hardware/qcom-caf/sm6225/audio/primary-hal
copy android_hardware_qcom-caf_sm6225_dataipa           hardware/qcom-caf/sm6225/dataipa
copy android_hardware_qcom-caf_sm6225_data-ipa-cfg-mgr  hardware/qcom-caf/sm6225/data-ipa-cfg-mgr

echo "Creating platform link files"
mkdir -p "$root/hardware/qcom" "$root/hardware/qcom-caf/sm6225/audio"
ln -sfn ../qcom-caf/common/os_pickup_aosp.mk "$root/hardware/qcom/Android.mk"
ln -sfn ../../../hardware/qcom-caf/common/os_pickup_sepolicy_vndr.mk \
    "$root/device/qcom/sepolicy_vndr/SEPolicy.mk"
ln -sfn ../common/os_pickup_qssi.bp "$root/hardware/qcom-caf/sm6225/Android.bp"
ln -sfn ../common/os_pickup.mk      "$root/hardware/qcom-caf/sm6225/Android.mk"
ln -sfn ../../common/os_pickup_audio-ar.mk \
    "$root/hardware/qcom-caf/sm6225/audio/Android.mk"

# Do not register zephyr/uzbforce here. This tree is an unofficial build;
# official status is assigned by the MistOS maintainers, not by this script.
# Leaving the device out of mist.devices makes version.mk emit UNOFFICIAL.

# AVB signing key. Reuse keys/ next to this script when it exists, otherwise
# generate a local key so recovery.img/vbmeta can be produced on a fresh tree.
if [ ! -f "$root/vendor/lineage-priv/keys/avb.pem" ]; then
    if [ -d "$here/keys" ]; then
        mkdir -p "$root/vendor/lineage-priv/keys"
        cp -a "$here/keys/." "$root/vendor/lineage-priv/keys/"
    else
        echo "Generating a local AVB signing key"
        mkdir -p "$root/vendor/lineage-priv/keys"
        openssl genrsa -out "$root/vendor/lineage-priv/keys/avb.pem" 4096
        if [ -x "$root/out/host/linux-x86/bin/avbtool" ]; then
            AVBTOOL="$root/out/host/linux-x86/bin/avbtool"
        else
            AVBTOOL="python3 $root/external/avb/avbtool"
        fi
        $AVBTOOL extract_public_key --key "$root/vendor/lineage-priv/keys/avb.pem" \
            --output "$root/vendor/lineage-priv/keys/avb_pkmd.bin"
    fi
fi

# Applying patches needs the projects to be git checkouts (they are, since the
# repos are copies of the repo-managed trees).
"$here/apply.sh" "$root"

cat <<EOF

Done. Build with:
  cd $root
  source build/envsetup.sh
  lunch lineage_zephyr-cp2a-userdebug
  mka bacon
EOF
