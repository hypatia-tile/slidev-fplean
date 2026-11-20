{
  description = "Functional Programming in Lean as Slidev decks backed by checked Lean code";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # elan provides `lean`/`lake` proxies; the toolchain is pinned in lean/lean-toolchain.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.elan
            pkgs.nodejs_24
            pkgs.pnpm
          ];
        };
      });
    };
}
