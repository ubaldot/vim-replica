#!/usr/bin/env bash

# OBS! The payload shall finish with \n
#
_VIM_SENTINEL_START="__VIM_PAYLOAD__"
_VIM_SENTINEL_END="__END__"


RED="\033[31m"
GREEN="\033[32m"
END="\033[0m"

# OBS! This shall be the same as in variable_explorer.vim
PROMPT_COMMAND=
# PS1='vim_replica> '
PS1="${GREEN}vim_replica>${END} "

# User must append the variables to _VIM_USER_VARS to visualize, e.g.
#   FOO=ubaldot
#   _VIM_USER_VARS+=("FOO")

declare -a _VIM_USER_VARS=()

__vim_inspect() {
  local var="$1"

  if [[ -z "$var" ]]; then
    echo "Usage: __vim_inspect VARIABLE_NAME"
    return
  fi

  # check variable existence
  if ! declare -p "$var" &>/dev/null; then
    echo "Variable '$var' does not exist"
    return
  fi

  local decl type output payload

  decl=$(declare -p "$var" 2>/dev/null)

  if [[ $decl == declare\ -a* ]]; then
    type="array"
  elif [[ $decl == declare\ -A* ]]; then
    type="associative"
  else
    type="scalar"
  fi

  output=""

  case "$type" in
    scalar)
      # indirect expansion
      output="${!var}"
      ;;
    array)
      # expand indexed array
      eval "output=\"(\${$var[*]})\""
      ;;
    associative)
      # iterate keys
      local k v
      eval "
        for k in \"\${!$var[@]}\"; do
          v=\"\${$var[\$k]}\"
          output+=\"\$k=\$v\"\$'\n'
        done
      "
      output="${output%$'\n'}"
      ;;
  esac

  payload=$(printf '%s\n' "$output" | base64)
  echo "${_VIM_SENTINEL_START}${payload}${_VIM_SENTINEL_END}"
}

__vim_whos() {
  local out="" name type decl

  for name in "${_VIM_USER_VARS[@]}"; do
    # Skip readonly variables
    declare -p "$name" 2>/dev/null | grep -q 'readonly' && continue

    decl=$(declare -p "$name" 2>/dev/null)
    [[ -z $decl ]] && continue

    if [[ $decl == declare\ -a* ]]; then
      type="array"
    elif [[ $decl == declare\ -A* ]]; then
      type="associative"
    else
      type="scalar"
    fi

    case "$type" in
      scalar)
        out+="$name=${!name}"$'\n'
        ;;
      array)
        eval "out+=\"$name=(\${$name[*]})\""
        out+=$'\n'
        ;;
      associative)
        local kv="" k v
        eval "
          for k in \"\${!$name[@]}\"; do
            v=\"\${$name[\$k]}\"
            kv+=\"\$k=\$v, \"
          done
        "
        kv="${kv%, }"
        out+="$name=($kv)"$'\n'
        ;;
    esac
  done

  out="${out}"
  printf '%s' "${_VIM_SENTINEL_START}$(printf '%s\n' "$out" | base64)${_VIM_SENTINEL_END}"
}

__vim_variable_names() {
    # Check if _VIM_USER_VARS exists
    if [ "${_VIM_USER_VARS+x}" ]; then
        # Build a string with one variable name per line
        local out=""
        for var in "${_VIM_USER_VARS[@]}"; do
            out+="$var"$'\n'
        done

        # Encode in Base64 and wrap with Vim sentinel markers
        printf '%s' "${_VIM_SENTINEL_START}$(printf '%s' "$out" | base64)${_VIM_SENTINEL_END}"
    else
        printf 'No _VIM_USER_VARS defined.\n' >&2
        return 1
    fi
}
