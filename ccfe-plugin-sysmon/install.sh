#!/bin/sh
#
#  ccfe-plugin-sysmon installer
#  Copyright (C) 2009, 2012 Massimo Loschi
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#  Author: Massimo Loschi <ccfedevel@gmail.com>
#

# This can be used as sample for pre-installation scripts for packaged CCFE
# plugins.

INSTANCE=ccfe

ABORT_MSG='Plugin installation aborted'
MYNAME='sysmon plugin'

# Check if CCFE is in the $PATH:
$INSTANCE -h > /dev/null 2>&1 || { echo "CCFE instance \"$INSTANCE\" not found or not in \$PATH - abort" ; exit 1; }

# Get CCFE library directory:
eval $($INSTANCE -c 2>&1 | grep LIB_DIR)
prefix=$LIB_DIR/$INSTANCE

if [ -d $prefix/demo.menu ]
then
  if [ -w $prefix ]
  then
    cp sysmon.item $prefix/demo.menu/
    cp sysmon.menu $prefix/
    cp -r sysmon.d $prefix/
    cp README $prefix/sysmon.d/
    echo "$MYNAME installed in default demo menu."
  else
    echo "cannot write $prefix - $ABORT_MSG"
    exit 2
  fi
else
  echo "Default demo menu not found - $ABORT_MSG"
  exit 1
fi
