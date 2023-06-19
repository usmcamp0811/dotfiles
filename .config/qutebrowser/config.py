import subprocess
import os
from qutebrowser.api import interceptor
import sys

# import catppuccin

config.load_autoconfig(False)

# config.source("themes/onedark.py")
config.source("themes/city-lights-theme.py")
# set the flavour you'd like to use
# valid options are 'mocha', 'macchiato', 'frappe', and 'latte'
# catppuccin.setup(c, "mocha")

c.content.autoplay = False
autoplay_domains = []
try:
    with open(config.configdir / "secret_autoplay_false", "r") as saf:
        autoplay_domains += [l.strip() for l in saf if l.strip()]
except FileNotFoundError:
    pass
for dom in autoplay_domains:
    with config.pattern("*://*." + dom + "/*") as p:
        p.content.autoplay = False

# whats this.. maybe change out for proton?
for dom in [
    "https://mail.google.com?extsrc=mailto&url=%25s",
    "https://calendar.google.com?cid=%25s",
]:
    with config.pattern(dom) as p:
        p.content.register_protocol_handler = True

c.content.geolocation = False
c.content.media.audio_video_capture = True
c.content.media.audio_capture = True
c.content.media.video_capture = True
c.content.notifications.enabled = True
c.content.cookies.accept = "no-3rdparty"
c.content.blocking.whitelist = ["thepiratebay.org"]
c.content.javascript.can_access_clipboard = True
c.editor.command = ["kitty", "-e", "nvim", "{}"]
c.downloads.open_dispatcher = "rifle"
c.downloads.position = "bottom"
c.downloads.location.remember = True
c.downloads.location.suggestion = "both"
c.downloads.remove_finished = 5000
c.downloads.location.prompt = True
# c.scrolling.bar = "always"
c.statusbar.widgets = ["keypress", "url", "history", "tabs", "progress"]
c.tabs.background = True
c.tabs.last_close = "default-page"
c.tabs.select_on_remove = "last-used"
c.tabs.new_position.stacking = False
# ### PADDING ###
# v_padding = 10
# h_padding = 20
# s_padding = 10
# l_padding = 5
# t_padding = 5
#
# c.tabs.padding = { 'top': v_padding, 'bottom': v_padding, 'left': h_padding, 'right': h_padding }
c.tabs.indicator.padding = {"top": 2, "bottom": 2, "left": 5, "right": 5}
c.url.default_page = str(config.configdir / "startpage.html")
c.url.start_pages = c.url.default_page
c.colors.messages.error.bg = "#b22222"
c.colors.webpage.bg = "#1D252C"


c.content.tls.certificate_errors = "ask"
c.content.unknown_url_scheme_policy = "allow-from-user-interaction"
c.auto_save.session = True
c.qt.force_platformtheme = "dark"

c.url.searchengines = {
    "DEFAULT": "https://searx.aicampground.com/?q={}",
    "!a": "https://www.amazon.com/s?k={}",
    "!d": "https://duckduckgo.com/?ia=web&q={}",
    "!dd": "https://thefreedictionary.com/{}",
    "!e": "https://www.ebay.com/sch/i.html?_nkw={}",
    "!fb": "https://www.facebook.com/s.php?q={}",
    "!gh": "https://github.com/search?o=desc&q={}&s=stars",
    "!gist": "https://gist.github.com/search?q={}",
    "!gi": "https://www.google.com/search?tbm=isch&q={}&tbs=imgo:1",
    "!gn": "https://news.google.com/search?q={}",
    "!ig": "https://www.instagram.com/explore/tags/{}",
    "!m": "https://www.google.com/maps/search/{}",
    "!p": "https://pry.sh/{}",
    "!r": "https://www.reddit.com/search?q={}",
    "!sd": "https://slickdeals.net/newsearch.php?q={}&searcharea=deals&searchin=first",
    "!t": "https://www.thesaurus.com/browse/{}",
    "!tw": "https://twitter.com/search?q={}",
    "!w": "https://en.wikipedia.org/wiki/{}",
    "!yelp": "https://www.yelp.com/search?find_desc={}",
    "!yt": "https://www.youtube.com/results?search_query={}",
}

c.window.title_format = "{perc}{current_title}"
c.zoom.default = "100%"
c.zoom.levels = [
    "25%",
    "33%",
    "50%",
    "60%",
    "67%",
    "75%",
    "90%",
    "100%",
    "110%",
    "125%",
    "150%",
    "175%",
    "200%",
    "250%",
    "300%",
    "400%",
    "500%",
]
c.fonts.default_family = ["DejaVu Sans Mono"]
c.fonts.prompts = "default_size default_family"
c.fonts.tabs.selected = "15pt default_family"
c.fonts.tabs.unselected = "15pt default_family"
c.completion.open_categories = ["quickmarks", "bookmarks", "history"]
c.hints.selectors["magnets"] = ['[href^="magnet:"]']

c.bindings.commands["normal"] = {
    "x": "tab-close",
    "<ctrl-h>": "tab-prev",
    "<ctrl-l>": "tab-next",
    "J": "tab-prev",
    "K": "tab-next",
    # zoom
    "<ctrl-=>": "zoom-in",
    "<ctrl-->": "zoom-out",
    "<ctrl-0>": "zoom 100",
    # Youtube
    "gM": "hint links spawn mpv {hint-url} --ytdl-format='bestvideo[height<1080]+bestaudio/best[height<1080]'",
    "gm": "spawn mpv '{url}'",
    "gq": "hint --rapid links spawn ~/.local/bin/umpv '{hint-url}'",
    # Bitwarden
    "zl": "spawn --userscript ~/.config/qutebrowser/userscripts/qute-bitwarden",
    "za": "spawn --userscript ~/.local/bin/bwadd '{url}'",
}

c.content.user_stylesheets = ["~/.config/qutebrowser/reddit.css"]
c.colors.webpage.preferred_color_scheme = 'dark'
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.threshold.text = 150
c.colors.webpage.darkmode.threshold.background = 100
c.colors.webpage.darkmode.policy.images = 'always'
c.colors.webpage.darkmode.grayscale.images = 0.35
