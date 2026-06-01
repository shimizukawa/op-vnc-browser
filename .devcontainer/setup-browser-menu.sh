#!/bin/bash
set -euo pipefail

install_root="$HOME/.local/share/op-vnc-browser"
bin_dir="$HOME/.local/bin"
cache_dir="$HOME/.cache/op-vnc-browser"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
firefox_dir="$install_root/firefox"
chrome_dir="$install_root/google-chrome"
firefox_locale="ja"
firefox_version="151.0.2"
secure_launcher="$install_root/launch-browser-with-op-cert.sh"
firefox_bin="$bin_dir/firefox"
chrome_bin="$bin_dir/google-chrome"
chromium_browser_bin="$bin_dir/chromium-browser"
x_www_browser_bin="$bin_dir/x-www-browser"

mkdir -p "$HOME/.fluxbox" "$bin_dir" "$cache_dir" "$install_root"

download_firefox() {
   if [[ -x "$firefox_dir/firefox" && -f "$firefox_dir/.op-vnc-browser-locale" ]] && [[ "$(<"$firefox_dir/.op-vnc-browser-locale")" == "$firefox_locale" ]]; then
		return
	fi

   local archive="$cache_dir/firefox.tar.xz"
   rm -rf "$firefox_dir"
   curl --noproxy '*' -fsSL -A 'Mozilla/5.0' "https://download-installer.cdn.mozilla.net/pub/firefox/releases/${firefox_version}/linux-x86_64/${firefox_locale}/firefox-${firefox_version}.tar.xz" -o "$archive"
	rm -rf "$firefox_dir"
   tar -xJf "$archive" -C "$install_root"
	if [[ -d "$install_root/firefox" ]]; then
      echo "$firefox_locale" > "$install_root/firefox/.op-vnc-browser-locale"
		return
	fi
	if [[ -d "$install_root/firefox-esr" ]]; then
		mv "$install_root/firefox-esr" "$firefox_dir"
      echo "$firefox_locale" > "$firefox_dir/.op-vnc-browser-locale"
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

configure_novnc_language() {
   local novnc_dir
   novnc_dir="$(find /usr/local/novnc -maxdepth 1 -type d -name 'noVNC-*' | head -n 1)"
   if [[ -z "$novnc_dir" ]]; then
      return
   fi

   if [[ -f "$novnc_dir/vnc.html" ]]; then
      sudo sed -i 's#<html lang="en"#<html lang="ja"#' "$novnc_dir/vnc.html"
   fi

   if [[ -f "$novnc_dir/app/localization.js" ]]; then
      sudo sed -i "s/this.language = 'en';\/\/ Default: US English/this.language = 'ja';\/\/ Default: Japanese/" "$novnc_dir/app/localization.js"
      sudo sed -i "0,/this.language = 'en';/s//this.language = 'ja';/" "$novnc_dir/app/localization.js"
   fi
}

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

cat > "$HOME/.fluxbox/overlay" <<EOF
window.font: IPAGothic-10
menu.title.font: IPAGothic-10:bold
menu.frame.font: IPAGothic-10
toolbar.clock.font: IPAGothic-10
toolbar.workspace.font: IPAGothic-10
toolbar.iconbar.focused.font: IPAGothic-10:bold
toolbar.iconbar.unfocused.font: IPAGothic-10
EOF

configure_novnc_language

install -m 755 "$script_dir/launch-browser-with-op-cert.sh" "$secure_launcher"

write_launcher "$firefox_bin" "$firefox_dir/firefox" firefox
write_launcher "$chrome_bin" "$chrome_dir/opt/google/chrome/google-chrome" chrome
write_launcher "$chromium_browser_bin" "$chrome_dir/opt/google/chrome/google-chrome" chrome
write_launcher "$x_www_browser_bin" "$chrome_dir/opt/google/chrome/google-chrome" chrome

download_firefox
download_chrome

echo "Fluxbox menu updated with Firefox and Chrome"
