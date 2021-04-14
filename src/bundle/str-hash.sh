#!/usr/bin/env bash

# Pipelines are considered failed if any of the constituent commands fail
set -o pipefail

usage()
{
    cat <<END
str-hash [-n number] <input>

Calcualates a string hash value. 
The resulting string uses lowercase ASCII leters only.

Options:
  -n number 
    Number of characters to include in the string (default is 6)
END
}

if [[ ($# -ne 1) && ($# -ne 3) ]]; then
    usage
    exit 1
fi

count=6
if [[ $# -eq 3 ]]; then
    if [[ "$1" == "-n" ]]; then
        shift
        count=$(($1))
        shift
    else
        usage
        exit 1
    fi
fi

input=$1

readarray -t bytes < <(echo "$input" | openssl sha512 -r | cut -f 1 -d ' ' | fold -w 2)

output=""
for (( i=0; i<count; ++i )); do
  val=$(("0x${bytes[i]}"))                          # Convert from hex notation to number
  val=$(( (val % 26) + 97 ))                        # 26 ASCII letters, 'a' is 97
  printf -v output "${output}\x$(printf %x $val)"   # To convert from code to char need to use code in hex format
done

echo "$output"
