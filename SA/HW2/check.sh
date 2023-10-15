#! /bin/sh

shellcheck -s sh -a ~/kypkk/NYCU_NASA/SA/HW2/HW2.sh > /dev/null 2>&1
return_val=$?

if [[ $return_val -eq 0 ]]; then
  exit 0
else
  exit 1
fi


