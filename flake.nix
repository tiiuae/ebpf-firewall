{
  description = "Rust development dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    crane,
    fenix,
    rust-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [(import rust-overlay)];
        };

        inherit (pkgs) lib;
        rustTarget = pkgs.rust-bin.fromRustupToolchainFile ./ebpf-fw-ebpf/rust-toolchain.toml;

        #NOTE might be needed later
        /*
         rustTarget = pkgs.rust-bin.selectLatestNightlyWith (toolchain:
        toolchain.default.override {
          extensions = [
            "rust-src"
            "clippy"
            "rustfmt"
            "rust-analysis"
            "rustc"
            "miri"
            "rust"
            "rust-std"
            "cargo"
            "rust-analyzer"
          ];
        });
        */

        craneLib = (crane.mkLib pkgs).overrideToolchain rustTarget;
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

        individualCrateArgs =
          commonArgs
          // {
            inherit cargoArtifacts;
            inherit
              (craneLib.crateNameFromCargoToml {inherit src;})
              version
              ;
            doCheck = false;
            cargoVendorDir = craneLib.vendorMultipleCargoDeps {
              inherit (craneLib.findCargoFiles src) cargoConfigs;
              cargoLockList = [
                ./ebpf-fw-ebpf/Cargo.lock
                ./Cargo.lock
                # Unfortunately this approach requires IFD (import-from-derivation)
                # otherwise Nix will refuse to read the Cargo.lock from our toolchain
                # (unless we build with `--impure`).
                #
                # Another way around this is to manually copy the rustlib `Cargo.lock`
                # to the repo and import it with `./path/to/rustlib/Cargo.lock` which
                # will avoid IFD entirely but will require manually keeping the file
                # up to date!
                "${rustTarget.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/library/Cargo.lock"
              ];
            };
          };

        fileSetForCrate = crate:
          lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              ./Cargo.toml
              ./Cargo.lock
              ./xtask
              ./ebpf-fw-common
              ./ebpf-fw
              ./ebpf-fw-ebpf
              crate
            ];
          };

        mkEbpFwPackage = buildType:
          craneLib.buildPackage (individualCrateArgs
            // {
              pname = "ebpf-fw-ebpf";
              cargoExtraArgs = "-p ebpf-fw-ebpf -p xtask -p ebpf-fw-common";
              src = fileSetForCrate ./ebpf-fw-ebpf;
              #CARGO_BUILD_RUSTFLAGS = "-C link-arg=-lasan -Zproc-macro-backtrace";
              nativeBuildInputs = with pkgs; [
                openssl
                pkg-config
                eza
                fd
                lldb
                clang
                cargo-audit
                bpf-linker
              ];
              buildPhaseCargoCommand = ''
                if [[ "${buildType}" == "release" ]]; then
                     cargo run --bin xtask build-ebpf --release
                     cargo build --release
                  else
                    cargo run --bin xtask build-ebpf
                     cargo build
                  fi

              '';
              installPhase = ''
                mkdir -p $out/bin
                install -D -m755 target/${buildType}/ebpf-fw $out/bin/${buildType}/ebpf-fw
              '';
            });
        # Create packages for different build types
        ebpfFwRelease = mkEbpFwPackage "release";
        ebpfFwDebug = mkEbpFwPackage "debug";
      in
        with pkgs; {
          formatter = pkgs.alejandra;
          packages = {
            inherit ebpfFwRelease ebpfFwDebug;
            default = ebpfFwRelease; # Default to release build
          };

          devShells.default = craneLib.devShell {
            inherit (commonArgs) buildInputs;
          };
        }
    );
}
