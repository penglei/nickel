{ pkgs, buildPackage, fixupGitRevision, env }:
{
  kompose-cli = buildPackage {
    cargoPackage = "kompose-cli";
    pnameSuffix = "-cli";
    extraArgs.meta.mainProgram = "kp";
  };
} // (if pkgs.stdenv.hostPlatform.isMacOS then { } else
{
  kompose-static =
    fixupGitRevision
      (buildPackage {
        cargoPackage = "kompose-cli";
        pnameSuffix = "-cli";
        extraArgs = {
          inherit env;
          CARGO_BUILD_TARGET = pkgs.rust.toRustTarget pkgs.pkgsMusl.stdenv.hostPlatform;
          RUSTFLAGS = "-L${pkgs.pkgsMusl.llvmPackages.libcxx}/lib -lstatic=c++abi -C link-arg=-lc";
          CXXSTDLIB = "static=c++";
          stdenv = pkgs.pkgsMusl.libcxxStdenv;
          doCheck = false;
          meta.mainProgram = "kp";
        };
      });

  nls-static =
    fixupGitRevision
      (buildPackage {
        cargoPackage = "nickel-lang-lsp";
        pnameSuffix = "-static";
        extraArgs = {
          inherit env;
          CARGO_BUILD_TARGET = pkgs.rust.toRustTarget pkgs.pkgsMusl.stdenv.hostPlatform;
          RUSTFLAGS = "-L${pkgs.pkgsMusl.llvmPackages.libcxx}/lib -lstatic=c++abi -C link-arg=-lc";
          CXXSTDLIB = "static=c++";
          stdenv = pkgs.pkgsMusl.libcxxStdenv;
          doCheck = false;
          meta.mainProgram = "nls";
        };
      });
})
