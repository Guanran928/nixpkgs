{
  stdenv,
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  makeBinaryWrapper,
  nix-eval-jobs,
  nix,
  colmena,
  testers,
}:

rustPlatform.buildRustPackage rec {
  pname = "colmena";
  version = "0.4.0-unstable-2025-05-10";

  src = fetchFromGitHub {
    owner = "zhaofengli";
    repo = "colmena";
    rev = "df694ee23be7ed7b2d8b42c245a640f0724eb06c";
    hash = "sha256-ymQzXrfHVT8/RJiGbfrNjEeuzXQan46lUJdxEhgivdM=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-iL0lcHXB9+4/FPMJ4VtikVSLKD3TnmN84x2cgkxzCkU=";

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ];

  buildInputs = [ nix-eval-jobs ];

  NIX_EVAL_JOBS = "${nix-eval-jobs}/bin/nix-eval-jobs";

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd colmena \
      --bash <($out/bin/colmena gen-completions bash) \
      --zsh <($out/bin/colmena gen-completions zsh) \
      --fish <($out/bin/colmena gen-completions fish)

    wrapProgram $out/bin/colmena \
      --prefix PATH ":" "${lib.makeBinPath [ nix ]}"
  '';

  # Recursive Nix is not stable yet
  doCheck = false;

  passthru = {
    # We guarantee CLI and Nix API stability for the same minor version
    apiVersion = builtins.concatStringsSep "." (lib.take 2 (lib.splitVersion version));

    tests.version = testers.testVersion { package = colmena; };
  };

  meta = with lib; {
    description = "Simple, stateless NixOS deployment tool";
    homepage = "https://colmena.cli.rs/${passthru.apiVersion}";
    license = licenses.mit;
    maintainers = with maintainers; [ zhaofengli ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "colmena";
  };
}
