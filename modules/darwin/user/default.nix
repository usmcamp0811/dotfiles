{ lib
, config
, ...
}:
let
  inherit (lib) types mkIf;
  inherit (lib.fmf) mkOpt;

  cfg = config.fmf.user;
in
{
  options.fmf.user = {
    name = mkOpt types.str "abe" "The user account.";

    fullName = mkOpt types.str "Matt Camp" "The full name of the user.";
    email = mkOpt types.str "matt@aicampground.com" "The email of the user.";

    uid = mkOpt (types.nullOr types.int) 501 "The uid for the user account.";
  };

  config = {
    users.users.${cfg.name} = {
      # @NOTE(jakehamilton): Setting the uid here is required for another
      # module to evaluate successfully since it reads
      # `users.users.${fmf.user.name}.uid`.
      uid = mkIf (cfg.uid != null) cfg.uid;
    };
  };
}
