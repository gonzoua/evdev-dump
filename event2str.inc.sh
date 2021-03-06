#!/usr/bin/env bash

# Copyright (c) 2005-2010 Nikolai Kondrashov
#
# This file is part of evdev-dump.
#
# Evdev-dump is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Evdev-dump is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with evdev-dump; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

set -e

UNKNOWN_STR="<UNKNOWN>"
IGNORE_TYPE_REGEXP="(VERSION|MAX)"
IGNORE_CODE_REGEXP="MAX"

function get_type_synonym_regexp() {

    local code=$1

    if [ "$code" == "KEY" ]; then
        echo "(KEY|BTN)"
    else
        echo "$code"
    fi

}

function print_code_case() {

    local code=$1

    cat <<CUT
                case ${code}:
                    *pcode_str = "${code}";
                    break;

CUT
}

function print_type_case() {

    local INPUT_H=$1
    local type=$2
    local type_synonym_regexp=`get_type_synonym_regexp ${type}`
    local code

    cat <<CUT
        case EV_$type:

            *ptype_str = "EV_$type";

            switch (e->code)
            {
CUT

    cat $INPUT_H |
        egrep "^#define ${type_synonym_regexp}_" |
        cut -d' ' -f2- |
        egrep -v "^${type_synonym_regexp}_$IGNORE_CODE_REGEXP" |
        gawk --non-decimal-data '{printf "%s\t%d\n", $1, $2}' |
        sort --key=2 --numeric-sort --uniq |    # remove duplicated code entries
        cut -f1 |
        while read code; do
            cat <<CUT
                MAP($code);
CUT
        done
    
    cat <<CUT
                default:
                    *pcode_str = NULL;
                    break;
            } /* switch (e->code) */
            break; /* EV_$type */

CUT

}

function print_event2str() {

    local INPUT_H=$1
    local type

    cat <<CUT
static void
event2str(const struct input_event     *e,
          const char                  **ptype_str,
          const char                  **pcode_str)
{
#define MAP(_name) \\
    case _name:                 \\
        *pcode_str = #_name;    \\
        break

    switch (e->type)
    {

CUT

    cat $INPUT_H |
        egrep '^#define EV_' |
        cut -d_ -f2- |
        egrep -v "^$IGNORE_TYPE_REGEXP" |
        gawk --non-decimal-data '{printf "%s\t%d\n", $1, $2}' |
        sort --key=2 --numeric-sort --uniq |    # remove duplicated code entries
        cut -f1 |
        while read type; do
            print_type_case "$INPUT_H" "$type"
        done

    cat <<CUT
        default:
            *ptype_str = NULL;
            *pcode_str = NULL;
            break;

    } /* switch (e->type) */

#undef MAP

}
CUT

}

cat <<CUT
/*
 * vim:nomodifiable
 * DO NOT EDIT
 * This file is generated automatically by ${0##*/}.
 */

CUT
print_event2str $1
