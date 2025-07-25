{
  majorVersion,
  minorVersion,
  sourceSha256,
  patchesToFetch ? [ ],
}:
{
  stdenv,
  lib,
  fetchurl,
  cmake,
  libGLU,
  libGL,
  libX11,
  xorgproto,
  libXt,
  libpng,
  libtiff,
  fetchpatch,
  enableQt ? false,
  qtx11extras,
  qttools,
  qtdeclarative,
  qtEnv,
  enablePython ? false,
  python ? throw "vtk: Python support requested, but no python interpreter was given.",
  enableEgl ? false,
}:

let
  inherit (lib) optionalString optionals;

  version = "${majorVersion}.${minorVersion}";
  pythonMajor = lib.substring 0 1 python.pythonVersion;

in
stdenv.mkDerivation {
  pname = "vtk" + optionalString enableEgl "-egl" + optionalString enableQt "-qvtk";
  inherit version;

  src = fetchurl {
    url = "https://www.vtk.org/files/release/${majorVersion}/VTK-${version}.tar.gz";
    sha256 = sourceSha256;
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    libpng
    libtiff
  ]
  ++ optionals enableQt [
    (qtEnv "qvtk-qt-env" [
      qtx11extras
      qttools
      qtdeclarative
    ])
  ]
  ++ optionals stdenv.hostPlatform.isLinux [
    libGLU
    xorgproto
    libXt
  ]
  ++ optionals enablePython [
    python
  ];
  propagatedBuildInputs = optionals stdenv.hostPlatform.isLinux [
    libX11
    libGL
  ];
  # see https://github.com/NixOS/nixpkgs/pull/178367#issuecomment-1238827254

  patches = map fetchpatch patchesToFetch;

  # GCC 13: error: 'int64_t' in namespace 'std' does not name a type
  postPatch = ''
    sed '1i#include <cstdint>' \
      -i ThirdParty/libproj/vtklibproj/src/proj_json_streaming_writer.hpp \
      -i IO/Image/vtkSEPReader.h
  ''
  + optionalString stdenv.hostPlatform.isDarwin ''
    sed -i 's|COMMAND vtkHashSource|COMMAND "DYLD_LIBRARY_PATH=''${VTK_BINARY_DIR}/lib" ''${VTK_BINARY_DIR}/bin/vtkHashSource-${majorVersion}|' ./Parallel/Core/CMakeLists.txt
    sed -i 's/fprintf(output, shift)/fprintf(output, "%s", shift)/' ./ThirdParty/libxml2/vtklibxml2/xmlschemas.c
    sed -i 's/fprintf(output, shift)/fprintf(output, "%s", shift)/g' ./ThirdParty/libxml2/vtklibxml2/xpath.c
  '';

  dontWrapQtApps = true;

  # Shared libraries don't work, because of rpath troubles with the current
  # nixpkgs cmake approach. It wants to call a binary at build time, just
  # built and requiring one of the shared objects.
  # At least, we use -fPIC for other packages to be able to use this in shared
  # objects.
  cmakeFlags = [
    "-DCMAKE_C_FLAGS=-fPIC"
    "-DCMAKE_CXX_FLAGS=-fPIC"
    "-DVTK_MODULE_USE_EXTERNAL_vtkpng=ON"
    "-DVTK_MODULE_USE_EXTERNAL_vtktiff=1"
    "-DVTK_MODULE_ENABLE_VTK_RenderingExternal=YES"
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "-DOPENGL_INCLUDE_DIR=${lib.getInclude libGL}/include"
    (lib.cmakeBool "VTK_OPENGL_HAS_EGL" enableEgl)
  ]
  ++ [
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DVTK_VERSIONED_INSTALL=OFF"
  ]
  ++ optionals enableQt [
    "-DVTK_GROUP_ENABLE_Qt:STRING=YES"
  ]
  ++ optionals enablePython [
    "-DVTK_WRAP_PYTHON:BOOL=ON"
    "-DVTK_PYTHON_VERSION:STRING=${pythonMajor}"
  ];

  env = {
    # Lots of warnings in vendored code…
    NIX_CFLAGS_COMPILE =
      if stdenv.cc.isClang then
        "-Wno-error=incompatible-function-pointer-types"
      else
        "-Wno-error=incompatible-pointer-types";
  };

  postInstall = optionalString enablePython ''
    substitute \
      ${./vtk.egg-info} \
      $out/${python.sitePackages}/vtk-${version}.egg-info \
      --subst-var-by VTK_VER "${version}"
  '';

  meta = with lib; {
    description = "Open source libraries for 3D computer graphics, image processing and visualization";
    homepage = "https://www.vtk.org/";
    license = licenses.bsd3;
    maintainers = with maintainers; [
      tfmoraes
    ];
    platforms = platforms.unix;
    badPlatforms = optionals enableEgl platforms.darwin;
  };
}
