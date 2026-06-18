{
  description = "xcnix - A robust deployment engine for NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # System types to support (Helios laptop is x86_64-linux)
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      
      # Helper function to generate attributes for each system
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # 1. This lets people install or run it directly
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.writers.writePython3Bin "xcnix" {
            # Add any external pip packages your script needs here
            libraries = with pkgs.python3Packages; [
              # requests
              # rich
            ];
          } (builtins.readFile ./xcnix.py);
        });

      # 2. This lets you test it locally in a development shell
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              (pkgs.python3.withPackages (ps: with ps; [
                # Match the same libraries here for your dev environment
              ]))
            ];
          };
        });
    };
}
