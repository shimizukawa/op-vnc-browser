#!/bin/bash
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
	echo "usage: $0 <browser-binary> <firefox|chrome> [args...]" >&2
	exit 64
fi

browser_bin="$1"
browser_kind="$2"
shift 2

config_path="${OP_BROWSER_ENV_FILE:-$HOME/.config/op-vnc-browser/launcher.env}"
if [[ -f "$config_path" ]]; then
	# shellcheck disable=SC1090
	. "$config_path"
	export OP_CERT_P12_REF OP_CERT_PASSWORD_REF
fi

language_env=(LANGUAGE=ja LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8)

launch_browser() {
	case "$browser_kind" in
		firefox)
			exec env "${language_env[@]}" "$browser_bin" "$@"
			;;
		chrome)
			exec env "${language_env[@]}" "$browser_bin" --lang=ja "$@"
			;;
		*)
			echo "unsupported browser kind: $browser_kind" >&2
			exit 64
			;;
	esac
}

if [[ -z "${OP_CERT_P12_REF:-}" || -z "${OP_CERT_PASSWORD_REF:-}" ]]; then
	launch_browser "$@"
fi

require_command() {
	local command_name="$1"
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "$command_name is required when OP_CERT_P12_REF and OP_CERT_PASSWORD_REF are set" >&2
		exit 1
	fi
}

require_command op
require_command certutil
require_command pk12util

tmp_parent="${TMPDIR:-/tmp}"
if [[ -d /dev/shm && -w /dev/shm ]]; then
	tmp_parent="/dev/shm"
fi

tmp_root="$(mktemp -d "$tmp_parent/op-browser-XXXXXX")"
cleanup() {
	rm -rf "$tmp_root"
}
trap cleanup EXIT

p12_path="$tmp_root/client-cert.p12"
op read --out-file "$p12_path" "$OP_CERT_P12_REF"
p12_password="$(op read "$OP_CERT_PASSWORD_REF")"

case "$browser_kind" in
	firefox)
		profile_dir="$tmp_root/firefox-profile"
		mkdir -p "$profile_dir"
		certutil -N -d "sql:$profile_dir" --empty-password
		pk12util -i "$p12_path" -d "sql:$profile_dir" -W "$p12_password"
		exec env "${language_env[@]}" "$browser_bin" --profile "$profile_dir" --no-remote "$@"
		;;
	chrome)
		home_dir="$tmp_root/home"
		profile_dir="$tmp_root/chrome-profile"
		mkdir -p "$home_dir/.pki/nssdb" "$profile_dir"
		certutil -N -d "sql:$home_dir/.pki/nssdb" --empty-password
		pk12util -i "$p12_path" -d "sql:$home_dir/.pki/nssdb" -W "$p12_password"
		exec env HOME="$home_dir" "${language_env[@]}" "$browser_bin" --lang=ja --user-data-dir="$profile_dir" --no-first-run --password-store=basic "$@"
		;;
	*)
		echo "unsupported browser kind: $browser_kind" >&2
		exit 64
		;;
esac