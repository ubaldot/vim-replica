#!/bin/zsh

# OBS! The payload shall finish with \n

_VIM_SENTINEL_START="__VIM_PAYLOAD__"
_VIM_SENTINEL_END="__END__"

# OBS! This shall be the same as in variable_explorer.vim
PROMPT='vim_replica> '

# User must append the variables to _VIM_USER_VARS to visualize, e.g.
#   FOO=ubaldot
#   _VIM_USER_VARS+=("FOO")
typeset -a _VIM_USER_VARS

__vim_inspect() {
  local var="$1"
  if [[ -z "$var" ]]; then
    # It can be only shown in the logger
    echo "Usage: __vim_inspect VARIABLE_NAME"
    return
  fi

  # check variable existence
  if ! typeset -p "$var" &>/dev/null; then
    # It can be only shown in the logger
    echo "Variable '$var' does not exist"
    return
  fi

  local decl type output key val
  decl=$(typeset -p "$var" 2>/dev/null)

  if [[ $decl == typeset*"-a"* ]]; then
      type="array"
  elif [[ $decl == typeset*"-A"* ]]; then
      type="associative"
  else
      type="scalar"
  fi

  output=""

  case $type in
    scalar)
      output="${(P)var}"
      ;;
    array)
      output="(${(j: :)${(P)var}})"  # indexed array
      ;;
    associative)
      # TODO: improve this
      for k in $(eval "echo \${(k)${var}}"); do
        val=$(eval "echo \${${var}[\$k]}")
        output+="$k=$val"$'\n'
      done
      output=${output%$'\n'}
      ;;
  esac
  # encode
  local payload
  payload=$(print -rn -- "$output" | base64)
  # If payload is too long, consider more echo statements. See python
  # init_script for examples
  echo "${_VIM_SENTINEL_START}${payload}${_VIM_SENTINEL_END}"
}


__vim_whos() {
  local out="" name type

  for name in "${_VIM_USER_VARS[@]}"; do
    # Skip readonly variables
    typeset -p "$name" 2>/dev/null | grep -q 'readonly' && continue

    # Get declaration safely
    local decl
    decl=$(typeset -p "$name" 2>/dev/null)
    [[ -z $decl ]] && continue

    # Determine type
    if [[ $decl == typeset*"-a"* ]]; then
        type="array"
    elif [[ $decl == typeset*"-A"* ]]; then
        type="associative"
    else
        type="scalar"
    fi

    # Build output line by line
    case $type in
      scalar)
        out+="$name=${(P)name}"$'\n'
        ;;
      array)
        out+="$name=(${(j: :)${(P)name}})"$'\n'
        ;;
      associative)
        local kv="" k

        # TODO: improve this
        for k in $(eval "echo \${(k)${name}}"); do
          val=$(eval "echo \${${name}[\$k]}")
          kv+="$k=$val",' '
        done
        kv=${kv%, }
        out+="$name=($kv)"$'\n'
        ;;
    esac
  done

  # TODO: uncomment to get exported vars (env variables)
  # while IFS='=' read -r key val; do
  #   out+="$key=$val"$'\n'
  # done < <(env)

  # Strip trailing newline
  out=${out%$'\n'}
  # If payload is too long, consider more echo statements. See python
  # init_script for examples
  print -r -- "${_VIM_SENTINEL_START}$(print -rn -- "$out" | base64)${_VIM_SENTINEL_END}"
}
