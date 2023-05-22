#!/usr/bin/env bash

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
# ==================================================================
# VARIABLES
# ==================================================================
#
# BUILD VARIABLES
#
declare -gx LOGGER_VERSION="v-1.0.0"
declare -gx LOGGER_BUILD="x"
declare -gx LOGGER_BUILD_DATE="2023-05-03T16:00:00+10:00"
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
# ==================================================================
# FUNCTIONS
# ==================================================================
# ------------------------------------------------------------------
# logger::init
# ------------------------------------------------------------------
# ------------------------------------------------------------------
logger::init()
{
    local fileName="${1:-"debug"}"
}