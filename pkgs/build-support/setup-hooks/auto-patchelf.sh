# shellcheck shell=bash

declare -a autoPatchelfLibs
declare -a extraAutoPatchelfLibs

gatherLibraries() {
    autoPatchelfLibs+=("$1/lib")
}

# shellcheck disable=SC2154
# (targetOffset is referenced but not assigned.)
addEnvHooks "$targetOffset" gatherLibraries

# Can be used to manually add additional directories with shared object files
# to be included for the next autoPatchelf invocation.
addAutoPatchelfSearchPath() {
    local -a findOpts=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --) shift; break;;
            --no-recurse) shift; findOpts+=("-maxdepth" 1);;
            --*)
                echo "addAutoPatchelfSearchPath: ERROR: Invalid command line" \
                     "argument: $1" >&2
                return 1;;
            *) break;;
        esac
    done

    local dir=
    while IFS= read -r -d '' dir; do
        extraAutoPatchelfLibs+=("$dir")
    done <  <(find "$@" "${findOpts[@]}" \! -type d \
            \( -name '*.so' -o -name '*.so.*' \) -print0 \
            | sed -z 's#/[^/]*$##' \
            | uniq -z
        )
}


autoPatchelf() {
    local norecurse=
    while [ $# -gt 0 ]; do
        case "$1" in
            --) shift; break;;
            --no-recurse) shift; norecurse=1;;
            --*)
                echo "autoPatchelf: ERROR: Invalid command line" \
                     "argument: $1" >&2
                return 1;;
            *) break;;
        esac
    done

    concatTo ignoreMissingDepsArray autoPatchelfIgnoreMissingDeps
    concatTo appendRunpathsArray appendRunpaths
    concatTo runtimeDependenciesArray runtimeDependencies
    concatTo patchelfFlagsArray patchelfFlags
    concatTo autoPatchelfFlagsArray autoPatchelfFlags

    # Check if ignoreMissingDepsArray contains "1" and if so, replace it with
    # "*", printing a deprecation warning.
    for dep in "${ignoreMissingDepsArray[@]}"; do
        if [ "$dep" == "1" ]; then
            echo "autoPatchelf: WARNING: setting 'autoPatchelfIgnoreMissingDeps" \
                 "= true;' is deprecated and will be removed in a future release." \
                 "Use 'autoPatchelfIgnoreMissingDeps = [ \"*\" ];' instead." >&2
            ignoreMissingDepsArray=( "*" )
            break
        fi
    done

    auto-patchelf                                                       \
        ${norecurse:+--no-recurse}                                      \
        --ignore-missing "${ignoreMissingDepsArray[@]}"                 \
        --paths "$@"                                                    \
        --libs "${autoPatchelfLibs[@]}"                                 \
               "${extraAutoPatchelfLibs[@]}"                            \
        --runtime-dependencies "${runtimeDependenciesArray[@]/%//lib}"  \
        --append-rpaths "${appendRunpathsArray[@]}"                     \
        "${autoPatchelfFlagsArray[@]}"                                  \
        --extra-args "${patchelfFlagsArray[@]}"
}

autoPatchelfPostFixup() {
    # XXX: This should ultimately use fixupOutputHooks but we currently don't have
    # a way to enforce the order. If we have $runtimeDependencies set, the setup
    # hook of patchelf is going to ruin everything and strip out those additional
    # RPATHs.
    #
    # So what we do here is basically run in postFixup and emulate the same
    # behaviour as fixupOutputHooks because the setup hook for patchelf is run in
    # fixupOutput and the postFixup hook runs later.
    if [[ -z "${dontAutoPatchelf-}" ]]; then
        autoPatchelf -- $(for output in $(getAllOutputNames); do
            [ -e "${!output}" ] || continue
            [ "${output}" = debug ] && continue
            echo "${!output}"
        done)
    fi
}

postFixupHooks+=(autoPatchelfPostFixup)
