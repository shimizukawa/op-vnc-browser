#!/bin/bash
set -euo pipefail

install_root="$HOME/.local/share/op-vnc-browser"
bin_dir="$HOME/.local/bin"
cache_dir="$HOME/.cache/op-vnc-browser"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
firefox_dir="$install_root/firefox"
chrome_dir="$install_root/google-chrome"
secure_launcher="$install_root/launch-browser-with-op-cert.sh"
firefox_bin="$bin_dir/firefox"
chrome_bin="$bin_dir/google-chrome"
chromium_browser_bin="$bin_dir/chromium-browser"
x_www_browser_bin="$bin_dir/x-www-browser"

mkdir -p "$HOME/.fluxbox" "$bin_dir" "$cache_dir" "$install_root"

download_firefox() {
	if [[ -x "$firefox_dir/firefox" ]]; then
		return
	fi

   local archive="$cache_dir/firefox.tar.xz"
   curl --noproxy '*' -fsSL -A 'Mozilla/5.0' "https://download-installer.cdn.mozilla.net/pub/firefox/releases/151.0.2/linux-x86_64/en-US/firefox-151.0.2.tar.xz" -o "$archive"
	rm -rf "$firefox_dir"
   tar -xJf "$archive" -C "$install_root"
	if [[ -d "$install_root/firefox" ]]; then
		return
	fi
	if [[ -d "$install_root/firefox-esr" ]]; then
		mv "$install_root/firefox-esr" "$firefox_dir"
	fi
}

download_chrome() {
	if [[ -x "$chrome_dir/opt/google/chrome/google-chrome" ]]; then
		return
	fi

   curl --noproxy '*' -fsSL -A 'Mozilla/5.0' "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$cache_dir/google-chrome-stable_current_amd64.deb"
	rm -rf "$chrome_dir"
	mkdir -p "$chrome_dir"
	dpkg-deb -x "$cache_dir/google-chrome-stable_current_amd64.deb" "$chrome_dir"
}

write_launcher() {
	local path="$1"
	local target="$2"
   local browser_kind="$3"
	cat > "$path" <<EOF
#!/bin/sh
exec "$secure_launcher" "$target" "$browser_kind" "\$@"
EOF
	chmod +x "$path"
}

download_firefox
download_chrome
install -m 755 "$script_dir/launch-browser-with-op-cert.sh" "$secure_launcher"

write_launcher "$firefox_bin" "$firefox_dir/firefox" firefox
write_launcher "$chrome_bin" "$chrome_dir/opt/google/chrome/google-chrome" chrome
write_launcher "$chromium_browser_bin" "$chrome_dir/opt/google/chrome/google-chrome" chrome
write_launcher "$x_www_browser_bin" "$chrome_dir/opt/google/chrome/google-chrome" chrome

cat > "$HOME/.fluxbox/menu" <<EOF
[begin] (Fluxbox)
   [submenu] (Applications) {}
      [submenu] (Network) {}
         [submenu] (Web Browsing) {}
            [exec] (Firefox) {$firefox_bin} <>
            [exec] (Chrome) {$chrome_bin} <>
            [exec] (Web Browser) {$x_www_browser_bin} <>
            [exec] (Lynx) { x-terminal-emulator -T "Lynx" -e lynx} <>
         [end]
      [end]
      [submenu] (Shells) {}
         [exec] (Bash) { x-terminal-emulator -T "Bash" -e /bin/bash --login} <>
         [exec] (Dash) { x-terminal-emulator -T "Dash" -e /bin/dash -i} <>
         [exec] (fish) { x-terminal-emulator -T "fish" -e /usr/bin/fish} <>
         [exec] (Sh) { x-terminal-emulator -T "Sh" -e /bin/sh --login} <>
         [exec] (Zsh) { x-terminal-emulator -T "Zsh" -e /bin/zsh} <>
      [end]
      [submenu] (System) {}
         [submenu] (Administration) {}
            [exec] (Editres) {editres} <>
            [exec] (Xfontsel) {xfontsel} <>
            [exec] (Xkill) {xkill} <>
         [end]
         [submenu] (Monitoring) {}
            [exec] (Xev) {x-terminal-emulator -e xev} <>
         [end]
      [end]
   [end]
   [submenu] (Window Managers) {}
      [restart] (FluxBox)  {/usr/bin/startfluxbox}
   [end]

   [config] (Configuration)
   [submenu] (Styles) {}
      [stylesdir] (/usr/share/fluxbox/styles)
      [stylesdir] (~/.fluxbox/styles)
   [end]
   [workspaces] (Workspaces)
   [reconfig] (Reconfigure)
   [restart] (Restart)
   [exit] (Exit)

[end]
EOF

echo "Fluxbox menu updated with Firefox and Chrome"
