# SECCION: HOME MANAGER
# IPC: enable package dirs autostart
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.oozewalls;
in
{
  options.programs.oozewalls = {
    enable = lib.mkEnableOption "oozewalls";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
    };
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Reaplica el fondo guardado al iniciar la sesion grafica (oozewalls restore).";
    };
    dirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    systemd.user.services.oozewalls-restore = lib.mkIf cfg.autostart {
      Unit = {
        Description = "OozeWalls restore";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/oozewalls restore";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    xdg.configFile."oozewalls/config.json".text = builtins.toJSON {
      current = null;
      wallpapers = { };
      scaling = { };
      dirs = cfg.dirs;
      output = "*";
      mute = true;
      volume = 100;
      hwdec = "auto-safe";
      layer = "background";
    };
  };
}
