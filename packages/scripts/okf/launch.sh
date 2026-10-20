#!/usr/bin/env bash
# Open a built OKF site in a browser. Nix fills in @name@ and @site@.
set -euo pipefail

name="@name@"
site="@site@"

usage() {
  cat <<EOF
Usage: $name [options] [PAGE]

Open the documentation site in a browser. Nothing is served: the pages are plain
files and work offline.

  PAGE                  a page relative to the site, e.g. modules/nixos/services/niks3/README.html
  -s, --search QUERY    open the search page for QUERY (type:Guide, tag:vault, ...)
  -t, --theme THEME     use a theme: field-manual, trail-map, manpage, lantern, toc, okf-visualizer or okf-visualizer-dark
  -b, --browser CMD     browser command; may include arguments
  -p, --print           print the URL and do not open anything
  -h, --help            show this help

Browser, first match wins: --browser, \$OKF_BROWSER, \$BROWSER, then qutebrowser,
firefox, brave, chromium, google-chrome-stable, xdg-open.
EOF
}

urlencode() {
  local text="$1" out="" i char
  for ((i = 0; i < ${#text}; i++)); do
    char="${text:i:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) out+="$char" ;;
      *) out+="$(printf '%%%02X' "'$char")" ;;
    esac
  done
  printf '%s' "$out"
}

browser="${OKF_BROWSER:-}"
page="index.html"
print_only=0
theme=""

while [ $# -gt 0 ]; do
  case "$1" in
    -b | --browser)
      [ $# -ge 2 ] || { echo "$name: $1 needs a command" >&2; exit 2; }
      browser="$2"
      shift 2
      ;;
    -s | --search)
      [ $# -ge 2 ] || { echo "$name: $1 needs a query" >&2; exit 2; }
      page="search.html?q=$(urlencode "$2")"
      shift 2
      ;;
    -t | --theme)
      [ $# -ge 2 ] || { echo "$name: $1 needs a theme" >&2; exit 2; }
      case "$2" in field-manual|trail-map|manpage|lantern|toc|okf-visualizer|okf-visualizer-dark) theme="$2" ;; *)
        echo "$name: unknown theme: $2" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    -p | --print)
      print_only=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "$name: unknown option $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      page="$1"
      shift
      ;;
  esac
done

file="${page%%\?*}"
if [ ! -f "$site/$file" ]; then
  echo "$name: no such page: $file" >&2
  exit 1
fi
url="file://$site/$page"
if [ -n "$theme" ]; then
  if [[ "$url" == *\?* ]]; then url+="&theme=$(urlencode "$theme")"; else url+="?theme=$(urlencode "$theme")"; fi
fi

if [ "$print_only" -eq 1 ]; then
  printf '%s\n' "$url"
  exit 0
fi

cmd=()
if [ -n "$browser" ]; then
  read -r -a cmd <<<"$browser"
elif [ -n "${BROWSER:-}" ]; then
  read -r -a cmd <<<"$BROWSER"
else
  for candidate in qutebrowser firefox brave brave-browser chromium chromium-browser google-chrome-stable xdg-open; do
    if command -v "$candidate" >/dev/null 2>&1; then
      cmd=("$candidate")
      break
    fi
  done
fi

if [ "${#cmd[@]}" -eq 0 ] || ! command -v "${cmd[0]}" >/dev/null 2>&1; then
  echo "$name: no browser found${cmd[0]:+ (${cmd[0]} is not on PATH)}; set OKF_BROWSER or pass --browser." >&2
  echo "Open this yourself: $url" >&2
  exit 1
fi

exec "${cmd[@]}" "$url"
