{
  description = "xcnix the lightweight package-manager-ish helping daemon for configuration.nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
    let
      # Supported architectures
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      
      # Helper function to generate attributes for each architecture system
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      # 1. Define the actual package output
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pythonScript = builtins.readFile ./xcnix.py;
        in {
          default = pkgs.writers.writePython3Bin "xcnix" { libraries = [ ]; } pythonScript;
        }
      );

      # 2. Define a reusable NixOS Module overlay so other systems can import it instantly
      overlays.default = self: super: {
        xcnix = self.callPackage ({ pkgs }: self.packages.${pkgs.system}.default) {};
      };
    };
}
