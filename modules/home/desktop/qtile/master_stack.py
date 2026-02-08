# Copyright (c) 2010 Aldo Cortesi
# Copyright (c) 2010-2011 Paul Colomiets
# Copyright (c) 2011 Mounier Florian
# Copyright (c) 2011 Tzbob
# Copyright (c) 2012 roger
# Copyright (c) 2012-2014 Tycho Andersen
# Copyright (c) 2013 Tao Sauvage
# Copyright (c) 2014 ramnes
# Copyright (c) 2014 Sean Vig
# Copyright (c) 2014 dmpayton
# Copyright (c) 2014 dequis
# Copyright (c) 2017 Dirk Hartmann.
# Copyright (c) 2018 Nazar Mokrynskyi
# Copyright (c) 2023 Gábor Motkó
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
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

from libqtile.command.base import expose_command
from libqtile.config import Match
from libqtile.layout.base import _SimpleLayoutBase

class MasterStack(_SimpleLayoutBase):
    """A flexible master-and-stack layout

    The screen is divided into two halves. The master may contain a number of windows up to
    a limit; all windows beyond that are moved to the stack. The master can be located along
    any of the screen_rect's borders.
    """

    defaults = [
        ("border_focus", "#0000ff", "Border colour(s) for the focused window."),
        ("border_normal", "#000000", "Border colour(s) for un-focused windows."),
        ("border_on_single", True, "Whether to draw border if there is only one window."),
        ("border_width", 1, "Border width."),
        ("margin", 0, "Margin of the layout (int or list of ints [N E S W])"),
        ("margin_on_single", True, "Whether to draw margin if there is only one window."),
        ("ratio", 0.618, "Width-percentage of screen size reserved for master windows."),
        ("max_ratio", 0.85, "Maximum width of master windows"),
        ("min_ratio", 0.15, "Minimum width of master windows"),
        (
            "master_length",
            1,
            "Amount of windows displayed in the master stack. Surplus windows "
            "will be moved to the stack stack.",
        ),
        (
            "expand",
            True,
            "Expand the master windows to the full screen width if no stacks " "are present.",
        ),
        (
            "ratio_increment",
            0.05,
            "By which amount to change ratio when decrease_ratio or "
            "increase_ratio are called.",
        ),
        (
            "add_window_position",
            "last",
            "Defines where newly spawned windows should appear. Possible values are: "
            "first, last, first_stack, last_master, before_focus, after_focus"
        ),
        (
            "master_position",
            "left",
            "The half of the screen occupied by the master: left (default), right, top, or bottom."
        ),
        (
            "shift_windows",
            False,
            "Allow to shift windows within the layout. If False, the layout "
            "will be rotated instead.",
        ),
        (
            "master_match",
            None,
            "A Match object defining which window(s) should be kept masters (single or a list "
            "of Match-objects).",
        ),
        (
            "promote_mode",
            "append",
            "What to do when the user promotes a window. 'append'/'prepend' moves the window to the"
            "bottom/top of the master and increases its size. 'replace' (default) moves the window"
            "to the top of the master and pushes other windows down."
        ),
    ]


    def __init__(self, **config):
        _SimpleLayoutBase.__init__(self, **config)
        self.add_defaults(MasterStack.defaults)
        self._initial_ratio = self.ratio
        if self.master_position not in ["left", "right", "top", "bottom"]:
            self.master_position = "left"
        if self.add_window_position not in ["first", "last", "first_stack", "last_stack", "before_focus", "after_focus"]:
            self.add_window_position = "last"

        if "add_after_last" in config and config["add_after_last"]:
            self.add_window_position = "last"
        elif "add_on_top" in config and config["add_on_top"]:
            self.add_window_position = "first_stack"


    @property
    def ratio_size(self):
        return self.ratio


    @ratio_size.setter
    def ratio_size(self, ratio):
        self.ratio = min(max(ratio, self.min_ratio), self.max_ratio)


    @property
    def master_windows(self):
        return self.clients[:self.master_length]


    @property
    def stack_windows(self):
        return self.clients[self.master_length:]


    @expose_command("shuffle_left")
    def shuffle_up(self):
        if self.shift_windows:
            self.clients.shuffle_up()
        else:
            self.clients.rotate_down()
        self.group.layout_all()


    @expose_command("shuffle_right")
    def shuffle_down(self):
        if self.shift_windows:
            self.clients.shuffle_down()
        else:
            self.clients.rotate_up()
        self.group.layout_all()


    @expose_command
    def reposition_master(self, target = "flip"):
        """Changes the master's position according to the `target` argument:
        - flip (default): to the opposite edge,
        - rotate: to the adjacent clockwise edge,
        - unrotate: to the adjacent counterclockwise edge,
        - top, bottom, left, right: as indicated.
        """

        if target == "flip":
            self.master_position = {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}[self.master_position]
        elif target == "rotate":
            self.master_position = {"left": "top", "top": "right", "right": "bottom", "bottom": "left"}[self.master_position]
        elif target == "unrotate":
            self.master_position = {"left": "bottom", "bottom": "right", "right": "top", "top": "left"}[self.master_position]
        elif target in ["left", "right", "top", "bottom"]:
            self.master_position = target
        self.group.layout_all()


    @expose_command
    def promote_or_demote(self):
        current_client = self.clients.current_client
        if self.clients.current_index >= self.master_length: # this implies that len(clients) > master_length
            self.promote()
        else:
            self.demote()


    @expose_command
    def promote(self):
        """Move the focused window to the master."""

        current_client = self.clients.current_client
        if self.clients.current_index >= self.master_length:
            if self.promote_mode == "append":
                self.master_length += 1
                target = self.master_length - 1
                self.clients.clients.insert(target, self.clients.clients.pop(self.clients.current_index))
                self.clients.current_index = target
            elif self.promote_mode == "prepend":
                self.master_length += 1
                self.clients.clients.insert(0, self.clients.clients.pop(self.clients.current_index))
                self.clients.current_index = 0
            else:
                self.clients.clients.insert(0, self.clients.clients.pop(self.clients.current_index))
                self.clients.current_index = 0

        self.group.layout_all()


    @expose_command
    def demote(self):
        """Move the focused window to the stack."""

        current_client = self.clients.current_client
        if self.clients.current_index < self.master_length:
            if self.promote_mode in ("append", "prepend"):
                target = self.master_length - 1
                self.clients.clients.insert(target, self.clients.clients.pop(self.clients.current_index))
                self.clients.current_index = target
                self.master_length = max(1, self.master_length - 1)

            elif len(self.stack_windows) > 0:
                self.clients.clients.insert(0, self.clients.clients.pop(self.master_length))

        self.group.layout_all()



    def reset_master(self, match=None):
        if not match and not self.master_match:
            return
        if self.clients:
            master_match = match or self.master_match
            if isinstance(master_match, Match):
                master_match = [master_match]
            masters = []
            for c in self.clients:
                for match in master_match:
                    if match.compare(c):
                        masters.append(c)
            for client in reversed(masters):
                self.clients.remove(client)
                self.clients.append_head(client)


    def clone(self, group):
        c = _SimpleLayoutBase.clone(self, group)
        return c


    def add_client(self, client, offset_to_current=1):
            #"first, last, first_stack, last_master, before_focus, after_focus"
        addpos = self.add_window_position
        cc = len(self.clients)
        if addpos == "first":
            self.clients.add_client(client, client_position = "top")
        elif addpos == "last":
            self.clients.add_client(client, client_position = "bottom")
        elif addpos == "first_stack":
            self.clients.clients.insert(self.master_length, client)
        elif addpos == "last_master":
            self.clients.clients.insert(max(self.master_length - 1, 0), client)
        elif addpos == "before_focus":
            self.clients.add_client(client, client_position = "before_current")
        elif addpos == "after_focus":
            self.clients.add_client(client, client_position = "after_current")
        else:
            super().add_client(client, offset_to_current)

        self.reset_master()


    def remove(self, client):
        # If a window in the master is destroyed, make sure the topmost stack window doesn't
        # overflow into the master
        if self.clients.index(client) < self.master_length:
            self.master_length = max(1, self.master_length - 1)
        self.group.layout_all()
        return _SimpleLayoutBase.remove(self, client)


    def _is_master(self, client):
        """Determines if the client is in the master or in the stack."""
        return self.clients.index(client) < self.master_length


    def _get_window_rect_left(self, client, screen_rect):
        """Returns the rect (x, y, w, h) occupied by the client in a left-master orientation."""
        screen_width = screen_rect.width
        screen_height = screen_rect.height
        if self._is_master(client):
            w = int(screen_width * self.ratio_size) if len(self.stack_windows) or not self.expand else screen_width
            h = screen_height // min(self.master_length, max(1, len(self.master_windows)))
            x = screen_rect.x
            y = screen_rect.y + self.clients.index(client) * h
        else:
            master_w = int(screen_width * self.ratio_size)
            w = screen_width - master_w
            h = screen_height // len(self.stack_windows)
            x = screen_rect.x + master_w
            y = screen_rect.y + self.stack_windows.index(client) * h
        return x, y, w, h


    def _get_window_rect_right(self, client, screen_rect):
        """Returns the rect (x, y, w, h) occupied by the client in a right-master orientation."""
        screen_width = screen_rect.width
        screen_height = screen_rect.height
        if self._is_master(client):
            w = int(screen_width * self.ratio_size) if len(self.stack_windows) or not self.expand else screen_width
            h = screen_height // min(self.master_length, max(1, len(self.master_windows)))
            x = screen_rect.x + screen_width - w
            y = screen_rect.y
        else:
            master_w = int(screen_width * self.ratio_size)
            w = screen_width - master_w
            h = screen_height // len(self.stack_windows)
            x = screen_rect.x
            y = screen_rect.y + self.stack_windows.index(client) * h
        return x, y, w, h


    def _get_window_rect_top(self, client, screen_rect):
        """Returns the rect (x, y, w, h) occupied by the client in a top-master orientation."""
        screen_width = screen_rect.width
        screen_height = screen_rect.height
        if self._is_master(client):
            w = screen_width // min(self.master_length, max(1, len(self.master_windows)))
            h = int(screen_height * self.ratio_size) if len(self.stack_windows) or not self.expand else screen_height
            x = screen_rect.x + self.clients.index(client) * w
            y = screen_rect.y
        else:
            master_h = int(screen_height * self.ratio_size)
            w = screen_width // len(self.stack_windows)
            h = screen_height - master_h
            x = screen_rect.x + self.stack_windows.index(client) * w
            y = screen_rect.y + master_h
        return x, y, w, h


    def _get_window_rect_bottom(self, client, screen_rect):
        """Returns the rect (x, y, w, h) occupied by the client in a bottom-master orientation."""
        screen_width = screen_rect.width
        screen_height = screen_rect.height
        if self._is_master(client):
            w = screen_width // min(self.master_length, max(1, len(self.master_windows)))
            h = int(screen_height * self.ratio_size) if len(self.stack_windows) or not self.expand else screen_height
            x = screen_rect.x
            y = screen_rect.y + screen_height - h
        else:
            master_h = int(screen_height * self.ratio_size)
            w = screen_width // len(self.stack_windows)
            h = screen_height - master_h
            x = screen_rect.x + self.stack_windows.index(client) * w
            y = screen_rect.y
        return x, y, w, h


    # Returns the rect (x, y, w, h) that a client should occupy.
    def _get_window_rect(self, client, screen_rect):
        if self.master_position == "right":
            return self._get_window_rect_right(client, screen_rect)
        elif self.master_position == "top":
            return self._get_window_rect_top(client, screen_rect)
        elif self.master_position == "bottom":
            return self._get_window_rect_bottom(client, screen_rect)
        else:
            return self._get_window_rect_left(client, screen_rect)


    def configure(self, client, screen_rect):
        screen_width = screen_rect.width
        screen_height = screen_rect.height
        border_width = self.border_width
        if self.clients and client in self.clients:
            x, y, w, h = self._get_window_rect(client, screen_rect)

            if client.has_focus:
                bc = self.border_focus
            else:
                bc = self.border_normal
            if not self.border_on_single and len(self.clients) == 1:
                border_width = 0
            else:
                border_width = self.border_width
            client.place(
                x,
                y,
                w - border_width * 2,
                h - border_width * 2,
                border_width,
                bc,
                margin = 0 if (not self.margin_on_single and len(self.clients) == 1) else self.margin,
            )
            client.unhide()
        else:
            client.hide()


    @expose_command()
    def info(self):
        d = _SimpleLayoutBase.info(self)
        d.update(
            dict(
                master=[c.name for c in self.master_windows],
                stack=[c.name for c in self.stack_windows],
            )
        )
        return d


    @expose_command(["left", "up"])
    def previous(self):
        _SimpleLayoutBase.previous(self)


    @expose_command(["right", "down"])
    def next(self):
        _SimpleLayoutBase.next(self)


    @expose_command("normalize")
    def reset(self):
        self.ratio_size = self._initial_ratio
        self.group.layout_all()


    @expose_command()
    def decrease_ratio(self):
        self.ratio_size -= self.ratio_increment
        self.group.layout_all()


    @expose_command()
    def increase_ratio(self):
        self.ratio_size += self.ratio_increment
        self.group.layout_all()


    @expose_command()
    def decrease_nmaster(self):
        self.master_length -= 1
        if self.master_length <= 0:
            self.master_length = 1
        self.group.layout_all()


    @expose_command()
    def increase_nmaster(self):
        self.master_length += 1
        self.group.layout_all()
