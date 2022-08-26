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
from libqtile import hook, qtile

# get display scaling facotr
GDK_SCALE = os.environ.get("GDK_SCALE")
if not GDK_SCALE:
    GDK_SCALE = 1.35

win_list = []
def stick_win(qtile):
    global win_list
    win_list.append(qtile.current_window)
def unstick_win(qtile):
    global win_list
    if qtile.current_window in win_list:
        win_list.remove(qtile.current_window)
@hook.subscribe.setgroup
def move_win():
    for w in win_list:
        w.togroup(qtile.current_group.name)

def move_to_top(qtile):
    w = qtile.current_window
    w.bring_to_front()
# thanks to rogerduran for the implementation of my idea (borrowed
# from stumpwm)
class PrevFocus(object):
    """Store last focus per group and go back when called"""

    def __init__(self):
        self.focus = None
        self.old_focus = None
        self.groups_focus = {}
        hook.subscribe.client_focus(self.on_focus)

    def on_focus(self, window):
        group = window.group
        # only store focus if the group is set
        if not group:
            return
        group_focus = self.groups_focus.setdefault(group.name, {
            "current": None, "prev": None
        })
        # don't change prev if the current focus is the same as before
        if group_focus["current"] == window:
            return
        group_focus["prev"] = group_focus["current"]
        group_focus["current"] = window

    def __call__(self, qtile):
        group = qtile.current_group
        group_focus = self.groups_focus.get(group.name, {"prev": None})
        prev = group_focus["prev"]
        if prev and group.name == prev.group.name:
            group.focus(prev, False)


# taken from
# https://github.com/qtile/qtile-examples/blob/master/roger/config.py#L34
# and adapted
def pull_window_group_here(**kwargs):
    """Switch to the *next* window matched by match_window_re with the given
    **kwargs

    If you have multiple windows matching the args, switch_to will
    cycle through them.

    (Those semantics are similar to the fvwm Next commands with
    patterns)
    """

    def callback(qtile):
        windows = windows_matching_shuffle(qtile, **kwargs)
        if windows:
            window = windows[0]
            qtile.current_screen.set_group(window.group)
            window.group.focus(window, False)
            window.focus(window, False)

    return lazy.function(callback)


def window_switch_to_screen_or_pull_group(**kwargs):
    """If the group of the window matched by match_window_re with the
    given **kwargs is in a visible on another screen, switch to the
    screen, otherwise pull the group to the current screen

    """

    def callback(qtile):
        windows = windows_matching_shuffle(qtile, **kwargs)
        if windows:
            window = windows[0]
            if window.group != qtile.current_group:
                if window.group.screen:
                    qtile.cmd_to_screen(window.group.screen.index)
                qtile.current_screen.set_group(window.group)
            window.group.focus(window, False)

    return lazy.function(callback)


switch_window = window_switch_to_screen_or_pull_group


# def make_sticky(qtile, *args):
#     window = qtile.current_window
#     screen = qtile.current_screen.index
#     window.static(
#         screen,
#         window.x,
#         window.y,
#         window.width,
#         window.height)


def pull_window_here(**kwargs):
    """pull the matched window to the current group and focus it

    matching behaviour is the same as in switch_to
    """
    def callback(qtile):
        windows = windows_matching_shuffle(qtile, **kwargs)
        if windows:
            window = windows[0]
            window.togroup(qtile.current_group.name)
            qtile.current_group.focus(window, False)

    return lazy.function(callback)


def windows_matching_shuffle(qtile, **kwargs):
    """return a list of windows matching window_match_re with **kwargs,
    ordered so that the current Window (if it matches) comes last
    """
    windows = sorted(
        [
            w
            for w in qtile.windows_map.values()
            if w.group and window_match_re(w, **kwargs)],
        key=lambda ww: ww.window.wid)
    idx = 0
    if qtile.current_window is not None:
        try:
            idx = windows.index(qtile.current_window)
            idx += 1
        except ValueError:
            pass
    if idx >= len(windows):
        idx = 0
    return windows[idx:] + windows[:idx]


def window_match_re(window, wmname=None, wmclass=None, role=None):
    """
    match windows by name/title, class or role, by regular expressions

    Multiple conditions will be OR'ed together
    """

    if not (wmname or wmclass or role):
        raise TypeError(
            "at least one of name, wmclass or role must be specified"
        )
    ret = False
    if wmname:
        ret = ret or re.match(wmname, window.name)
    try:
        if wmclass:
            cls = window.window.get_wm_class()
            if cls:
                for v in cls:
                    ret = ret or re.match(wmclass, v)
        if role:
            rol = window.window.get_wm_window_role()
            if rol:
                ret = ret or re.match(role, rol)
    except (xcffib.xproto.WindowError, xcffib.xproto.AccessError):
        return False
    return ret


def modifier_window_commands(match, spawn, *keys):
    # Use switch_window by default (just mod)
    # Use pull_window_here with additional ctrl
    # spawn new window with additional shift
    # Use pull_window_group_here with additional shift (mod, "shift", "control")
    mapping = (
        ([mod], switch_window(**match)),
        ([mod, "control"], pull_window_here(**match)),
        ([mod, "shift"], lazy.spawn(spawn)),
        ([mod, "shift", "control"], pull_window_group_here(**match)))
    return [Key(mods, key, command)
            for mods, command in mapping
            for key in keys]

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

    # Grow windows. If current window is on the edge of screen and dkrection
    # will be to screen edge - window would shrink.

    Key([mod, "control"], "j", 
        lazy.layout.grow_down(),
        lazy.layout.decrease_ratio(),
        desc="Grow window down, Tile: Reduce Ratio"),
    Key([mod, "control"], "k", 
        lazy.layout.grow_up(),
        lazy.layout.increase_ratio(),
        desc="Grow window up, Tile: Increase Ratio"),
    Key([mod], "n", lazy.layout.normalize(),
        desc="Reset all window sizes"),
    Key([mod], "i", lazy.layout.grow()),
    Key([mod], "m", lazy.layout.shrink()),
    Key([mod], "o", lazy.layout.maximize()),
    Key([mod, "shift"], "space", lazy.layout.flip()),

    Key([mod], "a", lazy.spawn("rofi -show-icons -show window")),
    Key([mod], "s", lazy.function(stick_win), desc="stick win"),
    Key([mod, "shift"], "s", lazy.function(unstick_win), desc="unstick win"),
    Key([mod], "z", lazy.layout.swap_main()),
    Key([mod, "shift"] ,"z", lazy.function(move_to_top), desc="move to top"),
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
             lazy.layout.client_to_next(),
             desc='Expand window (MonadTall), increase number in master pane (Tile), move to next stack (Stack)'
             ),
    Key([mod, "control"], "l",
             lazy.layout.shrink(),
             lazy.layout.decrease_nmaster(),
             lazy.layout.client_to_previous(),
             desc='Shrink window (MonadTall), decrease number in master pane (Tile), move to previous stack (Stack)'
             ),
    # Toggle between split and unsplit sides of stack.
    # Split = all windows displayed
    # Unsplit = 1 window displayed, like Max layout, but still with
    # multiple stack panes

    Key([mod], "space",
             lazy.layout.next(),
             desc='Switch window focus to other pane(s) of stack'
             ),
    Key([mod, "shift"], "Return", lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack"),
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    Key([mod, "shift"], "f",
             lazy.window.toggle_floating(),
             desc='toggle floating'
             ),
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
    Key([mod], "F2", lazy.spawn(f"brave --no-xshm --high-dpi-support=1 --force-device-scale-factor={GDK_SCALE}")),
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
               ("WORK1", {'layout': 'monadtall'}),
               ("WORK2", {'layout': 'monadtall'}),
               ("SYS", {'layout': 'monadtall'}),
               ("COMMS", {'layout': 'stack'}),
               ("EMAIL", {'layout': 'monadtall'}),
               ("CAL", {'layout': 'monadtall'}),
               ("DOC", {'layout': 'floating'})]

groups = [Group(name, **kwargs) for name, kwargs in group_names]

for i, (name, kwargs) in enumerate(group_names, 1):
    # Switch to another group
    keys.append(Key([mod], str(i), lazy.group[name].toscreen()))
    # Send current window to another group
    keys.append(Key([mod, "shift"], str(i), lazy.window.togroup(name)))


layout_theme = {"border_width": 2,
                "margin": 10,
                "border_focus": "#e1acff",
                "border_normal": "#1D2330",
                "grow_amount": 5
                }

layouts = [
    # layout.Columns(border_focus_stack='#d75f5f'),
    # layout.Max(),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2),
    layout.Bsp(**layout_theme),
    layout.Matrix(),
    layout.Tile(shift_windows=True, **layout_theme),
    layout.Stack(num_stacks=2, **layout_theme),
    layout.MonadTall(**layout_theme),
    layout.MonadWide(**layout_theme),
    layout.RatioTile(**layout_theme),
    layout.Tile(),
    layout.TreeTab(**layout_theme)
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
                    padding=10,
                    foreground=colors[2],
                    background=colors[0]
                ),
                widget.GroupBox(
                    font="Ubuntu Bold",
                    fontsize=11,
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
            35,
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


# see
# http://docs.qtile.org/en/latest/manual/faq.html#my-pointer-mouse-cursor-isn-t-the-one-i-expect-it-to-be  # noqa
# see https://wiki.dfn-cert.de/cgi-bin/wiki.pl/Workstations15.1Not_WorkingYet#toc15
@hook.subscribe.startup
def runner():
    subprocess.Popen(['xsetroot', '-cursor_name', 'left_ptr'])

# prevent xfce4-notifyd windows from jumping around by ignoring them


# @hook.subscribe.client_new
# def auto_sticky(window):
#     if window.name == "xfce4-notifyd":
#         if window.group:
#             screen = window.group.screen.index
#         else:
#             screen = window.qtile.current_screen.index
#         window.window.configure(stackmode=xcffib.xproto.StackMode.Above)
#         window.static(screen)


# from http://qtile.readthedocs.org/en/latest/manual/config/hooks.html#automatic-floating-dialogs
@hook.subscribe.client_new
def floating_dialogs(window):
    dialog = window.window.get_wm_type() == 'dialog'
    transient = window.window.get_wm_transient_for()
    bubble = window.window.get_wm_window_role() == 'bubble'
    if dialog or transient or bubble:
        window.floating = True


# from https://github.com/ramnes/qtile-config/blob/98e097cfd8d5dd1ab1858c70babce141746d42a7/config.py#L108
@hook.subscribe.screen_change
def set_screens(qtile, event):
    if not os.path.exists(os.path.expanduser('~/NO-AUTORANDR')):
        subprocess.run(["autorandr", "--change"])
        qtile.cmd_restart()
