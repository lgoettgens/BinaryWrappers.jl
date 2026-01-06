module BinaryWrappers

export @generate_wrappers

using Scratch 
using JLLWrappers

const wrapper_key = "binarywrappers_v$(VERSION.major).$(VERSION.minor)"

function wrapper_contents(libpath::String, sourcebinary::String)
    return """
        #!/bin/sh
        # Since we cannot run these binaries through the usual julia commands we need
        # this wrapper that sets up the correct library paths.
        export $(JLLWrappers.LIBPATH_env)="$(libpath)"
        exec $(sourcebinary) "\$@"
        """
end

function shell_script_wrapper_contents(libpath::String, sourcebinary::String)
    # For shell scripts we use `source` (.) instead of exec to avoid macOS stripping
    # the LIBPATH. This means \$0 will point to our wrapper.
    # For 4ti2 this means that its own wrapper scripts will call our wrapper for the
    # binaries, so strictly speaking adjusting the LIBPATH here is not necessary.
    return """
        #!/bin/sh
        # We cannot run shell scripts directly as macOS will remove
        # DYLD_FALLBACK_LIBRARY_PATH for any subshells.
        # So we source the original script instead.
        export $(JLLWrappers.LIBPATH_env)="$(libpath)"
        . $(sourcebinary) "\$@"
        """
end

# defined in Perl_jllExt
function perl_script_wrapper_contents(_, _)
    error("`perl_script_wrapper_contents` needs `Perl_jll` to be loaded.")
end

# use @generate_wrappers instead to automatically deduce the calling module
function generate_wrappers(m::Module, caller::Union{Module, Base.UUID, Nothing})
    # we generate wrappers per minor julia version
    # the scratch will belong to the jll which the wrappers are generated for
    # and the usage is tied to the module calling the `@generate` macro.
    target = get_scratch!(m, wrapper_key, caller)

    binpath(name) = joinpath(target, "bin", name)
    mkpath(binpath(""))

    bindir = joinpath(getproperty(m, :artifact_dir), "bin")
    sourcebinary = joinpath(bindir, "\$(basename \$0)")
    libpath = getproperty(m, :LIBPATH)[]

    # POSIX compatible shells
    shellre = r"^#!/bin/(ba|da|z|k)?sh"

    # Perl scripts
    perlre = r"^#!/usr/bin/(perl|env perl)"

    for bin in readdir(bindir)
        if isfile(joinpath(bindir, bin))
            (tmpfile, tmpio) = mktemp(binpath(""); cleanup=false)
            shebang = readline(joinpath(bindir, bin))
            if match(shellre, shebang) !== nothing
                # shell scripts use a different wrapper because macOS...
                write(tmpio, shell_script_wrapper_contents(libpath, sourcebinary))
            elseif match(perlre, shebang) !== nothing
                write(tmpio, perl_script_wrapper_contents(libpath, sourcebinary))
            else
                write(tmpio, wrapper_contents(libpath, sourcebinary))
            end
            close(tmpio)
            chmod(tmpfile, 0o755)
            # using mv would introduce some race conditions due to concurrent deletes
            Base.Filesystem.rename(tmpfile, binpath(bin))
        end
    end
    return binpath("")
end

# this behaves slightly different than the @get_scratch! function:
# it will associate the scratch to the module passed as argument
# and use the calling module for the scratch usage (for gc)
macro generate_wrappers(m::Union{Symbol,Expr})
    uuid = Base.PkgId(__module__).uuid
    return quote
        generate_wrappers($(esc(m)), $(esc(uuid)))
    end
end

end
