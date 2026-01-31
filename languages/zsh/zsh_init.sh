#!/bin/zsh

_VIM_SENTINEL_START="__VIM_PAYLOAD__"
_VIM_SENTINEL_END="__END__"

__vim_inspect() {
  local var="$1"
  if [[ -z "$var" ]]; then
    echo "Usage: __vim_inspect VARIABLE_NAME"
    return
  fi

  # check variable existence
  if ! typeset -p "$var" &>/dev/null; then
    echo "Variable '$var' does not exist"
    return
  fi

  local decl type output key val
  decl=$(typeset -p "$var" 2>/dev/null)

  # detect type
  if [[ $decl == *'()'* ]]; then
    type="array"
  elif [[ $decl == *'=('* ]]; then
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
      output="(${(j:, :)${(P)var}})"
      ;;
    associative)
      for key in ${(kP)var}; do
        val=${(P)var[$key]}
        output+="$key=$val"$'\t'
      done
      output=${output%$'\t'}
      ;;
  esac

  # encode
  local payload
  payload=$(print -rn -- "$output" | base64)
  echo "${_VIM_SENTINEL_START}${payload}${_VIM_SENTINEL_END}"
}

# TODO: Only track variables you explicitly want. You cannot track all the
# variables, not even the user-defined variables
typeset -a _VIM_USER_VARS
# When creating variables:
# 1️⃣ Scalar
FOO="hello world"
_VIM_USER_VARS+=("FOO")

# 2️⃣ Array
BAR=(a b c)
_VIM_USER_VARS+=("BAR")

# 3️⃣ Associative array

# %%
# 9️⃣ Nested associative array
declare -A COMPLEX=( ['a']=1 ['b']=2 )
_VIM_USER_VARS+=("COMPLEX")

# 5️⃣ Float
declare -F PI=3.14159
_VIM_USER_VARS+=("PI")

# 6️⃣ Readonly scalar
readonly NAME="ubaldot"
_VIM_USER_VARS+=("NAME")

# 7️⃣ Color / string style (like you had for prompt colors)
COLOR_DIR="%F{197}"
_VIM_USER_VARS+=("COLOR_DIR")
COLOR_DEF="%f"
_VIM_USER_VARS+=("COLOR_DEF")

# 8️⃣ Empty array
EMPTY_ARRAY=()
_VIM_USER_VARS+=("EMPTY_ARRAY")

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
    if [[ $decl == *'()'* ]]; then
      type=array
    elif [[ $decl == *'=('* ]]; then
      type=associative
    else
      type=scalar
    fi

    # Build output line by line
    case $type in
      scalar)
        out+="$name=${(P)name}"$'\n'
        ;;
      array)
        out+="$name=(${(j:, :)${(P)name}})"$'\n'
        ;;
      associative)
        local kv="" k
        for k in ${(kP)name}; do
          kv+="$k=${(P)name[$k]}, "
        done
        kv=${kv%, }
        out+="$name=($kv)"$'\n'
        ;;
    esac
  done

  # Strip trailing newline
  out=${out%$'\n'}
  print -r -- "${_VIM_SENTINEL_START}$(print -rn -- "$out" | base64)${_VIM_SENTINEL_END}"
}
