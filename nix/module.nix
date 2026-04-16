{ config, lib, pkgs, ... }:
let
  cfg = config.programs.qylock;
  inherit (lib) mkEnableOption mkIf mkOption types;

  themeNames =
    lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../themes));

  wantsSddm = cfg.mode == "sddm" || cfg.mode == "both";
  wantsQuickshell = cfg.mode == "quickshell" || cfg.mode == "both";

  qylockThemePackage = pkgs.runCommandLocal "qylock-theme-${cfg.theme}" { nativeBuildInputs = [ pkgs.gnused ]; } ''
    mkdir -p "$out/share/sddm/themes"
    cp -r ${../themes}/${cfg.theme} "$out/share/sddm/themes/${cfg.theme}"
    chmod -R u+w "$out/share/sddm/themes/${cfg.theme}"

    conf="$out/share/sddm/themes/${cfg.theme}/theme.conf"
    if [ -f "$conf" ]; then
      case "${cfg.theme}" in
        terraria)
          sed -i "s/^background_mode=.*/background_mode=${cfg.terraria.backgroundMode}/" "$conf"
          sed -i "s/^background_index=.*/background_index=${toString cfg.terraria.backgroundIndex}/" "$conf"
          ;;
        Genshin)
          sed -i "s/^background_mode=.*/background_mode=${cfg.genshin.backgroundMode}/" "$conf"
          sed -i "s/^background_index=.*/background_index=${toString cfg.genshin.backgroundIndex}/" "$conf"
          ;;
        clockwork)
          sed -i "s/^themeMode=.*/themeMode=${cfg.clockwork.themeMode}/" "$conf"
          sed -i "s/^enableWindup=.*/enableWindup=${if cfg.clockwork.enableWindup then "true" else "false"}/" "$conf"
          ;;
        osu)
          sed -i "s/^gameMode=.*/gameMode=${cfg.osu.gameMode}/" "$conf"
          ;;
      esac
    fi
  '';

  qylockQuickshellPackage = pkgs.stdenvNoCC.mkDerivation {
    name = "qylock-quickshell";
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/share/qylock"
      cp -r ${../quickshell-lockscreen} "$out/share/qylock/quickshell-lockscreen"
      cp -r ${../themes} "$out/share/qylock/themes"
      chmod +x "$out/share/qylock/quickshell-lockscreen/lock.sh"

      mkdir -p "$out/bin"
      cat > "$out/bin/qylock-lock" <<'EOF'
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      exec "${placeholder "out"}/share/qylock/quickshell-lockscreen/lock.sh" "${1:-${cfg.theme}}"
      EOF
      chmod +x "$out/bin/qylock-lock"
    '';
  };

  commonPackages = [
    pkgs.qt6.qt5compat
    pkgs.qt6.qtdeclarative
    pkgs.qt6.qtmultimedia
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-plugins-ugly
    pkgs.ffmpeg
  ];

  sddmPackages = [
    pkgs.sddm
    pkgs.qt6.qtsvg
  ];

  quickshellPackages = [ pkgs.quickshell ];
in
{
  options.programs.qylock = {
    enable = mkEnableOption "Qylock themes on NixOS";

    mode = mkOption {
      type = types.enum [ "sddm" "quickshell" "both" ];
      default = "sddm";
      description = "Install target: SDDM, Quickshell lockscreen, or both.";
    };

    theme = mkOption {
      type = types.enum themeNames;
      default = "nier-automata";
      description = "Default Qylock theme/background.";
    };

    terraria = {
      backgroundMode = mkOption {
        type = types.enum [ "time" "random" "static" ];
        default = "time";
        description = "Terraria background mode.";
      };
      backgroundIndex = mkOption {
        type = types.ints.between 1 5;
        default = 1;
        description = "Terraria static background index (1-5).";
      };
    };

    genshin = {
      backgroundMode = mkOption {
        type = types.enum [ "time" "random" "static" ];
        default = "time";
        description = "Genshin background mode.";
      };
      backgroundIndex = mkOption {
        type = types.ints.between 1 4;
        default = 1;
        description = "Genshin static background index (1-4).";
      };
    };

    clockwork = {
      themeMode = mkOption {
        type = types.enum [ "dark" "light" ];
        default = "dark";
        description = "Clockwork visual mode.";
      };
      enableWindup = mkOption {
        type = types.bool;
        default = true;
        description = "Enable clock windup animation.";
      };
    };

    osu = {
      gameMode = mkOption {
        type = types.enum [ "menu" "game" ];
        default = "game";
        description = "Osu login mode.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !wantsSddm || config.services.displayManager.sddm.enable or false;
        message = "programs.qylock.mode includes 'sddm', but services.displayManager.sddm.enable is false.";
      }
    ];

    environment.systemPackages =
      commonPackages
      ++ lib.optionals wantsSddm sddmPackages
      ++ lib.optionals wantsQuickshell (quickshellPackages ++ [ qylockQuickshellPackage ]);

    services.displayManager.sddm = mkIf wantsSddm {
      theme = lib.mkDefault cfg.theme;
      themePackages = [ qylockThemePackage ];
    };
  };
}
