{
  options = {
    # Basic settings
    foldmethod = "syntax";
    completeopt = ["menuone" "noselect"];
    termguicolors = true;
    autoindent = true;
    diffopt = "filler";
    cursorline = true;
    mouse = "a";
    wrap = true;
    magic = true;
    joinspaces = false;
    showmode = false;
    startofline = false;
    ruler = true;
    nu = true;
    shell = "zsh";
    splitbelow = true;
    splitright = true;
    title = true;
    wildmenu = true;
    wrapscan = true;
    encoding = "utf-8";
    fileencoding = "utf-8";
    paste = false;
    shortmess = "atI";
    showtabline = 2;
    sidescrolloff = 3;
    smartcase = true;
    smarttab = true;
    scrolloff = 3;
    lazyredraw = true;
    spell = true;
    wo.number = true;
    wo.relativenumber = true;
    wildmode = "longest,list,full";
    laststatus = 3;

    # List characters
    listchars = {
      eol = "¬";
      tab = ">·";
      trail = "~";
      precedes = "<";
      space = "␣";
      extends = ">";
    };

    # Keywords
    iskeyword = "-";

    # Window settings
    window = {number = true;};

    # Buffer settings
    buffer = {
      expandtab = true;
      shiftwidth = 2;
      softtabstop = 2;
      tabstop = 2;
    };

    # Font settings
    guifont = ["Source Code Pro" ":h8"];

    # Wild ignore patterns
    wildignore = [
      ".DS_Store"
      "*.jpg"
      "*.jpeg"
      "*.gif"
      "*.png"
      "*.psd"
      "*.o"
      "*.obj"
      "*.min.js"
      "*/bower_components/*"
      "*/node_modules/*"
      "*/smarty/*"
      "*/vendor/*"
      "*/.git/*"
      "*/.hg/*"
      "*/.svn/*"
      "*/.sass-cache/*"
      "*/log/*"
      "*/tmp/*"
      "*/build/*"
      "*/ckeditor/*"
      "*/doc/*"
      "*/source_maps/*"
      "*/dist/*"
    ];
    # undodir = "~/.config/nvim/undo";
    # undofile = true;
  };
}
