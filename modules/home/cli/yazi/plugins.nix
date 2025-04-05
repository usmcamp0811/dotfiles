{ pkgs, ... }: {
  official-plugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "9a095057d698aaaedc4dd23d638285bd3fd647e9";
    hash = "sha256-Lx+TliqMuaXpjaUtjdUac7ODg2yc3yrd1mSWJo9Mz2Q=";
  };

  mime-preview = pkgs.fetchFromGitHub {
    owner = "DreamMaoMao";
    repo = "mime-preview.yazi";
    rev = "5ee0e78d7a46b756b77bec029722d31823869f08";
    hash = "sha256-utK+Ng0M5BvxAH/Cjz6/Gg6vc+cD9bwJxiQTerOhnW8=";
  };

  mime-ext = pkgs.fetchFromGitHub {
    owner = "DreamMaoMao";
    repo = "mime-ext.yazi";
    rev = "47b5f85b0b6156f689641132eb9d29f7301b9b6a";
    hash = "sha256-+hxHKEhvpvHcTrb56BY7cuvzKYO3ywbvdY4dmPQR4pU=";
  };

  mediainfo = pkgs.fetchFromGitHub {
    owner = "boydaihungst";
    repo = "mediainfo.yazi";
    rev = "2c3f675d3722672eb3a3422590375d1145843a40";
    hash = "sha256-LKO2kbpI8NnEnvIIAp01RefSlhGQV1BRDNO03eLQZoA=";
  };

  office = pkgs.fetchFromGitHub {
    owner = "macydnah";
    repo = "office.yazi";
    rev = "bcd9e9e78835c96eb2bb8b8841e4753704b99b17";
    hash = "sha256-rZas/oMNI6H5lXOixDQcL/dQC+J9VCFrOOIIjjLDUc4=";
  };

  eza-preview = pkgs.fetchFromGitHub {
    owner = "ahkohd";
    repo = "eza-preview.yazi";
    rev = "6575a9a4806d8dc96ac75adf28791155551804fb";
    hash = "sha256-RwJu79bjdgmKbRaDH++y8wreBKdGGwbyGOx4G/px2PE=";
  };

  glow = pkgs.fetchFromGitHub {
    owner = "Reledia";
    repo = "glow.yazi";
    rev = "5ce76dc92ddd0dcef36e76c0986919fda3db3cf5";
    hash = "sha256-UljcrXXO5DZbufRfavBkiNV3IGUNct31RxCujRzC9D4=";
  };

  hexyl = pkgs.fetchFromGitHub {
    owner = "Reledia";
    repo = "hexyl.yazi";
    rev = "39d3d4e23ad7cec8888f648ddf55af4386950ce7";
    hash = "sha256-nsnnL3GluKk/p1dQZTZ/RwQPlAmTBu9mQzHz1g7K0Ww=";
  };

  ouch = pkgs.fetchFromGitHub {
    owner = "ndtoan96";
    repo = "ouch.yazi";
    rev = "ce6fb75431b9d0d88efc6ae92e8a8ebb9bc1864a";
    hash = "sha256-oUEUGgeVbljQICB43v9DeEM3XWMAKt3Ll11IcLCS/PA=";
  };

  rich-preview = pkgs.fetchFromGitHub {
    owner = "AnirudhG07";
    repo = "rich-preview.yazi";
    rev = "2559e5fa7c1651dbe7c5615ef6f3b5291347d81a";
    hash = "sha256-dW2gAAv173MTcQdqMV32urzfrsEX6STR+oCJoRVGGpA=";
  };

  yatline = pkgs.fetchFromGitHub {
    owner = "imsi32";
    repo = "yatline.yazi";
    rev = "600ed1fb1d04e1292da04280a65f8deca04dc36a";
    hash = "sha256-oHCRScbahGaX8MTVNalNXlxQ7NJN5QKvGHbTXreAWFM=";
  };

  lazygit = pkgs.fetchFromGitHub {
    owner = "Lil-Dank";
    repo = "lazygit.yazi";
    rev = "9f924e34cde61d5965d6d620698b0b15436c8e08";
    hash = "sha256-ns9DzIdI2H3IuCByoJjOtUWQQB9vITxmJ/QrYt+Rdao=";
  };

  githead = pkgs.fetchFromGitHub {
    owner = "llanosrocas";
    repo = "githead.yazi";
    rev = "23750247d59da485e4b5257ad5e83837bb86a685";
    hash = "sha256-VErtv5+I3BBnfbOQrHFvvLo7GAExXwVmhHNq+84kam8=";
  };

  onedark = pkgs.fetchFromGitHub {
    owner = "BennyOe";
    repo = "onedark.yazi";
    rev = "main";
    hash = "sha256-SJdkLjF2i5/G0H/x9kTPXv/ozzMO1WhddWMjZi6+x3A=";
  };

  kanagawa = pkgs.fetchFromGitHub {
    owner = "dangooddd";
    repo = "kanagawa.yazi";
    rev = "d98f0c3e27299f86ee080294df2722c5a634495a";
    hash = "sha256-Z/lyXNCSqX0wvCQd39ZedxOGlhRzQ+M0hqzkBEcpxEE=";
  };

  material-ocean = pkgs.fetchFromGitHub {
    owner = "myamusashi";
    repo = "material-ocean.yazi";
    rev = "b0d8a53e5df7dd9935f8be108c2e6f47c208a75c";
    hash = "sha256-Hc3CmoQYWaIxob7z6bXtrxT/sL/GWxxn8E5fEV4MIKU=";
  };

  fzf = pkgs.fetchFromGitHub {
    owner = "DreamMaoMao";
    repo = "fg.yazi";
    rev = "daf696065d65e61a1b3026ab8190351203513d51";
    hash = "sha256-dcidPBhc0+NvPb80hK+kUoq+PxspceFCliyEc7K3OTk=";
  };
}
