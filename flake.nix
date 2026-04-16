{
  description = "qylock - SDDM themes and quickshell lockscreen";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, ... }: {
    nixosModules.default = import ./nix/module.nix;
    nixosModules.qylock = self.nixosModules.default;
  };
}
