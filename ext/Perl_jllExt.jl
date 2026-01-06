module Perl_jllExt

import BinaryWrappers
import Perl_jll

function BinaryWrappers.perl_script_wrapper_contents(libpath::String, sourcebinary::String)
    return "test"
end

end # module Perl_jllExt
