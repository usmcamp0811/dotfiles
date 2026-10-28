#!/usr/bin/env bash
# Open a built OKF site in a browser. Nix fills in @name@ and @site@.
set -euo pipefail

name="@name@"
site="@site@"
python="@python@"

usage() {
  cat <<EOF
Usage: $name [options] [PAGE]

Open the documentation site in a browser. The pages are plain files and work offline;
with --serve they are served over HTTP instead, for other machines to read.

  PAGE                  a page relative to the site, e.g. modules/nixos/services/niks3/README.html
  -s, --search QUERY    open the search page for QUERY (type:Guide, tag:vault, ...)
  -t, --theme THEME     use a theme: navy, navy-light, usmc, docusaurus, field-manual, trail-map, manpage, lantern, toc, okf-visualizer or okf-visualizer-dark
  -b, --browser CMD     browser command; may include arguments
  -p, --print           print the URL and do not open or serve anything
      --serve           serve the site over HTTP instead of opening a browser
      --bind ADDR       address to serve on (default 127.0.0.1; 0.0.0.0 for every interface)
      --port PORT       port to serve on (default 8080)
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
serve=0
bind="127.0.0.1"
port="8080"

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
      case "$2" in navy|navy-light|usmc|docusaurus|field-manual|trail-map|manpage|lantern|toc|okf-visualizer|okf-visualizer-dark) theme="$2" ;; *)
        echo "$name: unknown theme: $2" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    -p | --print)
      print_only=1
      shift
      ;;
    --serve)
      serve=1
      shift
      ;;
    --bind)
      [ $# -ge 2 ] || { echo "$name: $1 needs an address" >&2; exit 2; }
      bind="$2"
      shift 2
      ;;
    --port)
      [ $# -ge 2 ] || { echo "$name: $1 needs a port" >&2; exit 2; }
      case "$2" in '' | *[!0-9]*) echo "$name: bad port: $2" >&2; exit 2 ;; esac
      port="$2"
      shift 2
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
if [ "$serve" -eq 1 ]; then
  # A wildcard address is not one a browser can visit, so print localhost for it.
  case "$bind" in 0.0.0.0 | :: | '') shown="localhost" ;; *:*) shown="[$bind]" ;; *) shown="$bind" ;; esac
  url="http://$shown:$port/$page"
else
  url="file://$site/$page"
fi
if [ -n "$theme" ]; then
  if [[ "$url" == *\?* ]]; then url+="&theme=$(urlencode "$theme")"; else url+="?theme=$(urlencode "$theme")"; fi
fi

if [ "$print_only" -eq 1 ]; then
  printf '%s\n' "$url"
  exit 0
fi

if [ "$serve" -eq 1 ]; then
  echo "$name: serving $site on $bind:$port (Ctrl-C to stop)" >&2
  echo "$name: $url" >&2
  exec "$python" -m http.server "$port" --bind "$bind" --directory "$site"
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
