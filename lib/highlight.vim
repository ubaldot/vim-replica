vim9script

import "../lib/logger.vim"

# ---------------------------------------
# Functions for highlighing cells
# ---------------------------------------
sign define ReplicaConsoleHl  linehl=CursorLine
sign define ReplicaConsoleHlFast  linehl=UnderLined

var line_in_old = 1
var line_out_old = line("$")
var list_sign_id_old = []
var list_sign_id = []


# Find lines range based on cell_delimiter
export def GetExtremes(display_range: bool = false): list<number>
  var line_in = search($"\^{b:cells_delimiter}", 'cnbW')
  var line_out = search($"\^{b:cells_delimiter}", 'nW')
  # If search() returns 0 it means that the pattern has not been found
  if line_in == 0
    line_in = 1
  endif
  if line_out == 0
    line_out = line("$")
  endif
  # Display range only if some cell has been found
  if (line_in != 1 || line_out != line("$")) && display_range && g:replica_display_range
    echo $"cell_range=[{line_in}, {line_out}]"
  endif
  return [line_in, line_out]
enddef

# var counter_dbg = 0
# When adding a sign keep in mind that we set sign_id = line number
# TODO: lines are shaded through sign feature, but this also add a small sign
# next by the line numbers which is not super nice. Is there any other
# alternative to sign for shading lines?
export def HighlightCell(display_range: bool = false)
  var extremes = GetExtremes(display_range)
  var line_in = extremes[0]
  var line_out = extremes[1]

  # Decide highlight group
  var hlgroup = g:replica_alt_highlight
    ? "ReplicaConsoleHlFast"
    : "ReplicaConsoleHl"

  # Define a unique sign group for this plugin
  const sign_group = "ReplicaConsole"

  # Only highlight if there is at least one cell
  if line_in != 1 || line_out != line("$")
    # If cursor moved to a new cell, update signs
    if line_in != line_in_old || line_out != line_out_old
      # Remove existing signs
      for line in list_sign_id_old
        sign_unplace(sign_group, {"buffer": expand("%:p"), "id": line})
      endfor

      # Compute new lines to highlight
      if g:replica_alt_highlight
        list_sign_id = [line_in, line_out]
      else
    # Highlight lines before the cell
    var top_range = line_in > 1 ? range(1, line_in - 1) : []

    # Highlight lines after the cell, but only if there are lines outside
    var bottom_range = line_out < line("$") ? range(line_out + 1, line("$")) : []

    list_sign_id = top_range + bottom_range

      endif

      # Place signs in the unique group
      list_sign_id_old = []
      for line in list_sign_id
        sign_place(line, sign_group, hlgroup, expand("%:p"), {"lnum": line})
        add(list_sign_id_old, line)
      endfor

      # Update old values
      line_in_old = line_in
      line_out_old = line_out

      logger.Info($'highlighted lines: {line_in} - {line_out}')
    endif
  else
    # No cells → remove all signs
    for line in list_sign_id_old
      sign_unplace(sign_group, {"buffer": expand("%:p"), "id": line})
    endfor
  endif
enddef
