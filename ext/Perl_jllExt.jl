module Perl_jllExt

import BinaryWrappers
import JLLWrappers
import Perl_jll

function BinaryWrappers.perl_script_wrapper_contents(libpath::String, sourcebinary::String)
    perlbinary = Perl_jll.get_perl_path()
    return """
        #!/bin/sh
        # Since we cannot run these binaries through the usual julia commands we need
        # this wrapper that sets up the correct library paths.
        export $(JLLWrappers.LIBPATH_env)="$(libpath)"
        exec $(perlbinary) -- $(sourcebinary) "\$@"
        """
end

end # module Perl_jllExt
