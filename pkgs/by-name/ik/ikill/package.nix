{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "ikill";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "pjmp";
    repo = "ikill";
    rev = "v${version}";
    sha256 = "sha256-hOQBBwxkVnTkAZJi84qArwAo54fMC0zS+IeYMV04kUs=";
  };

  cargoHash = "sha256-Xbl9cQKWxtwNQqWW41mQrVAsvMLUkTb0irDLD/XstMI=";

  meta = with lib; {
    description = "Interactively kill running processes";
    homepage = "https://github.com/pjmp/ikill";
    maintainers = with maintainers; [ zendo ];
    license = [ licenses.mit ];
    platforms = platforms.linux;
    mainProgram = "ikill";
  };
}
