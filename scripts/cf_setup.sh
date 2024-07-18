#!/usr/bin/env bash

set -xe

CF_HOME="aosp_cf_x86_64_phone"

setup_cf_env() {
  # Install Bazel first
  sudo apt install apt-transport-https curl gnupg -y
  curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
  sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
  sudo apt update && sudo apt install bazel

  # Build Android Cuttlefish
  git clone https://github.com/google/android-cuttlefish
  cd android-cuttlefish
  tools/buildutils/build_packages.sh
  sudo dpkg -i ./cuttlefish-base_*_*64.deb || sudo apt-get install -f
  cd ../
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
  sudo udevadm control --reload-rules
  sudo udevadm trigger
  sudo usermod -aG kvm,cvdnetwork,render $USER
}

download_cf() {
  local BUILD_ID=$(curl -sL https://ci.android.com/builds/branches/aosp-main/status.json | \
    jq -r '.targets[] | select(.name == "aosp_cf_x86_64_phone-trunk_staging-userdebug") | .last_known_good_build')
  local SYS_IMG_URL="https://ci.android.com/builds/submitted/${BUILD_ID}/aosp_cf_x86_64_phone-trunk_staging-userdebug/latest/raw/aosp_cf_x86_64_phone-img-${BUILD_ID}.zip"
  local HOST_PKG_URL="https://ci.android.com/builds/submitted/${BUILD_ID}/aosp_cf_x86_64_phone-trunk_staging-userdebug/latest/raw/cvd-host_package.tar.gz"
  curl -L $SYS_IMG_URL -o cf-img.zip
  curl -LO $HOST_PKG_URL
  tar xvf cvd-host_package.tar.gz
  unzip cf-img.zip
}

run_cf() {
  HOME=$(pwd) ./bin/launch_cvd --daemon --resume=false
  adb devices
}

mkdir -p $CF_HOME
cd $CF_HOME

case "$1" in
  setup )
    setup_cf_env
    download_cf
    ;;
  run )
    run_cf
    ;;
  * )
    exit 1
    ;;
esac
