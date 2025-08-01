# Python {#python}

## Reference {#reference}

### Interpreters {#interpreters}

@python-interpreter-table@

The Nix expressions for the interpreters can be found in
`pkgs/development/interpreters/python`.

All packages depending on any Python interpreter get appended
`out/{python.sitePackages}` to `$PYTHONPATH` if such directory
exists.

#### Missing `tkinter` module standard library {#missing-tkinter-module-standard-library}

To reduce closure size the `Tkinter`/`tkinter` is available as a separate package, `pythonPackages.tkinter`.

#### Attributes on interpreters packages {#attributes-on-interpreters-packages}

Each interpreter has the following attributes:

- `libPrefix`. Name of the folder in `${python}/lib/` for corresponding interpreter.
- `interpreter`. Alias for `${python}/bin/${executable}`.
- `buildEnv`. Function to build python interpreter environments with extra packages bundled together. See [](#python.buildenv-function) for usage and documentation.
- `withPackages`. Simpler interface to `buildEnv`. See [](#python.withpackages-function) for usage and documentation.
- `sitePackages`. Alias for `lib/${libPrefix}/site-packages`.
- `executable`. Name of the interpreter executable, e.g. `python3.10`.
- `pkgs`. Set of Python packages for that specific interpreter. The package set can be modified by overriding the interpreter and passing `packageOverrides`.

### Building packages and applications {#building-packages-and-applications}

Python libraries and applications that use tools to follow PEP 517 (e.g. `setuptools` or `hatchling`, etc.) or
previous tools such as `distutils` are typically built with respectively the [`buildPythonPackage`](#buildpythonpackage-function) and
[`buildPythonApplication`](#buildpythonapplication-function) functions. These two functions also support installing a `wheel`.

All Python packages reside in `pkgs/top-level/python-packages.nix` and all
applications elsewhere. In case a package is used as both a library and an
application, then the package should be in `pkgs/top-level/python-packages.nix`
since only those packages are made available for all interpreter versions. The
preferred location for library expressions is in
`pkgs/development/python-modules`. It is important that these packages are
called from `pkgs/top-level/python-packages.nix` and not elsewhere, to guarantee
the right version of the package is built.

Based on the packages defined in `pkgs/top-level/python-packages.nix` an
attribute set is created for each available Python interpreter. The available
sets are

* `pkgs.python27Packages`
* `pkgs.python3Packages`
* `pkgs.python310Packages`
* `pkgs.python311Packages`
* `pkgs.python312Packages`
* `pkgs.python313Packages`
* `pkgs.python314Packages`
* `pkgs.pypy27Packages`
* `pkgs.pypy310Packages`

and the aliases

* `pkgs.python2Packages` pointing to `pkgs.python27Packages`
* `pkgs.python3Packages` pointing to `pkgs.python313Packages`
* `pkgs.pythonPackages` pointing to `pkgs.python2Packages`
* `pkgs.pypy2Packages` pointing to `pkgs.pypy27Packages`
* `pkgs.pypy3Packages` pointing to `pkgs.pypy310Packages`
* `pkgs.pypyPackages` pointing to `pkgs.pypy2Packages`


#### `buildPythonPackage` function {#buildpythonpackage-function}

The `buildPythonPackage` function has its name binding in
`pkgs/development/interpreters/python/python-packages-base.nix` and is
implemented in `pkgs/development/interpreters/python/mk-python-derivation.nix`
using setup hooks.

The following is an example:

```nix
{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  setuptools,
  setuptools-scm,

  # dependencies
  attrs,
  pluggy,
  py,
  setuptools,
  six,

  # tests
  hypothesis,
}:

buildPythonPackage rec {
  pname = "pytest";
  version = "3.3.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-z4Q23FnYaVNG/NOrKW3kZCXsqwDWQJbOvnn7Ueyy65M=";
  };

  postPatch = ''
    # don't test bash builtins
    rm testing/test_argcomplete.py
  '';

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    attrs
    py
    setuptools
    six
    pluggy
  ];

  nativeCheckInputs = [ hypothesis ];

  meta = {
    changelog = "https://github.com/pytest-dev/pytest/releases/tag/${version}";
    description = "Framework for writing tests";
    homepage = "https://github.com/pytest-dev/pytest";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      lovek323
      madjar
      lsix
    ];
  };
}
```

The `buildPythonPackage` mainly does four things:

* In the [`buildPhase`](#build-phase), it calls `${python.pythonOnBuildForHost.interpreter} -m build --wheel` to
  build a wheel binary zipfile.
* In the [`installPhase`](#ssec-install-phase), it installs the wheel file using `${python.pythonOnBuildForHost.interpreter} -m installer *.whl`.
* In the [`postFixup`](#var-stdenv-postFixup) phase, the `wrapPythonPrograms` bash function is called to
  wrap all programs in the `$out/bin/*` directory to include `$PATH`
  environment variable and add dependent libraries to script's `sys.path`.
* In the [`installCheck`](#ssec-installCheck-phase) phase, `${python.interpreter} -m pytest` is run.

By default tests are run because [`doCheck = true`](#var-stdenv-doCheck). Test dependencies, like
e.g. the test runner, should be added to [`nativeCheckInputs`](#var-stdenv-nativeCheckInputs).

By default `meta.platforms` is set to the same value
as the interpreter unless overridden otherwise.

##### `buildPythonPackage` parameters {#buildpythonpackage-parameters}

All parameters from [`stdenv.mkDerivation`](#sec-using-stdenv) function are still supported. The
following are specific to `buildPythonPackage`:

* `catchConflicts ? true`: If `true`, abort package build if a package name
  appears more than once in dependency tree. Default is `true`.
* `disabled ? false`: If `true`, package is not built for the particular Python
  interpreter version.
* `dontWrapPythonPrograms ? false`: Skip wrapping of Python programs.
* `permitUserSite ? false`: Skip setting the `PYTHONNOUSERSITE` environment
  variable in wrapped programs.
* `pyproject`: Whether the pyproject format should be used. As all other formats
  are deprecated, you are recommended to set this to `true`. When you do so,
  `pypaBuildHook` will be used, and you can add the required build dependencies
  from `build-system.requires` to `build-system`. Note that the pyproject
  format falls back to using `setuptools`, so you can use `pyproject = true`
  even if the package only has a `setup.py`. When set to `false`, you can
  use the existing [hooks](#setup-hooks) or provide your own logic to build the
  package. This can be useful for packages that don't support the pyproject
  format. When unset, the legacy `setuptools` hooks are used for backwards
  compatibility.
* `makeWrapperArgs ? []`: A list of strings. Arguments to be passed to
  [`makeWrapper`](#fun-makeWrapper), which wraps generated binaries. By default, the arguments to
  [`makeWrapper`](#fun-makeWrapper) set `PATH` and `PYTHONPATH` environment variables before calling
  the binary. Additional arguments here can allow a developer to set environment
  variables which will be available when the binary is run. For example,
  `makeWrapperArgs = ["--set" "FOO" "BAR" "--set" "BAZ" "QUX"]`.

  ::: {.note}
  When `__structuredAttrs = false`, the attribute `makeWrapperArgs` is passed as a space-separated string to the build script. Developers should use `prependToVar` or `appendToVar` to add arguments to it in build phases, or use `__structuredAttrs = true` to ensure that `makeWrapperArgs` is passed as a Bash array.

  For compatibility purposes,
  when `makeWrapperArgs` shell variable is specified as a space-separated string (instead of a Bash array) in the build script, the string content is Bash-expanded before concatenated into the `wrapProgram` command. Still, developers should not rely on such behaviours, but use `__structuredAttrs = true` to specify flags containing spaces (e.g. `makeWrapperArgs = [ "--set" "GREETING" "Hello, world!" ]`), or use -pre and -post phases to specify flags with Bash-expansions (e.g. `preFixup = ''makeWrapperArgs+=(--prefix PATH : "$SOME_PATH")`'').
  :::

* `namePrefix`: Prepends text to `${name}` parameter. In case of libraries, this
  defaults to `"python3.8-"` for Python 3.8, etc., and in case of applications to `""`.
* `pypaBuildFlags ? []`: A list of strings. Arguments to be passed to `python -m build --wheel`.
* `pythonPath ? []`: List of packages to be added into `$PYTHONPATH`. Packages
  in `pythonPath` are not propagated (contrary to [`propagatedBuildInputs`](#var-stdenv-propagatedBuildInputs)).
* `preShellHook`: Hook to execute commands before `shellHook`.
* `postShellHook`: Hook to execute commands after `shellHook`.
* `removeBinByteCode ? true`: Remove bytecode from `/bin`. Bytecode is only
  created when the filenames end with `.py`.
* `setupPyGlobalFlags ? []`: List of flags passed to `setup.py` command.
* `setupPyBuildFlags ? []`: List of flags passed to `setup.py build_ext` command.

The [`stdenv.mkDerivation`](#sec-using-stdenv) function accepts various parameters for describing
build inputs (see "Specifying dependencies"). The following are of special
interest for Python packages, either because these are primarily used, or
because their behaviour is different:

* `nativeBuildInputs ? []`: Build-time only dependencies. Typically executables.
* `build-system ? []`: Build-time only Python dependencies. Items listed in `build-system.requires`/`setup_requires`.
* `buildInputs ? []`: Build and/or run-time dependencies that need to be
  compiled for the host machine. Typically non-Python libraries which are being
  linked.
* `nativeCheckInputs ? []`: Dependencies needed for running the [`checkPhase`](#ssec-check-phase). These
  are added to [`nativeBuildInputs`](#var-stdenv-nativeBuildInputs) when [`doCheck = true`](#var-stdenv-doCheck). Items listed in
  `tests_require` go here.
* `dependencies ? []`: Aside from propagating dependencies,
  `buildPythonPackage` also injects code into and wraps executables with the
  paths included in this list. Items listed in `install_requires` go here.
* `optional-dependencies ? { }`: Optional feature flagged dependencies.  Items listed in `extras_require` go here.


##### Overriding Python packages {#overriding-python-packages}

The `buildPythonPackage` function has a `overridePythonAttrs` method that can be
used to override the package. In the following example we create an environment
where we have the `blaze` package using an older version of `pandas`. We
override first the Python interpreter and pass `packageOverrides` which contains
the overrides for packages in the package set.

```nix
with import <nixpkgs> { };

(
  let
    python =
      let
        packageOverrides = self: super: {
          pandas = super.pandas.overridePythonAttrs (old: rec {
            version = "0.19.1";
            src = fetchPypi {
              pname = "pandas";
              inherit version;
              hash = "sha256-JQn+rtpy/OA2deLszSKEuxyttqBzcAil50H+JDHUdCE=";
            };
          });
        };
      in
      pkgs.python3.override {
        inherit packageOverrides;
        self = python;
      };

  in
  python.withPackages (ps: [ ps.blaze ])
).env
```

The next example shows a non trivial overriding of the `blas` implementation to
be used through out all of the Python package set:

```nix
{
  python3MyBlas = pkgs.python3.override {
    packageOverrides = self: super: {
      # We need toPythonModule for the package set to evaluate this
      blas = super.toPythonModule (super.pkgs.blas.override { blasProvider = super.pkgs.mkl; });
      lapack = super.toPythonModule (super.pkgs.lapack.override { lapackProvider = super.pkgs.mkl; });
    };
  };
}
```

This is particularly useful for numpy and scipy users who want to gain speed with other blas implementations.
Note that using `scipy = super.scipy.override { blas = super.pkgs.mkl; };` will likely result in
compilation issues, because scipy dependencies need to use the same blas implementation as well.

#### `buildPythonApplication` function {#buildpythonapplication-function}

The [`buildPythonApplication`](#buildpythonapplication-function) function is practically the same as
[`buildPythonPackage`](#buildpythonpackage-function). The main purpose of this function is to build a Python
package where one is interested only in the executables, and not importable
modules. For that reason, when adding this package to a [`python.buildEnv`](#python.buildenv-function), the
modules won't be made available.

Another difference is that [`buildPythonPackage`](#buildpythonpackage-function) by default prefixes the names of
the packages with the version of the interpreter. Because this is irrelevant for
applications, the prefix is omitted.

When packaging a Python application with [`buildPythonApplication`](#buildpythonapplication-function), it should be
called with `callPackage` and passed `python3` or `python3Packages` (possibly
specifying an interpreter version), like this:

```nix
{
  lib,
  python3Packages,
  fetchPypi,
}:

python3Packages.buildPythonApplication rec {
  pname = "luigi";
  version = "2.7.9";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Pe229rT0aHwA98s+nTHQMEFKZPo/yw6sot8MivFDvAw=";
  };

  build-system = with python3Packages; [ setuptools ];

  dependencies = with python3Packages; [
    tornado
    python-daemon
  ];

  meta = {
    # ...
  };
}
```

This is then added to `pkgs/by-name` just as any other application would be.

Since the package is an application, a consumer doesn't need to care about
Python versions or modules, which is why they don't go in `python3Packages`.

#### `toPythonApplication` function {#topythonapplication-function}

A distinction is made between applications and libraries, however, sometimes a
package is used as both. In this case the package is added as a library to
`python-packages.nix` and as an application to `pkgs/by-name`. To reduce
duplication the `toPythonApplication` can be used to convert a library to an
application.

The Nix expression shall use [`buildPythonPackage`](#buildpythonpackage-function) and be called from
`python-packages.nix`. A reference shall be created from `pkgs/by-name` to
the attribute in `python-packages.nix`, and the `toPythonApplication` shall be
applied to the reference:

```nix
{ python3Packages }:

python3Packages.toPythonApplication python3Packages.youtube-dl
```

#### `toPythonModule` function {#topythonmodule-function}

In some cases, such as bindings, a package is created using
[`stdenv.mkDerivation`](#sec-using-stdenv) and added as attribute in `pkgs/by-name` or in `all-packages.nix`. The Python
bindings should be made available from `python-packages.nix`. The
`toPythonModule` function takes a derivation and makes certain Python-specific
modifications.

```nix
{
  opencv = toPythonModule (
    pkgs.opencv.override {
      enablePython = true;
      pythonPackages = self;
    }
  );
}
```

Do pay attention to passing in the right Python version!

#### `mkPythonMetaPackage` function {#mkpythonmetapackage-function}

This will create a meta package containing [metadata files](https://packaging.python.org/en/latest/specifications/recording-installed-packages/) to satisfy a dependency on a package, without it actually having been installed into the environment.
In nixpkgs this is used to package Python packages with split binary/source distributions such as [psycopg2](https://pypi.org/project/psycopg2/)/[psycopg2-binary](https://pypi.org/project/psycopg2-binary/).

```nix
mkPythonMetaPackage {
  pname = "psycopg2-binary";
  inherit (psycopg2) optional-dependencies version;
  dependencies = [ psycopg2 ];
  meta = { inherit (psycopg2.meta) description homepage; };
}
```

#### `mkPythonEditablePackage` function {#mkpythoneditablepackage-function}

When developing Python packages it's common to install packages in [editable mode](https://setuptools.pypa.io/en/latest/userguide/development_mode.html).
Like `mkPythonMetaPackage` this function exists to create an otherwise empty package, but also containing a pointer to an impure location outside the Nix store that can be changed without rebuilding.

The editable root is passed as a string. Normally `.pth` files contains absolute paths to the mutable location. This isn't always ergonomic with Nix, so environment variables are expanded at runtime.
This means that a shell hook setting up something like a `$REPO_ROOT` variable can be used as the relative package root.

As an implementation detail, the [PEP-518](https://peps.python.org/pep-0518/) `build-system` specified won't be used, but instead the editable package will be built using [hatchling](https://pypi.org/project/hatchling/).
The `build-system`'s provided will instead become runtime dependencies of the editable package.

Note that overriding packages deeper in the dependency graph _can_ work, but it's not the primary use case and overriding existing packages can make others break in unexpected ways.

```nix
{
  pkgs ? import <nixpkgs> { },
}:

let
  pyproject = pkgs.lib.importTOML ./pyproject.toml;

  myPython = pkgs.python.override {
    self = myPython;
    packageOverrides = pyfinal: pyprev: {
      # An editable package with a script that loads our mutable location
      my-editable = pyfinal.mkPythonEditablePackage {
        # Inherit project metadata from pyproject.toml
        pname = pyproject.project.name;
        inherit (pyproject.project) version;

        # The editable root passed as a string
        root = "$REPO_ROOT/src"; # Use environment variable expansion at runtime

        # Inject a script (other PEP-621 entrypoints are also accepted)
        inherit (pyproject.project) scripts;
      };
    };
  };

  pythonEnv = myPython.withPackages (ps: [ ps.my-editable ]);

in
pkgs.mkShell { packages = [ pythonEnv ]; }
```

#### `python.buildEnv` function {#python.buildenv-function}

Python environments can be created using the low-level `pkgs.buildEnv` function.
This example shows how to create an environment that has the Pyramid Web Framework.
Saving the following as `default.nix`

```nix
with import <nixpkgs> { };

python3.buildEnv.override {
  extraLibs = [ python3Packages.pyramid ];
  ignoreCollisions = true;
}
```

and running `nix-build` will create

```
/nix/store/cf1xhjwzmdki7fasgr4kz6di72ykicl5-python-2.7.8-env
```

with wrapped binaries in `bin/`.

You can also use the `env` attribute to create local environments with needed
packages installed. This is somewhat comparable to `virtualenv`. For example,
running `nix-shell` with the following `shell.nix`

```nix
with import <nixpkgs> { };

(python3.buildEnv.override {
  extraLibs = with python3Packages; [
    numpy
    requests
  ];
}).env
```

will drop you into a shell where Python will have the
specified packages in its path.

##### `python.buildEnv` arguments {#python.buildenv-arguments}


* `extraLibs`: List of packages installed inside the environment.
* `postBuild`: Shell command executed after the build of environment.
* `ignoreCollisions`: Ignore file collisions inside the environment (default is `false`).
* `permitUserSite`: Skip setting the `PYTHONNOUSERSITE` environment variable in
  wrapped binaries in the environment.

#### `python.withPackages` function {#python.withpackages-function}

The [`python.withPackages`](#python.withpackages-function) function provides a simpler interface to the [`python.buildEnv`](#python.buildenv-function) functionality.
It takes a function as an argument that is passed the set of python packages and returns the list
of the packages to be included in the environment. Using the [`withPackages`](#python.withpackages-function) function, the previous
example for the Pyramid Web Framework environment can be written like this:

```nix
with import <nixpkgs> { };

python.withPackages (ps: [ ps.pyramid ])
```

[`withPackages`](#python.withpackages-function) passes the correct package set for the specific interpreter
version as an argument to the function. In the above example, `ps` equals
`pythonPackages`. But you can also easily switch to using python3:

```nix
with import <nixpkgs> { };

python3.withPackages (ps: [ ps.pyramid ])
```

Now, `ps` is set to `python3Packages`, matching the version of the interpreter.

As [`python.withPackages`](#python.withpackages-function) uses [`python.buildEnv`](#python.buildenv-function) under the hood, it also
supports the `env` attribute. The `shell.nix` file from the previous section can
thus be also written like this:

```nix
with import <nixpkgs> { };

(python3.withPackages (
  ps: with ps; [
    numpy
    requests
  ]
)).env
```

In contrast to [`python.buildEnv`](#python.buildenv-function), [`python.withPackages`](#python.withpackages-function) does not support the
more advanced options such as `ignoreCollisions = true` or `postBuild`. If you
need them, you have to use [`python.buildEnv`](#python.buildenv-function).

Python 2 namespace packages may provide `__init__.py` that collide. In that case
[`python.buildEnv`](#python.buildenv-function) should be used with `ignoreCollisions = true`.

#### Setup hooks {#setup-hooks}

The following are setup hooks specifically for Python packages. Most of these
are used in [`buildPythonPackage`](#buildpythonpackage-function).

- `eggUnpackhook` to move an egg to the correct folder so it can be installed
  with the `eggInstallHook`
- `eggBuildHook` to skip building for eggs.
- `eggInstallHook` to install eggs.
- `pypaBuildHook` to build a wheel using
  [`pypa/build`](https://pypa-build.readthedocs.io/en/latest/index.html) and
  PEP 517/518. Note a build system (e.g. `setuptools` or `flit`) should still
  be added as `build-system`.
- `pypaInstallHook` to install wheels.
- `pytestCheckHook` to run tests with `pytest`. See [example usage](#using-pytestcheckhook).
- `pythonCatchConflictsHook` to fail if the package depends on two different versions of the same dependency.
- `pythonImportsCheckHook` to check whether importing the listed modules works.
- `pythonRelaxDepsHook` will relax Python dependencies restrictions for the package.
  See [example usage](#using-pythonrelaxdepshook).
- `pythonRemoveBinBytecode` to remove bytecode from the `/bin` folder.
- `setuptoolsBuildHook` to build a wheel using `setuptools`.
- `sphinxHook` to build documentation and manpages using Sphinx.
- `venvShellHook` to source a Python 3 `venv` at the `venvDir` location. A
  `venv` is created if it does not yet exist. `postVenvCreation` can be used to
  to run commands only after venv is first created.
- `wheelUnpackHook` to move a wheel to the correct folder so it can be installed
  with the `pipInstallHook`.
- `unittestCheckHook` will run tests with `python -m unittest discover`. See [example usage](#using-unittestcheckhook).

## User Guide {#user-guide}

### Using Python {#using-python}

#### Overview {#overview}

Several versions of the Python interpreter are available on Nix, as well as a
high amount of packages. The attribute `python3` refers to the default
interpreter, which is currently CPython 3.13. The attribute `python` refers to
CPython 2.7 for backwards-compatibility. It is also possible to refer to
specific versions, e.g. `python313` refers to CPython 3.13, and `pypy` refers to
the default PyPy interpreter.

Python is used a lot, and in different ways. This affects also how it is
packaged. In the case of Python on Nix, an important distinction is made between
whether the package is considered primarily an application, or whether it should
be used as a library, i.e., of primary interest are the modules in
`site-packages` that should be importable.

In the Nixpkgs tree Python applications can be found throughout, depending on
what they do, and are called from the main package set. Python libraries,
however, are in separate sets, with one set per interpreter version.

The interpreters have several common attributes. One of these attributes is
`pkgs`, which is a package set of Python libraries for this specific
interpreter. E.g., the `toolz` package corresponding to the default interpreter
is `python3.pkgs.toolz`, and the CPython 3.13 version is `python313.pkgs.toolz`.
The main package set contains aliases to these package sets, e.g.
`pythonPackages` refers to `python.pkgs` and `python313Packages` to
`python313.pkgs`.

#### Installing Python and packages {#installing-python-and-packages}

The Nix and NixOS manuals explain how packages are generally installed. In the
case of Python and Nix, it is important to make a distinction between whether the
package is considered an application or a library.

Applications on Nix are typically installed into your user profile imperatively
using `nix-env -i`, and on NixOS declaratively by adding the package name to
`environment.systemPackages` in `/etc/nixos/configuration.nix`. Dependencies
such as libraries are automatically installed and should not be installed
explicitly.

The same goes for Python applications. Python applications can be installed in
your profile, and will be wrapped to find their exact library dependencies,
without impacting other applications or polluting your user environment.

But Python libraries you would like to use for development cannot be installed,
at least not individually, because they won't be able to find each other
resulting in import errors. Instead, it is possible to create an environment
with [`python.buildEnv`](#python.buildenv-function) or [`python.withPackages`](#python.withpackages-function) where the interpreter and other
executables are wrapped to be able to find each other and all of the modules.

In the following examples we will start by creating a simple, ad-hoc environment
with a nix-shell that has `numpy` and `toolz` in Python 3.13; then we will create
a re-usable environment in a single-file Python script; then we will create a
full Python environment for development with this same environment.

Philosophically, this should be familiar to users who are used to a `venv` style
of development: individual projects create their own Python environments without
impacting the global environment or each other.

#### Ad-hoc temporary Python environment with `nix-shell` {#ad-hoc-temporary-python-environment-with-nix-shell}

The simplest way to start playing with the way nix wraps and sets up Python
environments is with `nix-shell` at the cmdline. These environments create a
temporary shell session with a Python and a *precise* list of packages (plus
their runtime dependencies), with no other Python packages in the Python
interpreter's scope.

To create a Python 3.13 session with `numpy` and `toolz` available, run:

```sh
$ nix-shell -p 'python313.withPackages(ps: with ps; [ numpy toolz ])'
```

By default `nix-shell` will start a `bash` session with this interpreter in our
`PATH`, so if we then run:

```Python console
[nix-shell:~/src/nixpkgs]$ python3
Python 3.13.3 (main, Apr  8 2025, 13:54:08) [GCC 14.2.1 20250322] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import numpy; import toolz
```

Note that no other modules are in scope, even if they were imperatively
installed into our user environment as a dependency of a Python application:

```Python console
>>> import requests
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ModuleNotFoundError: No module named 'requests'
```

We can add as many additional modules onto the `nix-shell` as we need, and we
will still get 1 wrapped Python interpreter. We can start the interpreter
directly like so:

```sh
$ nix-shell -p "python313.withPackages (ps: with ps; [ numpy toolz requests ])" --run python3
Python 3.13.3 (main, Apr  8 2025, 13:54:08) [GCC 14.2.1 20250322] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import requests
>>>
```

Notice that this time it built a new Python environment, which now includes
`requests`. Building an environment just creates wrapper scripts that expose the
selected dependencies to the interpreter while re-using the actual modules. This
means if any other env has installed `requests` or `numpy` in a different
context, we don't need to recompile them -- we just recompile the wrapper script
that sets up an interpreter pointing to them. This matters much more for "big"
modules like `pytorch` or `tensorflow`.

Module names usually match their names on [pypi.org](https://pypi.org/), but
normalized according to PEP 503/508. (e.g. Foo__Bar.baz -> foo-bar-baz)
You can use the [Nixpkgs search website](https://nixos.org/nixos/packages.html)
to find them as well (along with non-python packages).

At this point we can create throwaway experimental Python environments with
arbitrary dependencies. This is a good way to get a feel for how the Python
interpreter and dependencies work in Nix and NixOS, but to do some actual
development, we'll want to make it a bit more persistent.

##### Running Python scripts and using `nix-shell` as shebang {#running-python-scripts-and-using-nix-shell-as-shebang}

Sometimes, we have a script whose header looks like this:

```python
#!/usr/bin/env python3
import numpy as np
a = np.array([1,2])
b = np.array([3,4])
print(f"The dot product of {a} and {b} is: {np.dot(a, b)}")
```

Executing this script requires a `python3` that has `numpy`. Using what we learned
in the previous section, we could startup a shell and just run it like so:

```ShellSession
$ nix-shell -p 'python313.withPackages (ps: with ps; [ numpy ])' --run 'python3 foo.py'
The dot product of [1 2] and [3 4] is: 11
```

But if we maintain the script ourselves, and if there are more dependencies, it
may be nice to encode those dependencies in source to make the script re-usable
without that bit of knowledge. That can be done by using `nix-shell` as a
[shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)), like so:

```python
#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages(ps: [ ps.numpy ])"
import numpy as np
a = np.array([1,2])
b = np.array([3,4])
print(f"The dot product of {a} and {b} is: {np.dot(a, b)}")
```

Then we execute it, without requiring any environment setup at all!

```sh
$ ./foo.py
The dot product of [1 2] and [3 4] is: 11
```

If the dependencies are not available on the host where `foo.py` is executed, it
will build or download them from a Nix binary cache prior to starting up, prior
that it is executed on a machine with a multi-user nix installation.

This provides a way to ship a self bootstrapping Python script, akin to a
statically linked binary, where it can be run on any machine (provided nix is
installed) without having to assume that `numpy` is installed globally on the
system.

By default it is pulling the import checkout of Nixpkgs itself from our nix
channel, which is nice as it cache aligns with our other package builds, but we
can make it fully reproducible by pinning the `nixpkgs` import:

```python
#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (ps: [ ps.numpy ])"
#!nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/e51209796c4262bfb8908e3d6d72302fe4e96f5f.tar.gz
import numpy as np
a = np.array([1,2])
b = np.array([3,4])
print(f"The dot product of {a} and {b} is: {np.dot(a, b)}")
```

This will execute with the exact same versions of Python 3.10, numpy, and system
dependencies a year from now as it does today, because it will always use
exactly git commit `e51209796c4262bfb8908e3d6d72302fe4e96f5f` of Nixpkgs for all
of the package versions.

This is also a great way to ensure the script executes identically on different
servers.

##### Load environment from `.nix` expression {#load-environment-from-.nix-expression}

We've now seen how to create an ad-hoc temporary shell session, and how to
create a single script with Python dependencies, but in the course of normal
development we're usually working in an entire package repository.

As explained [in the `nix-shell` section](https://nixos.org/manual/nix/stable/command-ref/nix-shell) of the Nix manual, `nix-shell` can also load an expression from a `.nix` file.
Say we want to have Python 3.13, `numpy` and `toolz`, like before,
in an environment. We can add a `shell.nix` file describing our dependencies:

```nix
with import <nixpkgs> { };
(python313.withPackages (
  ps: with ps; [
    numpy
    toolz
  ]
)).env
```

And then at the command line, just typing `nix-shell` produces the same
environment as before. In a normal project, we'll likely have many more
dependencies; this can provide a way for developers to share the environments
with each other and with CI builders.

What's happening here?

1. We begin with importing the Nix Packages collections. `import <nixpkgs>`
   imports the `<nixpkgs>` function, `{}` calls it and the `with` statement
   brings all attributes of `nixpkgs` in the local scope. These attributes form
   the main package set.
2. Then we create a Python 3.13 environment with the [`withPackages`](#python.withpackages-function) function, as before.
3. The [`withPackages`](#python.withpackages-function) function expects us to provide a function as an argument
   that takes the set of all Python packages and returns a list of packages to
   include in the environment. Here, we select the packages `numpy` and `toolz`
   from the package set.

To combine this with `mkShell` you can:

```nix
with import <nixpkgs> { };
let
  pythonEnv = python313.withPackages (ps: [
    ps.numpy
    ps.toolz
  ]);
in
mkShell {
  packages = [
    pythonEnv

    black
    mypy

    libffi
    openssl
  ];
}
```

This will create a unified environment that has not just our Python interpreter
and its Python dependencies, but also tools like `black` or `mypy` and libraries
like `libffi` the `openssl` in scope. This is generic and can span any number of
tools or languages across the Nixpkgs ecosystem.

##### Installing environments globally on the system {#installing-environments-globally-on-the-system}

Up to now, we've been creating environments scoped to an ad-hoc shell session,
or a single script, or a single project. This is generally advisable, as it
avoids pollution across contexts.

However, sometimes we know we will often want a Python with some basic packages,
and want this available without having to enter into a shell or build context.
This can be useful to have things like vim/emacs editors and plugins or shell
tools "just work" without having to set them up, or when running other software
that expects packages to be installed globally.

To create your own custom environment, create a file in `~/.config/nixpkgs/overlays/`
that looks like this:

```nix
# ~/.config/nixpkgs/overlays/myEnv.nix
self: super: {
  myEnv = super.buildEnv {
    name = "myEnv";
    paths = [
      # A Python 3 interpreter with some packages
      (self.python3.withPackages (
        ps: with ps; [
          pyflakes
          pytest
          black
        ]
      ))

      # Some other packages we'd like as part of this env
      self.mypy
      self.black
      self.ripgrep
      self.tmux
    ];
  };
}
```

You can then build and install this to your profile with:

```sh
nix-env -iA myEnv
```

One limitation of this is that you can only have 1 Python env installed
globally, since they conflict on the `python` to load out of your `PATH`.

If you get a conflict or prefer to keep the setup clean, you can have `nix-env`
atomically *uninstall* all other imperatively installed packages and replace
your profile with just `myEnv` by using the `--replace` flag.

##### Environment defined in `/etc/nixos/configuration.nix` {#environment-defined-in-etcnixosconfiguration.nix}

For the sake of completeness, here's how to install the environment system-wide
on NixOS.

```nix
{
  # ...

  environment.systemPackages = with pkgs; [
    (python310.withPackages (
      ps: with ps; [
        numpy
        toolz
      ]
    ))
  ];
}
```

### Developing with Python {#developing-with-python}

Above, we were mostly just focused on use cases and what to do to get started
creating working Python environments in nix.

Now that you know the basics to be up and running, it is time to take a step
back and take a deeper look at how Python packages are packaged on Nix.

#### Python library packages in Nixpkgs {#python-library-packages-in-nixpkgs}

With Nix all packages are built by functions. The main function in Nix for
building Python libraries is [`buildPythonPackage`](#buildpythonpackage-function). Let's see how we can build the
`toolz` package.

```nix
{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
}:

buildPythonPackage rec {
  pname = "toolz";
  version = "0.10.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-CP3V73yWSArRHBLUct4hrNMjWZlvaaUlkpm1QP66RWA=";
  };

  build-system = [ setuptools ];

  # has no tests
  doCheck = false;

  pythonImportsCheck = [
    "toolz.itertoolz"
    "toolz.functoolz"
    "toolz.dicttoolz"
  ];

  meta = {
    changelog = "https://github.com/pytoolz/toolz/releases/tag/${version}";
    homepage = "https://github.com/pytoolz/toolz";
    description = "List processing tools and functional utilities";
    license = lib.licenses.bsd3;
  };
}
```

What happens here? The function [`buildPythonPackage`](#buildpythonpackage-function) is called and as argument
it accepts a set. In this case the set is a recursive set, `rec`. One of the
arguments is the name of the package, which consists of a basename (generally
following the name on PyPI) and a version. Another argument, `src` specifies the
source, which in this case is fetched from PyPI using the helper function
`fetchPypi`. The argument `doCheck` is used to set whether tests should be run
when building the package. Since there are no tests, we rely on [`pythonImportsCheck`](#using-pythonimportscheck)
to test whether the package can be imported. Furthermore, we specify some meta
information. The output of the function is a derivation.

An expression for `toolz` can be found in the Nixpkgs repository. As explained
in the introduction of this Python section, a derivation of `toolz` is available
for each interpreter version, e.g. `python313.pkgs.toolz` refers to the `toolz`
derivation corresponding to the CPython 3.13 interpreter.

The above example works when you're directly working on
`pkgs/top-level/python-packages.nix` in the Nixpkgs repository. Often though,
you will want to test a Nix expression outside of the Nixpkgs tree.

The following expression creates a derivation for the `toolz` package,
and adds it along with a `numpy` package to a Python environment.

```nix
with import <nixpkgs> { };

(
  let
    my_toolz = python313.pkgs.buildPythonPackage rec {
      pname = "toolz";
      version = "0.10.0";
      pyproject = true;

      src = fetchPypi {
        inherit pname version;
        hash = "sha256-CP3V73yWSArRHBLUct4hrNMjWZlvaaUlkpm1QP66RWA=";
      };

      build-system = [ python313.pkgs.setuptools ];

      # has no tests
      doCheck = false;

      meta = {
        homepage = "https://github.com/pytoolz/toolz/";
        description = "List processing tools and functional utilities";
        # [...]
      };
    };

  in
  python313.withPackages (
    ps: with ps; [
      numpy
      my_toolz
    ]
  )
).env
```

Executing `nix-shell` will result in an environment in which you can use
Python 3.13 and the `toolz` package. As you can see we had to explicitly mention
for which Python version we want to build a package.

So, what did we do here? Well, we took the Nix expression that we used earlier
to build a Python environment, and said that we wanted to include our own
version of `toolz`, named `my_toolz`. To introduce our own package in the scope
of [`withPackages`](#python.withpackages-function) we used a `let` expression. You can see that we used
`ps.numpy` to select numpy from the nixpkgs package set (`ps`). We did not take
`toolz` from the Nixpkgs package set this time, but instead took our own version
that we introduced with the `let` expression.

#### Handling dependencies {#handling-dependencies}

Our example, `toolz`, does not have any dependencies on other Python packages or system libraries.
[`buildPythonPackage`](#buildpythonpackage-function) uses the the following arguments in the following circumstances:

- `dependencies` - For Python runtime dependencies.
- `build-system` - For Python build-time requirements.
- [`buildInputs`](#var-stdenv-buildInputs) - For non-Python build-time requirements.
- [`nativeCheckInputs`](#var-stdenv-nativeCheckInputs) - For test dependencies

Dependencies can belong to multiple arguments, for example if something is both a build time requirement & a runtime dependency.

The following example shows which arguments are given to [`buildPythonPackage`](#buildpythonpackage-function) in
order to build [`datashape`](https://github.com/blaze/datashape).

```nix
{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build dependencies
  setuptools,

  # dependencies
  numpy,
  multipledispatch,
  python-dateutil,

  # tests
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "datashape";
  version = "0.4.7";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-FLLvdm1MllKrgTGC6Gb0k0deZeVYvtCCLji/B7uhong=";
  };

  build-system = [ setuptools ];

  dependencies = [
    multipledispatch
    numpy
    python-dateutil
  ];

  nativeCheckInputs = [ pytestCheckHook ];

  meta = {
    changelog = "https://github.com/blaze/datashape/releases/tag/${version}";
    homepage = "https://github.com/ContinuumIO/datashape";
    description = "Data description language";
    license = lib.licenses.bsd2;
  };
}
```

We can see several runtime dependencies, `numpy`, `multipledispatch`, and
`python-dateutil`. Furthermore, we have [`nativeCheckInputs`](#var-stdenv-nativeCheckInputs) with `pytestCheckHook`.
`pytestCheckHook` is a test runner hook and is only used during the [`checkPhase`](#ssec-check-phase) and is
therefore not added to `dependencies`.

In the previous case we had only dependencies on other Python packages to consider.
Occasionally you have also system libraries to consider. E.g., `lxml` provides
Python bindings to `libxml2` and `libxslt`. These libraries are only required
when building the bindings and are therefore added as [`buildInputs`](#var-stdenv-buildInputs).

```nix
{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  libxml2,
  libxslt,
}:

buildPythonPackage rec {
  pname = "lxml";
  version = "3.4.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-s9NiusRxFydHzaNRMjjxFcvWxfi45jGb9ql6eJJyQJk=";
  };

  build-system = [ setuptools ];

  buildInputs = [
    libxml2
    libxslt
  ];

  # tests are meant to be ran "in-place" in the same directory as src
  doCheck = false;

  pythonImportsCheck = [
    "lxml"
    "lxml.etree"
  ];

  meta = {
    changelog = "https://github.com/lxml/lxml/releases/tag/lxml-${version}";
    description = "Pythonic binding for the libxml2 and libxslt libraries";
    homepage = "https://lxml.de";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ sjourdois ];
  };
}
```

In this example `lxml` and Nix are able to work out exactly where the relevant
files of the dependencies are. This is not always the case.

The example below shows bindings to The Fastest Fourier Transform in the West,
commonly known as FFTW. On Nix we have separate packages of FFTW for the
different types of floats (`"single"`, `"double"`, `"long-double"`). The
bindings need all three types, and therefore we add all three as [`buildInputs`](#var-stdenv-buildInputs).
The bindings don't expect to find each of them in a different folder, and
therefore we have to set `LDFLAGS` and `CFLAGS`.

```nix
{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build dependencies
  setuptools,

  # dependencies
  fftw,
  fftwFloat,
  fftwLongDouble,
  numpy,
  scipy,
}:

buildPythonPackage rec {
  pname = "pyfftw";
  version = "0.9.2";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-9ru2r6kwhUCaskiFoaPNuJCfCVoUL01J40byvRt4kHQ=";
  };

  build-system = [ setuptools ];

  buildInputs = [
    fftw
    fftwFloat
    fftwLongDouble
  ];

  dependencies = [
    numpy
    scipy
  ];

  preConfigure = ''
    export LDFLAGS="-L${fftw.dev}/lib -L${fftwFloat.out}/lib -L${fftwLongDouble.out}/lib"
    export CFLAGS="-I${fftw.dev}/include -I${fftwFloat.dev}/include -I${fftwLongDouble.dev}/include"
  '';

  # Tests cannot import pyfftw. pyfftw works fine though.
  doCheck = false;

  pythonImportsCheck = [ "pyfftw" ];

  meta = {
    changelog = "https://github.com/pyFFTW/pyFFTW/releases/tag/v${version}";
    description = "Pythonic wrapper around FFTW, the FFT library, presenting a unified interface for all the supported transforms";
    homepage = "http://hgomersall.github.com/pyFFTW";
    license = with lib.licenses; [
      bsd2
      bsd3
    ];
  };
}
```

Note also the line [`doCheck = false;`](#var-stdenv-doCheck), we explicitly disabled running the test-suite.

#### Testing Python Packages {#testing-python-packages}

It is highly encouraged to have testing as part of the package build. This
helps to avoid situations where the package was able to build and install,
but is not usable at runtime.
Your package should provide its own [`checkPhase`](#ssec-check-phase).

::: {.note}
The [`checkPhase`](#ssec-check-phase) for python maps to the `installCheckPhase` on a
normal derivation. This is due to many python packages not behaving well
to the pre-installed version of the package. Version info, and natively
compiled extensions generally only exist in the install directory, and
thus can cause issues when a test suite asserts on that behavior.
:::

::: {.note}
Tests should only be disabled if they don't agree with nix
(e.g. external dependencies, network access, flakey tests), however,
as many tests should be enabled as possible. Failing tests can still be
a good indication that the package is not in a valid state.
:::

::: {.note}
We only want to test the functionality of a package. In particular, we are not
interested in coverage, formatting, and type checking. If pytest fails with
`unrecognized arguments: --cov`, add `pytest-cov-stub` to `nativeCheckInputs`
rather than `pytest-cov`.
:::

#### Using pytest {#using-pytest}

Pytest is the most common test runner for python repositories. A trivial
test run would be:

```nix
{
  nativeCheckInputs = [ pytest ];
  checkPhase = ''
    runHook preCheck

    pytest

    runHook postCheck
  '';
}
```

However, many repositories' test suites do not translate well to nix's build
sandbox, and will generally need many tests to be disabled.

This is achievable by
- Including paths or test items (`path/to/file.py::MyClass` or `path/to/file.py::MyClass::test_method`) with positional arguments.
- Excluding paths with `--ignore` or globbed paths with `--ignore-glob`.
- Excluding test items using the `--deselect` flag.
- Including or excluding classes or test methods by their name using the `-k` flag.
- Including or excluding test by their marks using the `-m` flag.

We highly recommend `pytestCheckHook` for an easier and more structural setup.

#### Using pytestCheckHook {#using-pytestcheckhook}

`pytestCheckHook` is a convenient hook which will set up (or configure)
a [`checkPhase`](#ssec-check-phase) to run `pytest`. This is also beneficial
when a package may need many items disabled to run the test suite.
Most packages use `pytest` or `unittest`, which is compatible with `pytest`,
so you will most likely use `pytestCheckHook`.

To use `pytestCheckHook`, add it to `nativeCheckInputs`.
Adding `pytest` is not required, since it is included with `pytestCheckHook`.

```nix
{ nativeCheckInputs = [ pytestCheckHook ]; }
```

`pytestCheckHook` recognizes the following attributes:

`enabledTestPaths` and `disabledTestPaths`

:   To specify path globs (files or directories) or test items.

`enabledTests` and `disabledTests`

:   To specify keywords for class names or test method names.

`enabledTestMarks` and `disabledTestMarks`

:   To specify test marks.

`pytestFlags`

:   To append additional command-line arguments to `pytest`.

By default, `pytest` automatically discovers which tests to run.
If tests are explicitly enabled, only those tests will run.
A test, that is both enabled and disabled, will not run.

The following example demonstrates usage of various `pytestCheckHook` attributes:

```nix
{
  nativeCheckInputs = [ pytestCheckHook ];

  # Allow running the following test paths and test objects.
  enabledTestPaths = [
    # Find tests under the tests directory.
    # The trailing slash is not necessary.
    "tests/"

    # Additionally run test_foo
    "other-tests/test_foo.py::Foo::test_foo"
  ];

  # Override the above-enabled test paths and test objects.
  disabledTestPaths = [
    # Tests under tests/integration requires additional data.
    "tests/integration"
  ];

  # Allow tests by keywords matching their class names or method names.
  enabledTests = [
    # pytest by default only runs test methods begin with "test_" or end with "_test".
    # This includes all functions whose name contains "test".
    "test"
  ];

  # Override the above-enabled tests by keywords matching their class names or method names.
  disabledTests = [
    # Tests touching networks.
    "upload"
    "download"
  ];

  # Additional pytest flags
  pytestFlags = [
    # Disable benchmarks and run benchmarking tests only once.
    "--benchmark-disable"
  ];
}
```

These attributes are all passed into the derivation directly
and added to the `pytest` command without additional Bash expansion.
It requires `__structuredAttrs = true` to pass list elements containing spaces.

The `<enabled/disabled>TestsPaths` attributes expand Unix-style globs.
If a test path contains characters like `*`, `?`, `[`, or `]`, you can
quote them with square brackets (`[*]`, `[?]`, `[[]`, and `[]]`) to match literally.

The `<enabled/disabled>Tests` and `<enabled/disabled>TestMarks` attribute pairs
form a logical expression `((included_element1) or (included_element2)) and not (excluded_element1) and not (excluded_element2)`
which will be passed to pytest's `-k` and `-m` flags respectively.
With `__structuredAttrs = true` enabled, they additionally support sub-expressions.

For example, you could disable test items like `TestFoo::test_bar_functionality`
by disabling tests that match both `"Foo"` **and** `"bar"`:

```nix
{
  __structuredAttrs = true;

  disabledTests = [ "Foo and bar" ];
}
```

The main benefits of using `pytestCheckHook` to construct `pytest` commands
is structuralization and eval-time accessibility.
This is especially helpful to select tests or specify flags conditionally:

```nix
{
  disabledTests = [
    # touches network
    "download"
    "update"
  ]
  ++ lib.optionals (pythonAtLeast "3.8") [
    # broken due to python3.8 async changes
    "async"
  ]
  ++ lib.optionals stdenv.buildPlatform.isDarwin [
    # can fail when building with other packages
    "socket"
  ];
}
```

#### Using pythonImportsCheck {#using-pythonimportscheck}

Although unit tests are highly preferred to validate correctness of a package, not
all packages have test suites that can be run easily, and some have none at all.
To help ensure the package still works, [`pythonImportsCheck`](#using-pythonimportscheck) can attempt to import
the listed modules.

```nix
{
  pythonImportsCheck = [
    "requests"
    "urllib"
  ];
}
```

roughly translates to:

```nix
{
  postCheck = ''
    PYTHONPATH=$out/${python.sitePackages}:$PYTHONPATH
    python -c "import requests; import urllib"
  '';
}
```

However, this is done in its own phase, and not dependent on whether [`doCheck = true;`](#var-stdenv-doCheck).

This can also be useful in verifying that the package doesn't assume commonly
present packages (e.g. `setuptools`).

#### Using pythonRelaxDepsHook {#using-pythonrelaxdepshook}

It is common for upstream to specify a range of versions for its package
dependencies. This makes sense, since it ensures that the package will be built
with a subset of packages that is well tested. However, this commonly causes
issues when packaging in Nixpkgs, because the dependencies that this package
may need are too new or old for the package to build correctly. We also cannot
package multiple versions of the same package since this may cause conflicts
in `PYTHONPATH`.

One way to side step this issue is to relax the dependencies. This can be done
by either removing the package version range or by removing the package
declaration entirely. This can be done using the `pythonRelaxDepsHook` hook. For
example, given the following `requirements.txt` file:

```
pkg1<1.0
pkg2
pkg3>=1.0,<=2.0
```

we can do:

```nix
{
  pythonRelaxDeps = [
    "pkg1"
    "pkg3"
  ];
  pythonRemoveDeps = [ "pkg2" ];
}
```

which would result in the following `requirements.txt` file:

```
pkg1
pkg3
```

Another option is to pass `true`, that will relax/remove all dependencies, for
example:

```nix
{ pythonRelaxDeps = true; }
```

which would result in the following `requirements.txt` file:

```
pkg1
pkg2
pkg3
```

In general you should always use `pythonRelaxDeps`, because `pythonRemoveDeps`
will convert build errors into runtime errors. However `pythonRemoveDeps` may
still be useful in exceptional cases, and also to remove dependencies wrongly
declared by upstream (for example, declaring `black` as a runtime dependency
instead of a dev dependency).

Keep in mind that while the examples above are done with `requirements.txt`,
`pythonRelaxDepsHook` works by modifying the resulting wheel file, so it should
work with any of the [existing hooks](#setup-hooks).

The `pythonRelaxDepsHook` has no effect on build time dependencies, such as
those specified in `build-system`. If a package requires incompatible build
time dependencies, they should be removed in `postPatch` through
`substituteInPlace` or similar.

For ease of use, both `buildPythonPackage` and `buildPythonApplication` will
automatically add `pythonRelaxDepsHook` if either `pythonRelaxDeps` or
`pythonRemoveDeps` is specified.

#### Using unittestCheckHook {#using-unittestcheckhook}

`unittestCheckHook` is a hook which will set up (or configure) a [`checkPhase`](#ssec-check-phase) to run `python -m unittest discover`:

```nix
{
  nativeCheckInputs = [ unittestCheckHook ];

  unittestFlags = [
    "-s"
    "tests"
    "-v"
  ];
}
```

`pytest` is compatible with `unittest`, so in most cases you can use `pytestCheckHook` instead.

#### Using sphinxHook {#using-sphinxhook}

The `sphinxHook` is a helpful tool to build documentation and manpages
using the popular Sphinx documentation generator.
It is setup to automatically find common documentation source paths and
render them using the default `html` style.

```nix
{
  outputs = [
    "out"
    "doc"
  ];

  nativeBuildInputs = [ sphinxHook ];
}
```

The hook will automatically build and install the artifact into the
`doc` output, if it exists. It also provides an automatic diversion
for the artifacts of the `man` builder into the `man` target.

```nix
{
  outputs = [
    "out"
    "doc"
    "man"
  ];

  # Use multiple builders
  sphinxBuilders = [
    "singlehtml"
    "man"
  ];
}
```

Overwrite `sphinxRoot` when the hook is unable to find your
documentation source root.

```nix
{
  # Configure sphinxRoot for uncommon paths
  sphinxRoot = "weird/docs/path";
}
```

The hook is also available to packages outside the python ecosystem by
referencing it using `sphinxHook` from top-level.

### Organising your packages {#organising-your-packages}

So far we discussed how you can use Python on Nix, and how you can develop with
it. We've looked at how you write expressions to package Python packages, and we
looked at how you can create environments in which specified packages are
available.

At some point you'll likely have multiple packages which you would
like to be able to use in different projects. In order to minimise unnecessary
duplication we now look at how you can maintain a repository with your
own packages. The important functions here are `import` and `callPackage`.

### Including a derivation using `callPackage` {#including-a-derivation-using-callpackage}

Earlier we created a Python environment using [`withPackages`](#python.withpackages-function), and included the
`toolz` package via a `let` expression.
Let's split the package definition from the environment definition.

We first create a function that builds `toolz` in `~/path/to/toolz/release.nix`

```nix
{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
}:

buildPythonPackage rec {
  pname = "toolz";
  version = "0.10.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-CP3V73yWSArRHBLUct4hrNMjWZlvaaUlkpm1QP66RWA=";
  };

  build-system = [ setuptools ];

  meta = {
    changelog = "https://github.com/pytoolz/toolz/releases/tag/${version}";
    homepage = "https://github.com/pytoolz/toolz/";
    description = "List processing tools and functional utilities";
    license = lib.licenses.bsd3;
  };
}
```

It takes an argument [`buildPythonPackage`](#buildpythonpackage-function). We now call this function using
`callPackage` in the definition of our environment

```nix
with import <nixpkgs> { };

(
  let
    toolz = callPackage /path/to/toolz/release.nix {
      buildPythonPackage = python3Packages.buildPythonPackage;
    };
  in
  python3.withPackages (ps: [
    ps.numpy
    toolz
  ])
).env
```

Important to remember is that the Python version for which the package is made
depends on the `python` derivation that is passed to [`buildPythonPackage`](#buildpythonpackage-function). Nix
tries to automatically pass arguments when possible, which is why generally you
don't explicitly define which `python` derivation should be used. In the above
example we use [`buildPythonPackage`](#buildpythonpackage-function) that is part of the set `python3Packages`,
and in this case the `python3` interpreter is automatically used.

## FAQ {#faq}

### How to solve circular dependencies? {#how-to-solve-circular-dependencies}

Consider the packages `A` and `B` that depend on each other. When packaging `B`,
a solution is to override package `A` not to depend on `B` as an input. The same
should also be done when packaging `A`.

### How to override a Python package? {#how-to-override-a-python-package}

We can override the interpreter and pass `packageOverrides`. In the following
example we rename the `pandas` package and build it.

```nix
with import <nixpkgs> { };

(
  let
    python =
      let
        packageOverrides = self: super: {
          pandas = super.pandas.overridePythonAttrs (old: {
            name = "foo";
          });
        };
      in
      pkgs.python310.override { inherit packageOverrides; };

  in
  python.withPackages (ps: [ ps.pandas ])
).env
```

Using `nix-build` on this expression will build an environment that contains the
package `pandas` but with the new name `foo`.

All packages in the package set will use the renamed package. A typical use case
is to switch to another version of a certain package. For example, in the
Nixpkgs repository we have multiple versions of `django` and `scipy`. In the
following example we use a different version of `scipy` and create an
environment that uses it. All packages in the Python package set will now use
the updated `scipy` version.

```nix
with import <nixpkgs> { };

(
  let
    packageOverrides = self: super: { scipy = super.scipy_0_17; };
  in
  (pkgs.python310.override { inherit packageOverrides; }).withPackages (ps: [ ps.blaze ])
).env
```

The requested package `blaze` depends on `pandas` which itself depends on `scipy`.

If you want the whole of Nixpkgs to use your modifications, then you can use
`overlays` as explained in this manual. In the following example we build a
`inkscape` using a different version of `numpy`.

```nix
let
  pkgs = import <nixpkgs> { };
  newpkgs = import pkgs.path {
    overlays = [
      (self: super: {
        python310 =
          let
            packageOverrides = python-self: python-super: {
              numpy = python-super.numpy_1_18;
            };
          in
          super.python310.override { inherit packageOverrides; };
      })
    ];
  };
in
newpkgs.inkscape
```

### `python setup.py bdist_wheel` cannot create .whl {#python-setup.py-bdist_wheel-cannot-create-.whl}

Executing `python setup.py bdist_wheel` in a `nix-shell`fails with

```
ValueError: ZIP does not support timestamps before 1980
```

This is because files from the Nix store (which have a timestamp of the UNIX
epoch of January 1, 1970) are included in the .ZIP, but .ZIP archives follow the
DOS convention of counting timestamps from 1980.

The command `bdist_wheel` reads the `SOURCE_DATE_EPOCH` environment variable,
which `nix-shell` sets to 1. Unsetting this variable or giving it a value
corresponding to 1980 or later enables building wheels.

Use 1980 as timestamp:

```shell
nix-shell --run "SOURCE_DATE_EPOCH=315532800 python3 setup.py bdist_wheel"
```

or the current time:

```shell
nix-shell --run "SOURCE_DATE_EPOCH=$(date +%s) python3 setup.py bdist_wheel"
```

or unset `SOURCE_DATE_EPOCH`:

```shell
nix-shell --run "unset SOURCE_DATE_EPOCH; python3 setup.py bdist_wheel"
```

### `install_data` / `data_files` problems {#install_data-data_files-problems}

If you get the following error:

```
could not create '/nix/store/6l1bvljpy8gazlsw2aw9skwwp4pmvyxw-python-2.7.8/etc':
Permission denied
```

This is a [known bug](https://github.com/pypa/setuptools/issues/130) in
`setuptools`. Setuptools `install_data` does not respect `--prefix`. An example
of such package using the feature is `pkgs/tools/X11/xpra/default.nix`.

As workaround install it as an extra `preInstall` step:

```shell
${python.pythonOnBuildForHost.interpreter} setup.py install_data --install-dir=$out --root=$out
sed -i '/ = data\_files/d' setup.py
```

### Rationale of non-existent global site-packages {#rationale-of-non-existent-global-site-packages}

On most operating systems a global `site-packages` is maintained. This however
becomes problematic if you want to run multiple Python versions or have multiple
versions of certain libraries for your projects. Generally, you would solve such
issues by creating virtual environments using `virtualenv`.

On Nix each package has an isolated dependency tree which, in the case of
Python, guarantees the right versions of the interpreter and libraries or
packages are available. There is therefore no need to maintain a global `site-packages`.

If you want to create a Python environment for development, then the recommended
method is to use `nix-shell`, either with or without the [`python.buildEnv`](#python.buildenv-function)
function.

### How to consume Python modules using pip in a virtual environment like I am used to on other Operating Systems? {#how-to-consume-python-modules-using-pip-in-a-virtual-environment-like-i-am-used-to-on-other-operating-systems}

While this approach is not very idiomatic from Nix perspective, it can still be
useful when dealing with pre-existing projects or in situations where it's not
feasible or desired to write derivations for all required dependencies.

This is an example of a `default.nix` for a `nix-shell`, which allows to consume
a virtual environment created by `venv`, and install Python modules through
`pip` the traditional way.

Create this `default.nix` file, together with a `requirements.txt` and
execute `nix-shell`.

```nix
with import <nixpkgs> { };

let
  pythonPackages = python3Packages;
in
pkgs.mkShell rec {
  name = "impurePythonEnv";
  venvDir = "./.venv";
  buildInputs = [
    # A Python interpreter including the 'venv' module is required to bootstrap
    # the environment.
    pythonPackages.python

    # This executes some shell code to initialize a venv in $venvDir before
    # dropping into the shell
    pythonPackages.venvShellHook

    # Those are dependencies that we would like to use from nixpkgs, which will
    # add them to PYTHONPATH and thus make them accessible from within the venv.
    pythonPackages.numpy
    pythonPackages.requests

    # In this particular example, in order to compile any binary extensions they may
    # require, the Python modules listed in the hypothetical requirements.txt need
    # the following packages to be installed locally:
    taglib
    openssl
    git
    libxml2
    libxslt
    libzip
    zlib
  ];

  # Run this command, only after creating the virtual environment
  postVenvCreation = ''
    unset SOURCE_DATE_EPOCH
    pip install -r requirements.txt
  '';

  # Now we can execute any commands within the virtual environment.
  # This is optional and can be left out to run pip manually.
  postShellHook = ''
    # allow pip to install wheels
    unset SOURCE_DATE_EPOCH
  '';

}
```

In case the supplied venvShellHook is insufficient, or when Python 2 support is
needed, you can define your own shell hook and adapt to your needs like in the
following example:

```nix
with import <nixpkgs> { };

let
  venvDir = "./.venv";
  pythonPackages = python3Packages;
in
pkgs.mkShell rec {
  name = "impurePythonEnv";
  buildInputs = [
    pythonPackages.python
    # Needed when using python 2.7
    # pythonPackages.virtualenv
    # ...
  ];

  # This is very close to how venvShellHook is implemented, but
  # adapted to use 'virtualenv'
  shellHook = ''
    SOURCE_DATE_EPOCH=$(date +%s)

    if [ -d "${venvDir}" ]; then
      echo "Skipping venv creation, '${venvDir}' already exists"
    else
      echo "Creating new venv environment in path: '${venvDir}'"
      # Note that the module venv was only introduced in python 3, so for 2.7
      # this needs to be replaced with a call to virtualenv
      ${pythonPackages.python.interpreter} -m venv "${venvDir}"
    fi

    # Under some circumstances it might be necessary to add your virtual
    # environment to PYTHONPATH, which you can do here too;
    # PYTHONPATH=$PWD/${venvDir}/${pythonPackages.python.sitePackages}/:$PYTHONPATH

    source "${venvDir}/bin/activate"

    # As in the previous example, this is optional.
    pip install -r requirements.txt
  '';
}
```

Note that the `pip install` is an imperative action. So every time `nix-shell`
is executed it will attempt to download the Python modules listed in
requirements.txt. However these will be cached locally within the `virtualenv`
folder and not downloaded again.

### How to override a Python package from `configuration.nix`? {#how-to-override-a-python-package-from-configuration.nix}

If you need to change a package's attribute(s) from `configuration.nix` you could do:

```nix
{
  nixpkgs.config.packageOverrides = super: {
    python3 = super.python3.override {
      packageOverrides = python-self: python-super: {
        twisted = python-super.twisted.overridePythonAttrs (oldAttrs: {
          src = super.fetchPypi {
            pname = "Twisted";
            version = "19.10.0";
            hash = "sha256-c5S6fycq5yKnTz2Wnc9Zm8TvCTvDkgOHSKSQ8XJKUV0=";
            extension = "tar.bz2";
          };
        });
      };
    };
  };
}
```

`python3Packages.twisted` is now globally overridden.
All packages and also all NixOS services that reference `twisted`
(such as `services.buildbot-worker`) now use the new definition.
Note that `python-super` refers to the old package set and `python-self`
to the new, overridden version.

To modify only a Python package set instead of a whole Python derivation, use
this snippet:

```nix
{
  myPythonPackages = python3Packages.override { overrides = self: super: { twisted = <...>; }; };
}
```

### How to override a Python package using overlays? {#how-to-override-a-python-package-using-overlays}

Use the following overlay template:

```nix
self: super: {
  python = super.python.override {
    packageOverrides = python-self: python-super: {
      twisted = python-super.twisted.overrideAttrs (oldAttrs: {
        src = super.fetchPypi {
          pname = "Twisted";
          version = "19.10.0";
          hash = "sha256-c5S6fycq5yKnTz2Wnc9Zm8TvCTvDkgOHSKSQ8XJKUV0=";
          extension = "tar.bz2";
        };
      });
    };
  };
}
```

### How to override a Python package for all Python versions using extensions? {#how-to-override-a-python-package-for-all-python-versions-using-extensions}

The following overlay overrides the call to [`buildPythonPackage`](#buildpythonpackage-function) for the
`foo` package for all interpreters by appending a Python extension to the
`pythonPackagesExtensions` list of extensions.

```nix
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      foo = python-prev.foo.overridePythonAttrs (oldAttrs: {
        # ...
      });
    })
  ];
}
```

### How to use Intel’s MKL with numpy and scipy? {#how-to-use-intels-mkl-with-numpy-and-scipy}

MKL can be configured using an overlay. See the section "[Using overlays to
configure alternatives](#sec-overlays-alternatives-blas-lapack)".

### What inputs do `setup_requires`, `install_requires` and `tests_require` map to? {#what-inputs-do-setup_requires-install_requires-and-tests_require-map-to}

In a `setup.py` or `setup.cfg` it is common to declare dependencies:

* `setup_requires` corresponds to `build-system`
* `install_requires` corresponds to `dependencies`
* `tests_require` corresponds to [`nativeCheckInputs`](#var-stdenv-nativeCheckInputs)

### How to enable interpreter optimizations? {#optimizations}

The Python interpreters are by default not built with optimizations enabled, because
the builds are in that case not reproducible. To enable optimizations, override the
interpreter of interest, e.g using

```nix
let
  pkgs = import ./. { };
  mypython = pkgs.python3.override {
    enableOptimizations = true;
    reproducibleBuild = false;
    self = mypython;
  };
in
mypython
```

### How to add optional dependencies? {#python-optional-dependencies}

Some packages define optional dependencies for additional features. With
`setuptools` this is called `extras_require` and `flit` calls it
`extras-require`, while PEP 621 calls these `optional-dependencies`.

```nix
{
  optional-dependencies = {
    complete = [ distributed ];
  };
}
```

and letting the package requiring the extra add the list to its dependencies

```nix
{
  dependencies = [
    # ...
  ]
  ++ dask.optional-dependencies.complete;
}
```

This method is using `passthru`, meaning that changing `optional-dependencies` of a package won't cause it to rebuild.

Note this method is preferred over adding parameters to builders, as that can
result in packages depending on different variants and thereby causing
collisions.

::: {.note}
The `optional-dependencies` attribute should only be used for dependency groups
as defined in package metadata. If a package gracefully handles missing
dependencies in runtime but doesn't advertise it through package metadata, then
these dependencies should not be listed at all. (One may still have to list
them in `nativeCheckInputs` to pass test suite.)
:::

### How to contribute a Python package to nixpkgs? {#tools}

Packages inside nixpkgs must use the [`buildPythonPackage`](#buildpythonpackage-function) or [`buildPythonApplication`](#buildpythonapplication-function) function directly,
because we can only provide security support for non-vendored dependencies.

We recommend [nix-init](https://github.com/nix-community/nix-init) for creating new python packages within nixpkgs,
as it already prefetches the source, parses dependencies for common formats and prefills most things in `meta`.
When using the tool, pull from the original source repository instead of PyPI, if possible.

See also [contributing section](#contributing).

### Are Python interpreters built deterministically? {#deterministic-builds}

The Python interpreters are now built deterministically. Minor modifications had
to be made to the interpreters in order to generate deterministic bytecode. This
has security implications and is relevant for those using Python in a
`nix-shell`.

When the environment variable `DETERMINISTIC_BUILD` is set, all bytecode will
have timestamp 1. The [`buildPythonPackage`](#buildpythonpackage-function) function sets `DETERMINISTIC_BUILD=1`
and [PYTHONHASHSEED=0](https://docs.python.org/3.13/using/cmdline.html#envvar-PYTHONHASHSEED).
Both are also exported in `nix-shell`.

### How to provide automatic tests to Python packages? {#automatic-tests}

It is recommended to test packages as part of the build process.
Source distributions (`sdist`) often include test files, but not always.

The best practice today is to pass a test hook (e.g. pytestCheckHook, unittestCheckHook) into nativeCheckInputs.
This will reconfigure the checkPhase to make use of that particular test framework.
Occasionally packages don't make use of a common test framework, which may then require a custom checkPhase.

#### Common issues {#common-issues}

* Tests that attempt to access `$HOME` can be fixed by using `writableTmpDirAsHomeHook` in
  `nativeCheckInputs`, which sets up a writable temporary directory as the home directory. Alternatively,
  you can achieve the same effect manually (e.g. in `preCheck`) with: `export HOME=$(mktemp -d)`.
* Compiling with Cython causes tests to fail with a `ModuleNotLoadedError`.
  This can be fixed with two changes in the derivation: 1) replacing `pytest` with
  `pytestCheckHook` and 2) adding a `preCheck` containing `cd $out` to run
  tests within the built output.

## Contributing {#contributing}

### Contributing guidelines {#contributing-guidelines}

The following rules are desired to be respected:

* Python libraries are called from `python-packages.nix` and packaged with
  [`buildPythonPackage`](#buildpythonpackage-function). The expression of a library should be in
  `pkgs/development/python-modules/<name>/default.nix`.
* Python applications live outside of `python-packages.nix` and are packaged
  with [`buildPythonApplication`](#buildpythonapplication-function).
* Make sure libraries build for all Python interpreters.
  If it fails to build on some Python versions, consider disabling them by setting `disable = pythonAtLeast "3.x"` along with a comment.
* The two parameters, `pyproject` and `build-system` are set to avoid the legacy setuptools/distutils build.
* Only unversioned attributes (e.g. `pydantic`, but not `pypdantic_1`) can be included in `dependencies`,
  since due to `PYTHONPATH` limitations we can only ever support a single version for libraries
  without running into duplicate module name conflicts.
* The version restrictions of `dependencies` can be relaxed by [`pythonRelaxDepsHook`](#using-pythonrelaxdepshook).
* Make sure the tests are enabled using for example [`pytestCheckHook`](#using-pytestcheckhook) and, in the case of
  libraries, are passing for all interpreters. If certain tests fail they can be
  disabled individually. Try to avoid disabling the tests altogether. In any
  case, when you disable tests, leave a comment explaining not only _what_ the failure
  is but _why_ the test failure can be ignored for safe distribution with nixpkgs.
* `pythonImportsCheck` is set. This is still a good smoke test even if `pytestCheckHook` is set.
* `meta.platforms` takes the default value in many cases.
  It does not need to be set explicitly unless the package requires a specific platform.
* The file is formatted with `nixfmt-rfc-style`.
* Commit names of Python libraries must reflect that they are Python
  libraries (e.g. `python313Packages.numpy: 1.11 -> 1.12` rather than `numpy: 1.11 -> 1.12`).
* The current default version of python should be included
  in commit messages to enable automatic builds by ofborg.
  For example `python313Packages.numpy: 1.11 -> 1.12` should be used rather
  than `python3Packages.numpy: 1.11 -> 1.12`.
  Note that `pythonPackages` is an alias for `python27Packages`.
* Attribute names in `python-packages.nix` as well as `pname`s should match the
  library's name on PyPI, but be normalized according to [PEP
  0503](https://www.python.org/dev/peps/pep-0503/#normalized-names). This means
  that characters should be converted to lowercase and `.` and `_` should be
  replaced by a single `-` (foo-bar-baz instead of Foo__Bar.baz).
  If necessary, `pname` has to be given a different value within `fetchPypi`.
* It's generally preferable to fetch `src` directly from the repo and not from
  PyPI. Use `fetchPypi` when there's a clear technical reason to do so.
* Packages from sources such as GitHub and GitLab that do not exist on PyPI
  should not use a name that is already used on PyPI. When possible, they should
  use the package repository name prefixed with the owner (e.g. organization) name
  and using a `-` as delimiter.
* Attribute names in `python-packages.nix` should be sorted alphanumerically to
  avoid merge conflicts and ease locating attributes.
* Non-python runtime dependencies should be added via explicit wrapping or
  patching (using e.g. `substituteInPlace`), rather than through propagation via
  `dependencies`/`propagatedBuildInputs`, to reduce clutter in `$PATH`.

This list is useful for reviewers as well as for self-checking when submitting packages.

## Package set maintenance {#python-package-set-maintenance}

The whole Python package set has a lot of packages that do not see regular
updates, because they either are a very fragile component in the Python
ecosystem, like for example the `hypothesis` package, or packages that have
no maintainer, so maintenance falls back to the package set maintainers.

### Updating packages in bulk {#python-package-bulk-updates}

A tool to bulk-update numerous Python libraries is available in the
repository at `maintainers/scripts/update-python-libraries`.

It can quickly update minor or major versions for all packages selected
and create update commits, and supports the `fetchPypi`, `fetchurl` and
`fetchFromGitHub` fetchers. When updating lots of packages that are
hosted on GitHub, exporting a `GITHUB_API_TOKEN` is highly recommended.

Updating packages in bulk leads to lots of breakages, which is why a
stabilization period on the `python-updates` branch is required.

If a package is fragile and often breaks during these bulks updates, it
may be reasonable to set `passthru.skipBulkUpdate = true` in the
derivation. This decision should not be made on a whim and should
always be supported by a qualifying comment.

Once the branch is sufficiently stable it should normally be merged
into the `staging` branch.

An exemplary call to update all python libraries between minor versions
would be:

```ShellSession
$ maintainers/scripts/update-python-libraries --target minor --commit --use-pkgs-prefix pkgs/development/python-modules/**/default.nix
```

## CPython Update Schedule {#python-cpython-update-schedule}

With [PEP 602](https://www.python.org/dev/peps/pep-0602/), CPython now
follows a yearly release cadence. In nixpkgs, all supported interpreters
are made available, but only the most recent two
interpreters package sets are built; this is a compromise between being
the latest interpreter, and what the majority of the Python packages support.

New CPython interpreters are released in October. Generally, it takes some
time for the majority of active Python projects to support the latest stable
interpreter. To help ease the migration for Nixpkgs users
between Python interpreters the schedule below will be used:

| When | Event |
| --- | --- |
| After YY.11 Release | Bump CPython package set window. The latest and previous latest stable should now be built. |
| After YY.05 Release | Bump default CPython interpreter to latest stable. |

In practice, this means that the Python community will have had a stable interpreter
for ~2 months before attempting to update the package set. And this will
allow for ~7 months for Python applications to support the latest interpreter.
