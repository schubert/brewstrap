#!/usr/bin/env sh

BREWSTRAP_BASE="https://github.com/schubert/brewstrap"
PLATFORM=`uname -s`
BREWSTRAP_BIN="${BREWSTRAP_BASE}/raw/master/brewstrap_${PLATFORM}.sh"
PLATFORM_BIN="/tmp/${USER}-brewstrap_${PLATFORM}.sh"
FETCH_CMD="echo 'No known fetch command for ${PLATFORM}'"
FETCH_PROGRAM=`which curl 2> /dev/null`
if [ $? = 0 ]; then
  FETCH_CMD="curl -fsSL ${BREWSTRAP_BIN} > ${PLATFORM_BIN}"
else
  echo "curl not found. trying ftp..."
  FETCH_PROGRAM=`which ftp 2> /dev/null`
  if [ $? = 0 ]; then
    FETCH_CMD="ftp -o ${PLATFORM_BIN} ${BREWSTRAP_BIN}"
  else
    echo "ftp not found."
  fi
fi
$FETCH_CMD
if [ -f ${PLATFORM_BIN} ]; then
  exec sh ${PLATFORM_BIN}
else
  echo "Unable to find ${PLATFORM_BIN}. Download failed for ${PLATFORM}?"
  exit 1
fi

