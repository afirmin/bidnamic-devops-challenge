#!/usr/bin/env bash

TAB="$(printf '\t')"

cat << EOF > Makefile
run:
${TAB}black get-pip.py
${TAB}black flask.py
${TAB}pylint get-pip.py
${TAB}pylint flask.py
EOF
