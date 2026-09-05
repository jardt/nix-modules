{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    optionals
    types
    ;
  cfg = config.modules.home.reverse-engineering;

  corePackages = with pkgs; [
    binutils
    file
    hexyl
    jq
    ripgrep
    upx
    yara
  ];

  nativePackages =
    with pkgs;
    [
      gdb
      lldb
      patchelf
      radare2
    ]
    ++ optionals pkgs.stdenv.hostPlatform.isLinux (
      with pkgs;
      [
        ltrace
        strace
      ]
    );

  coreExtraPackages = with pkgs; [
    capa
    checksec
    cutter
    elfutils
    lief
    rizin
  ];

  dynamicAnalysisPackages = with pkgs; [
    capstone
    gef
    keystone
    python3Packages.angr
    unicorn
  ];

  networkAnalysisPackages = with pkgs; [
    mitmproxy
    wireshark
  ];

  androidPackages = with pkgs; [
    android-tools
    androguard
    apktool
    frida-tools
    jadx
    cfg.hbcdumpPackage
  ];

  firmwarePackages = with pkgs; [
    binwalk
    dtc
    jefferson
    mtdutils
    squashfsTools
    ubi_reader
    ubootTools
  ];
in
{
  options.modules.home.reverse-engineering = {
    enable = mkEnableOption "reverse-engineering tools";

    native.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install native binary analysis and debugging tools.";
    };

    coreExtras.enable = mkEnableOption "additional core reverse-engineering tools";

    dynamicAnalysis.enable = mkEnableOption "dynamic binary analysis tools";

    networkAnalysis.enable = mkEnableOption "network traffic analysis tools";

    android.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Install Android command-line analysis tools.";
    };

    firmware.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Install firmware inspection and extraction tools.";
    };

    hbcdumpPackage = mkOption {
      type = types.package;
      description = "hbcdump package to use for Android analysis.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.ghidra ]";
      description = "Additional reverse-engineering packages to install.";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      corePackages
      ++ optionals cfg.native.enable nativePackages
      ++ optionals cfg.coreExtras.enable coreExtraPackages
      ++ optionals cfg.dynamicAnalysis.enable dynamicAnalysisPackages
      ++ optionals cfg.networkAnalysis.enable networkAnalysisPackages
      ++ optionals cfg.android.enable androidPackages
      ++ optionals cfg.firmware.enable firmwarePackages
      ++ cfg.extraPackages;
  };
}
