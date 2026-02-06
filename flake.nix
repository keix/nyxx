{
  description = "Nyxx Dev Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zigpkgs.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, zigpkgs }:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ] (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ zigpkgs.overlays.default ];
      };
      lib = pkgs.lib;
    in {
      devShells.default = pkgs.mkShell {
        name = "nyxx-shell";

        packages = [
          pkgs.zigpkgs."0.14.1"
        ]
        ++ lib.optionals (!pkgs.stdenv.isDarwin) [
          pkgs.SDL2
        ];

        shellHook = ''
          echo "Nyxx DevShell loaded (${system})"
          echo "  zig: $(zig version)"
        '';
      };
    }
  );
}
