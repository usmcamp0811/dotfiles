{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.qutebrowser;
  dir = ./qutebrowser;
  stylesheet = ./qutebrowser/reddit.css;
in
{
  options.fmf.apps.qutebrowser = {
    enable = mkEnableOption "qutebrowser";
  };

  config = mkIf cfg.enable {
    programs.qutebrowser = {
      enable = true;

      loadAutoconfig = false;

      searchEngines = {
        DEFAULT = "https://searx.aicampground.com/?q={}";
        "!a" = "https://www.amazon.com/s?k={}";
        "!d" = "https://duckduckgo.com/?ia=web&q={}";
        "!dd" = "https://thefreedictionary.com/{}";
        "!e" = "https://www.ebay.com/sch/i.html?_nkw={}";
        "!fb" = "https://www.facebook.com/s.php?q={}";
        "!gh" = "https://github.com/search?o=desc&q={}&s=stars";
        "!gist" = "https://gist.github.com/search?q={}";
        "!gi" = "https://www.google.com/search?tbm=isch&q={}&tbs=imgo:1";
        "!gn" = "https://news.google.com/search?q={}";
        "!ig" = "https://www.instagram.com/explore/tags/{}";
        "!m" = "https://www.google.com/maps/search/{}";
        "!p" = "https://pry.sh/{}";
        "!r" = "https://www.reddit.com/search?q={}";
        "!sd" = "https://slickdeals.net/newsearch.php?q={}&searcharea=deals&searchin=first";
        "!t" = "https://www.thesaurus.com/browse/{}";
        "!tw" = "https://twitter.com/search?q={}";
        "!w" = "https://en.wikipedia.org/wiki/{}";
        "!yelp" = "https://www.yelp.com/search?find_desc={}";
        "!yt" = "https://www.youtube.com/results?search_query={}";
      };

      settings = {
        content = {
          autoplay = false;
          geolocation = false;
          media.audio_capture = true;
          media.video_capture = true;
          media.audio_video_capture = true;
          notifications.enabled = true;
          cookies.accept = "no-3rdparty";
          javascript.clipboard = "access-paste";
          tls.certificate_errors = "ask";
          unknown_url_scheme_policy = "allow-from-user-interaction";
          # user_stylesheets = [stylesheet];
        };

        content.blocking.whitelist = [ "thepiratebay.org" ];

        editor.command = [ "kitty" "-e" "nvim" "{}" ];

        downloads = {
          open_dispatcher = "rifle";
          position = "bottom";
          location = {
            remember = true;
            suggestion = "both";
            prompt = true;
          };
          remove_finished = 5000;
        };

        statusbar.widgets = [ "keypress" "url" "history" "tabs" "progress" ];

        tabs = {
          background = true;
          last_close = "default-page";
          select_on_remove = "last-used";
          new_position.stacking = false;

          # indicator.padding = {
          #   top = 2;
          #   bottom = 2;
          #   left = 5;
          #   right = 5;
          # };
        };

        url = {
          default_page = "file://${config.xdg.configHome}/qutebrowser/startpage.html";
          start_pages = [ "file://${config.xdg.configHome}/qutebrowser/startpage.html" ];
        };

        colors = {
          messages.error.bg = "#b22222";
          webpage.bg = "#1D252C";
          webpage.preferred_color_scheme = "dark";

          webpage.darkmode = {
            enabled = false;
            algorithm = "lightness-cielab";
            threshold.foreground = 150;
            threshold.background = 100;
            policy.images = "always";
          };
        };

        auto_save.session = true;

        qt.force_platformtheme = "dark";

        fonts = {
          default_family = [ "DejaVu Sans Mono" ];
          prompts = "default_size default_family";
          tabs.selected = "15pt default_family";
          tabs.unselected = "15pt default_family";
        };

        completion.open_categories = [ "quickmarks" "bookmarks" "history" ];

        window.title_format = "{perc}{current_title}";

        zoom = {
          default = "100%";
          levels = [
            "25%"
            "33%"
            "50%"
            "60%"
            "67%"
            "75%"
            "90%"
            "100%"
            "110%"
            "125%"
            "150%"
            "175%"
            "200%"
            "250%"
            "300%"
            "400%"
            "500%"
          ];
        };
      };

      keyBindings.normal = {
        "x" = "tab-close";
        "<ctrl-h>" = "tab-prev";
        "<ctrl-l>" = "tab-next";
        "J" = "tab-prev";
        "K" = "tab-next";
        "<ctrl-=>" = "zoom-in";
        "<ctrl-->" = "zoom-out";
        "<ctrl-0>" = "zoom 100";
        "gM" = "hint links spawn mpv {hint-url} --ytdl-format='bestvideo[height<1080]+bestaudio/best[height<1080]'";
        "gm" = "spawn mpv '{url}'";
        "gq" = "hint --rapid links spawn ~/.local/bin/umpv '{hint-url}'";
        "zl" = "spawn --userscript ~/.config/qutebrowser/userscripts/qute-bitwarden";
        "za" = "spawn --userscript ~/.local/bin/bwadd '{url}'";
        "<ctrl-d>" = ":config-cycle colors.webpage.darkmode.enabled ;; reload";
      };

      quickmarks = {
        security = "https://app.threatswitch.com/login";
        time = "https://secure.ebillity.com/firm4.0/login.aspx";
        fb = "https://www.facebook.com/";
        r = "https://www.reddit.com/";
        mail = "https://mail.proton.me/u/0/inbox";
        news = "https://news.aicampground.com/";
        dotfiles = "https://gitlab.com/usmcamp0811/dotfiles";
        "ata slack" = "https://app.slack.com/client/T03KWC12A/C03KWC13S";
        "seed slack" = "https://app.slack.com/client/T1LAJS8CA/C03GX18ND2L";
        yt = "https://www.youtube.com/";
        aws = "https://signin.amazonaws-us-gov.com/oauth?response_type=code&client_id=arn%3Aaws-us-gov%3Asignin%3A%3A%3Aconsole%2Fcanvas&redirect_uri=https%3A%2F%2Fconsole.amazonaws-us-gov.com%2Fconsole%2Fhome%3FhashArgs%3D%2523%26isauthcode%3Dtrue%26state%3DhashArgsFromTB_us-gov-west-1_94c7adbbfd4435dd&forceMobileLayout=0&forceMobileApp=0&code_challenge=GjjxYXJk-xLjVn2Q2_6vlbRt4b7uD0bHDw8uVL_bNnI&code_challenge_method=SHA-256";
        campground = "http://10.8.0.1/Status_Lan.asp";
        skynet = "http://192.168.1.1/";
        octoprint = "http://10.8.0.200:5000/login/?redirect=%2F%3F&permissions=STATUS%2CSETTINGS_READ";
        sms = "https://messages.google.com/web/conversations";
        gmail = "https://mail.google.com/mail/u/1/#inbox";
        photos = "https://photos.aicampground.com/library/browse";
        amex = "https://www.americanexpress.com/en-us/account/login?inav=iNavLnkLog";
        az = "https://www.amazon.com/";
        jelly = "https://jellyfin.aicampground.com/web/index.html#!/home.html";
        chat = "https://chat.openai.com/";
        chad = "https://chat.openai.com/";
      };

      extraConfig = ''
        from qutebrowser.api import interceptor
        c.hints.selectors["magnets"] = ['[href^="magnet:"]']
        config.set("content.register_protocol_handler", True, "*://*.mail.google.com/*")
        config.set("content.register_protocol_handler", True, "*://*.calendar.google.com/*")
        c.tabs.indicator.padding = {'top': 2, 'bottom': 2, 'left': 5, 'right': 5}
      '';
    };
  };
}
