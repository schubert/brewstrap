#!/usr/bin/env sh

BREWSTRAP_BASE="https://github.com/schubert/brewstrap"
PLATFORM=`uname -s`
BREWSTRAP_BIN="${BREWSTRAP_BASE}/raw/master/brewstrap_${PLATFORM}.sh"
FETCH_CMD="echo 'No known fetch command for ${PLATFORM}'"
FETCH_PROGRAM=`which curl`
if [ $? -eq 0 ]; then
  FETCH_CMD="curl -fsSL \"${BREWSTRAP_BIN}\" > /tmp/${USER}-brewstrap_${PLATFORM}.sh"
else
  FETCH_PROGRAM=`which ftp`
  if [ $? -eq 0 ]; then
    FETCH_CMD="ftp -o /tmp/${USER}-brewstrap_${PLATFORM}.sh \"${BREWSTRAP_BIN}\""
  fi
fi
$FETCH_CMD
exec sh /tmp/${USER}-brewstrap_${PLATFORM}.sh

