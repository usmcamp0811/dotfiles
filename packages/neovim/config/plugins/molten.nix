{ pkgs, ... }: {
  plugins.molten = {
    enable = true; # Whether to enable molten-nvim
    settings = {
      auto_open_output =
        false; # Automatically open the output window when your cursor moves over a cell
      copy_output =
        true; # Copy evaluation output to clipboard automatically (requires pyperclip)
      enter_output_behavior =
        "open_then_enter"; # The behavior of MoltenEnterOutput
      image_provider = "image.nvim"; # How images are displayed
      output_crop_border =
        true; # ‘crops’ the bottom border of the output window
      output_show_more =
        false; # Shows the number of extra lines in the window footer
      output_virt_lines = false; # Pad the main buffer with virtual lines
      output_win_cover_gutter =
        true; # Should the output window cover the gutter
      output_win_hide_on_leave =
        true; # After leaving the output window, do not redraw it
      output_win_max_height = 999999; # Max height of the output window
      output_win_max_width = 999999; # Max width of the output window
      output_win_style = false; # Style of the output window
      show_mimetype_debug = false; # Show mime-type for each output chunk
      use_border_highlights =
        false; # Uses different highlights for output border
      virt_lines_off_by1 =
        false; # Allows the output window to cover exactly one line
      wrap_output = false; # Wrap text in output windows
    };
  };
}
