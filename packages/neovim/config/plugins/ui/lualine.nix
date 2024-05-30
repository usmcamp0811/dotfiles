{...}: {
  plugins = {
    lualine = {
      enable = true;
      iconsEnabled = true;
      theme = "auto";
      alwaysDivideMiddle = true;
      globalstatus = true;
      disabledFiletypes.statusline = ["alpha" "dashboard" "NvimTree" "Outline"];
      extensions = [];

      sectionSeparators = {
        left = "";
        right = "";
      };

      componentSeparators = {
        left = "";
        right = "";
      };

      # sections = {
      #   lualine_a = [{ name = "mode"; }];
      #   lualine_b = [{ name = "branch"; }];
      #   lualine_c = [{ name = "filename"; }];
      #   lualine_x = [{ name = "encoding"; }];
      #   lualine_y = [{ name = "progress"; }];
      #   lualine_z = [{ name = "location"; }];
      # };
    };
  };
  # TODO: Move what i can into the above nix stuff
  extraConfigLua = ''
    local diagnostics = {
    	"diagnostics",
    	sources = { "nvim_diagnostic" },
    	sections = { "error", "warn" },
    	symbols = { error = " ", warn = " " },
    	colored = false,
    	update_in_insert = false,
    	always_visible = true,
    	globalstatus = true,
    }

    local diff = {
    	"diff",
    	colored = false,
    	symbols = { added = " ", modified = " ", removed = " " }, -- changes diff symbols
    	cond = hide_in_width,
    }

    local mode = {
    	"mode",
    	fmt = function(str)
    		return "-- " .. str .. " --"
    	end,
    }

    local filetype = {
    	"filetype",
    	icons_enabled = false,
    	icon = nil,
    }

    local branch = {
    	"branch",
    	icons_enabled = true,
    	icon = "",
    }

    local location = {
    	"location",
    	padding = 0,
    }
    -- cool function for progress
    local progress = function()
    	local current_line = vim.fn.line(".")
    	local total_lines = vim.fn.line("$")
    	local chars = { "__", "▁▁", "▂▂", "▃▃", "▄▄", "▅▅", "▆▆", "▇▇", "██" }
    	local line_ratio = current_line / total_lines
    	local index = math.ceil(line_ratio * #chars)
    	return chars[index]
    end

    local spaces = function()
    	return "spaces: " .. vim.api.nvim_buf_get_option(0, "shiftwidth")
    end

    local status_ok, lualine = pcall(require, "lualine")
    if not status_ok then
    	return
    end

    local status_ok, navic = pcall(require, "nvim-navic")
    if not status_ok then
    	return
    end
    lualine.setup({
    	options = {
    		icons_enabled = true,
    		theme = "auto",
    		section_separators = { left = "", right = "" },
    		component_separators = { left = "", right = "" },
    		disabled_filetypes = { "alpha", "dashboard", "NvimTree", "Outline" },
    		always_divide_middle = true,
    	},
    	sections = {
    		lualine_a = { branch, diagnostics },
    		lualine_b = { mode },
    		lualine_c = { { navic.get_location, cond = navic.is_available } },
    		-- lualine_x = { "encoding", "fileformat", "filetype" },
    		lualine_x = { diff, spaces, "encoding", filetype },
    		lualine_y = { location },
    		lualine_z = { progress },
    	},
    	inactive_sections = {
    		lualine_a = {},
    		lualine_b = {},
    		lualine_c = { "filename" },
    		lualine_x = { "location" },
    		lualine_y = {},
    		lualine_z = {},
    	},
    	tabline = {},
    	extensions = {},
    })
  '';
}
# TODO: Impliment these lualine sections

