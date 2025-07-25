{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  libsndfile,
  libsamplerate,
  flex,
  bison,
  boost,
  gettext,
  portaudio,
  alsa-lib ? null,
  libpulseaudio ? null,
  libjack2 ? null,
  liblo ? null,
  ladspa-sdk ? null,
  fluidsynth ? null,
  # , gmm ? null  # opcodes don't build with gmm 5.1
  eigen ? null,
  curl ? null,
  tcltk ? null,
  fltk ? null,
}:

stdenv.mkDerivation {
  pname = "csound";
  version = "6.18.1-unstable-2024-07-02";

  hardeningDisable = [ "format" ];

  src = fetchFromGitHub {
    owner = "csound";
    repo = "csound";
    rev = "2536da284dd70ec7272040cb0763f70ae57123c4";
    sha256 = "sha256-NDYltwmjBsX1DWCjy8/4cXMSl3/mK+HaQHSKUmRR9TI=";
  };

  cmakeFlags = [
    "-DBUILD_CSOUND_AC=0"
  ] # fails to find Score.hpp
  ++ lib.optional stdenv.hostPlatform.isDarwin "-DCS_FRAMEWORK_DEST=${placeholder "out"}/lib"
  # Ignore gettext in CMAKE_PREFIX_PATH on cross to prevent find_program picking up the wrong gettext
  ++ lib.optional (
    stdenv.hostPlatform != stdenv.buildPlatform
  ) "-DCMAKE_IGNORE_PATH=${lib.getBin gettext}/bin";

  nativeBuildInputs = [
    cmake
    flex
    bison
    gettext
  ];
  buildInputs = [
    libsndfile
    libsamplerate
    boost
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    portaudio
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux (
    builtins.filter (optional: optional != null) [
      alsa-lib
      libpulseaudio
      libjack2
      liblo
      ladspa-sdk
      fluidsynth
      eigen
      curl
      tcltk
      fltk
    ]
  );

  postInstall = lib.optional stdenv.hostPlatform.isDarwin ''
    mkdir -p $out/Library/Frameworks
    ln -s $out/lib/CsoundLib64.framework $out/Library/Frameworks
  '';

  meta = with lib; {
    description = "Sound design, audio synthesis, and signal processing system, providing facilities for music composition and performance on all major operating systems and platforms";
    homepage = "https://csound.com/";
    license = licenses.lgpl21Plus;
    maintainers = [ maintainers.marcweber ];
    platforms = platforms.unix;
    broken = stdenv.hostPlatform.isDarwin;
  };
}
