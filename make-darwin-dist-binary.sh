#!/usr/bin/env bash

set -euo pipefail;

function replace_sys_libs() {
	local file="$1"

	local libs=$(otool -L "$file" | tail -n +2 | sed 's/^[[:space:]]*//' | cut -d' ' -f1)

	local libiconv=$(echo "$libs" | grep libiconv || :)
	local libcxx=$(echo "$libs" | grep libcxx || :)

	chmod +wx "$file"

	[ -n "${libiconv}" ] && install_name_tool -change "$libiconv" /usr/lib/libiconv.dylib "$file"

	[ -n "${libcxx}" ] && install_name_tool -change "$libcxx" /usr/lib/libc++.1.dylib "$file"
}

function make_dist_binary() {
	g_binaries=()

	local binaries=("$@")

	for a in ${binaries[@]}; do

		local binary_file="$a"
		local binary_name=$(basename $binary_file)

		if [[ -f "$binary_file" ]]; then

			echo "replace $binary_file libs..."

			local arch=$(lipo -archs "$binary_file")
			local to_arch_dir="dist/${arch}-darwin"
			mkdir -p $to_arch_dir

			cp $binary_file $to_arch_dir

			local file="$to_arch_dir/$binary_name"
			g_binaries+=($file)
			replace_sys_libs $file
		fi

	done
	unset a
}

function nix_build_all_darwin() {
	local app="$1"
	shift

	local binaries=("$@")

	for src in ${binaries[@]}; do
		local result_dir=$(echo $src | awk -F '/' '{print $1}')
		local system=$(echo $result_dir | awk -F '.' '{print $2}')
		nix build --system $system -o $result_dir $app

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
	lipo -create "${dest_binaries[@]}" -output $result_dir/$binary_name

	echo "results:"
	tree dist
}

function make_binary() {
    local binary="$1"
    local nix_app="$2"
    local source_binaries=("result.aarch64-darwin/bin/$binary" "result.x86_64-darwin/bin/$binary")

    nix_build_all_darwin $nix_app "${source_binaries[@]}"
    make_dist_binary "${source_binaries[@]}"
    make_universal "$binary" "${g_binaries[@]}"
}

make_binary "kp" ".#kompose-cli"
#make_binary "nickel" ".#nickel-lang-cli"
make_binary "nls" ".#lsp-nls"

## you may need to run `publish-khaos-to-mirrors.sh dist/darwin-universal/nickel`

