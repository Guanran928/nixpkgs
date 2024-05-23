{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  boost,
  cli11,
  libGL,
  libcpr,
  nlohmann_json,
  skia-aseprite,
  xorg,
}:

stdenv.mkDerivation rec {
  pname = "blur";
  version = "2.04";

  src = fetchFromGitHub {
    owner = "f0e";
    repo = "blur";
    tag = "v${version}";
    hash = "sha256-NojJ117G9ex2VhlxKxlw9VrzrCwHW+SpJZA0fu4GObc=";
    fetchSubmodules = true;
  };

  strictDeps = true;

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    boost
    cli11
    libGL
    libcpr
    nlohmann_json
    skia-aseprite
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libxcb
  ];

  prePatch = ''
    sed -i '27ifind_package(Threads REQUIRED)' CMakeLists.txt
    cp -r ${skia-aseprite} ./dependencies/skia
  '';

  cmakeFlags = [
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_QUIET=OFF"
    "-DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS"
  ];

  meta = {
    description = "Add motion blur to videos";
    homepage = "https://github.com/f0e/blur";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ Guanran928 ];
    mainProgram = "blur-cli";
    platforms = lib.platforms.all;
  };
}
