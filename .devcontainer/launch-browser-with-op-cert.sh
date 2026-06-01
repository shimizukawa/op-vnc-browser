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
	export OP_CERT_P12_PATH OP_CERT_PASSWORD_PATH
fi

log_dir="$HOME/.cache/op-vnc-browser"
log_path="$log_dir/launcher.log"
mkdir -p "$log_dir"

log_line() {
	printf '%s pid=%s kind=%s %s\n' "$(date -Iseconds)" "$$" "$browser_kind" "$1" >> "$log_path"
}

available_kb() {
	local dir_path="$1"
	df -Pk "$dir_path" 2>/dev/null | awk 'NR==2 {print $4}'
}

select_tmp_parent() {
	local required_kb="$1"
	local free_kb
	local candidate="${OP_BROWSER_TMP_PARENT:-}"

	if [[ -z "$candidate" ]]; then
		echo "OP_BROWSER_TMP_PARENT is not set; configure a dedicated ephemeral mount for browser state" >&2
		exit 1
	fi
	if [[ ! -d "$candidate" || ! -w "$candidate" ]]; then
		echo "OP_BROWSER_TMP_PARENT is not writable: $candidate" >&2
		exit 1
	fi

	free_kb="$(available_kb "$candidate")"
	if [[ -z "$free_kb" ]]; then
		echo "could not determine free space for OP_BROWSER_TMP_PARENT: $candidate" >&2
		exit 1
	fi
	if (( free_kb < required_kb )); then
		echo "OP_BROWSER_TMP_PARENT does not have enough free space: $candidate (${free_kb}KB < ${required_kb}KB)" >&2
		exit 1
	fi

	echo "$candidate"
}

language_env=(LANGUAGE=ja LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8)

launch_browser() {
	log_line "mode=plain home=$HOME config=$config_path args=$*"
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

if [[ -z "${OP_CERT_P12_PATH:-}" || -z "${OP_CERT_PASSWORD_PATH:-}" ]]; then
	launch_browser "$@"
fi

require_command() {
	local command_name="$1"
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "$command_name is required when OP_CERT_P12_REF and OP_CERT_PASSWORD_REF are set" >&2
		exit 1
	fi
}

require_command certutil
require_command pk12util

if [[ ! -r "$OP_CERT_P12_PATH" || ! -r "$OP_CERT_PASSWORD_PATH" ]]; then
	log_line "mode=plain missing_materialized_cert p12=${OP_CERT_P12_PATH:-unset} pass=${OP_CERT_PASSWORD_PATH:-unset}"
	launch_browser "$@"
fi

log_line "mode=secure home=$HOME config=$config_path staged_p12=$OP_CERT_P12_PATH staged_password=$OP_CERT_PASSWORD_PATH"

required_tmp_kb=131072

tmp_parent="$(select_tmp_parent "$required_tmp_kb")"
log_line "tmp_parent=$tmp_parent required_kb=$required_tmp_kb"

tmp_root="$(mktemp -d "$tmp_parent/op-browser-XXXXXX")"
cleanup() {
	rm -rf "$tmp_root"
}
trap cleanup EXIT

p12_path="$tmp_root/client-cert.p12"
cp "$OP_CERT_P12_PATH" "$p12_path"
p12_password="$(cat "$OP_CERT_PASSWORD_PATH")"

case "$browser_kind" in
	firefox)
		profile_dir="$tmp_root/firefox-profile"
		mkdir -p "$profile_dir"
		certutil -N -d "sql:$profile_dir" --empty-password
		pk12util -i "$p12_path" -d "sql:$profile_dir" -W "$p12_password"
		log_line "launch profile=$profile_dir browser=$browser_bin"
		exec env "${language_env[@]}" "$browser_bin" --profile "$profile_dir" --no-remote "$@"
		;;
	chrome)
		home_dir="$tmp_root/home"
		profile_dir="$tmp_root/chrome-profile"
		mkdir -p "$home_dir/.pki/nssdb" "$profile_dir"
		certutil -N -d "sql:$home_dir/.pki/nssdb" --empty-password
		pk12util -i "$p12_path" -d "sql:$home_dir/.pki/nssdb" -W "$p12_password"
		log_line "launch profile=$profile_dir home_override=$home_dir browser=$browser_bin"
		exec env HOME="$home_dir" "${language_env[@]}" "$browser_bin" --lang=ja --no-sandbox --disable-dev-shm-usage --user-data-dir="$profile_dir" --no-first-run --password-store=basic "$@"
		;;
	*)
		echo "unsupported browser kind: $browser_kind" >&2
		exit 64
		;;
esac