#!/usr/bin/env bash

set -euo pipefail

function replace_sys_libs() {
  local file="$1"
  local libs
  local libiconv
  local libcxx

  libs=$(otool -L "$file" | tail -n +2 | sed 's/^[[:space:]]*//' | cut -d' ' -f1)

  libiconv=$(echo "$libs" | grep libiconv || :)
  libcxx=$(echo "$libs" | grep libcxx || :)

  chmod +wx "$file"

  if [ -n "${libiconv}" ]; then
    install_name_tool -change "$libiconv" /usr/lib/libiconv.dylib "$file"
  fi

  if [ -n "${libcxx}" ]; then
    install_name_tool -change "$libcxx" /usr/lib/libc++.1.dylib "$file"
  fi
}

function make_dist_binary() {

  g_binaries=()

  local binaries=("$@")
  local binary_name
  local arch

  for a in "${binaries[@]}"; do

    local binary_file="$a"
    binary_name=$(basename "$binary_file")

    if [[ -f "$binary_file" ]]; then

      echo "replace $binary_file libs..."

      arch=$(lipo -archs "$binary_file")
      local to_arch_dir="dist/${arch}-darwin"
      mkdir -p "$to_arch_dir"

      cp "$binary_file" "$to_arch_dir"

      local file="$to_arch_dir/$binary_name"
      g_binaries+=("$file")
      replace_sys_libs "$file"
    fi

  done
  unset a
}

function nix_build_all_darwin() {
  local app="$1"
  local result_dir system
  shift

  local binaries=("$@")

  for src in "${binaries[@]}"; do
    result_dir=$(echo "$src" | awk -F '/' '{print $1}')
    system=$(echo "$result_dir" | awk -F '.' '{print $2}')
    nix build --system "$system" -o "$result_dir" "$app"

    # nix build --system aarch64-darwin -o result.aarch64-darwin .#nickel-lang-cli
    # nix build --system x86_64-darwin -o result.x86_64-darwin .#nickel-lang-cli

  done
}

function make_universal() {
  local binary_name="$1"
  shift
  local dest_binaries=("$@")

  local result_dir=dist/darwin-universal
  mkdir -p $result_dir
  lipo -create "${dest_binaries[@]}" -output $result_dir/"$binary_name"

  echo "results:"
  tree dist
}

function make_binary() {
  local binary="$1"
  local nix_app="$2"
  local source_binaries=("result.aarch64-darwin/bin/$binary" "result.x86_64-darwin/bin/$binary")

  nix_build_all_darwin "$nix_app" "${source_binaries[@]}"
  make_dist_binary "${source_binaries[@]}"
  make_universal "$binary" "${g_binaries[@]}"
}

make_binary "kp" ".#kompose-cli"
make_binary "nls" ".#nickel-lang-lsp"

## you may need to run `publish-khaos-to-mirrors.sh dist/darwin-universal/nickel`
