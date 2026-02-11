module VimReplica

using Base64
using InteractiveUtils

const _VIM_SENTINEL_START = "__VIM_PAYLOAD__"
const _VIM_SENTINEL_END = "__END__"

function __vim_inspect(expr::AbstractString)
  io_buf = IOBuffer()
  try
    # Evaluate in Main explicitly
    obj = Base.eval(Main, Meta.parse(expr))

    if isa(obj, AbstractArray)
      if ndims(obj) == 1
        println(io_buf, join(obj, '\t'))
      elseif ndims(obj) == 2
        for row in eachrow(obj)
          println(io_buf, join(row, '\t'))
        end
      elseif ndims(obj) == 3
        # eachslice returns 2D slices along dim=3
        for (i, slice2d) in enumerate(eachslice(obj, dims=3))
          if i > 1
            println(io_buf)  # separate slices
          end
          for row in eachrow(slice2d)
            println(io_buf, join(row, '\t'))
          end
        end
      end
    elseif :DataFrames in names(Main, all=true)
      DF = getfield(Main, :DataFrames)
      if isa(obj, DF.AbstractDataFrame)
        try
          show(io_buf, obj)
        catch
          println(io_buf, repr(obj))
        end
      end

    else
      println(io_buf, repr(obj))
    end
  catch e
    println(io_buf, "[vim_inspect error] ", e)
  end

  payload = base64encode(String(take!(io_buf)))
  println("$_VIM_SENTINEL_START$payload$_VIM_SENTINEL_END")
end
"""
    __vim_whos()

Print textual information about all variables in Main using
a sentinel + base64 frame.
"""
function __vim_whos()
  io_buf = IOBuffer()
  try
    # Iterate over all names in Main
    for name in names(Main, all=true)
      # Skip builtin modules and internal names starting with #
      if isdefined(Main, name) && !(startswith(string(name), "#")) && !(name in (:Base, :Core, :InteractiveUtils, :VimReplica))
        val_repr = try
          repr(getfield(Main, name))
        catch
          "[error getting value]"
        end
        println(io_buf, "$name = $val_repr")
      end
    end
  catch e
    println(io_buf, "[vim_whos error] ", e)
  end

  payload = base64encode(String(take!(io_buf)))
  println("$(VimReplica._VIM_SENTINEL_START)$payload$(VimReplica._VIM_SENTINEL_END)")
end


function __vim_variable_names()
  """
  Return user-defined variable names in the current Main module,
  excluding modules, functions, DataFrames, and common internals.
  Output is sent to Vim via stdout using a sentinel + base64 frame.
  """

  io_buf = IOBuffer()

  try
    # Names to exclude entirely
    EXCLUDE_NAMES = (:Base, :Core, :VimReplica, :exit, :quit)

    # Types to exclude
    EXCLUDE_TYPES = Union{Module, Function}

    # Iterate over all names in Main
    for name in names(Main, all=true)
      # Skip if not defined first
      if !isdefined(Main, name)
        continue
      end

      # Get value safely
      val = try
        getfield(Main, name)
      catch
        nothing
      end

      if val === nothing || val === ""
          continue
      end

      # Skip names starting with _ or in exclude list or of excluded types
      if startswith(string(name), "_") || startswith(string(name), "#") ||
        (name in EXCLUDE_NAMES) || isa(val, EXCLUDE_TYPES)
        continue
      end

      println(io_buf, name)
    end

  catch e
    println(io_buf, "[vim_get_variables error] ", e)
  end

  payload = base64encode(String(take!(io_buf)))
  println("$(VimReplica._VIM_SENTINEL_START)$payload$(VimReplica._VIM_SENTINEL_END)")
end

end # module
