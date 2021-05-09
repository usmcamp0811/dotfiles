# Copyright (c) 2010 Aldo Cortesi
# Copyright (c) 2010, 2014 dequis
# Copyright (c) 2012 Randall Ma
# Copyright (c) 2012-2014 Tycho Andersen
# Copyright (c) 2012 Craig Barnes
# Copyright (c) 2013 horsik
# Copyright (c) 2013 Tao Sauvage
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# from typing import List  # noqa: F401
import os
import re
import socket
import subprocess
from libqtile.config import KeyChord, Key, Screen, Group, Drag, Click, Drag, Key, Match
from libqtile.command import lazy
from libqtile import layout, bar, widget, hook
from libqtile.widget import *
from libqtile.lazy import lazy
from typing import List  # noqa: F401
from libqtile.utils import guess_terminal
from libqtile import hook

# get display scaling facotr
GDK_SCALE = os.environ.get("GDK_SCALE")
if not GDK_SCALE:
    GDK_SCALE = 1.35


# @hook.subscribe.startup_once
@hook.subscribe.startup
def autostart():
    home = os.path.expanduser('~/.config/qtile/autostart.sh')
    subprocess.call([home])


# mod = "mod4"
mod = "mod1"
terminal = guess_terminal()
myTerm = "alacritty"                             # My terminal of choice
arrow_font_size = 35
# The Qtile config file location
myConfig = "/home/mcamp/.config/qtile/config.py"

colors = [["#282c34", "#282c34"],  # panel background
          ["#434758", "#434758"],  # background for current screen tab
          ["#ffffff", "#ffffff"],  # font color for group names
          ["#E06C75", "#E06C75"],  # border line color for current tab
          ["#98C379", "#98C379"],  # border line color for other tab and odd widgets
          ["#484948", "#484948"],  # color for the even widgets
          ["#e1acff", "#e1acff"],
          ["#363636", "#363636"],
          ]  # window name

prompt = "{0}@{1}: ".format(os.environ["USER"], socket.gethostname())

##### DEFAULT WIDGET SETTINGS #####
widget_defaults = dict(
    font="IBM Plex Mono",
    # fontsize=int(14 * SCALE_BY),
    fontsize=14,
    padding=1,
    background=colors[2]
)

def open_calendar(qtile):  # spawn calendar widget
    qtile.cmd_spawn(myTerm + ' -e zenity --calendar --text "Cancel to close. Ok to schedule an appt" --title "My Calendar"')

def backlight(action):
    def f(qtile):
        brightness = int(subprocess.run(['xbacklight', '-get'],
                                        stdout=subprocess.PIPE).stdout)
        if action == 'dec':
            subprocess.run(['backlight_control', '-10'])
        else:
            subprocess.run(['backlight_control', '+10'])
    return f

keys = [
    # Switch between windows
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "space", lazy.layout.top(),
        desc="Move window focus to other window"),

    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key([mod, "shift"], "h", lazy.layout.swap_left(),
        desc="Move window to the left"),
    Key([mod, "shift"], "l", lazy.layout.swap_right(),
        desc="Move window to the right"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(),
        desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),

    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"], "j", lazy.layout.grow_down(),
        desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    Key([mod], "i", lazy.layout.grow()),
    Key([mod], "m", lazy.layout.shrink()),
    Key([mod], "n", lazy.layout.normalize()),
    Key([mod], "o", lazy.layout.maximize()),
    Key([mod, "shift"], "space", lazy.layout.flip()),

    Key([mod], "z", lazy.layout.swap_main()),
    Key([mod], "r",
             lazy.spawn("ranger"),
             desc='File Explorek'
             ),
    Key([mod, "mod1"], "r",
             lazy.spawn(myTerm+" -e rtv"),
             desc='reddit terminal viewer'
             ),

    Key([mod, "control"], "h",
             lazy.layout.grow(),
             lazy.layout.increase_nmaster(),
             desc='Expand window (MonadTall), increase number in master pane (Tile)'
             ),
    Key([mod, "control"], "l",
             lazy.layout.shrink(),
             lazy.layout.decrease_nmaster(),
             desc='Shrink window (MonadTall), decrease number in master pane (Tile)'
             ),
    # Toggle between split and unsplit sides of stack.
    # Split = all windows displayed
    # Unsplit = 1 window displayed, like Max layout, but still with
    # multiple stack panes
    Key([mod, "shift"], "Return", lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack"),
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    Key([mod], "f",
        lazy.window.toggle_fullscreen(),
        desc="toggle fullscreen on currently focused window",
        ),

    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
    Key([mod, "shift"], "q", lazy.window.kill(), desc="Kill focused window"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    # Key([mod], "d", lazy.spawncmd(),
    # desc="Spawn a command using a prompt widget"),
    Key([mod], "F2", lazy.spawn(f"brave --high-dpi-support=1 --force-device-scale-factor={GDK_SCALE}")),
    Key([mod], "F3", lazy.spawn("ranger")),
    Key([mod, "control"], "r", lazy.restart()),
    Key([mod], "e", lazy.spawn(["sh", "-c", "~/.local/bin/dmenuunicode"])),
    Key([mod], "d", lazy.spawn(
        """rofi -show drun -font "IBM Plex Mono 12" -run-shell-command '{terminal} -e " {cmd}; read -n 1 -s"'""")),
    Key([mod, "control"], "w", lazy.spawn(
        """alacritty -t VimWiki -e nvim +VimwikiIndex""")),
    Key([mod], "F11", lazy.spawn("/bin/bash ~/.local/bin/auto-screen")),
    Key([mod], "F12", lazy.spawn("/bin/bash ~/.local/bin/laptop_screen_toggle")),
    Key(["mod4"], "l", lazy.spawn("i3lock-fancy")),
    Key([], 'XF86MonBrightnessUp',   lazy.spawn(["sh", "-c", "/usr/bin/backlight_control +10"])),
    Key([], 'XF86MonBrightnessDown', lazy.spawn(["sh", "-c", "/usr/bin/backlight_control -10"])),
    Key([], 'XF86AudioRaiseVolume', lazy.spawn(["sh", "-c", "~/.local/bin/lmc up"])),
    Key([], 'XF86AudioLowerVolume', lazy.spawn(["sh", "-c", "~/.local/bin/lmc down"])),
    Key([], 'XF86AudioMute', lazy.spawn(["sh", "-c", "~/.local/bin/lmc toggle"])),
    Key([], 'XF86Launch4', lazy.spawn(["sh", "-c", "asusctl", "profile -n"])),
    Key([], 'XF86Launch3', lazy.spawn(["sh", "-c", "asusctl", "led-mode -n"])),
    Key([], 'XF86Display', lazy.spawn(["sh", "-c", "~/.local/bin/laptop_screen_toggle"])),
    Key([], 'XF86Launch1', lazy.spawn(["sh", "-c", "~/.local/bin/laptop_screen_toggle"])),



    # Key([mod], "F2", lazy.spawn("brave")),
]


# groups = [Group(i) for i in "123456789"]

group_names = [("WEB", {'layout': 'monadtall'}),
               ("DEV", {'layout': 'monadtall'}),
               ("EMAIL", {'layout': 'monadtall'}),
               ("CHAT", {'layout': 'monadtall'}),
               ("SYS", {'layout': 'monadtall'}),
               ("GAME", {'layout': 'monadtall'}),
               ("MUS", {'layout': 'monadtall'}),
               ("VID", {'layout': 'monadtall'}),
               ("DOC", {'layout': 'floating'})]

groups = [Group(name, **kwargs) for name, kwargs in group_names]

for i, (name, kwargs) in enumerate(group_names, 1):
    # Switch to another group
    keys.append(Key([mod], str(i), lazy.group[name].toscreen()))
    # Send current window to another group
    keys.append(Key([mod, "shift"], str(i), lazy.window.togroup(name)))


layout_theme = {"border_width": 2,
                "margin": 6,
                "border_focus": "#e1acff",
                "border_normal": "#1D2330"
                }

layouts = [
    # layout.Columns(border_focus_stack='#d75f5f'),
    # layout.Max(),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2),
    # layout.Bsp(**layout_theme),
    # layout.Matrix(),
    layout.Tile(shift_windows=True, **layout_theme),
    layout.Stack(num_stacks=2, **layout_theme),
    layout.MonadTall(**layout_theme),
    layout.MonadWide(**layout_theme),
    # layout.RatioTile(**layout_theme),
    # layout.Tile(),
    # layout.VerticalTile(**layout_theme),
    # layout.Zoomy(),
]

extension_defaults = widget_defaults.copy()


screens = [
    Screen(
        top=bar.Bar(
            [
                widget.Sep(
                    linewidth=0,
                    padding=6,
                    foreground=colors[2],
                    background=colors[0]
                ),
                widget.GroupBox(
                    font="Ubuntu Bold",
                    fontsize=9,
                    margin_y=3,
                    margin_x=0,
                    padding_y=5,
                    padding_x=3,
                    borderwidth=3,
                    active=colors[2],
                    inactive=colors[2],
                    rounded=False,
                    highlight_color=colors[1],
                    highlight_method="line",
                    this_current_screen_border=colors[3],
                    this_screen_border=colors[4],
                    other_current_screen_border=colors[0],
                    other_screen_border=colors[0],
                    foreground=colors[2],
                    background=colors[0]
                ),
                widget.Prompt(
                    prompt=prompt,
                    font="Ubuntu Mono",
                    padding=10,
                    foreground=colors[3],
                    background=colors[1]
                ),
                widget.Sep(
                    linewidth=0,
                    padding=40,
                    foreground=colors[0],
                    background=colors[0]
                ),
                widget.WindowName(
                    foreground=colors[6],
                    background=colors[0],
                    padding=0
                ),
                widget.TextBox(
                    text='',
                    background=colors[0],
                    foreground=colors[7],
                    padding=0,
                    fontsize=arrow_font_size
                ),
                widget.TextBox(
                    text="🔋",
                    padding=0,
                    foreground=colors[2],
                    background=colors[7],
                    fontsize=17
                ),
                widget.Battery(
                    format='{char} {percent:2.0%}',
                    foreground=colors[2],
                    background=colors[7],
                    padding=5
                ),
                widget.TextBox(
                    text='',
                    background=colors[7],
                    foreground=colors[0],
                    padding=0,
                    fontsize=arrow_font_size
                ),
                widget.TextBox(
                    text="",
                    foreground=colors[2],
                    background=colors[0],
                    padding=0,
                    fontsize=25
                ),
                widget.Memory(
                    foreground=colors[2],
                    background=colors[0],
                    mouse_callbacks={
                        'Button1': lambda qtile: qtile.cmd_spawn(myTerm + ' -e htop')},
                    padding=5,
                    measure_mem="G",
                ),
                widget.TextBox(
                    text='',
                    foreground=colors[5],
                    background=colors[0],
                    padding=0,
                    fontsize=arrow_font_size
                ),
                widget.Net(
                    interface="wlp59s0",
                    format='{down} ↓↑ {up}',
                    foreground=colors[2],
                    background=colors[5],
                    padding=5
                ),
                widget.TextBox(
                    text='',
                    foreground=colors[7],
                    background=colors[5],
                    padding=0,
                    fontsize=arrow_font_size
                ),
                widget.TextBox(
                    text=" 🔊 ",
                    foreground=colors[2],
                    background=colors[7],
                    padding=0
                ),
                widget.Volume(
                    foreground=colors[2],
                    background=colors[7],
                    padding=5
                ),
                widget.TextBox(
                    text='',
                    foreground=colors[5],
                    background=colors[7],
                    padding=0,
                    fontsize=arrow_font_size
                ),
                widget.CurrentLayoutIcon(
                    custom_icon_paths=[os.path.expanduser(
                        "~/.config/qtile/icons")],
                    foreground=colors[2],
                    background=colors[5],
                    padding=0,
                    scale=0.7
                ),
                widget.CurrentLayout(
                    foreground=colors[2],
                    background=colors[5],
                    padding=5
                ),
                widget.TextBox(
                    text='',
                    foreground=colors[0],
                    background=colors[5],
                    padding=0,
                    fontsize=arrow_font_size
                ),
                widget.Clock(
                    foreground=colors[2],
                    background=colors[0],
                    mouse_callbacks={
                        'Button1':  lambda: qtile.cmd_spawn('alacritty — hold -e cal -3') 
                        },
                    format="%A, %B %d  [ %H:%M ]"
                ),
                widget.Sep(
                    linewidth=0,
                    padding=10,
                    foreground=colors[2],
                    background=colors[0]
                ),
                widget.Systray(
                    background=colors[0],
                    icon_size=20,
                    padding=5
                ),
            ],
            # init_widgets_list(),
            28,
        ),
    ),
]

# Drag floating layouts.
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(),
         start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),
         start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front())
]

dgroups_key_binder = None
dgroups_app_rules = []  # type: List
main = None  # WARNING: this is deprecated and will be removed soon
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
floating_layout = layout.Floating(float_rules=[
    # Run the utility of `xprop` to see the wm class and name of an X client.
    *layout.Floating.default_float_rules,
    Match(wm_class='confirmreset'),  # gitk
    Match(wm_class='makebranch'),  # gitk
    Match(wm_class='maketag'),  # gitk
    Match(wm_class='ssh-askpass'),  # ssh-askpass
    Match(title='branchdialog'),  # gitk
    Match(title='pinentry'),  # GPG key password entry
    Match(wm_class="Wine"),
    Match(wm_class="steam_app_1238810"), # for Battlefiled V
    Match(wm_class="steam_app_1238840"), # for Battlefield 1
    Match(wm_class="steam_app_1182480"), # origin thing for steam games
])
auto_fullscreen = True
focus_on_window_activation = "smart"


# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"
