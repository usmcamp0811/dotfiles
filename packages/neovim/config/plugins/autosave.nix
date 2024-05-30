{
  extraConfigLua = "";
  autoCmd = [
    {
      event = ["FileType"];
      pattern = ["markdown"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["python"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["julia"];
      command = "let b:auto_save = 0";
    }
    {
      event = ["FileType"];
      pattern = ["go"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["css"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["json"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["java"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["html"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["r"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["scss"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["sql"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["sh"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["dockerfile"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["javascript"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["vue"];
      command = "let b:auto_save = 0";
    }
    {
      event = ["FileType"];
      pattern = ["vim"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["rmd"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["tex"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["lua"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["md"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["FileType"];
      pattern = ["vimwiki"];
      command = "let b:auto_save = 1";
    }
    {
      event = ["BufWinEnter"];
      pattern = ["plugins.lua"];
      command = "let b:auto_save = 0";
    }
  ];
}
