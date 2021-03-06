#!/bin/bash
#
#  Copyright (c) 2021 Siddharth Chandrasekaran <sidcha.dev@gmail.com>
#
#  SPDX-License-Identifier: Apache-2.0
#

usage() {
	cat >&2<<----
	LibOSDP build configure script

	Configures a bare minimum build environemt for LibOSDP. This is not a
	replacement for cmake and intended only for those users who don't care
	about all the bells and whistles and need only the library.

	OPTIONS:
	  --packet-trace               Enable raw packet trace for diagnostics
	  --skip-mark                  Don't send the leading mark byte (0xFF)
	  --use-openssl                Use methods from openssl instead of in-tree ones
	  --openssl-include-dir DIR    Include directory for openssl if not in system path
	  --no-colours                 Don't colourize log ouputs
	  --static-pd                  Setup PD single statically
	  --lib-only                   Only build the library
	  --file                       Compile support for file tx command
	  --osdpctl                    Build osdpctl tool
	  -f, --force                  Use this flags to override some checks
	  -h, --help                   Print this help
	---
}

while [ $# -gt 0 ]; do
	case $1 in
	--packet-trace)        PACKET_TRACE=1;;
	--skip-mark)           SKIP_MARK_BYTE=1;;
	--cross-compile)       CROSS_COMPILE=$2; shift;;
	--use-openssl)         USE_OPENSSL=1;;
	--openssl-include-dir) OPENSSL_INCLUDE_DIR=$2; shift;;
	--no-colours)          NO_COLOURS=1;;
	--static-pd)           STATIC_PD=1;;
	--lib-only)            LIB_ONLY=1;;
	--file)                FILE=1;;
	--osdpctl)             OSDPCTL=1;;
	-f|--force)            FORCE=1;;
	-h|--help)             usage; exit 0;;
	*) echo -e "Unknown option $1\n"; usage; exit 1;;
	esac
	shift
done

if [ -f config.mak ] && [ -z "$FORCE" ]; then
	echo "LibOSDP already configured! Use --force to re-configure"
	exit 1
fi

if [[ ("$OSTYPE" == "cygwin") || ("$OSTYPE" == "win32") ]]; then
	echo "Warning: unsuported platform. Expect issues!"
fi

## Toolchains
CC=${CC:-${CROSS_COMPILE}gcc}
CXX=${CXX:-${CROSS_COMPILE}g++}
AR=${AR:-${CROSS_COMPILE}ar}

## check if submodules are initialized
if [[ -z "$(ls -A utils)" ]]; then
	"Initializing git-submodule utils"
	git submodule update --init
fi

## Build options
if [[ ! -z "${NO_COLOURS}" ]]; then
	CCFLAGS+=" -DCONFIG_DISABLE_PRETTY_LOGGING"
fi

if [[ ! -z "${PACKET_TRACE}" ]]; then
	CCFLAGS+=" -DCONFIG_OSDP_PACKET_TRACE"
fi

if [[ ! -z "${SKIP_MARK_BYTE}" ]]; then
	CCFLAGS+=" -DCONFIG_OSDP_SKIP_MARK_BYTE"
fi

if [[ ! -z "${STATIC_PD}" ]]; then
	CCFLAGS+=" -DCONFIG_OSDP_STATIC_PD"
fi

if [[ ! -z "${FILE}" ]]; then
	CCFLAGS+=" -DCONFIG_OSDP_FILE"
fi

## Repo meta data
echo "Extracting source code meta information"
PROJECT_VERSION=$(perl -ne 'print if s/^project\(libosdp VERSION ([0-9.]+)\)$/\1/' CMakeLists.txt)
if [[ -z "${PROJECT_VERSION}" ]]; then
	echo "Failed to parse PROJECT_VERSION!"
	exit -1
fi

PROJECT_NAME=libosdp
if [[ -d .git ]]; then
	GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
	GIT_REV=$(git log --pretty=format:'%h' -n 1)
	GIT_TAG=$(git describe --exact-match --tags 2>/dev/null)
	GIT_DIFF=$(git diff --quiet --exit-code || echo +)
fi

if [[ ! -z "${USE_OPENSSL}" ]]; then
	CCFLAGS+=" -DCONFIG_OSDP_USE_OPENSSL"
	if [[ ! -z "${OPENSSL_INCLUDE_DIR}" ]]; then
		CCFLAGS+=" -I${OPENSSL_INCLUDE_DIR}"
		CXXFLAGS+=" -I${OPENSSL_INCLUDE_DIR}"
	fi
fi

## Declare sources
if [[ -z "${USE_OPENSSL}" ]]; then
	echo "Using in-tree AES methods. Consider using openssl (--use-openssl)"
	LIBOSDP_SOURCES+=" src/osdp_aes.c"
fi
LIBOSDP_SOURCES+=" src/osdp_common.c src/osdp_phy.c src/osdp_sc.c src/osdp_pd.c src/osdp_file.c"
LIBOSDP_SOURCES+=" utils/src/list.c utils/src/queue.c utils/src/slab.c utils/src/utils.c"

if [[ -z "${STATIC_PD}" ]]; then
	LIBOSDP_SOURCES+=" src/osdp_cp.c"
	TARGETS="cp_app.elf pd_app.elf"
else
	TARGETS="pd_app.elf"
fi

if [[ ! -z "${FILE}" ]]; then
	LIBOSDP_SOURCES+=" src/osdp_file.c"
fi

if [[ ! -z "${OSDPCTL}" ]]; then
	TARGETS+=" osdpctl.elf"
fi

if [[ ! -z "${LIB_ONLY}" ]]; then
	TARGETS=""
fi

## Generate osdp_config.h
echo "Generating osdp_config.h"
cp src/osdp_config.h.in osdp_config.h
sed -i "" -e "s/@PROJECT_VERSION@/${PROJECT_VERSION}/" osdp_config.h
sed -i "" -e "s/@PROJECT_NAME@/${PROJECT_NAME}/" osdp_config.h
sed -i "" -e "s/@GIT_BRANCH@/${GIT_BRANCH}/" osdp_config.h
sed -i "" -e "s/@GIT_REV@/${GIT_REV}/" osdp_config.h
sed -i "" -e "s/@GIT_TAG@/${GIT_TAG}/" osdp_config.h
sed -i "" -e "s/@GIT_DIFF@/${GIT_DIFF}/" osdp_config.h

## Generate osdp_exports.h
echo "Generating osdp_exports.h"
cat > osdp_export.h <<----
#ifndef OSDP_EXPORT_H
#define OSDP_EXPORT_H

#define OSDP_EXPORT
#define OSDP_NO_EXPORT

#endif /* OSDP_EXPORT_H */
---

## Generate Makefile
echo "Generating config.mak"
cat > config.mak << ---
CC=${CC}
CXX=${CXX}
AR=${AR}
SYSROOT=${SYSROOT}
CCFLAGS=${CCFLAGS}
CXXFLAGS=${CXXFLAGS}
LDFLAGS=${LDFLAGS}
SRC_LIBOSDP=${LIBOSDP_SOURCES}
TARGETS=${TARGETS}
---
echo
echo "LibOSDP lean build system configured!"
echo "Invoke 'make' to build."
