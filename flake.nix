{
  description = "Rust development dev shell";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, crane, fenix, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        inherit (pkgs) lib;

        craneLib = (crane.mkLib pkgs).overrideToolchain (p:
        p.rust-bin.nightly.latest.default.override {
          extensions = ["rust-src" "clippy" "rustfmt"
                        "rust-analysis" "rustc" "miri"
                        "rust" "rust-std" "cargo" "rust-analyzer"];
        });
        src = craneLib.cleanCargoSource ./.;
        commonArgs = {
          inherit src;
          strictDeps = true;

          buildInputs = with pkgs; [
            openssl
            pkg-config
            eza
            fd
            lldb
            clang
            cargo-audit
            bpf-linker
          ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        individualCrateArgs = commonArgs // {
          inherit cargoArtifacts;
          inherit (craneLib.crateNameFromCargoToml { inherit src; })
          version;
          doCheck = false;
        };

        fileSetForCrate = crate: lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./Cargo.toml
            ./Cargo.lock
            ./xtask
            ./ebpf-fw-common
            ./ebpf-fw
            crate
          ];
        };

        ebpf-fw= craneLib.buildPackage (individualCrateArgs //
        {
          pname = "ebpf-fw";
          cargoExtraArgs = "-p ebpf-fw";
          src = fileSetForCrate ./ebpf-fw;
          CARGO_BUILD_RUSTFLAGS = "-C link-arg=-lasan -Zproc-macro-backtrace";
        });

      in
      with pkgs;
      {
        packages = {
          inherit ebpf-fw;
          default = ebpf-fw;
        };

        devShells.default = craneLib.devShell {
          inherit (commonArgs) buildInputs;
        };
      }
    );
}
