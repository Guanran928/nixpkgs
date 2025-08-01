{
  lib,
  stdenv,
  fetchFromGitHub,
  ats2,
}:

stdenv.mkDerivation {
  pname = "ats-acc";
  version = "0-unstable-2018-10-21";

  src = fetchFromGitHub {
    owner = "sparverius";
    repo = "ats-acc";
    rev = "2d49f4e76d0fe1f857ceb70deba4aed13c306dcb";
    sha256 = "sha256-Wp39488YNL40GKp4KaJwhi75PsYP+gMtrZqAvs4Q/sw=";
  };

  postPatch = ''
    substituteInPlace Makefile \
      --replace "mv acc \''$(PATSHOME)/bin/" "install -Dm755 acc ${placeholder "out"}/bin/"
  '';

  nativeBuildInputs = [ ats2 ];

  meta = with lib; {
    description = "Pretty-print error messages of the ATS Compiler";
    homepage = "https://github.com/sparverius/ats-acc";
    maintainers = with maintainers; [ moni ];
    license = licenses.unfree; # Upstream has no license
  };
}
