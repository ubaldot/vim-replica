#!/bin/zsh

_VIM_SENTINEL_START="__VIM_PAYLOAD__"
_VIM_SENTINEL_END="__END__"
_MAX_LEN=200  # maximum length for a variable value in the payload

# Example variables
a=42
b="hello"
arr=(1 2 3 4)
typeset -A dict  # Zsh associative array
dict=(x 10 y 20)

__vim_inspect() {
  local var="$1"
  if [[ -z "$var" ]]; then
    echo "Usage: __vim_inspect VARIABLE_NAME"
    return
  fi

  local output=""

  if [[ -n ${(P)var} ]]; then
    # Check if array
    if [[ ${(tP)var} == "array" ]]; then
      output="${(j:\t:)${(P)var}}"
    # Check if associative array
    elif [[ ${(tP)var} == "associative" ]]; then
      output=""
      for key in ${(kP)var}; do
        local val=${(P)var[$key]}
        output+="$key=$val\t"
      done
      output=${output%$'\t'}
    else
      # scalar
      output="${(P)var}"
    fi
  else
    output="Variable '$var' does not exist"
  fi

  local payload=$(echo -n "$output" | base64)
  echo "${_VIM_SENTINEL_START}${payload}${_VIM_SENTINEL_END}"
}


__vim_whos() {
  output=""

  # Loop over environment variables only
  env | while IFS='=' read -r name value; do
    # skip internal variables if you want
    case "$name" in
      "_"|"PWD"|"OLDPWD") continue ;;
    esac

    # truncate value if too long
    if [ "${#value}" -gt $_MAX_LEN ]; then
      value="...truncated..."
    fi

    output="$output$name=$value\t"
  done

  # encode payload
  payload=$(printf '%s' "$output" | base64)
  printf '%s%s%s\n' "$_VIM_SENTINEL_START" "$payload" "$_VIM_SENTINEL_END"
}
