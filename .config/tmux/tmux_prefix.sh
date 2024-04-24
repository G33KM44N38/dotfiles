#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo ""
    exit 1
fi

IFS='_' read -r -a argument_array <<< "$1"


if [[ ${argument_array[0]} == "Dev" ]]; then
    echo -n "󰵮"
elif [[ ${argument_array[0]} == "Setting*" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "Code" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "React" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "Go" ]]; then
    echo -n "󰟓"
elif [[ ${argument_array[0]} == "C*" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "Rust" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "Docker" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "Ansible" ]]; then
    echo -n "󱂚"
elif [[ ${argument_array[0]} == "Fish" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "Ssh" ]]; then
    echo -n "󰒒"
elif [[ ${argument_array[0]} == "Hack" ]]; then
    echo -n "󱓇"
elif [[ ${argument_array[0]} == "Vi" ]]; then
    echo -n ""
elif [[ ${argument_array[0]} == "C" ]]; then
    echo -n ""
else
    echo -n "${argument_array[0]}"
fi
echo -n " ${argument_array[1]}"
