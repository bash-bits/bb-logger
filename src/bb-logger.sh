#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155,SC2154
# ==================================================================
# bb-logger
# ==================================================================
# BB-Logger Library File
#
# File:         bb-logger
# Author:       Ragdata
# Date:         03/05/2023
# License:      MIT License
# Copyright:    Copyright © 2023 Darren (Ragdata) Poulton
# ==================================================================
# PREFLIGHT
# ==================================================================
# ==================================================================
# DEPENDENCIES
# ==================================================================
bb-import bb-ansi
bb-import bb-functions/filesystem
bb-import bb-functions/is
bb-import bb-functions/utility
bb-import bb-regex/numeric
bb-import bb-regex/options
# ==================================================================
# VARIABLES
# ==================================================================
#
# VERSION
#
PKG_VERSION="0.1.0"
PKG_BUILD="1001"
PKG_BUILD_DATE="20230813:1940"
#
# DEFAULT PATHS
#
[[ -z "${BB_BASE_DIR}" ]] && declare -gx BB_BASE_DIR="$HOME/.bb"
[[ -z "${BB_CACHE_DIR}" ]] && declare -gx BB_CACHE_DIR="${BB_BASE_DIR}/cache"
[[ -z "${BB_LOG_DIR}" ]] && declare -gx BB_LOG_DIR="${BB_BASE_DIR}/log"
[[ -z "${BB_LOG}" ]] && declare -gx BB_LOG="${BB_LOG_DIR}/import"
#
# DEFAULT VARIABLES
#
[[ -z "${BB_LOG_SIZE}" ]] && declare -gx BB_LOG_SIZE=1048576
[[ -z "${BB_LOG_BACKUPS}" ]] && declare -gx BB_LOG_BACKUPS=5
[[ -z "${BB_LOG_ARCHIVE}" ]] && declare -gx BB_LOG_ARCHIVE=1
#
# REGEX VARIABLES
#
#[[ -z "$isINT" ]] && declare isINT='^[-+]?\d+$'
#[[ -z "$isOPT" ]] && declare isOPT='^(-([A-Za-z]+)[\s]?([A-Za-z0-9_\.]*))$|^(--(([A-Za-z0-9_\.]+)=?([A-Za-z0-9_\.]*)))$'
# ==================================================================
# FUNCTIONS
# ==================================================================
# ------------------------------------------------------------------
# log::checkLog
# ------------------------------------------------------------------
# @description Checks log file integrity
#
# @noargs
#
# @exitcode 0   Success (log file is OK)
# @exitcode 1   Failure (log file is NOT OK)
# ------------------------------------------------------------------
log::checkLog()
{
    local size, fileName="${1:-"debug"}"
    # initialize logfile if it doesn't exist
    [[ ! -f "${BB_LOG}" ]] && { log::init "$fileName" || errorReturn "$fileName Log Failed Integrity Check ('$?')" 2; }
    # check logfile size
    size=$(wc -c "${BB_LOG}" | awk '{print $1}')
    # rotate logfile if necessary
    [[ $size -ge $BB_LOG_SIZE ]] && { log::rotate || errorReturn "$fileName Log Failed Integrity Check ('$?')" 2; }
    # returns success IF we got this far ...
    return 0
}
# ------------------------------------------------------------------
# log::init
# ------------------------------------------------------------------
# @description Initializes log file
#
# @arg  $1  [string]    Log File Name
# ------------------------------------------------------------------
log::init()
{
    local fileName="${1:-"debug"}"

	if [[ "${fileName:0:1}" != "/" ]]; then
	    [[ ! -d "$BB_LOG_DIR" ]] && { mkdir -p "$BB_LOG_DIR" || return 1; }
    	[[ ! -f "$BB_LOG_DIR/$fileName" ]] && { touch "$BB_LOG_DIR/$fileName" || return 1; }
    	unset BB_LOG
    	declare -gx BB_LOG="${BB_LOG_DIR}/$fileName"
    else
		local fileDir="${fileName%/*}"
		[[ ! -d "$fileDir" ]] && { mkdir -p "$fileDir" || return 1; }
		[[ ! -f "$fileName" ]] && { touch "$fileName" || return 1; }
		unset BB_LOG
		declare -gx BB_LOG="$fileName"
    fi

    return 0
}
#
# FUNCTION ALIAS
#
initLog() { log::init "${1:-"debug"}"; }
# ------------------------------------------------------------------
# log::rotate
# ------------------------------------------------------------------
# ------------------------------------------------------------------
log::rotate()
{
    local filePath="${BB_LOG}"
    local fileDir="${filePath%/*}"
    local fileName="${filePath##*/}"
    local timestamp="$(date +%s)"
    local archive="${BB_LOG_ARCHIVE}"
    local files diff c
    # archive file if configured to do so
    [[ "$archive" ]] && tar -czf "$filePath" "$filePath.tar.gz" && filePath="$filePath.tar.gz"
    # timestamp the current logfile
    mv "$filePath" "$filePath.$timestamp"
    # cull excess backups
    files="$(find "$fileDir" -name "$fileName" | wc -l)"
    diff=$(( "$files" - "$BB_LOG_BACKUPS" ))
    diff=$diff++
    if [[ "$diff" -gt 0 ]]; then
        c=1
        for file in "$fileDir/$fileName"*
        do
            rm -f "$file"
            [[ $c -eq $diff ]] && break || $c++
        done
    fi
    # open a fresh log file
    touch "$BB_LOG"
}
# ------------------------------------------------------------------
# log::write
# ------------------------------------------------------------------
# ------------------------------------------------------------------
log::write()
{
    local msg fileName exitCode color user priority timestamp options
    local tag msgLog msgOut msgErr
    local isError=false toStdOut=false toStdErr=false toFile=true

	[[ "$TEST" ]] && return 0

	import::log::checkLog

    if [[ ! "$1" =~ $isOPT ]]; then
        msg="$1"
        shift
    fi

    options="$(getopt -l "code:,Color:,Init:,Msg:,priority:,tag:,error,warn,info,success" -o "c:C:I:M:p:t:123ewis" -a -- "$@")"

    eval set --"$options"

    while true
    do
        case "$1" in
            -c|--code)
                [[ ! "$2" =~ $isINT ]] && errorReturn "Invalid Argument!" 3
                exitCode="$2"
                shift 2
                ;;
            -C|--Color)
                color="$2"
                shift 2
                ;;
            -I|--Init)
                fileName="$2"
                shift 2
                ;;
            -M|--Msg)
                msg="$2"
                shift 2
                ;;
            -p|--priority)
                case "$2" in
                    10)     priority="TRACE";;
                    100)    priority="DEBUG";;
                    200)    priority="ROUTINE";;
                    300)    priority="INFO";;
                    400)    priority="NOTICE";;
                    500)    priority="WARNING";;
                    600)    priority="ALERT";;
                    700)    priority="ERROR"; isError=1;;
                    800)    priority="CRITICAL"; isError=1;;
                    900)    priority="FATAL"; isError=1;;
                    *)
                        echoError "Invalid Argument!"
                        return 3
                        ;;
                esac
                shift 2
                ;;
            -t|--tag)
                tag="$2"
                shift 2
                ;;
            -1)
                toStdOut=true
                shift
                ;;
            -2)
                toStdErr=true
                shift
                ;;
            -3)
                toFile=false
                shift
                ;;
            -e|--error)
                isError=true
                shift
                ;;
            -w|--warn)
                isWarning=true
                shift
                ;;
            -i|--info)
                isInfo=true
                shift
                ;;
            -s|--success)
                isSuccess=true
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                errorReturn "Invalid Argument '$1'!" 3
                ;;
        esac
    done

    #
    # COMPILE LOG MESSAGE
    #

    [[ -n "$exitCode" ]] && [[ ! "$isError" ]] && exitCode=0
    [[ -n "$exitCode" ]] && [[ "$isError" ]] && exitCode=1

    [[ "$SUDO_USER" ]] && user="$SUDO_USER" || user="$(whoami)"

    timestamp="$(date '+%y-%m-%d:%I%M%S.%3N')"

    # shellcheck disable=SC2001
    msg=$(echo "$msg" | sed 's/\\e\[.+m//g')

    [[ "$isError" && -z "$priority" ]] && priority="ERROR"
    [[ -z "$priority" ]] && priority="ROUTINE"

    [[ "$toFile" ]] && msgLog="$timestamp [$priority] ($user) :: ${tag}${msg}"

    if [[ ! "$isError" ]] && [[ ! "$isWarning" ]] && [[ "$toStdOut" ]]; then
        [[ "$priority" == "ROUTINE" ]] && msgOut="${tag}${msg}" || msgOut="${priority} :: ${tag}${msg}"
    elif [[ "$isError" ]] || [[ "$isWarning" ]] && [[ "$toStdErr" ]]; then
        msgErr="${priority}($!) :: ${tag}${msg}"
    fi

    #
    # WRITE TO LOG FILE
    #
    if [[ "$toFile" ]]; then
        # shellcheck disable=SC2094
        if [[ -w "$BB_LOG" ]]; then
            #echo "$msgLog" | tee -a "$BB_LOG" > /dev/null
            echo "$msgLog" >> "$BB_LOG"
        else
            #echo "$msgLog" | sudo tee -a "$BB_LOG" > /dev/null || { echoError "Log Write Failed!"; return 1; }
            sudo bash -c 'echo "$msgLog" >> "$BB_LOG"'
        fi
    fi

#    #
#    # WRITE TO STDOUT / STDERR
#    #
#    if [[ "$toStdOut" ]]; then
#        if [[ "$isInfo" ]]; then
#            echoInfo "$msgOut"
#        elif [[ "$isSuccess" ]]; then
#            echoSuccess "$msgOut"
#        elif [[ -n "$color" ]]; then
#            echo "${color}${msgOut}${RESET}"
#        else
#            echo "$msgOut"
#        fi
#    elif [[ "$toStdErr" ]]; then
#        if [[ "$isWarning" ]]; then
#            echoWarning "$msgErr"
#        else
#            echoError "$msgErr"
#        fi
#    fi
}
# ------------------------------------------------------------------
# log::debug
# ------------------------------------------------------------------
# @description Alias for log::write
#
# @arg  $1  [string]    Log Message
# ------------------------------------------------------------------
log::debug() { log::write "$1" -p 100; }
# ------------------------------------------------------------------
# log::info
# ------------------------------------------------------------------
# @description Alias for log::write
#
# @arg  $1  [string]    Log Message
# ------------------------------------------------------------------
log::info() { log::write "$1" -p 300; }
# ------------------------------------------------------------------
# log::warning
# ------------------------------------------------------------------
# @description Alias for log::write
#
# @arg  $1  [string]    Log Message
# ------------------------------------------------------------------
log::warning() { log::write "$1" -p 500; }
# ------------------------------------------------------------------
# log::error
# ------------------------------------------------------------------
# @description Alias for log::write
#
# @arg  $1  [string]    Log Message
# @arg  $2  [integer]   Exit Code (optional)
# ------------------------------------------------------------------
log::error() { log::write "$1" -p 700; return "${2:-1}"; }
# ------------------------------------------------------------------
# log::critical
# ------------------------------------------------------------------
# @description Alias for log::write
#
# @arg  $1  [string]    Log Message
# @arg  $2  [integer]   Exit Code (optional)
# ------------------------------------------------------------------
log::critical() { log::write "$1" -p 800; exit "${2:-1}"; }
# ------------------------------------------------------------------
# log::fatal
# ------------------------------------------------------------------
# @description Alias for log::write
#
# @arg  $1  [string]    Log Message
# @arg  $2  [integer]   Exit Code (optional)
# ------------------------------------------------------------------
log::fatal() { log::write "$1" -p 900; exit "${2:-1}"; }
# ------------------------------------------------------------------
# log::echoAlias
# ------------------------------------------------------------------
# @description Master alias function for `echo` command
#
# @arg  $1			[string]        String to be rendered
# @arg  -c="$VAR"   [option]        Color alias as defined above 				(required)
# @arg  -p='string' [option]        String to prefix to $1 						(optional)
# @arg  -s='string' [option]        String to suffix to $1 						(optional)
# @arg  -e          [option]        Enable escape codes 						(optional)
# @arg  -n          [option]        Disable newline at end of rendered string 	(optional)
#
# @exitcode     0   Success
# @exitcode     1   Failure
# @exitcode     2   ERROR - Requires Argument
# @exitcode     3   ERROR - Invalid Argument
# ------------------------------------------------------------------
log::echoAlias()
{
    local msg="${1:-}"
    local COLOR=""
    local OUTPUT=""
    local PREFIX=""
    local SUFFIX=""
    local _0=""
    local STREAM=1
    local -a OUTARGS

    shift

    [[ -z "$msg" ]] && { echo "${RED}${SYMBOL_ERROR} ERROR :: log::echoAlias :: Requires Argument!${RESET}"; return 2; }

    options=$(getopt -l "color:,prefix:,suffix:,escape,noline" -o "c:p:s:en" -a -- "$@")

    eval set --"$options"

    while true
    do
        case "$1" in
            -c|--color)
                COLOR="$2"
                shift 2
                ;;
            -p|--prefix)
                PREFIX="$2"
                shift 2
                ;;
            -s|--suffix)
                SUFFIX="$2"
                shift 2
                ;;
            -e|--escape)
                OUTARGS+=("-e")
                shift
                ;;
            -n|--noline)
                OUTARGS+=("-n")
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "${RED}ERROR :: echoAlias ::Invalid Argument '$1'!${RESET}"
                return 1
                ;;
        esac
    done

    [[ -n "$COLOR" ]] && _0="${RESET}" || _0=""

    OUTPUT="${COLOR}${PREFIX}${msg}${SUFFIX}${_0}"

    # shellcheck disable=SC2015
    [[ "$STREAM" -eq 2 ]] && { echo "${OUTARGS[@]}" "${OUTPUT}" >&2; log::error "${OUTARGS[@]}" "${OUTPUT}"; } || { echo "${OUTARGS[@]}" "${OUTPUT}"; log::info "${OUTARGS[@]}" "${OUTPUT}"; }

#    return 0
}
#
# MESSAGE ALIASES
#
#echoLog() { log::echoAlias "$1" "${@:2}"; }
#errLog() { log::echoAlias "$1" -c "${RED}" "${@:2}"; }
#exitLog() { log::echoAlias "$1"; exit "${2:-1}"; }
# ------------------------------------------------------------------
# log::usage
# ------------------------------------------------------------------
# ------------------------------------------------------------------
log::usage()
{
	echo
}
# ------------------------------------------------------------------
# log::version
# ------------------------------------------------------------------
# @description Reports the version and build date of this release
#
# @noargs
#
# @stdout Version, Copyright, & Build Information
# ------------------------------------------------------------------
log::version()
{
	local verbosity="${1:-}"

	if [[ -z "$verbosity" ]]; then
		echo "${PKG_VERSION}"
	else
		echo
		echo "Bash-Bits Modular Bash Library"
		echoWhite "BB-Logger Module ${PKG_VERSION}"
		echo "Copyright © 2022-2023 Darren (Ragdata) Poulton"
		echo "Build: ${PKG_BUILD}"
		echo "Build Date: ${PKG_BUILD_DATE}"
		echo
	fi
}
# ==================================================================
# ALIAS FUNCTIONS
# ==================================================================
#
# PRIORITY ALIASES
#
debugLog() { log::debug "$1" "${@:2}"; }
infoLog() { log::info "$1" "${@:2}"; }
warningLog() { log::warning "$1" "${@:2}"; }
debugLog() { log::debug "$1" "${@:2}"; }
errLog() { log::error "$1" "${@:2}"; }
fatalLog() { log::fatal "$1" "${@:2}"; }
criticalLog() { log::critical "$1" "${@:2}"; }
#
# MESSAGE ALIASES
#
# ------------------------------------------------------------------
# echoLog
# ------------------------------------------------------------------
# ------------------------------------------------------------------
echoLog()
{
	local msg options priority
	local -a OUTARGS

    if [[ ! "$1" =~ $isOPT ]]; then
        OUTARGS+=("$1")
        shift
    fi

    options=$(getopt -l "code:,Color:,Init:,Msg:,priority:,tag:,error,warn,info,success" -o "c:C:I:M:p:t:123ewis" -a -- "$@")

    eval set --"$options"

    while true
    do
    	case "$1" in
            -c|--code)
                [[ ! "$2" =~ $isINT ]] && errorReturn "Invalid Argument!" 3
                OUTARGS+=("-c")
                OUTARGS+=("$2")
                shift 2
                ;;
            -C|--Color)
            	OUTARGS+=("-C")
            	OUTARGS+=("$2")
                shift 2
                ;;
            -I|--Init)
            	OUTARGS+=("-I")
            	OUTARGS+=("$2")
                shift 2
                ;;
            -M|--Msg)
            	OUTARGS+=("-M")
            	OUTARGS+=("$2")
                shift 2
                ;;
            -p|--priority)
            	OUTARGS+=("-p")
            	priority="${2,,}"
                case "$2" in
                    10|trace)     OUTARGS+=("10");;
                    100|debug)    OUTARGS+=("100");;
                    200|routine)  OUTARGS+=("200");;
                    300|info)     OUTARGS+=("300");;
                    400|notice)   OUTARGS+=("400");;
                    500|warning)  OUTARGS+=("500");;
                    600|alert)    OUTARGS+=("600");;
                    700|error)    OUTARGS+=("700");;
                    800|critical) OUTARGS+=("800");;
                    900|fatal)    OUTARGS+=("900");;
                    *)            OUTARGS+=("300");;
                esac
                shift 2
                ;;
            -t|--tag)
            	OUTARGS+=("-t")
            	OUTARGS+=("$2")
                shift 2
                ;;
            -e|--error)
                OUTARGS+=("-e")
                shift
                ;;
            -w|--warn)
                OUTARGS+=("-w")
                shift
                ;;
            -i|--info)
                OUTARGS+=("-i")
                shift
                ;;
            -s|--success)
                OUTARGS+=("-s")
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                errorReturn "Invalid Argument '$1'!" 3
                ;;
    	esac
    done

    log::write "${OUTARGS[@]}"
}
# ------------------------------------------------------------------
# errorLog
# ------------------------------------------------------------------
# ------------------------------------------------------------------
errorLog()
{
	local msg options priority
	local -a OUTARGS

    if [[ ! "$1" =~ $isOPT ]]; then
        OUTARGS+=("$1")
        shift
    fi

    options=$(getopt -l "code:,priority:,tag:" -o "c:p:t:" -a -- "$@")

    eval set --"$options"

    while true
    do
    	case "$1" in
            -c|--code)
                [[ ! "$2" =~ $isINT ]] && errorReturn "Invalid Argument!" 3
                OUTARGS+=("-c")
                OUTARGS+=("$2")
                shift 2
                ;;
            -p|--priority)
            	OUTARGS+=("-p")
            	priority="${2,,}"
                case "$2" in
                    700|error)    OUTARGS+=("700");;
                    800|critical) OUTARGS+=("800");;
                    900|fatal)    OUTARGS+=("900");;
                    *)            OUTARGS+=("700");;
                esac
                shift 2
                ;;
            -t|--tag)
            	OUTARGS+=("-t")
            	OUTARGS+=("$2")
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                errorReturn "Invalid Argument '$1'!" 3
                ;;
    	esac
    done

    log::write "${OUTARGS[@]}"
}
# ------------------------------------------------------------------
# infoLog
# ------------------------------------------------------------------
# ------------------------------------------------------------------
infoLog()
{
	local msg options priority
	local -a OUTARGS

    if [[ ! "$1" =~ $isOPT ]]; then
        OUTARGS+=("$1")
        shift
    fi

    options=$(getopt -l "code:,priority:,tag:" -o "c:p:t:" -a -- "$@")

    eval set --"$options"

    while true
    do
    	case "$1" in
            -c|--code)
                [[ ! "$2" =~ $isINT ]] && errorReturn "Invalid Argument!" 3
                OUTARGS+=("-c")
                OUTARGS+=("$2")
                shift 2
                ;;
            -p|--priority)
            	OUTARGS+=("-p")
            	priority="${2,,}"
                case "$2" in
                    10|trace)     OUTARGS+=("10");;
                    100|debug)    OUTARGS+=("100");;
                    200|routine)  OUTARGS+=("200");;
                    300|info)     OUTARGS+=("300");;
                    *)            OUTARGS+=("200");;
                esac
                shift 2
                ;;
            -t|--tag)
            	OUTARGS+=("-t")
            	OUTARGS+=("$2")
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                errorReturn "Invalid Argument '$1'!" 3
                ;;
    	esac
    done

    log::write "${OUTARGS[@]}"
}
# ------------------------------------------------------------------
# warnLog
# ------------------------------------------------------------------
# ------------------------------------------------------------------
warnLog()
{
	local msg options priority
	local -a OUTARGS

    if [[ ! "$1" =~ $isOPT ]]; then
        OUTARGS+=("$1")
        shift
    fi

    options=$(getopt -l "code:,priority:,tag:" -o "c:p:t:" -a -- "$@")

    eval set --"$options"

    while true
    do
    	case "$1" in
            -c|--code)
                [[ ! "$2" =~ $isINT ]] && errorReturn "Invalid Argument!" 3
                OUTARGS+=("-c")
                OUTARGS+=("$2")
                shift 2
                ;;
            -p|--priority)
            	OUTARGS+=("-p")
            	priority="${2,,}"
                case "$2" in
                    400|notice)   OUTARGS+=("400");;
                    500|warning)  OUTARGS+=("500");;
                    600|alert)    OUTARGS+=("600");;
                    *)            OUTARGS+=("500");;
                esac
                shift 2
                ;;
            -t|--tag)
            	OUTARGS+=("-t")
            	OUTARGS+=("$2")
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                errorReturn "Invalid Argument '$1'!" 3
                ;;
    	esac
    done

    log::write "${OUTARGS[@]}"
}
# ------------------------------------------------------------------
# exitLog
# ------------------------------------------------------------------
# ------------------------------------------------------------------
exitLog()
{
	local msg options priority
	local -a OUTARGS

    if [[ ! "$1" =~ $isOPT ]]; then
        OUTARGS+=("$1")
        shift
    fi

    options=$(getopt -l "code:,priority:,tag:,error,warn,info,success" -o "c:p:t:123ewis" -a -- "$@")

    eval set --"$options"

    while true
    do
    	case "$1" in
            -c|--code)
                [[ ! "$2" =~ $isINT ]] && errorReturn "Invalid Argument!" 3
                OUTARGS+=("-c")
                OUTARGS+=("$2")
                shift 2
                ;;
            -p|--priority)
            	OUTARGS+=("-p")
            	priority="${2,,}"
                case "$2" in
                    10|trace)     OUTARGS+=("10");;
                    100|debug)    OUTARGS+=("100");;
                    200|routine)  OUTARGS+=("200");;
                    300|info)     OUTARGS+=("300");;
                    400|notice)   OUTARGS+=("400");;
                    500|warning)  OUTARGS+=("500");;
                    600|alert)    OUTARGS+=("600");;
                    700|error)    OUTARGS+=("700");;
                    800|critical) OUTARGS+=("800");;
                    900|fatal)    OUTARGS+=("900");;
                    *)            OUTARGS+=("300");;
                esac
                shift 2
                ;;
            -t|--tag)
            	OUTARGS+=("-t")
            	OUTARGS+=("$2")
                shift 2
                ;;
            -1)
                OUTARGS+=("-1")
                shift
                ;;
            -2)
                OUTARGS+=("-2")
                shift
                ;;
            -3)
                OUTARGS+=("-3")
                shift
                ;;
            -e|--error)
                OUTARGS+=("-e")
                shift
                ;;
            -w|--warn)
                OUTARGS+=("-w")
                shift
                ;;
            -i|--info)
                OUTARGS+=("-i")
                shift
                ;;
            -s|--success)
                OUTARGS+=("-s")
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                errorReturn "Invalid Argument '$1'!" 3
                ;;
    	esac
    done

    log::write "${OUTARGS[@]}"
}
# ==================================================================
# MAIN
# ==================================================================
if [[ $(is::sourced) ]]; then
	log::load "$@" || return $?
else
	trap 'bb::errorHandler "LINENO" "BASH_LINENO" "${BASH_COMMAND}" "${?}"' ERR

	options=$(getopt -l "help,version::" -o "hv::" -a -- "$@")

	eval set --"$options"

	while true
	do
		case "$1" in
			-h|--help)
				log::usage
				shift
				exitReturn
				;;
			-v|--version)
				if [[ -n "${2}" ]]; then
					log::version "${2}"
					shift 2
				else
					log::version
					shift
				fi
				exitReturn
				;;
			--)
				shift
				break
				;;
			*)
				echoError "Invalid Argument!"
				exitReturn 2
				;;
		esac
	done
fi
