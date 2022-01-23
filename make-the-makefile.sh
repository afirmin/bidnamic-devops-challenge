#!/usr/bin/env bash

TAB="$(printf '\t')"

cat << EOF > Makefile
run:
${TAB}black flask.py
${TAB}pylint flask.py
EOF
