#!/bin/sh
#
#  Curses Command Front-end Installer
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

# getopt() used for shell portability

PREFIX='/usr/local/ccfe';
ETCDIR="$PREFIX/etc"
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib"
LOGDIR="$PREFIX/log"
MSGDIR="$PREFIX/msg"
MANDIR="$PREFIX/man"
DOCDIR="$PREFIX/doc"

PREFIX_DESCR='Destination prefix'
ETCDIR_DESCR='Configuration directory'
BINDIR_DESCR='Executables directory'
LIBDIR_DESCR='Libraries directory'
LOGDIR_DESCR='Logs directory'
MSGDIR_DESCR='Messages and localization directory'
MANDIR_DESCR='Man pages directory'
DOCDIR_DESCR='Documentation directory'

SAVED_INFO="ccfeinstall.conf"


usage ()
{
cat <<EOT
  Usage: `basename $0` [[-b][-u Path][-p Path][-c Path][-l Path][-e Path][-o Path][-m Path][-d Path][-a Path]][-h]

         -p: $PREFIX_DESCR
         -c: $ETCDIR_DESCR
         -l: $LIBDIR_DESCR
         -e: $BINDIR_DESCR
         -o: $LOGDIR_DESCR
         -m: $MSGDIR_DESCR
         -a: $MANDIR_DESCR
         -d: $DOCDIR_DESCR
         -b: Perform batch installation/update immediately
         -u: Update instead fresh installation.
             <Path> is the current CCFE configuration directory.
         -h: This help
EOT
exit 0
}



input ()
{
  local msg="$1"
  local default="$2"

  printf "%s? [%s] " "$msg" "$default"
  read keybuff
  [ -z "$keybuff" ] && keybuff=$default
}



mk_manpage ()
{
  local p=$1    # Source manpage filename (es. foo.1)
  local s       # Manual section

  s=`echo $p | cut -c ${#p}`
  cat man/$p | sed -e "s/ETC_DIR_PLACEHOLDER/$exp_etcdir/ ; s/BIN_DIR_PLACEHOLDER/$exp_bindir/ ; s/LIB_DIR_PLACEHOLDER/$exp_libdir/ ; s/LOG_DIR_PLACEHOLDER/$exp_logdir/ ; s/MSG_DIR_PLACEHOLDER/$exp_msgdir/ ; s/DOC_DIR_PLACEHOLDER/$exp_docdir/" > $MANDIR/man${s}/$p
}



mk_welcome ()
{
cat <<EOT
  IT WORKS!!!

  Please remove the following objects:
  - directory ${LIBDIR}/ccfe/ccfe.menu     (the previous test menu)
  - file      ${LIBDIR}/ccfe/it_works.txt  (this file)

  The demo menu will still be available running the command

    ${BINDIR}/ccfe demo

  but if you want to remove it, you have to delete the following directories:
    ${LIBDIR}/ccfe/demo.menu
    ${LIBDIR}/ccfe/demo.d

  CCFE demos uses /bin/sh as shell interpreter, and they assume that it is a
  Bourne compatible shell. If it is not like this, please change the CCFE shell
  in the ${ETCDIR}/ccfe.conf file.

  You can find documentation, samples and Licensing Information in the
  directory ${DOCDIR}.


  Enjoy!
EOT
}



install ()
{
  umask 0022
  if [ $update -eq 0 ]; then
    echo "Creating directories..."
    mkdir -p $ETCDIR
    mkdir -p $BINDIR
    mkdir -p $LIBDIR
    mkdir -p $LOGDIR
    mkdir -p $MSGDIR/C
    mkdir -p $MANDIR/man1
    mkdir -p $MANDIR/man5
    mkdir -p $DOCDIR
    mkdir -p $DOCDIR/samples
    chmod 1777 $LOGDIR
  fi
  
  echo "Copying program files..."
  sed -e "/^\$PREFIX = /d ; s/^\$ETCDIR = .*$/\$ETCDIR = '$exp_etcdir';/ ; s/^\$BINDIR = .*$/\$BINDIR = '$exp_bindir';/ ;s/^\$LIBDIR = .*$/\$LIBDIR = '$exp_libdir';/ ;s/^\$LOGDIR = .*$/\$LOGDIR = '$exp_logdir';/ ;s/^\$MSGDIR = .*$/\$MSGDIR = '$exp_msgdir';/ ;" ccfe.pl > $BINDIR/ccfe
  chmod 755 $BINDIR/ccfe

  if [ $update -eq 0 ]; then
    cp ccfe.conf $ETCDIR/
    cp msg/C/ccfe $MSGDIR/C/ccfe

    # Test main menu:
    mkdir -p $LIBDIR/ccfe
    cp ccfe.menu $LIBDIR/ccfe
    echo "Creating sample file $LIBDIR/ccfe/it_works.txt..."
    mk_welcome > $LIBDIR/ccfe/it_works.txt

    # Demos:
    cp -r demo.menu $LIBDIR/ccfe
    cp -r demo.d $LIBDIR/ccfe
    PATH=$BINDIR:$PATH
    export PATH
    cd ccfe-plugin-sysmon
    ./install.sh
    cd ..
  fi

  echo "Creating manpages..."
  for mp in ccfe.1 ccfe_form.5 ccfe_menu.5 ccfe_help.5 ccfe.conf.5
  do
    mk_manpage $mp
  done

  echo "Copying release documentation and samples..."
  cp README COPYING AUTHORS ChangeLog $DOCDIR/
  cp -rp ccfe-plugin-sysmon $DOCDIR/samples
  cp -p ccfe.conf.console $DOCDIR/samples

  if [ $update -eq 0 ]; then
    # Save subdirs for future uninstall option:
    echo "Saving install informations..."
    cat <<EOT > "$ETCDIR/$SAVED_INFO"
# Installed on $(date)
ETCDIR="$ETCDIR"
BINDIR="$BINDIR"
LIBDIR="$LIBDIR"
LOGDIR="$LOGDIR"
MSGDIR="$MSGDIR"
MANDIR="$MANDIR"
DOCDIR="$DOCDIR"
EOT
  fi
  echo "Done."
}



#################################### MAIN: ###################################

batch=0
update=0
mode='FRESH INSTALLATION'
while getopts p:c:l:e:o:m:d:a:u:hb a ; do
    case $a in
        p) PREFIX=$OPTARG
           # -p deve essere il primo se si vogliono specificare altri path,
           # senno' fa l'override.
	   ETCDIR="$PREFIX/etc"
	   BINDIR="$PREFIX/bin"
	   LIBDIR="$PREFIX/lib"
	   LOGDIR="$PREFIX/log"
	   MSGDIR="$PREFIX/msg"
	   MANDIR="$PREFIX/man"
	   DOCDIR="$PREFIX/doc"
           ;;
        c) ETCDIR=$OPTARG
           ;;
        l) LIBDIR=$OPTARG
           ;;
        e) BINDIR=$OPTARG
           ;;
        o) LOGDIR=$OPTARG
           ;;
        m) MSGDIR=$OPTARG
           ;;
        d) DOCDIR=$OPTARG
           ;;
        a) MANDIR=$OPTARG
           ;;
        b) batch=1
           ;;
        u) update=1
           mode='UPDATE'
	   prev_cnf="$OPTARG/$SAVED_INFO"
	   if [ -f "$prev_cnf" ]
	   then
	     echo "Using $prev_cnf"
	     . $prev_cnf
	   else
	     echo "ABORT: $prev_cnf not found."
             exit 1
	   fi
           ;;
        h) usage
           ;;
        *) usage
           ;;
    esac
done

if [ $batch -eq 0 ]
then
  keybuff=0
  while [ "$keybuff" != 'S' -a "$keybuff" != 's' -a "$keybuff" != 'Q' -a "$keybuff" != 'q' ]
  do
cat <<EOT


 ******************************************************************************
                   WELCOME TO CCFE INSTALLATION PROGRAM
 ******************************************************************************

EOT
    printf "  1. Change %-35s (%s)\n" "$PREFIX_DESCR" $PREFIX
    printf "  2. Change %-35s (%s)\n" "$ETCDIR_DESCR" $ETCDIR
    printf "  3. Change %-35s (%s)\n" "$BINDIR_DESCR" $BINDIR
    printf "  4. Change %-35s (%s)\n" "$LIBDIR_DESCR" $LIBDIR
    printf "  5. Change %-35s (%s)\n" "$LOGDIR_DESCR" $LOGDIR
    printf "  6. Change %-35s (%s)\n" "$MSGDIR_DESCR" $MSGDIR
    printf "  7. Change %-35s (%s)\n" "$MANDIR_DESCR" $MANDIR
    printf "  8. Change %-35s (%s)\n" "$DOCDIR_DESCR" $DOCDIR
    printf "\n  C. Change mode (Installation or Update)\n"
    printf "  S. START %s\n" "$mode"
    printf "  Q. Quit without install\n\n"
    input "Choice" Q
    case "$keybuff" in
      1) input "New $PREFIX_DESCR" $PREFIX
         PREFIX="$keybuff"
         ETCDIR="$PREFIX/etc"
         BINDIR="$PREFIX/bin"
         LIBDIR="$PREFIX/lib"
         LOGDIR="$PREFIX/log"
         MSGDIR="$PREFIX/msg"
         MANDIR="$PREFIX/man"
         DOCDIR="$PREFIX/doc"
         ;;
      2) input "New $ETCDIR_DESCR" $ETCDIR
         ETCDIR="$keybuff"
         ;;
      3) input "New $BINDIR_DESCR" $BINDIR
         BINDIR="$keybuff"
         ;;
      4) input "New $LIBDIR_DESCR" $LIBDIR
         LIBDIR="$keybuff"
         ;;
      5) input "New $LOGDIR_DESCR" $LOGDIR
         LOGDIR="$keybuff"
         ;;
      6) input "New $MSGDIR_DESCR" $MSGDIR
         MSGDIR="$keybuff"
         ;;
      7) input "New $MANDIR_DESCR" $MANDIR
         MANDIR="$keybuff"
         ;;
      8) input "New $DOCDIR_DESCR" $DOCDIR
         DOCDIR="$keybuff"
         ;;
      c|C) if [ $update -eq 0 ]
         then
           search_paths="/etc /usr/local /opt"
           input "Paths where search for CCFE configuration (\"none\" to skip)" "$search_paths"
           #echo "Paths where search for CCFE configuration"
           #input "(\"none\" to skip)" "$search_paths"
           #input "(\"none\" for don't search)" "$search_paths"
           search_paths="$keybuff"
           if [ "$search_paths" != "none" ]
           then
             prev_cnf=$(find $search_paths -type f -name ccfeinstall.conf -print 2> /dev/null | head -1)
             if [ -z "$prev_cnf" ]
             then
               echo "WARNING: configuration not found."
             else
               echo "Using $prev_cnf"
               . $prev_cnf
             fi
           fi
           update=1
           mode='UPDATE'
         else
           update=0
           mode='FRESH INSTALLATION'
         fi
         ;;
    esac
  done
fi

if [ \( "$keybuff" = 'S' -o "$keybuff" = 's' \) -o $batch -eq 1 ]
then
  exp_etcdir=$(echo $ETCDIR | sed -e 's/\//\\\//g')
  exp_bindir=$(echo $BINDIR | sed -e 's/\//\\\//g')
  exp_libdir=$(echo $LIBDIR | sed -e 's/\//\\\//g')
  exp_logdir=$(echo $LOGDIR | sed -e 's/\//\\\//g')
  exp_msgdir=$(echo $MSGDIR | sed -e 's/\//\\\//g')
  exp_docdir=$(echo $DOCDIR | sed -e 's/\//\\\//g')
  install
fi
