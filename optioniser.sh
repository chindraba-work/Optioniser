#!/bin/bash
# SPDX-License-Identifier: MIT

########################################################################
#                                                                      #
#  Optioniser: A script to simplify the use of positional parameters   #
#              in BASH beyond what getopt(s) can do.                   #
#                                                                      #
# Copyright 2019 Chindraba <coding@chindraba.work>                     #
#                                                                      #
# Permission is hereby granted, free of charge, to any person          #
# obtaining a copy of this software and associated documentation       #
# files (the "Software"), to deal in the Software without restriction, #
# including without limitation the rights to use, copy, modify, merge, #
# publish, distribute, sublicense, and/or sell copies of the Software, #
# and to permit persons to whom the Software is furnished to do so,    #
# subject to the following conditions:                                 #
#                                                                      #
# The above copyright notice and this permission notice shall be       #
# included in all copies or substantial portions of the Software       #
#                                                                      #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,      #
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF   #
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGE-   #
# MENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE   #
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF   #
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION   #
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.      #
#                                                                      #
########################################################################

shopt -s extglob
source ./optioniser.conf

declare -a _drabaOPT_manditory_table
declare -a _drabaOPT_value_table
declare -a _drabaOPT_level_table
declare -a _drabaOPT_cmd_table
declare -a _drabaOPT_toggle_table
declare -a _drabaOPT_trigger_table
declare -a __drabaOPT_args=( "$@" )
declare -A __drabaOPT_hints
declare -A __drabaOPT_links
declare -A __drabaOPT_options_abbrev
declare -A __drabaOPT_options_long
declare -A __drabaOPT_options_short
declare -a __drabaOPT_reset=()
declare -A __drabaOPT_short_case
declare -a __drabaOPT_skipped

__drabaOPT_level_splitter='([-+]?)([[:digit:]]*)'
__drabaOPT_long_splitter='(.+)=(.*)'
__drabaOPT_long_trap='@([[:alpha:]])+([-[:digit:][:alpha:]])@([[:digit:][:alpha:]])'
__drabaOPT_negative_splitter='(no|skip)-(.*)'
__drabaOPT_short_splitter='(.)=?(.*)'

__drabaOPT_match_long() {
#   Return the long option name which exactly matches the target.
    declare __drabaOPT_haystack
    declare __drabaOPT_needle
    __drabaOPT_needle="^($1)$"
    shift
    for __drabaOPT_haystack; do 
        [[ $__drabaOPT_haystack =~ $__drabaOPT_needle ]] || continue
        echo "${BASH_REMATCH[1]}"
        return
    done
    return 1
}

__drabaOPT_match_abbrev() {
#   Return the first abbreviated name, from the supplied list, where
#   the entire abbreviated name matches the beginning of the target.
#   The portion of the target which is longer than the name being 
#   compared with are ignored. There is no guarantee what order the 
#   list of vaild names will be processed in. Each should be unique.
    declare __drabaOPT_abbrev_option
    declare __drabaOPT_haystack
    declare __drabaOPT_needle
    __drabaOPT_haystack="$1"
    shift
    for __drabaOPT_abbrev_option; do
        __drabaOPT_needle="^($__drabaOPT_abbrev_option)"
        [[ $__drabaOPT_haystack =~ $__drabaOPT_needle ]] || continue
        echo "${BASH_REMATCH[1]}"
        return
    done
    return 1
}

__drabaOPT_match_short() {
#   Return the short option letter which is an exact match for the
#   target letter if found.
    declare __drabaOPT_haystack
    declare __drabaOPT_needle=$1
    shift
    for __drabaOPT_haystack in $@; do
        [ "$__drabaOPT_needle" = "$__drabaOPT_haystack" ] || continue
        echo "$__drabaOPT_haystack"
        return
    done
    return
}

__drabaOPT_build_tables() {
    declare __drabaOPT_type="$1"
    shift
    declare -a __drabaOPT_abbrevs
    declare -a __drabaOPT_data
    declare -i __drabaOPT_index=1
    declare -a __drabaOPT_longs
    declare __drabaOPT_option
    declare -a __drabaOPT_shorts
    while (( "$#" > $__drabaOPT_index )); do
        __drabaOPT_data=( "${@:$__drabaOPT_index:5}" )
        [ '-' != "${__drabaOPT_data[2]}" ] && {
            __drabaOPT_abbrevs+=( "${__drabaOPT_data[2]}" )
            __drabaOPT_links["${__drabaOPT_data[2]}"]="${__drabaOPT_data[0]}"
            __drabaOPT_hints["${__drabaOPT_data[2]}"]="${__drabaOPT_data[4]}"
        }
        [ '-' != "${__drabaOPT_data[1]}" ] && {
            __drabaOPT_longs+=( "${__drabaOPT_data[1]}" )
            __drabaOPT_links["${__drabaOPT_data[1]}"]="${__drabaOPT_data[0]}"
            __drabaOPT_hints["${__drabaOPT_data[1]}"]="${__drabaOPT_data[4]}"
        }
        [ '-' != "${__drabaOPT_data[3]}" ] && {
            __drabaOPT_shorts+=( "${__drabaOPT_data[3]}" )
            __drabaOPT_links["${__drabaOPT_data[3]}"]="${__drabaOPT_data[0]}"
            __drabaOPT_hints["${__drabaOPT_data[3]}"]="${__drabaOPT_data[4]}"
        }
        __drabaOPT_index="$__drabaOPT_index+5"
    done;
    __drabaOPT_options_abbrev[$__drabaOPT_type]="${__drabaOPT_abbrevs[@]}"
    __drabaOPT_options_long[$__drabaOPT_type]="${__drabaOPT_longs[@]}"
    __drabaOPT_options_short[$__drabaOPT_type]="${__drabaOPT_shorts[@]}"
    for __drabaOPT_option in ${__drabaOPT_options_short[$__drabaOPT_type]}; do
        __drabaOPT_short_case[$__drabaOPT_type]+=$__drabaOPT_option
    done
    return 0
}

__drabaOPT_find_link() {
    declare __drabaOPT_valid_option=''
    __drabaOPT_valid_option="$(__drabaOPT_find_option "$1" "${2:-long}" "$3")"
    (( ${#__drabaOPT_valid_option} )) || return 
    echo "${__drabaOPT_links[$__drabaOPT_valid_option]}"
    return
}

__drabaOPT_find_option() {
    declare __drabaOPT_found_option=''
    if [ 'go_long' = "go_$2" ]; then
        (( ${#__drabaOPT_found_option} )) || \
            __drabaOPT_found_option="$(__drabaOPT_match_long "$3" ${__drabaOPT_options_long[$1]})"
        (( ${#__drabaOPT_found_option} )) || \
            __drabaOPT_found_option="$(__drabaOPT_match_abbrev "$3" ${__drabaOPT_options_abbrev[$1]})"
    fi
    if [ 'go_short' = "go_$2" ] || [ 'go_group' = "go_$2" ]; then
        (( ${#__drabaOPT_found_option} )) || \
            __drabaOPT_found_option="$(__drabaOPT_match_short "${3::1}" "${__drabaOPT_options_short[$1]}")"
    fi
    (( ${#__drabaOPT_found_option} )) || return 
    echo "$__drabaOPT_found_option"
    return
}

__drabaOPT_launch_sub() {
    declare __drabaOPT_found_sub=''
    declare -a __drabaOPT_args
    declare -a __drabaOPT_to_send
    __drabaOPT_found_sub="$(__drabaOPT_find_link "cmd" "${1:-long}" "$2")"
    (( ${#__drabaOPT_found_sub} )) || return
    __drabaOPT_to_send=()
    [ 'Oyes' = "O$_drabaOPT_pass_unknown" ] && \
        __chindOPT_to_send=( "${__drabaOPT_reset[@]}" )
    [ 'Oyes' = "O$_drabaOPT_pass_balance" ] && \
        __chindOPT_to_send+=( "${__drabaOPT_args[@]}" )
    __drabaOPT_args=()
    __drabaOPT_target=''
    __drabaOPT_current=''
    set -- "${__drabaOPT_to_send[@]}"
    $__drabaOPT_found_sub "$@"
    return 0
}

__drabaOPT_process_option() {
    declare __drabaOPT_found_process=''
    __drabaOPT_found_process="$(__drabaOPT_find_link "$1" "$2" "$3")"
    (( ${#__drabaOPT_found_process} )) || return
    shift 3
    $__drabaOPT_found_process "$@"
    [ 'go_group' = "go_$2" ] || __drabaOPT_target=''
    __drabaOPT_current=''
}

__drabaOPT_reject_option() {
    declare __drabaOPT_rejected_option
    __drabaOPT_rejected_option="$(__drabaOPT_find_option "$1" "$2" "$3")"
    (( ${#__drabaOPT_rejected_option} )) || return
    if [ 'do_notice' = "do_$_drabaOPT_errors_disposition" ]; then
        printf "Invalid usage of %s '%s' in '%s' ignored.\n" "$1" "$__drabaOPT_rejected_option" "$__drabaOPT_current"
    elif [ 'do_fatal' = "do_$_drabaOPT_errors_disposition" ]; then
        printf "Invalid usage of %s '%s' in '%s'.\n" "$1" "$__drabaOPT_rejected_option" "$__drabaOPT_current"
        exit
    fi
    [ 'go_group' != "go_$2" ] && \
        __drabaOPT_target='' || \
        __drabaOPT_target="${__drabaOPT_target:1}"
    (( ${#__drabaOPT_target} )) || __drabaOPT_current=''
    return 0
}

__drabaOPT_shift() {
    (( ${#__drabaOPT_args[@]} )) && __drabaOPT_args=( "${__drabaOPT_args[@]:1}" )
    return 0
}

__drabaOPT_try_long_options() {
    case "$__drabaOPT_target" in
        no-$__drabaOPT_long_trap | skip-$__drabaOPT_long_trap )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_negative_splitter ]]
            __drabaOPT_negative_prefix="${BASH_REMATCH[1]}"
            __drabaOPT_toggle_name="${BASH_REMATCH[2]}"
            __drabaOPT_process_option toggle long "$__drabaOPT_toggle_name" off && return 0
            ;;&
        $__drabaOPT_long_trap=@([-+])+([[:digit:]]) )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_long_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            [[ "$__drabaOPT_data" =~ $__drabaOPT_level_splitter ]]
            __drabaOPT_level_inc="${BASH_REMATCH[1]}"
            __drabaOPT_level_delta="${BASH_REMATCH[2]}"
            case "$__drabaOPT_level_inc" in 
                '+' ) __drabaOPT_level_inc='inc'; ;;
                '-' ) __drabaOPT_level_inc='dec'; ;;
            esac
            __drabaOPT_process_option level long "$__drabaOPT_option_part" "$__drabaOPT_level_inc" "$__drabaOPT_level_delta" && \
                return 0
            __drabaOPT_process_option value long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_reject_option toggle long "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger long "$__drabaOPT_option_part" && \
                return 0
            ;;
        $__drabaOPT_long_trap=+([[:digit:]]) )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_long_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            __drabaOPT_process_option level long "$__drabaOPT_option_part" set "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option value long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_reject_option toggle long "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger long "$__drabaOPT_option_part" && \
                return 0
            ;;
        $__drabaOPT_long_trap=@([-+]) )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_long_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            case "$__drabaOPT_data" in 
                '+' ) __drabaOPT_level_inc='inc'; __drabaOPT_toggle_status='on'; ;;
                '-' ) __drabaOPT_level_inc='dec'; __drabaOPT_toggle_status='off'; ;;
            esac
            __drabaOPT_process_option toggle long "$__drabaOPT_option_part" "$__drabaOPT_toggle_status" && \
                return 0
            __drabaOPT_process_option level long "$__drabaOPT_option_part" "$__drabaOPT_level_inc" 0 && \
                return 0
            __drabaOPT_process_option value long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_reject_option trigger long "$__drabaOPT_option_part" && \
                return 0
            ;;
        $__drabaOPT_long_trap=?* )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_long_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            __drabaOPT_process_option value long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory long "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_reject_option level long "$__drabaOPT_option_part" && \
                return 0
            case "${__drabaOPT_data,,}" in
                'y' | 'yes' | 'on' | 'true' )
                    __drabaOPT_process_option toggle long "$__drabaOPT_option_part" on && return 0
                    ;;
                'n' | 'no' | 'off' | 'false' )
                    __drabaOPT_process_option toggle long "$__drabaOPT_option_part" off && return 0
                    ;;
            esac
            __drabaOPT_reject_option toggle long "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger long "$__drabaOPT_option_part" && \
                return 0
            ;;
        $__drabaOPT_long_trap= )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_long_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_process_option value long "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option manditory long "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option level long "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option toggle long "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger long "$__drabaOPT_option_part" && \
                return 0
            ;;
        $__drabaOPT_long_trap )
            __drabaOPT_process_option trigger long "$__drabaOPT_target" && \
                return 0
            __drabaOPT_process_option value long "$__drabaOPT_target" && \
                return 0
            if [ 'end--' = "end$__drabaOPT_next" ]; then
                __drabaOPT_reject_option toggle long "$__drabaOPT_target" && \
                    return 0
                __drabaOPT_reject_option level long "$__drabaOPT_target" && \
                    return 0
                __drabaOPT_reject_option manditory long "$__drabaOPT_target" && \
                    return 0
            fi
            declare __drabaOPT_option_search=''
            for __drabaOPT_search_group in manditory level toggle; do
                (( ${#__drabaOPT_option_search} )) || \
                    __drabaOPT_option_search="$(__drabaOPT_find_option $__drabaOPT_search_group long "$__drabaOPT_target")"
            done
            if (( ${#__drabaOPT_option_search} )); then
                case "$__drabaOPT_next" in
                    @([-+])+([[:digit:]]) )
                        [[ "$__drabaOPT_next" =~ $__drabaOPT_level_splitter ]]
                        __drabaOPT_level_inc="${BASH_REMATCH[1]}"
                        __drabaOPT_level_delta="${BASH_REMATCH[2]}"
                        case "$__drabaOPT_level_inc" in 
                            '+' ) __drabaOPT_level_inc='inc'; ;;
                            '-' ) __drabaOPT_level_inc='dec'; ;;
                        esac
                        __drabaOPT_process_option level long "$__drabaOPT_option_search" "$__drabaOPT_level_inc" "$__drabaOPT_level_delta" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option manditory long "$__drabaOPT_option_search" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0; 
                        }
                        __drabaOPT_reject_option toggle long "$__drabaOPT_option_search" && \
                            return 0
                        ;;
                    +([[:digit:]]) )
                        __drabaOPT_process_option level long "$__drabaOPT_option_search" set "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option manditory long "$__drabaOPT_option_search" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_reject_option toggle long "$__drabaOPT_option_search" && \
                            return 0
                        ;;
                    @([-+]) )
                        case "$__drabaOPT_next" in 
                            '+' ) __drabaOPT_level_inc='inc'; __drabaOPT_toggle_status='on'; ;;
                            '-' ) __drabaOPT_level_inc='dec'; __drabaOPT_toggle_status='off'; ;;
                        esac
                        __drabaOPT_process_option toggle long "$__drabaOPT_option_search" "$__drabaOPT_toggle_status" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option level long "$__drabaOPT_option_search" "$__drabaOPT_level_inc" 0 && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option manditory long "$__drabaOPT_option_search" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        ;;
                    * )
                        case "${__drabaOPT_next,,}" in
                            'y' | 'yes' | 'on' | 'true' )
                                __drabaOPT_process_option toggle long "$__drabaOPT_option_search" on && {
                                    __drabaOPT_shift
                                    return 0
                                }
                                ;;
                            'n' | 'no' | 'off' | 'false' )
                                __drabaOPT_process_option toggle long "$__drabaOPT_option_search" off && {
                                    __drabaOPT_shift
                                    return 0
                                }
                                ;;
                        esac
                        __drabaOPT_process_option manditory long "$__drabaOPT_target" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_reject_option toggle long "$__drabaOPT_target" && \
                            return 0
                        __drabaOPT_reject_option level long "$__drabaOPT_target" && \
                            return 0
                esac
            fi
            ;;
    esac
    return 1
}

__drabaOPT_try_short_options() {
    case "$__drabaOPT_target" in
        [[:alpha:]]?(=)@([-+])+([[:digit:]]) )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_short_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            [[ "$__drabaOPT_data" =~ $__drabaOPT_level_splitter ]]
            __drabaOPT_level_inc="${BASH_REMATCH[1]}"
            __drabaOPT_level_delta="${BASH_REMATCH[2]}"
            case "$__drabaOPT_level_inc" in 
                '+' ) __drabaOPT_level_inc='inc'; ;;
                '-' ) __drabaOPT_level_inc='dec'; ;;
            esac
            __drabaOPT_process_option level short "$__drabaOPT_option_part" "$__drabaOPT_level_inc" "$__drabaOPT_level_delta" && \
                return 0
            __drabaOPT_process_option value short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_reject_option toggle short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger short "$__drabaOPT_option_part" && \
                return 0
            ;;
        [[:alpha:]]?(=)+([[:digit:]]) )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_short_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            __drabaOPT_process_option level short "$__drabaOPT_option_part" set "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option value short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_reject_option toggle short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger short "$__drabaOPT_option_part" && \
                return 0
            ;;
        [[:alpha:]]?(=)@([-+]) )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_short_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            case "$__drabaOPT_data" in 
                '+' ) __drabaOPT_level_inc='inc'; __drabaOPT_toggle_status='on'; ;;
                '-' ) __drabaOPT_level_inc='dec'; __drabaOPT_toggle_status='off'; ;;
            esac
            __drabaOPT_process_option toggle short "$__drabaOPT_option_part" "$__drabaOPT_toggle_status" && \
                return 0
            __drabaOPT_process_option level short "$__drabaOPT_option_part" "$__drabaOPT_level_inc" 0 && \
                return 0
            __drabaOPT_process_option value short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_reject_option trigger short "$__drabaOPT_option_part" && \
                return 0
            ;;
        [[:alpha:]]= )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_long_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_process_option value short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option manditory short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option level short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option toggle short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger short "$__drabaOPT_option_part" && \
                return 0
            ;;
        [[:alpha:]]?(=)?* )
            [[ "$__drabaOPT_target" =~ $__drabaOPT_short_splitter ]]
            __drabaOPT_option_part="${BASH_REMATCH[1]}"
            __drabaOPT_data="${BASH_REMATCH[2]}"
            __drabaOPT_process_option value short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            __drabaOPT_process_option manditory short "$__drabaOPT_option_part" "$__drabaOPT_data" && \
                return 0
            case "${__drabaOPT_data,,}" in
                'y' | 'yes' | 'on' | 'true' )
                    __drabaOPT_process_option toggle short "$__drabaOPT_option_part" on && \
                return 0
                    ;;
                'n' | 'no' | 'off' | 'false' )
                    __drabaOPT_process_option toggle short "$__drabaOPT_option_part" off && \
                return 0
                    ;;
            esac
            __drabaOPT_reject_option level short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option toggle short "$__drabaOPT_option_part" && \
                return 0
            __drabaOPT_reject_option trigger short "$__drabaOPT_option_part" && \
                return 0
            ;;
        [[:alpha:]] )
            __drabaOPT_process_option trigger short "$__drabaOPT_target" && \
                return 0
            __drabaOPT_process_option value short "$__drabaOPT_target" && \
                return 0
            if [ 'end--' = "end$__drabaOPT_next" ]; then
                __drabaOPT_reject_option toggle short "$__drabaOPT_target" && \
                    return 0
                __drabaOPT_reject_option level short "$__drabaOPT_target" && \
                    return 0
                __drabaOPT_reject_option manditory short "$__drabaOPT_target" &&
            fi
            declare __drabaOPT_option_search=''
            for __drabaOPT_search_group in manditory level toggle; do
                (( ${#__drabaOPT_option_search} )) || \
                    __drabaOPT_option_search="$(__drabaOPT_find_option $__drabaOPT_search_group short "$__drabaOPT_target")"
            done
            if (( ${#__drabaOPT_option_search} )); then
                case "$__drabaOPT_next" in
                    @([-+])+([[:digit:]]) )
                        [[ "$__drabaOPT_next" =~ $__drabaOPT_level_splitter ]]
                        __drabaOPT_level_inc="${BASH_REMATCH[1]}"
                        __drabaOPT_level_delta="${BASH_REMATCH[2]}"
                        case "$__drabaOPT_level_inc" in 
                            '+' ) __drabaOPT_level_inc='inc'; ;;
                            '-' ) __drabaOPT_level_inc='dec'; ;;
                        esac
                        __drabaOPT_process_option level short "$__drabaOPT_option_search" "$__drabaOPT_level_inc" "$__drabaOPT_level_delta" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option manditory short "$__drabaOPT_option_search" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_reject_option toggle short "$__drabaOPT_option_search" && \
                            return 0
                        ;;
                    +([[:digit:]]) )
                        __drabaOPT_process_option level short "$__drabaOPT_option_search" set "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option manditory short "$__drabaOPT_option_search" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_reject_option toggle short "$__drabaOPT_option_search" && \
                            return 0
                        ;;
                    @([-+]) )
                        case "$__drabaOPT_next" in 
                            '+' ) __drabaOPT_level_inc='inc'; __drabaOPT_toggle_status='on'; ;;
                            '-' ) __drabaOPT_level_inc='dec'; __drabaOPT_toggle_status='off'; ;;
                        esac
                        __drabaOPT_process_option toggle short "$__drabaOPT_option_search" "$__drabaOPT_toggle_status" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option level short "$__drabaOPT_option_search" "$__drabaOPT_level_inc" 0 && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_process_option manditory short "$__drabaOPT_option_search" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        ;;
                    * )
                        case "${__drabaOPT_next,,}" in
                            'y' | 'yes' | 'on' | 'true' )
                                __drabaOPT_process_option toggle short "$__drabaOPT_option_search" on && {
                                    __drabaOPT_shift
                                    return 0
                                }
                                ;;
                            'n' | 'no' | 'off' | 'false' )
                                __drabaOPT_process_option toggle short "$__drabaOPT_option_search" off && {
                                    __drabaOPT_shift
                                    return 0
                                }
                                ;;
                        esac
                        __drabaOPT_process_option manditory short "$__drabaOPT_target" "$__drabaOPT_next" && {
                            __drabaOPT_shift
                            return 0
                        }
                        __drabaOPT_reject_option toggle short "$__drabaOPT_option_search" && \
                            return 0
                        __drabaOPT_reject_option level short "$__drabaOPT_option_search" && \
                            return 0
                esac
            fi
            ;;
    esac
}

__drabaOPT_unknown() {
    if [ 'do_rebuild' = "do_$_drabaOPT_unknown_disposition" ]; then
        __drabaOPT_reset+=( "$__drabaOPT_current" )
    elif [ 'do_notice' = "do_$_drabaOPT_unknown_disposition" ]; then
        printf "Unknown option '%s' in '%s' ignored.\n" "$1" "$__drabaOPT_current" >&2
    elif [ 'do_fatal' = "do_$__drabaOPT_unknown_disposition" ]; then
        printf "Unknown option '%s' found in '%s'.\n" "$1" "$__drabaOPT_current" >&2
        exit
    fi
    [ 'go_group' != "go$1" ] && \
        __drabaOPT_target='' || \
        __drabaOPT_target="${__drabaOPT_target:1}"
    (( ${#__drabaOPT_target} )) || __drabaOPT_current=''
    return 0
}

__drabaOPT_handle_dash() {
    __drabaOPT_target=''
    __drabaOPT_current=''
    return 0
}

__drabaOPT_end_options() {
    __drabaOPT_target=''
    __drabaOPT_current=''
    return 0
}

__drabaOPT_try_group_options() {
    [ 'Rok' = "R$__drabaOPT_group" ] || return 1
    while (( ${#__drabaOPT_target} )); do
        case "${__drabaOPT_target::1}" in
            "${__drabaOPT_short_case[trigger]}" )
                ;;
            "${__drabaOPT_short_case[toggle]}" )
                ;;
            "${__drabaOPT_short_case[level]}" )
                ;;
            "${__drabaOPT_short_case[value]}" )
                ;;
            "${__drabaOPT_short_case[manditory]}" )
                ;;
            * )
        esac
        __drabaOPT_target="${__drabaOPT_target:1}" 
    done
    return 1
}

drabaOPT_dispatch() {
    __drabaOPT_current=''
    while (( ${#__drabaOPT_args[@]} )); do
        if (( ! ${#__drabaOPT_current} )); then
            __drabaOPT_current="${__drabaOPT_args[0]}"
            __drabaOPT_shift
        fi
        [ 'X--' = "X$__drabaOPT_current" ] && __drabaOPT_end_options && continue
        [ 'X-' = "X$__drabaOPT_current" ] && __drabaOPT_handle_dash && continue
        __drabaOPT_char1="${__drabaOPT_current::1}"
        __drabaOPT_char2="${__drabaOPT_current:1:1}"
        __drabaOPT_go_short='no'
        __drabaOPT_go_long='no'
        __drabaOPT_short='no'
        __drabaOPT_long='no'
        case "${__drabaOPT_current::2}" in
            '+'? )
                __drabaOPT_leader='+'
                __drabaOPT_target="${__drabaOPT_current:1}"
                case "$__drabaOPT_target" in
                    $__drabaOPT_long_trap )
                        [ 'Oyes' = "O${_drabaOPT_long_plus,,}" ] && {
                            __drabaOPT_process_option trigger long "$__drabaOPT_target" && continue
                            __drabaOPT_process_option toggle long "$__drabaOPT_target" on && continue
                        }
                        ;;
                    [[:alpha:]] )
                        [ 'Oyes' = "O${_drabaOPT_short_plus,,}" ] && {
                            __drabaOPT_process_option trigger short "$__drabaOPT_target" && continue
                            __drabaOPT_process_option toggle short "$__drabaOPT_target" on && continue
                        }
                        ;;
                esac
                (( ${#__drabaOPT_target} )) && \
                    __drabaOPT_unknown $__drabaOPT_target || \
                    __drabaOPT_unknown $__drabaOPT_leader
                echo ""
                continue
                ;;
            '--' )
                __drabaOPT_leader='--'
                __drabaOPT_target="${__drabaOPT_current:2}"
                [ 'Oyes' = "O${_drabaOPT_long_double_dash,,}" ] && __drabaOPT_long='ok'
                ;;
            '-?' )
                __drabaOPT_leader='-'
                __drabaOPT_target="${__drabaOPT_current:1}"
                [ 'Oyes' = "O${_drabaOPT_short_dash,,}" ] && __drabaOPT_short='ok'
                [ 'Oyes' = "O${_drabaOPT_long_dash,,}" ] && __drabaOPT_long='ok'
                ;;
            * )
                __drabaOPT_leader=''
                __drabaOPT_target="$__drabaOPT_current"
                [ 'Oyes' = "O${_drabaOPT_short_no_dash,,}" ] && __drabaOPT_short='ok'
                [ 'Oyes' = "O${_drabaOPT_long_no_dash,,}" ] && __drabaOPT_long='ok'
        esac
        [ 'Oyes' = "O${_drabaOPT_commands,,}" ] && case "$__drabaOPT_target" in
            $__drabaOPT_long_trap )
                __drabaOPT_launch_sub long "$__drabaOPT_target" && continue
                ;;
            [[:alpha:]] )
                __drabaOPT_launch_sub short "$__drabaOPT_target" && continue
                ;;
        esac
        __drabaOPT_next="${__drabaOPT_args[0]:---}"
        __drabaOPT_group="$_drabaOPT_short_group"
        [ 'Rok' = "R$__drabaOPT_long" ] && __drabaOPT_try_long_options && continue
        [ 'Rok' = "R$__drabaOPT_short" ] && __drabaOPT_try_short_options && continue
        [ 'Rok' = "R$__drabaOPT_short" ] && __drabaOPT_try_group_options && continue
        __drabaOPT_unknown "$__drabaOPT_current"
    done
}

drabaOPT_init() {
    __drabaOPT_build_tables 'trigger' "${_drabaOPT_trigger_table[@]}"
    __drabaOPT_build_tables 'toggle' "${_drabaOPT_toggle_table[@]}"
    __drabaOPT_build_tables 'level' "${_drabaOPT_level_table[@]}"
    __drabaOPT_build_tables 'value' "${_drabaOPT_value_table[@]}"
    __drabaOPT_build_tables 'manditory' "${_drabaOPT_manditory_table[@]}"
    __drabaOPT_build_tables 'cmd' "${_drabaOPT_cmd_table[@]}"
}

