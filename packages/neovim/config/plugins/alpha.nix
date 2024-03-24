{
  # TODO: Fix shortcuts and button layout
  plugins = {
    alpha = {
      enable = true;

      layout = [
        {
          type = "padding";
          val = 2;
        }
        {
          opts = {
            hl = "Include";
            position = "center";
          };
          type = "text";
          val = [
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢿⠻⢿⣷⣷⣷⣷⣷⣷⣷⣷⣧⣤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢂⣀⠀⡀⠀⠀⠀⠀⠀⠀⠈⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡀⠀⢀⡍⢛⣷⣿⡆⠀⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣿⣿⣿⣆⠘⠀⠜⠿⠿⠳⠀⢀⣀⣿⣿⣿⣶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⣿⣿⡿⠻⣿⣿⣿⣿⣿⣾⣶⣶⣷⣿⣿⣿⣿⣿⡻⢿⣿⣿⣿⣶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠠⣶⣾⣿⣿⣿⡿⠟⠉⣤⡾⠋⣹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⠙⠷⣦⡈⠛⢾⣿⣿⣿⣿⣶⠄⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠀⠀⠉⠉⠀⠾⠿⠿⠃⠘⣿⣿⣿⣿⠇⠈⠿⠿⠷⠀⠉⠉⠀⠀⠉⠉⠉⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⡿⠉⣿⣿⡉⢿⣧⡀⠀⠀⠀⠀⡄⢂⣀⠀⠀⠀⠀⣊⠄⠴⠐⣤⡀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⠀⠀⠀⠀⠈⠩⠡⠔⠔⢤⣤⣤⣉⡃⠀⠀⠀⠐⢋⣭⣴⡀⠀⢀⣧⠠⠖⠘⣡⠈⢿⡆⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⢀⣤⠖⣻⣿⡿⠃⠀⢀⡀⠀⠀⠀⠀⠀⠈⠛⠀⢉⣶⣴⣤⣤⡀⡀⣀⠛⠻⣷⣀⣴⣿⣄⠘⣡⠡⠖⢸⡯⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠛⠟⠢⢴⣿⠃⠀⣀⣸⠁⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣯⣩⣉⣉⡂⢘⡈⠃⡆⢩⠙⠻⣷⣄⣁⢂⣡⡾⠃⠀⠀"
            "⠀⠀⠀⠀⠀⢠⡐⢠⣿⡗⠘⠇⠀⠐⠛⢛⣢⡀⢀⠀⠀⣤⣴⡈⣿⣿⣿⣿⡟⡛⠟⠿⠆⠻⠛⢦⣌⡘⠅⠦⠉⡋⠛⠉⠀⠀⠀⠀"
            "⠀⠀⠀⢠⡘⠂⢰⣿⣿⠇⣡⠀⠀⣿⡿⠿⠿⢽⣶⣦⣀⢛⠙⢿⠛⠚⠻⢿⣿⣿⣿⣷⣶⡀⠀⠈⢿⣿⣃⡀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⢒⠂⢠⣿⣿⣿⠠⠶⠀⠠⣴⣶⣾⣾⣾⣿⣿⣿⣿⣷⣶⠀⠀⠀⠀⠈⠹⢦⣬⣬⡁⠀⠀⠘⠋⠥⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⢈⠥⠀⣼⣿⠟⢡⡘⠁⡬⠁⢋⣉⣍⣍⣭⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠀⢀⡟⠻⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠠⢒⠰⠋⣅⠚⢂⣴⡀⠖⡰⡙⠿⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⡧⠀⠀⢀⡴⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⢩⠄⢓⣤⣾⣿⣿⣧⠘⡠⢁⠐⢶⣷⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⣰⣾⣶⡦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⣠⡄⠞⡈⢿⣿⣿⣿⣿⣄⠀⠋⡤⠀⠉⠡⣥⣽⣿⣿⣿⣿⣿⣆⣼⣉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠈⢡⠂⠻⣿⣿⣿⣿⣷⣦⣀⠋⡄⢀⠀⠈⠉⠛⠛⠛⠋⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠚⢡⠀⡈⠙⠻⠿⣿⣿⣷⣦⠘⠛⠖⠦⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠈⠘⠂⢆⢰⡀⣄⠨⠉⠉⢻⣿⣿⡿⠟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
          ];
        }
        {
          type = "padding";
          val = 2;
        }
        {
          type = "group";
          val = [
            {
              type = "button";
              val = "󱔚  Find file";
              on_press.__raw = "function() vim.cmd('Telescope find_files') end";
              opts = {
                keymap = [
                  "n"
                  "f"
                  "" 
                  {
                    noremap = true;
                    # silent = true;
                  }
                ];
                shortcut = "f";
                align_shortcut = "right";
                position = "center";
                width = 50;
                # hl = "Keyword";
              };
            }
            {
              type = "button";
              val = "  New file";
              on_press.__raw = "function() vim.cmd[[ene]] end";
              opts = {
                shortcut = "e"; 
                keymap = [
                  "n"
                  "e"
                  "" 
                  {
                    noremap = true;
                    silent = true;
                  }
                ];
                align_shortcut = "right";
                position = "center";
                width = 50;
                # hl = "Keyword";
              };
            }
            {
              type = "button";
              val = "󰶂  Recently used files";
              on_press.__raw = "function() vim.cmd('Telescope oldfiles') end";
              opts = {
                shortcut = "r"; 
                keymap = [
                  "n"
                  "r"
                  "" 
                  {
                    noremap = true;
                    silent = true;
                  }
                ];
                align_shortcut = "right";
                position = "center";
                width = 50;
                # hl = "Keyword";
              };
            }
            {
              type = "button";
              val = "󰇊  Find text";
              on_press.__raw = "function() vim.cmd('Telescope live_grep') end";
              opts = {
                shortcut = "t"; 
                keymap = [
                  "n"
                  "t"
                  "" 
                  {
                    noremap = true;
                    silent = true;
                  }
                ];
                align_shortcut = "right";
                position = "center";
                width = 50;
                # hl = "Keyword";
              };
            }
            {
              type = "button";
              val = "󱔚 Neorg Home";
              on_press.__raw =
                "function() vim.cmd(':e ~/vimwiki/home/index.norg<CR>') end";
              opts = {
                shortcut = "N"; 
                keymap = [
                  "n"
                  "N"
                  "" 
                  {
                    noremap = true;
                    silent = true;
                  }
                ];
                align_shortcut = "right";
                position = "center";
                width = 50;
                # hl = "Keyword";
              };
            }
            {
              type = "button";
              val = "󰇊  Quit Neovim";
              on_press.__raw = "function() vim.cmd[[qa]] end";
              opts = {
                shortcut = "q"; 
                keymap = [
                  "n"
                  "q"
                  "" 
                  {
                    noremap = true;
                    silent = true;
                  }
                ];
                align_shortcut = "right";
                position = "center";
                width = 50;
                # hl = "Keyword";
              };
            }
          ];
        }
        {
          type = "padding";
          val = 2;
        }
        {
          opts = {
            hl = "Type";
            position = "center";
          };
          type = "text";
          val = "aicampground.com";
        }
      ];
    };
  };
}

