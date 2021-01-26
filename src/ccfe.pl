#!/usr/bin/env perl
#
#  CCFE - The Curses Command Front-end
#  Copyright (C) 2009, 2016 Massimo Loschi
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

require 5.8.0;

use Curses;
use Sys::Hostname;
use File::Basename;
use POSIX qw(:sys_wait_h);
use Getopt::Std;
use IPC::Open3;
use Symbol qw(gensym);
use IO::File;
use Term::ANSIColor;
use Text::Balanced qw(extract_bracketed);
use IO::Select;
use File::Temp qw(tempfile);
use Digest::MD5 qw(md5_hex);

$VERSION      = '1.58';
$VERSION_DATE = '04/09/2016';
$VERSION_YEAR = '2009, 2016';

$PREFIX = "/usr/local/ccfe";

$ETCDIR = "$PREFIX/etc";
$BINDIR = "$PREFIX/bin";
$LIBDIR = "$PREFIX/lib";
$LOGDIR = "$PREFIX/log";
$MSGDIR = "$PREFIX/msg";

$REALNAME        = 'ccfe';
$DESCR           = 'The Curses Command Front-end';
$CALLNAME        = basename($0);
$USERNAME        = ( getpwuid($>) )[0];
$HOSTNAME        = ( split /\./, hostname )[0];
$MENUEXT         = '.menu';
$FORMEXT         = '.form';
$DMENU_DEF_FNAME = 'definition';
$PRIV_DIR        = "$ENV{HOME}/.$REALNAME";
$PERS_DIR        = "$PRIV_DIR/persistent";

$NO  = $OFF = $FALSE = 0;
$YES = $ON  = $TRUE  = 1;

$DEBUG            = $NO;
$PERMIT_DEBUG     = $YES;
$MARK_PRIV_SHCUTS = $YES;

$MAIN_PATH = '/usr/bin:/bin:/usr/local/bin:/sbin:/usr/sbin';
$PATH      = "$ENV{HOME}/bin";

$LOG_FNAME        = "$LOGDIR/$USERNAME.log";
$LOG_DATE         = $NO;
$LOG_NORMAL       = 1;
$LOG_LIST_CMD     = 2;
$LOG_DEFAULT_CMD  = 4;
$LOG_ACTION_CMD   = 8;
$LOG_FIELDS_VAL   = 16;
$LOG_MENU_CHOICE  = 32;
$LOG_ACTION_OUT   = 64;
$LOG_SYSCALL_ENV  = 128;
$LOG_SCAN_PATHS   = 256;
$LOG_INITFORM_OUT = 512;
$LOG_LEVEL        = $LOG_NORMAL;
$LOG_REQUESTED    = $NO;

$LW_COLS        = 76;
$LW_ROW0        = 2;
$LW_PAD_COLS    = 160;
$LW_FOOTER_ROWS = 3;

$MSG_WIN_ROWS = 5;

$MS_HEADER_ROWS = 2;
$MS_TOP_ROWS    = 2;
$MS_BOTTOM_ROWS = 0;
$MS_FOOTER_ROWS = 2;

$FS_HEADER_ROWS = 2;
$FS_TOP_ROWS    = 3;
$FS_BOTTOM_ROWS = 0;
$FS_FOOTER_ROWS = 2;

$RS_HEADER_ROWS = 2;
$RS_TOP_ROWS    = 1;
$RS_BOTTOM_ROWS = 0;
$RS_FOOTER_ROWS = 2;

$ES_NO_ERR     = 0;
$ES_SYNTAX_ERR = 1;
$ES_FOPEN_ERR  = 2;
$ES_NOT_FOUND  = 3;
$ES_NO_ITEMS   = 4;
$ES_USER_REQ   = 253;
$ES_CANCEL     = 254;
$ES_EXIT       = 255;

$NUMERIC     = 1;
$BOOLEAN     = 2;
$NULLBOOLEAN = 6;
$STRING      = 8;
$UCSTRING    = 24;
$SEPARATOR   = 256;

$SEP_TEXT        = 1;
$SEP_TEXT_CENTER = 2;
$SEP_LINE        = 3;
$SEP_LINE_DOUBLE = 4;

$BOOLEAN_FIELD_SIZE = 3;
$BFIELD_YES         = 'YES';
$BFIELD_NO          = 'NO';
$BFIELD_NULL        = '';
$BFIELD_DEFAULT     = $BFIELD_NO;
$MIN_ITEMS_FOR_FIND = 5;

$INIT_REMOVE_FIELDS  = 'CCFE_REMOVE_FIELDS';
$INIT_ENABLE_FIELDS  = 'CCFE_ENABLE_FIELDS';
$INIT_DISABLE_FIELDS = 'CCFE_DISABLE_FIELDS';

$FORM_ARGV_ID = 'ARGV';

$ALL_FIELDS_IDS_TAG = '\*';
$FSEP_ID_PRFX       = 'CCFEFSEP';

$NORMAL      = 0;
$SIMPLE      = 1;
%layout_vals = (
    normal => $NORMAL,
    simple => $SIMPLE
);

$ASKS_WIN_ROWS     = 5;
$ASKS_WIN_COLS     = 78;
$ASKS_WIN_FTR_ROWS = 2;
$ASKS_FIELD_SIZE   = 40;

$SAVE_SIMPLE   = 'Simple';
$SAVE_DETAILED = 'Detailed';
$SAVE_SCRIPT   = 'Script';

$RS_INFO_ID   = 'C';
$RS_STDOUT_ID = 'O';
$RS_STDERR_ID = 'E';

$SR_BUFF_SIZE = 512;

@cnf_path = ("$ETCDIR/$REALNAME.conf");
@mf_path = ( "$LIBDIR/$CALLNAME", "$ENV{HOME}/.$REALNAME/$CALLNAME" );
if ( $CALLNAME ne $REALNAME ) {
    push @cnf_path, "$ETCDIR/$CALLNAME.conf";
}

%bool_vals = (
    yes => $YES,
    no  => $NO
);
%type_vals = (
    numeric     => $NUMERIC,
    boolean     => $BOOLEAN,
    nullboolean => $NULLBOOLEAN,
    string      => $STRING,
    ucstring    => $UCSTRING
);
%sep_type_vals = (
    text        => $SEP_TEXT,
    text_center => $SEP_TEXT_CENTER,
    line        => $SEP_LINE,
    line_double => $SEP_LINE_DOUBLE
);

@fn_key_functions =
  qw( back exit help list redraw reset_field save sel_items shell_escape show_action );

$SCREEN_DIR = '';

$HTAB_COLS     = 2;
$FIELD_LMARGIN = 2;
$FIELD_RMARGIN = 2;

$child_es     = 0;
$last_item_id = '';
$pad_lines    = 0;
undef $exec_args;
undef $cpid;
undef $tmpfh;

$SIG{INT} = sub {
    trace("SIGINT handler start - child PID $cpid");
    if ( defined($cpid) ) {
        trace(
            "PID $$ received SIGINT: waiting child (PID $cpid) to terminate..."
        );
        kill 15, $cpid;
        waitpid( $cpid, 0 );
        trace("PID $cpid terminated");
        my $msg = "PID $cpid execution interrupted by SIGINT!";
        undef $cpid;
        print $tmpfh "$RS_INFO_ID:\n";
        print $tmpfh "$RS_INFO_ID:$msg\n";
        $pad_lines += 2;
    }
    trace("SIGINT handler end");
};

sub REAPER {
    my $child;
    while ( ( $child = waitpid( -1, WNOHANG ) ) > 0 ) {
        $child_es = $? >> 8;
    }
    $SIG{CHLD} = \&REAPER;
}
$SIG{CHLD} = \&REAPER;

sub fatal {
    trace("FATAL: @_");
    clrtobot( 0, 0 );
    addstr( 0, 0, "@_\n" );
    refresh();
    sleep 2;
    endwin();
    exit 1;
}

sub usage {
    my $layouts = lc join( '|', keys(%layout_vals) );
    print << "EOF";

$DESCR.

  Usage: $CALLNAME [OPTION]... [SHORTCUT]

  Options:
    -c      : print some Configuration parameters and exit
    -d      : set verbose log for Debugging purposes
    -h      : print this (Help) message and exit
    -l PATH : set forms and menus Library directory to PATH
    -s      : print available Shortcuts and exit
    -v      : print Version informations and exit

  SHORTCUT: initial form or menu name (without extension)

EOF
    exit;
}

sub print_config {
    print << "EOF";
ETC_DIR=$ETCDIR
LIB_DIR=$LIBDIR
MSG_DIR=$MSGDIR
EOF
    exit;
}

sub trim {
    my ($string) = @_;
    for ($$string) {
        s/^\s+//;
        s/\s+$//;
    }
}

sub ralign {
    my ( $str, $size ) = @_;
    return eval "sprintf \"% ${size}s\",\"$str\"";
}

sub valid_shell {
    my ($shell) = @_;

    my $shells = '/etc/shells';
    my $found  = $NO;
    open( SHELLS, $shells ) || die("Error opening $shells:\n$!");
    while (<SHELLS>) {
        chop;
        $found = $YES if /^$shell$/;
    }
    close(SHELLS);
    return $found;
}

sub trace {
    my ( $msg, $log_level ) = @_;
    my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my @buff   = localtime(time);
    my $now    = '';
    my $log_it = $NO;
    my ( $caller, $prev_umask );

    if ($DEBUG) {
        $caller = ( caller(1) )[3];
        $caller =~ s/^.*:://;
        $caller .= "[$$]: " if $caller;
    }

    if ($LOG_FNAME) {
        if ( $LOG_LEVEL & $log_level ) {
            $log_it = $YES;
            if ( $LOG_NORMAL & $log_level ) {
                $log_it = $NO if !$LOG_REQUESTED;
            }
        }
        $log_it = $YES if $DEBUG;

        if ($log_it) {
            $prev_umask = umask 0177;
            eval {
                open( LOG, ">>$LOG_FNAME" ) or die("$!\n");
                if ($LOG_DATE) {
                    $now = sprintf "%s %02d %d %02d:%02d:%02d%s",
                      $months[ $buff[4] ],
                      $buff[3], $buff[5] + 1900, $buff[2], $buff[1], $buff[0],
                      $DEBUG ? ' ' : "\n";
                }
                printf LOG "%s%s%s\n", $now, $caller, $msg or die("$!");
                close(LOG) or die("$!");
            };
            umask $prev_umask;
        }
    }
}

sub get_lang_id {
    my $lang_id = 'C';

    return $lang_id;
}

sub load_msgs {
    my $id;
    my $fname = "$MSGDIR/$LANG_ID/$CALLNAME";

    my @msg_id = qw(NULL_LIST_MSG
      NULL_LIST_TITLE
      NULL_FACTION_MSG
      NULL_FACTION_TITLE
      SAVE_FIELDVAL_MSG
      SAVE_FIELDVAL_TITLE
      BIG_OUTPUT_MSG
      BIG_OUTPUT_TITLE
      FOUND_NONE_MSG
      FOUND_NONE_TITLE
      SEARCH_PTRN_PROMPT
      SEARCH_PTRN_TITLE
      CALL_SYS_ES_MSG
      CALL_SYS_MSG
      MSG_WIN_BMSG
      MSG_WIN_TITLE
      BFIELD_YES_DESCR
      BFIELD_NO_DESCR
      BFIELD_NULL_DESCR
      CONFIRM_TITLE
      CONFIRM_DESCR_NO
      CONFIRM_DESCR_YES
      SHOW_ACTION_TITLE
      KEY_F1_LABEL
      KEY_F2_LABEL
      KEY_F3_LABEL
      KEY_F4_LABEL
      KEY_F5_LABEL
      KEY_F6_LABEL
      KEY_F7_LABEL
      KEY_F8_LABEL
      KEY_F9_LABEL
      KEY_F10_LABEL
      KEY_F11_LABEL
      KEY_F12_LABEL
      KEY_ENTER_LABEL
      KEY_INTR_LABEL
      KEY_FIND_LABEL
      KEY_FNEXT_LABEL
      KEY_SELALL_LABEL
      KEY_UNSELALL_LABEL
      CALL_SHELL_MSG
      WAIT_MSG_MSG
      FORM_ERR_TITLE
      LOAD_FORM_ERR_MSG
      INIT_FORM_ERR_MSG
      MENU_ERR_TITLE
      LOAD_MENU_ERR_MSG
      RB_TITLE
      RB_RUNNING_MSG
      RB_OK_MSG
      RB_FAILED_MSG
      RB_LINES_MSG
      RB_TIME_MSG
      SAVE_TYPE_TITLE
      SAVE_SIMPLE_DESCR
      SAVE_DETAILED_DESCR
      SAVE_SCRIPT_DESCR
      SAVE_FNAME_PROMPT
      SAVE_FNAME_TITLE
      SAVE_ERROR_MSG
      SAVE_ERROR_TITLE
      LOG_WRITE_ERROR_MSG
      LOG_WRITE_ERROR_TITLE
      PERS_WRITE_ERROR_TITLE
      PERS_WRITE_ERROR_MSG
      ERR_LITTLE_SCREEN[0]
      ERR_LITTLE_SCREEN[1]
      ERR_WRONG_FPATH[0]
      ERR_WRONG_FPATH[1]
      ERR_LOAD_INITIAL_OBJ
      ES_NO_ERR_MSG
      ES_SYNTAX_ERR_MSG
      ES_FOPEN_ERR_MSG
      ES_NOT_FOUND_MSG
      ES_NO_ITEMS_MSG
      LW_MULTIVAL_TOP_MSG[0]
      LW_MULTIVAL_TOP_MSG[1]
      LW_MULTIVAL_TOP_MSG[2]
      LW_SINGLEVAL_TOP_MSG[0]
      LW_SINGLEVAL_TOP_MSG[1]
      LW_SINGLEVAL_TOP_MSG[2]
      LW_DISPLAY_TOP_MSG[0]
      LW_DISPLAY_TOP_MSG[1]
      LW_DISPLAY_TOP_MSG[2]
      FORM_TOP_MSG[0]
      FORM_TOP_MSG[1]
      MENU_TOP_MSG[0]
      MENU_TOP_MSG[1]
      ERR_EMPTY_FIELD_MSG
      ERR_EMPTY_FIELD_TITLE
      BAD_SHELL_MSG
      BAD_SHELL_TITLE);

    foreach $id (@msg_id) {
        eval "\$$id = \"ERROR_OR_UNDEFINED_MSG:$id\"";
    }

    open( INF, $fname ) or die("$CALLNAME: Error opening file $fname\n");
    while (<INF>) {
        chop;
        next if /^\s*#/;
        next if /^$/;
        s/\s*#.*$//;
        s/^\s*([\w\[\]]+)\s*=\s*(.+)?/\$\U$1\E=$2/;
        $id = uc($1);
        ($id) = (/^\s*(\S+)\s*=/) if !$id;
        if ( in( $id, @msg_id ) ) {
            eval;
        }
        else {
            trace("unknown message ID '$id'");
        }
        while ( !$LW_MULTIVAL_TOP_MSG[$#LW_MULTIVAL_TOP_MSG] ) {
            pop(@LW_MULTIVAL_TOP_MSG);
        }
        while ( !$LW_SINGLEVAL_TOP_MSG[$#LW_SINGLEVAL_TOP_MSG] ) {
            pop(@LW_SINGLEVAL_TOP_MSG);
        }
        while ( !$LW_DISPLAY_TOP_MSG[$#LW_DISPLAY_TOP_MSG] ) {
            pop(@LW_DISPLAY_TOP_MSG);
        }
        $CONFIRM_ITEMS[0] = "$BFIELD_NO $CONFIRM_DESCR_NO";
        $CONFIRM_ITEMS[1] = "$BFIELD_YES $CONFIRM_DESCR_YES";
    }
    close(INF);
}

sub exec_command {
    my ( $cmd, $extra_path, $stdout_ref, $stderr_ref ) = @_;

    my ( $prev_path, $prev_wdir );

    chomp( $prev_wdir = `pwd` );
    chdir "$SCREEN_DIR";
    trace( "Changed CWD from $prev_wdir to " . substr( `pwd`, 0, -1 ) );
    $prev_path = $ENV{PATH};
    $ENV{PATH} = sprintf "%s%s:%s", $MAIN_PATH, $MAIN_PATH ? ":$PATH" : '',
      $SCREEN_DIR;
    if ($extra_path) {
        my @dirs = split /:/, $extra_path;
        foreach $i ( 0 .. $#dirs ) {
            $dirs[$i] = "$SCREEN_DIR/$dirs[$i]" unless $dirs[$i] =~ /^\//;
        }
        $extra_path = join( ':', @dirs );
    }
    $ENV{PATH} .= ":$extra_path" if $extra_path;
    trace( "PATH=\"$ENV{PATH}\"", $LOG_SYSCALL_ENV );

    trace("executing \"$cmd\"");
    @$stdout_ref = ();
    @$stderr_ref = ();
    local *CATCHERR = IO::File->new_tmpfile;
    my $pid =
      open3( gensym, \*CATCHOUT, ">&CATCHERR", $OPEN3_SHELL, '-c', $cmd );
    while (<CATCHOUT>) {
        push @$stdout_ref, $_;
    }
    waitpid( $pid, 0 );
    seek CATCHERR, 0, 0;
    while (<CATCHERR>) {
        push @$stderr_ref, $_;
    }
    $ENV{PATH} = $prev_path;
    chdir "$prev_wdir";
    trace( "Restored CWD to " . substr( `pwd`, 0, -1 ) );
    @$stdout_ref = map { s/\n//; $_ } @$stdout_ref;
    @$stderr_ref = map { s/\n//; $_ } @$stderr_ref;
    @$stdout_ref = map { s/\r//; $_ } @$stdout_ref;
    @$stderr_ref = map { s/\r//; $_ } @$stderr_ref;

    close(CATCHOUT);
    close(CATCHERR);
    return (@$stderr_ref) ? $FALSE : $TRUE;
}

sub init_title {
    my ( $win, $winRows, $title ) = @_;

    $title =~ s/^\s+//;
    $title =~ s/\s+$//;
    addstr( $win, 0, 0, $USERNAME . '@' . $HOSTNAME ) if ( $LAYOUT == $NORMAL );
    attron( $win, A_BOLD ) if ( $LAYOUT == $NORMAL );
    addstr( $win, 0, int( ( $COLS - length($title) ) / 2 ), $title );
    attroff( $win, A_BOLD ) if ( $LAYOUT == $NORMAL );
    hline( $win, $winRows - 1, 0, ACS_HLINE, $COLS ) if ( $LAYOUT == $NORMAL );
}

sub init_top {
    my ( $win, $has_border, $winY0, $winRows, @tlines ) = @_;
    my ( $maxLen, $i, $tlmargin, $maxY, $maxX );

    getmaxyx( $win, $maxY, $maxX );
    $maxLen = 0;
    foreach $i ( 0 .. $#tlines ) {
        $maxLen = length( $tlines[$i] ) if length( $tlines[$i] ) > $maxLen;
    }
    if ( $LAYOUT == $SIMPLE ) {
        $tlmargin = $has_border ? 2 : 0;
    }
    else {
        $tlmargin = int( ( $maxX - $maxLen ) / 2 ) + ( $has_border ? 1 : 0 );
    }

    foreach $i ( 0 .. $winRows - 1 ) {
        last if $i > $#tlines;
        addstr( $win, $winY0 + $i, $tlmargin, $tlines[$i] );
    }
}

sub init_footer {
    my ( $win, $has_border, $nRows, @keysList ) = @_;
    my ( $nOptPerRow, $labelSize, $labelLen, $y, $x, $y0, $x0, $i, $maxY,
        $maxX );

    sub sort_fnkeys {
        my ($klist_ref) = @_;

        my @sorted = sort {
            if ( $keys{$a}{key} !~ /F[0-9]+/ )
            {
                return 0;
            }
            elsif ( $keys{$b}{key} !~ /F[0-9]+/ ) {
                return 0;
            }
            else {
                return
                  substr( $keys{$a}{key}, 1 ) <=> substr( $keys{$b}{key}, 1 );
            }
        } @$klist_ref;
        @$klist_ref = @sorted;
    }

    getmaxyx( $win, $maxY, $maxX );
    $y0 = $maxY - $nRows - ( $has_border ? 1 : 0 );
    $x0 = $has_border ? 1 : 0;
    $i = 0;
    while ( $i <= $#keysList ) {
        if ( !$keys{ $keysList[$i] }{label} or !$keys{ $keysList[$i] }{key} ) {
            splice( @keysList, $i, 1 );
        }
        else {
            $i++;
        }
    }
    sort_fnkeys( \@keysList );
    if ( $nRows > 1 ) {
        $nOptPerRow = int( ( scalar @keysList / ( $nRows - 1 ) ) + .5 );
    }
    else {
        $nOptPerRow = scalar @keysList;
    }
    $labelSize = int( ( $maxX + 1 ) / $nOptPerRow );

    hline( $win, $y0, $x0, ACS_HLINE, $maxX - ( $has_border ? 2 : 0 ) )
      if ( $LAYOUT == $NORMAL );
    if ( $LAYOUT == $NORMAL and $has_border ) {
        addch( $win, $y0, $x0 - 1,   ACS_LTEE );
        addch( $win, $y0, $maxX - 1, ACS_RTEE );
    }
    $x = 0;
    $y = $y0++;

    foreach $i ( 1 .. $nRows - 1 ) {
        addstr(
            $win, $y + $i,
            $has_border ? 1 : 0,
            ' ' x ( $maxX - ( $has_border ? 2 : 0 ) )
        );
    }

    foreach $i ( 0 .. $#keysList ) {
        if ( $i % ($nOptPerRow) == 0 ) {
            $y++;
            $x = $x0;
        }
        addstr( $win, $y, $x, "$keys{$keysList[$i]}{key}" );
        addstr( $win, "$keys{$keysList[$i]}{label}" );
        if ( $LAYOUT == $NORMAL ) {
            if ( getbkgd($win) & A_REVERSE ) {
                chgat( $win, $y, $x, length( $keys{ $keysList[$i] }{key} ),
                    A_NORMAL, NULL, NULL );
            }
            else {
                chgat( $win, $y, $x, length( $keys{ $keysList[$i] }{key} ),
                    A_REVERSE, NULL, NULL );
            }
        }
        $x += $labelSize;
    }
}

sub call_shell {
    my ( $prompt, $prev_cwd );

    chomp( $prev_cwd = 'pwd' );
    chdir $ENV{HOME};
    $prompt = sprintf( "%s%s ", $CALLNAME, $> ? '$' : '#' );
    def_prog_mode();
    endwin();
    system("clear");
    print "$CALLNAME: $CALL_SHELL_MSG\n\n";
    system("PS1=\"$prompt\" $USER_SHELL");
    reset_prog_mode();
    chdir $prev_cwd;
}

sub call_system {
    my ( $wait_key, $cmd ) = @_;

    my ($res);
    def_prog_mode();
    endwin();
    my $prev_path = $ENV{PATH};
    $ENV{PATH} = sprintf "%s%s", $MAIN_PATH, $MAIN_PATH ? ":$PATH" : '';
    system("clear");
    trace("run \"$cmd\"");
    $res = system($cmd);
    $res = ( $res >> 8 );
    trace("command exited with status $res");

    if ( $wait_key or $res != 0 ) {
        local $SIG{INT} = 'IGNORE';
        print color 'reverse';
        print "$CALLNAME: $CALL_SYS_ES_MSG $res - " if $res;
        print $CALL_SYS_MSG;
        print color 'reset';
        system "stty", '-icanon', 'eol', "\001";
        getc(STDIN);
        system "stty", 'icanon', 'eol', '^@';
    }
    $ENV{PATH} = $prev_path;
    reset_prog_mode();
}

sub disp_msg {
    my ( $pwin, $msg, $title ) = @_;
    my ( $panel, $win, $ch, $width );

    my $win_bg_attr = $LAYOUT == $SIMPLE ? A_NORMAL : A_REVERSE;
    my $bottom_attr = A_NORMAL;

    $msg = substr( $msg, 0, $COLS - 4 ) if length($msg) > $COLS - 4;
    $width = length($msg);
    if ( length($MSG_WIN_BMSG) > $width ) {
        $width = length($MSG_WIN_BMSG);
    }
    $win = newwin(
        $MSG_WIN_ROWS, $width + 4,
        int( ( $LINES - $MSG_WIN_ROWS ) / 2 ),
        int( ( $COLS - $width ) / 2 ) - 1
    );
    bkgd( $win, $win_bg_attr );
    box( $win, 0, 0 );
    keypad( $win, $ON );
    $panel = new_panel($win);
    $title = $MSG_WIN_TITLE unless $title;
    if ($title) {
        $title = " $title ";
        addstr( $win, 0, 2 + int( ( $width - length($title) ) / 2 ), $title );
    }
    addstr( $win, 1, 2 + int( ( $width - length($msg) ) / 2 ), $msg );
    addstr( $win, 3, 2 + int( ( $width - length($MSG_WIN_BMSG) ) / 2 ),
        $MSG_WIN_BMSG );
    chgat( $win, 3, 1, $width + 2, $bottom_attr, NULL, NULL );
    refresh($win);
    $ch = getch($win);
    del_panel($panel);
    delwin($win);
    refresh($pwin);
    return $ch;
}

sub open_wait_msg {
    my ($title) = @_;
    my ( $panel, $win,         $ch, $width );
    my ( $msg,   $win_bg_attr, $y0, $msg_x0 );

    $msg = $WAIT_MSG_MSG;
    if ( $LAYOUT == $SIMPLE ) {
        $width       = 62;
        $win_bg_attr = A_NORMAL;
        $y0          = $LINES - 3;
        $msg_x0      = 2;
    }
    else {
        $width       = length($msg);
        $win_bg_attr = A_REVERSE;
        $y0          = int( ( $LINES - 3 ) / 2 );
        $msg_x0      = 2 + int( ( $width - length($msg) ) / 2 );
    }

    $win = newwin( 3, $width + 4, $y0, int( ( $COLS - $width ) / 2 ) );
    bkgd( $win, $win_bg_attr );
    box( $win, 0, 0 );
    $panel = new_panel($win);
    $title = $MSG_WIN_TITLE unless $title;
    if ($title) {
        $title = " $title ";
        addstr( $win, 0, 2 + int( ( $width - length($title) ) / 2 ), $title );
    }
    addstr( $win, 1, $msg_x0, $msg );
    refresh($win);
    return ( $panel, $win );
}

sub close_wait_msg {
    my ( $panel, $win, $parent_win ) = @_;

    del_panel($panel);
    delwin($win);
    refresh($parent_win);
}

sub ask_string {
    my ( $title, $prompt, $default ) = @_;
    my ( $panel, $win, $ch, $width, $height );
    my ( $field, $cform, $x0, $y0, $swin, $es, $strbuff );
    my @fp;
    my @fset;

    my $win_bg_attr = $LAYOUT == $SIMPLE ? A_NORMAL : A_REVERSE;
    my $lmargin     = 1;
    my $prompt_x    = $FIELD_LMARGIN;
    my $prompt_y    = 0;
    my $field_x     = $FIELD_LMARGIN + length($prompt) + 1;
    my $field_y     = 0;

    $prompt = substr( $prompt, 0, $COLS - 4 ) if length($prompt) > $COLS - 4;
    $width  = $ASKS_WIN_COLS;
    $height = $ASKS_WIN_ROWS;
    $x0     = int( ( $COLS - $width ) / 2 );
    $y0     = int( ( $LINES - $height ) / 2 );
    if ( $LAYOUT == $SIMPLE ) {
        $height   = 10;
        $y0       = $LINES - $height;
        $prompt_x = 1;
        $prompt_y = 2;
        $field_x  = 1;
        $field_y  = 4;
    }
    $win = newwin( $height, $width, $y0, $x0 );
    bkgd( $win, $win_bg_attr );
    $swin = derwin( $win, $height - 2 - $ASKS_WIN_FTR_ROWS, $width - 2, 1, 1 );
    box( $win, 0, 0 );
    $panel = new_panel($win);
    if ($title) {
        $title = " $title ";
        addstr( $win, 0, 1 + int( ( $width - length($title) ) / 2 ), $title );
    }
    init_footer( $win, $YES, $ASKS_WIN_FTR_ROWS, qw( help back exit ) );

    $field = new_field( 1, length($prompt), $prompt_y, $prompt_x, 0, 0 );
    if ( $field eq '' ) { fatal("ask_string().new_field.prompt failed") }
    set_field_buffer( $field, 0, $prompt );
    set_field_back( $field, $win_bg_attr );
    field_opts_off( $field, O_ACTIVE );
    field_opts_off( $field, O_EDIT );
    push @fp,   $field;
    push @fset, ${$field};

    $field = new_field( 1, $ASKS_FIELD_SIZE, $field_y, $field_x, 0, 0 );
    if ( $field eq '' ) {
        fatal("ask_string().new_field.value failed");
    }
    set_field_pad( $field, $ASKS_FIELD_PAD );
    set_field_buffer( $field, 0, $default ) if $default;
    set_field_back( $field, $valueBg );
    field_opts_on( $field, O_BLANK );
    field_opts_off( $field, O_AUTOSKIP );
    push @fp,   $field;
    push @fset, ${$field};

    push @fset, 0;
    $cform = new_form( pack 'L!*', @fset );
    if ( $cform eq '' ) { fatal("ask_string.new_form() failed") }
    set_form_win( $cform, $win );
    set_form_sub( $cform, $swin );
    keypad( $win, $ON );
    post_form($cform);
    if ($ovl_mode) {
        form_driver( $cform, REQ_OVL_MODE );
    }
    else {
        form_driver( $cform, REQ_INS_MODE );
    }
    form_driver( $cform, REQ_END_LINE );

    curs_set($ON) if $HIDE_CURSOR;
    while (1) {
        $ch = getch($win);
        if ( $ch == KEY_LEFT ) {
            form_driver( $cform, REQ_LEFT_CHAR );
        }
        elsif ( $ch == KEY_RIGHT ) {
            form_driver( $cform, REQ_RIGHT_CHAR );
        }
        elsif ( $ch == KEY_UP or $ch == KEY_DOWN ) {
        }
        elsif ( $ch == KEY_HOME ) {
            form_driver( $cform, REQ_BEG_FIELD );
        }
        elsif ( $ch == KEY_END ) {
            form_driver( $cform, REQ_END_FIELD );
        }
        elsif ( $ch == KEY_DC ) {
            form_driver( $cform, REQ_DEL_CHAR );
        }
        elsif ( ord($ch) == 8 or ord($ch) == 127 ) {
            form_driver( $cform, REQ_DEL_PREV );
        }
        elsif ( $ch == KEY_IC ) {
            if ($ovl_mode) {
                $ovl_mode = $FALSE;
                form_driver( $cform, REQ_INS_MODE );
            }
            else {
                $ovl_mode = $TRUE;
                form_driver( $cform, REQ_OVL_MODE );
            }
        }
        elsif ( $ch == KEY_BACKSPACE ) {
            form_driver( $cform, REQ_DEL_PREV );
        }
        elsif ( $ch == $keys{back}{code} or ord($ch) == 27 ) {
            $es = $ES_CANCEL;
            last;
        }
        elsif ( $ch == $keys{exit}{code} ) {
            $es = $ES_EXIT;
            last;
        }
        elsif ( $ch >= KEY_F(1) and $ch <= KEY_F(12) ) {
            beep();
        }
        elsif ( $ch eq "\r" or $ch eq "\n" ) {
            form_driver( $cform, REQ_VALIDATION );
            last;
        }
        elsif ( $ch =~ /[[:ascii:]]/ ) {
            form_driver( $cform, ord($ch) );
        }
        else {
            beep();
        }
    }
    unpost_form($cform);
    del_panel($panel);
    delwin($win);
    free_form($cform);
    $strbuff = field_buffer( $fp[1], 0 );
    $strbuff =~ s/\s+$//;
    map { free_field($_) } @fp;
    @fp   = ();
    @fset = ();
    curs_set($OFF) if $HIDE_CURSOR;
    return ( $es, $strbuff );
}

sub disp_page {
    my ( $win, $n, $tot, $caller, $screen_name ) = @_;

    my ( $saveY, $saveX, $buff, $pos, $obj, $ovl_flag );

    getyx( $win, $saveY, $saveX );
    $n = "0$n" if ( $tot > 9  and $n < 10 );
    $n = "0$n" if ( $tot > 99 and $n < 10 );
    if ( $caller eq 'browser' or $caller eq 'form' ) {
        $obj = 'Pg';
    }
    else {
        $obj = 'Op';
    }
    if ( $caller eq 'form' ) {
        $ovl_flag = $ovl_mode ? 'Ovl' : 'Ins';
    }
    else {
        $ovl_flag = '';
    }
    $pos         = "$obj:$n/$tot";
    $screen_name = basename($screen_name) if $screen_name;
    $buff        = sprintf( "%s %3s %s",
        $SHOW_SCREEN_NAME ? $screen_name : '',
        $ovl_flag, $pos );
    addstr( $win, 0, $COLS - length($buff), $buff );
    chgat( $win, 0, $COLS - length($pos) - 4, 3, A_REVERSE, NULL, NULL )
      if $ovl_flag and $LAYOUT == $NORMAL;
    move( $win, $saveY, $saveX );
}

sub load_menu {
    my ($name) = @_;

    my ( $key, $val, $text, $found, $ic, $res );
    my @lines;

    $found = $NO;
    for my $dir (@mf_path) {
        my $fname = "$dir/$name$MENUEXT";
        trace( "looking for $fname", $LOG_SCAN_PATHS );
        if ( -e $fname ) {
            $found = $YES;
            if ( -d $fname ) {
                trace("load dynamic menu $fname");
                @flist = glob("$fname/$DMENU_DEF_FNAME $fname/*.item");
            }
            else {
                trace("load static menu $fname");
                @flist = ($fname);
            }
            %menu = ();
            undef %menu;
            $res = $ES_NO_ERR;

            foreach my $fname (@flist) {
                if ( open( INF, $fname ) ) {
                    push @lines, $_ while (<INF>);
                    close(INF);
                }
                elsif ( $fname !~ /$DMENU_DEF_FNAME$/ ) {
                    $res = $ES_FOPEN_ERR;
                }
            }

            $ic = 0;
            if ( $res == $ES_NO_ERR ) {
                for ( my $i = 0 ; $i <= $#lines ; $i++ ) {
                    splice @lines, $i--, 1 if $lines[$i] =~ /^\s*#/;
                }
                $text = join( '', @lines );

                ( $val, undef, $key ) =
                  extract_bracketed( $text, '{', '\s*[a-zA-Z]+\s*' );
                while ($key) {
                    $val =~ s/^\{\s*//;
                    $val =~ s/\s*\n?\s*\}$//;
                    $key =~ s/^\s+//;
                    $key =~ s/\s+$//;
                  SWITCH: {
                        $_ = lc $key;
                        if (/^title$/) {
                            $menu{title} = $val;
                            last SWITCH;
                        }
                        elsif (/^top$/) {
                            @{ $menu{top} } = split /\s*\n\s*/, $val, 2;
                            last SWITCH;
                        }
                        elsif (/^path$/) {
                            $menu{path} = $val;
                            last SWITCH;
                        }
                        elsif (/^item$/) {
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s, 2;
                              ASWITCH: {
                                    $_ = lc $attrk;
                                    if (/^id$/) {
                                        for $i ( 0 .. $ic - 1 ) {
                                            if (
                                                $menu{items}[$i]{id} eq $attrv )
                                            {
                                                trace(
"WARNING: duplicated item ID \"$attrv\""
                                                );
                                            }
                                        }
                                        $menu{items}[$ic]{id} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^descr$/) {
                                        $menu{items}[$ic]{descr} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^action$/) {
                                        $menu{items}[$ic]{action} = $attrv;
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
                                            "unknown item attribute \"$attrk\""
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            $ic++;
                            last SWITCH;
                        }
                        elsif (/^bottom$/) {
                            @{ $menu{bottom} } = split /\s*\n\s*/, $val, 2;
                            last SWITCH;
                        }
                        else {
                            trace("unknown menu attribute \"$key\"");
                            $res = $ES_SYNTAX_ERR;
                        }
                    }
                    ( $val, undef, $key ) =
                      extract_bracketed( $text, '{', '\s*[a-zA-Z]+\s*' );
                }
                $res = $ES_SYNTAX_ERR if !pos($text);
                if ( $res == $ES_NO_ERR ) {
                    @{ $menu{top} } = @MENU_TOP_MSG unless @{ $menu{top} };
                    $SCREEN_DIR = $dir;
                    $$path      = $dir;
                }
            }
            else {
                trace("error opening $fname: $!");
                $res = $ES_FOPEN_ERR;
            }
            trace("found $ic menu item(s)");
            $res = $ES_NO_ITEMS if $ic < 1;
            last;
        }
    }
    unless ($found) {
        trace("menu \"$name\" NOT FOUND!");
        $res = $ES_NOT_FOUND;
    }
    return $res;
}

sub load_form {
    my ( $name, $path ) = @_;

    my ( $key, $val, $found, $text, $fc, $sc, $res );
    my @lines;

    $found = $NO;
    for my $dir (@mf_path) {
        my $fname = "$dir/$name$FORMEXT";
        trace( "looking for $fname", $LOG_SCAN_PATHS );
        if ( -f $fname ) {
            $found = $YES;
            trace("load $fname");
            %form = ();
            undef %form;
            $res = $ES_NO_ERR;
            if ( open( INF, $fname ) ) {
                while (<INF>) {
                    next if /^\s*#/;
                    push @lines, $_;
                }
                close(INF);
                $text = join( '', @lines );

                $sc = 0;
                $fc = 0;
                ( $val, undef, $key ) =
                  extract_bracketed( $text, '{', '\s*[a-zA-Z]*\s*' );
                while ($key) {
                    $val =~ s/^\{\s*//;
                    $val =~ s/\s*\n?\s*\}$//;
                    $key =~ s/^\s+//;
                    $key =~ s/\s+$//;
                  SWITCH: {
                        $_ = lc $key;
                        if (/^title$/) {
                            $form{title} = $val;
                            last SWITCH;
                        }
                        elsif (/^top$/) {
                            @{ $form{top} } = split /\s*\n\s*/, $val, 2;
                            last SWITCH;
                        }
                        elsif (/^path$/) {
                            $form{path} = $val;
                            last SWITCH;
                        }
                        elsif (/^field$/) {
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s, 2;
                              ASWITCH: {
                                    $_ = lc $attrk;
                                    if (/^id$/) {
                                        for $i ( 0 .. $fc - 1 ) {
                                            if ( $form{fields}[$i]{id} eq
                                                $attrv )
                                            {
                                                trace(
"WARNING: duplicated field ID \"$attrv\""
                                                );
                                            }
                                        }
                                        $form{fields}[$fc]{id} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^label$/) {
                                        $form{fields}[$fc]{label} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^len$/) {
                                        $form{fields}[$fc]{len} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^hscroll$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $form{fields}[$fc]{hscroll} =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^enabled$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $form{fields}[$fc]{enabled} =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^hidden$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $form{fields}[$fc]{hidden} =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^required$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $form{fields}[$fc]{required} =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^persist$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $form{fields}[$fc]{persist} =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^ignore_unchgd$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $form{fields}[$fc]{ignore_unchgd} =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^htab$/) {
                                        $form{fields}[$fc]{htab} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^vtab$/) {
                                        $form{fields}[$fc]{vtab} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^option$/) {
                                        $form{fields}[$fc]{option} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^type$/) {
                                        if (
                                            defined( $type_vals{ lc($attrv) } )
                                          )
                                        {
                                            $form{fields}[$fc]{type} =
                                              $type_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"unknown field type \"$attrv\" of key \"$key\""
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^default$/) {
                                        $form{fields}[$fc]{default} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^list_cmd$/) {
                                        $form{fields}[$fc]{list_cmd} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^list_sep$/) {
                                        if ( $attrv =~ /"([ ,;:])"/ ) {
                                            $form{fields}[$fc]{list_sep} = $1;
                                        }
                                        else {
                                            trace(
"syntax error \"$attrv\" in \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
                                            "unknown field attribute \"$attrk\""
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            $fc++;
                            last SWITCH;
                        }
                        elsif (/^separator$/) {
                            my $line_width =
                              $COLS - $FIELD_LMARGIN - $FIELD_RMARGIN;
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s, 2;
                              ASWITCH: {
                                    $_ = lc $attrk;
                                    if (/^id$/) {
                                        for $i ( 0 .. $fc - 1 ) {
                                            if ( $form{fields}[$i]{id} eq
                                                $attrv )
                                            {
                                                trace(
"WARNING: duplicated field ID in separator \"$attrv\""
                                                );
                                            }
                                        }
                                        $form{fields}[$fc]{id} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^type$/) {
                                        if (
                                            defined(
                                                $sep_type_vals{ lc($attrv) }
                                            )
                                          )
                                        {
                                            $form{fields}[$fc]{sep_type} =
                                              $sep_type_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"unknown separator type \"$attrv\" of key \"$key\""
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^text$/) {
                                        $form{fields}[$fc]{label} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^htab$/) {
                                        $form{fields}[$fc]{htab} = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^vtab$/) {
                                        $form{fields}[$fc]{vtab} = $attrv;
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
"unknown separator attribute \"$attrk\""
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            $form{fields}[$fc]{type}          = $SEPARATOR;
                            $form{fields}[$fc]{len}           = 1;
                            $form{fields}[$fc]{enabled}       = $NO;
                            $form{fields}[$fc]{required}      = $NO;
                            $form{fields}[$fc]{persist}       = $NO;
                            $form{fields}[$fc]{hidden}        = $NO;
                            $form{fields}[$fc]{hscroll}       = $NO;
                            $form{fields}[$fc]{ignore_unchgd} = $NO;
                            $form{fields}[$fc]{option}        = '';
                            $form{fields}[$fc]{default}       = '';
                            $form{fields}[$fc]{list_cmd}      = '';

                            unless ( $form{fields}[$fc]{id} ) {
                                $form{fields}[$fc]{id} =
                                  sprintf( "CCFEFSEP%03d", ++$sc );
                            }
                            if ( $form{fields}[$fc]{sep_type} ==
                                $SEP_TEXT_CENTER )
                            {
                                my $lblanks =
                                  ( $line_width -
                                      length( $form{fields}[$fc]{label} ) ) / 2;
                                $form{fields}[$fc]{label} = sprintf( "%s%s",
                                    ' ' x ($lblanks),
                                    $form{fields}[$fc]{label} );
                            }
                            if ( $form{fields}[$fc]{sep_type} == $SEP_LINE ) {
                                $form{fields}[$fc]{label} =
                                  sprintf( "%s", '-' x ${line_width} );
                            }
                            if ( $form{fields}[$fc]{sep_type} ==
                                $SEP_LINE_DOUBLE )
                            {
                                $form{fields}[$fc]{label} =
                                  sprintf( "%s", '=' x ${line_width} );
                            }
                            $fc++;
                            last SWITCH;
                        }
                        elsif (/^bottom$/) {
                            @{ $form{bottom} } = split /\s*\n\s*/, $val, 2;
                            last SWITCH;
                        }
                        elsif (/^init$/) {
                            $form{init} = $val;
                            last SWITCH;
                        }
                        elsif (/^action$/) {
                            $form{action} = $val;
                            last SWITCH;
                        }
                        else {
                            trace("unknown form attribute \"$key\"");
                            $res = $ES_SYNTAX_ERR;
                        }
                    }
                    ( $val, undef, $key ) =
                      extract_bracketed( $text, '{', '\s*[a-zA-Z]*\s*' );
                }
                $res = $ES_SYNTAX_ERR if !pos($text);
                if ( $res == $ES_NO_ERR ) {
                    @{ $form{top} } = @FORM_TOP_MSG unless @{ $form{top} };

                    foreach my $i ( 0 .. $#{ $form{fields} } ) {
                        my $id      = $form{fields}[$i]{id};
                        my $type    = $form{fields}[$i]{type};
                        my $val     = '';
                        my $default = '';
                        if ( $form{fields}[$i]{default} ) {
                            my ( $datatype, $data ) = split /:/,
                              $form{fields}[$i]{default}, 2;
                          SWITCH: {
                                $_ = lc $datatype;
                                if (/^const$/) {
                                    $default = $data;
                                    last SWITCH;
                                }
                                if (/^command$/) {

                                    trace(
"set default value field ID \"$id\" with cmd \"$data\"",
                                        $LOG_DEFAULT_CMD
                                    );
                                    my @res = ();
                                    my @err = ();
                                    unless (
                                        exec_command(
                                            $data, $form{path},
                                            \@res, \@err
                                        )
                                      )
                                    {
                                        trace( "error:\n" . join( '', @err ),
                                            $LOG_DEFAULT_CMD );
                                        @res = ('ERROR!');
                                    }
                                    $default = join( ' ', @res );

                                    last SWITCH;
                                }
                                $default = 'ERROR!';
                            }
                            if ( $type & $BOOLEAN ) {
                                my @vals = ();
                                @vals = ( $BFIELD_YES, $BFIELD_NO )
                                  if $type == $BOOLEAN;
                                @vals =
                                  ( $BFIELD_NULL, $BFIELD_YES, $BFIELD_NO )
                                  if $type == $NULLBOOLEAN;
                                $default =~ s/\s+$//;
                                $default =~ s/^\s+//;
                                unless ( in( uc($default), @vals ) ) {
                                    trace(
"wrong default value \"$default\" in (NULL)BOOLEAN in field ID $form{fields}[$i]{id}"
                                    );
                                    $default = 'ERROR!';
                                }
                                $default =
                                  uc( ralign( $default, $BOOLEAN_FIELD_SIZE ) );
                            }
                        }
                        elsif ( $type & $BOOLEAN ) {
                            $default =
                              ralign( $BFIELD_DEFAULT, $BOOLEAN_FIELD_SIZE );
                        }
                        $form{fields}[$i]{default} = $default;

                        if ( $type & $BOOLEAN ) {
                            $form{fields}[$i]{len} = $BOOLEAN_FIELD_SIZE;
                        }

                        unless ( defined( $form{fields}[$i]{type} ) ) {
                            $form{fields}[$i]{type} = $STRING;
                        }
                        unless ( defined( $form{fields}[$i]{len} ) ) {
                            $form{fields}[$i]{len} = 20;
                        }
                        unless ( defined( $form{fields}[$i]{enabled} ) ) {
                            $form{fields}[$i]{enabled} = $YES;
                        }
                        unless ( defined( $form{fields}[$i]{htab} ) ) {
                            $form{fields}[$i]{htab} = 0;
                        }
                        unless ( defined( $form{fields}[$i]{vtab} ) ) {
                            $form{fields}[$i]{vtab} = 0;
                        }
                        unless ( defined( $form{fields}[$i]{hidden} ) ) {
                            $form{fields}[$i]{hidden} = $NO;
                        }
                        unless ( defined( $form{fields}[$i]{ignore_unchgd} ) ) {
                            $form{fields}[$i]{ignore_unchgd} = $NO;
                        }
                        unless ( defined( $form{fields}[$i]{list_sep} ) ) {
                            $form{fields}[$i]{list_sep} = ' ';
                        }
                        $form{fields}[$i]{changed} = $NO;
                        $form{fields}[$i]{valueFg} = $valueFg;
                        $form{fields}[$i]{valueBg} = $valueBg;

                        if ( $type == $BOOLEAN ) {
                            $form{fields}[$i]{list_cmd} =
"const:single-val:\"$BFIELD_YES $BFIELD_YES_DESCR\",\"$BFIELD_NO $BFIELD_NO_DESCR\"";
                        }
                        if ( $type == $NULLBOOLEAN ) {
                            $form{fields}[$i]{list_cmd} =
"const:single-val:\"$BFIELD_YES $BFIELD_YES_DESCR\",\"$BFIELD_NO $BFIELD_NO_DESCR\",\"$BFIELD_NULL $BFIELD_NULL_DESCR\"";
                        }
                    }

                    ( $val, undef, $key ) =
                      extract_bracketed( $form{action}, '{',
                        '\s*select\-item+\s*' );
                    if ($key) {
                        my $id;
                        $val =~ s/^\{\s*//;
                        $val =~ s/\s*\n?\s*\}$//;
                        foreach $choice ( split /\n/, $val ) {
                            $choice =~ /^\s*(\w+)\s*:\s*(.+)\s*$/;
                            $id = $1;
                            $form{action} = $2;
                            last if ( $id eq $last_item_id );
                        }
                        if ( $id ne $last_item_id ) {
                            trace("ERROR: select-item with unknown item ID\n");
                            $form{action} = '';
                        }
                    }

                    $SCREEN_DIR = $dir;
                    $$path      = $dir;
                }
            }
            else {
                trace("error opening $name: $!");
                $res = $ES_FOPEN_ERR;
            }
            trace("found $fc form field(s)");
            last;
        }
    }
    unless ($found) {
        trace("form \"$name\" NOT FOUND!");
        $res = $ES_NOT_FOUND;
    }
    return $res;
}

sub load_config {
    my ( $key, $val, $text, $found, $res, $fname );
    my @lines;

    $found = $NO;
    for $fname (@cnf_path) {
        trace( "looking for $fname", $LOG_SCAN_PATHS );
        if ( -f $fname ) {
            @lines = ();
            $found = $YES;
            trace("load $fname");
            $res = $ES_NO_ERR;
            if ( open( INF, $fname ) ) {
                while (<INF>) {
                    next if /^\s*#/;
                    push @lines, $_;
                }
                close(INF);
                @lines = map { s/\s*#.*\n/\n/; $_ } @lines;
                $text = join( '', @lines );

                my $term = uc $ENV{TERM};
                ( $val, undef, $key ) =
                  extract_bracketed( $text, '{', '\s*[a-zA-Z_\.]+\s*' );
                while ($key) {
                    $val =~ s/^\{\s*//;
                    $val =~ s/\s*\n?\s*\}$//;
                    $key =~ s/^\s+//;
                    $key =~ s/\s+$//;
                  SWITCH: {
                        $_ = uc $key;
                        if (/^GLOBAL$/) {
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s, 2;
                              ASWITCH: {
                                    $_ = uc $attrk;
                                    if (/^SCREEN_LAYOUT$/) {
                                        if (
                                            defined(
                                                $layout_vals{ lc($attrv) }
                                            )
                                          )
                                        {
                                            $LAYOUT =
                                              $layout_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^HIDE_CURSOR$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $HIDE_CURSOR =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^SHOW_SCREEN_NAME$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $SHOW_SCREEN_NAME =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^PATH$/) {
                                        $PATH = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^LOG_LEVEL$/) {
                                        $LOG_LEVEL = $attrv;
                                        $LOG_FNAME = '' if $LOG_LEVEL == 0;
                                        last ASWITCH;
                                    }
                                    elsif (/^PERMIT_DEBUG$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $PERMIT_DEBUG =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^SHELL$/) {
                                        $OPEN3_SHELL = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^USER_SHELL$/) {
                                        $USER_SHELL = $attrv;
                                        last ASWITCH;
                                    }
                                    elsif (/^LOAD_USER_OBJECTS$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            if ( $bool_vals{ lc($attrv) } ) {
                                                push @mf_path,
"$ENV{HOME}/.$REALNAME/$CALLNAME";
                                                push @cnf_path,
"$ENV{HOME}/.$REALNAME/$CALLNAME.conf";
                                            }
                                        }
                                        else {
                                            trace(
"wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^KEY_F([0-9]{1,2})$/) {
                                        if ( $1 >= 1 and $1 <= 12 ) {
                                            if (
                                                in(
                                                    lc($attrv),
                                                    @fn_key_functions
                                                )
                                              )
                                            {
                                                $keys{ lc($attrv) }{code} =
                                                  KEY_F($1);
                                                $keys{ lc($attrv) }{key} =
                                                  "F$1";
                                                $keys{ lc($attrv) }{label} =
                                                  eval "\$KEY_F$1_LABEL";
                                            }
                                            else {
                                                trace(
"unknown function ID \"$attrv\" for \"$attrk\" attribute"
                                                );
                                            }
                                        }
                                        else {
                                            trace(
"trying to configure invalid key \"F$1\""
                                            );
                                        }
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
"unknown configuration parameter \"$attrk\""
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            last SWITCH;
                        }
                        elsif (/^BROWSER_GLOBAL$/) {
                            my $gs = lc($_);
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s;
                              ASWITCH: {
                                    $_ = uc $attrk;
                                    if (/^MAX_ROWS$/) {
                                        $MAX_PAD_LINES = $attrv;
                                        last ASWITCH;
                                    }
                                    if (/^INFO_ATTR$/) {
                                        eval "\$RS_INFO_ATTR = $attrv";
                                        last ASWITCH;
                                    }
                                    if (/^STDERR_ATTR$/) {
                                        eval "\$RS_STDERR_ATTR = $attrv";
                                        last ASWITCH;
                                    }
                                    if (/^STDOUT_ATTR$/) {
                                        eval "\$RS_STDOUT_ATTR = $attrv";
                                        last ASWITCH;
                                    }
                                    if (/^FNKEYS_ROWS$/) {
                                        $RS_FOOTER_ROWS = 1 + $attrv;
                                        last ASWITCH;
                                    }
                                    if (/^END_MARKER$/) {
                                        if ( $END_MARKER =
                                            substr( $attrv, 0, $COLS ) )
                                        {
                                            my $filler =
                                              ' ' x
                                              int(
                                                ( $COLS - length($END_MARKER) )
                                                / 2 );
                                            $END_MARKER =
                                              "$filler$END_MARKER$filler"
                                              . (
                                                length($out) < $COLS
                                                ? ' '
                                                : '' );
                                        }
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
"$gs: unknown parameter \"$attrk\" in configuration section $key\{\}"
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            last SWITCH;
                        }
                        elsif (/^FORM_GLOBAL$/) {
                            my $gs = lc($_);
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s;
                              ASWITCH: {
                                    $_ = uc $attrk;
                                    if (   /^FIELD_PAD$/
                                        or /^FIELD_PAD.\Q$term\E$/ )
                                    {
                                        if ( $attrv =~ /"(.)"/ ) {
                                            $FIELD_PAD = ord($1);
                                        }
                                        else {
                                            trace(
"$gs: syntax error \"$attrv\" in \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^HIDDEN_FIELD_PAD$/) {
                                        if ( $attrv =~ /"(.)"/ ) {
                                            $HFIELD_PAD = ord($1);
                                        }
                                        else {
                                            trace(
"$gs: syntax error \"$attrv\" in \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^SHOW_CHANGED_FIELDS$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $SHOW_CHGD_FIELDS =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"$gs: wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^SHOW_FIELD_FLAGS$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $SHOW_FIELD_FLAGS =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"$gs: wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^SHOW_DOTS$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $SHOW_DOTS =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"$gs: wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^INITIAL_OVL_MODE$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $INITIAL_OVL_MODE =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"$gs: wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^VALUE_DELIMITERS$/) {
                                        if ( $attrv =~ /"(.)"\s*,\s*"(.)"/ ) {
                                            @fval_delim = ( $1, $2 );
                                        }
                                        else {
                                            trace(
"$gs: syntax error \"$attrv\" in \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^FIELD_VALUE_POS$/) {
                                        if (    $attrv =~ /^-*[0-9]+$/
                                            and $attrv >= -1 )
                                        {
                                            $FIELD_VALUE_POS = $attrv;
                                        }
                                        else {
                                            trace(
"$gs: syntax error \"$attrv\" in \"$attrk\" attribute (number >= -1 expected)"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    elsif (/^FNKEYS_ROWS$/) {
                                        $FS_FOOTER_ROWS = 1 + $attrv;
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
"$gs: unknown configuration parameter \"$attrk\""
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            last SWITCH;
                        }
                        elsif ( /^FIELD_ATTR$/ or /^FIELD_ATTR.\Q$term\E$/ ) {
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s;
                              ASWITCH: {
                                    $_ = uc $attrk;
                                    if (/^LABEL_FG$/) {
                                        eval "\$labelFg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^LABEL_BG$/) {
                                        eval "\$labelBg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^VALUE_FG$/) {
                                        eval "\$valueFg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^VALUE_BG$/) {
                                        eval "\$valueBg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^CHANGED_VALUE_FG$/) {
                                        eval "\$cf_valueFg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^CHANGED_VALUE_BG$/) {
                                        eval "\$cf_valueBg = $attrv";
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
"unknown parameter \"$attrk\" in configuration section $key\{\}"
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            last SWITCH;
                        }
                        elsif (/^ACTIVE_FIELD_ATTR$/
                            or /^ACTIVE_FIELD_ATTR.\Q$term\E$/ )
                        {
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s;
                              ASWITCH: {
                                    $_ = uc $attrk;
                                    if (/^LABEL_FG$/) {
                                        eval "\$af_labelFg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^LABEL_BG$/) {
                                        eval "\$af_labelBg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^VALUE_FG$/) {
                                        eval "\$af_valueFg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^VALUE_BG$/) {
                                        eval "\$af_valueBg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^CHANGED_VALUE_FG$/) {
                                        eval "\$acf_valueFg = $attrv";
                                        last ASWITCH;
                                    }
                                    elsif (/^CHANGED_VALUE_BG$/) {
                                        eval "\$acf_valueBg = $attrv";
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
"unknown parameter \"$attrk\" in configuration section $key\{\}"
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            last SWITCH;
                        }
                        elsif (/^MENU_GLOBAL$/) {
                            my $gs = lc($_);
                            my $s;
                            my @finfo = split /\s*\n\s*/, $val;
                            foreach $s (@finfo) {
                                ( $attrk, $attrv ) = split /\s*=\s*/, $s;
                              ASWITCH: {
                                    $_ = uc $attrk;
                                    if (/^MARK_NOACTION_ITEMS$/) {
                                        if (
                                            defined( $bool_vals{ lc($attrv) } )
                                          )
                                        {
                                            $MARK_NOACT_ITEMS =
                                              $bool_vals{ lc($attrv) };
                                        }
                                        else {
                                            trace(
"$gs: wrong value \"$attrv\" for \"$attrk\" attribute"
                                            );
                                            $res = $ES_SYNTAX_ERR;
                                        }
                                        last ASWITCH;
                                    }
                                    if (/^FNKEYS_ROWS$/) {
                                        $MS_FOOTER_ROWS = 1 + $attrv;
                                        last ASWITCH;
                                    }
                                    else {
                                        trace(
"$gs: unknown parameter \"$attrk\" in configuration section $key\{\}"
                                        );
                                        $res = $ES_SYNTAX_ERR;
                                    }
                                }
                            }
                            last SWITCH;
                        }
                        else {
                            trace("unknown configuration parameter \"$key\"");
                            $res = $ES_SYNTAX_ERR;
                        }
                    }
                    ( $val, undef, $key ) =
                      extract_bracketed( $text, '{', '\s*[a-zA-Z_\.]+\s*' );
                }
                $res = $ES_SYNTAX_ERR if !pos($text);
                if ( $res == $ES_NO_ERR ) {
                }
            }
            else {
                trace("error opening $fname: $!");
                $res = $ES_FOPEN_ERR;
            }
        }
        unless ($found) {
            trace("configuration file \"$fname\" NOT FOUND!");
            $res = $ES_NOT_FOUND;
        }
    }
    return $res;
}

sub do_menu {
    my ( $menuname, $title ) = @_;

    my @fset;
    my ( $cmenu, $es, $rows, $cols, $i, $ci, $item, $ch, $mlmargin, $msub );
    my ( $action, $args, $wait_key );
    my @actopts;
    my ($pan);
    my ( $win,     $mwinr );
    my ( $exit_id, $exit_descr );
    my ( $pos_msg, $saveY, $saveX );
    local %menu;

    unless ( $es = load_menu($menuname) ) {
        foreach $i ( 0 .. $#{ $menu{items} } ) {
            if ( $MARK_NOACT_ITEMS and !$menu{items}[$i]{action} ) {
                $menu{items}[$i]{descr} = "($menu{items}[$i]{descr})";
            }
            if ( $LAYOUT != $SIMPLE ) {
                $menu{items}[$i]{descr} = " $menu{items}[$i]{descr} ";
            }
            $item = new_item( $menu{items}[$i]{descr}, "" );

            if ( $item eq '' ) {
                fatal("new_item($menu{items}[$i]{descr}) failed: $item");
            }
            $menu{items}[$i]{ptr} = $item;
            push @fset, ${$item};
        }
        push @fset, 0;

        $cmenu = new_menu( pack 'L!*', @fset );
        if ( $cmenu eq '' ) { fatal("do_menu.new_menu() failed") }

        $mwinr =
          $LINES -
          ( $MS_HEADER_ROWS +
              $MS_TOP_ROWS +
              $MS_BOTTOM_ROWS +
              $MS_FOOTER_ROWS );
        $win = newwin( $LINES, $COLS, 0, 0 );
        $pan = new_panel($win);

        set_menu_mark( $cmenu, ' ' );
        set_menu_format( $cmenu, $mwinr, 1 );
        scale_menu( $cmenu, $rows, $cols );

        $mlmargin = int( ( $COLS - $cols ) / 2 );
        $mlmargin = 1 if ( $LAYOUT == $SIMPLE );

        $msub = derwin( $win, $rows, $cols, $MS_HEADER_ROWS + $MS_TOP_ROWS,
            $mlmargin );
        set_menu_win( $cmenu, $win );
        set_menu_sub( $cmenu, $msub );
        keypad( $win, $ON );
        clear($win);

        $title = $menu{title} if $menu{title};
        init_title( $win, $MS_HEADER_ROWS, $title );
        init_top( $win, $NO, $MS_HEADER_ROWS, $MS_TOP_ROWS, @{ $menu{top} } );
        init_footer( $win, $NO, $MS_FOOTER_ROWS, @MSKeys );
        post_menu($cmenu);
        refresh($win);

        $es = 0;
        while ( !defined($exec_args) ) {
            disp_page( $win, item_index( current_item($cmenu) ) + 1,
                item_count($cmenu), 'menu', $menuname );

            $ch = getch($win);
            if ( $ch == KEY_UP ) {
                menu_driver( $cmenu, REQ_UP_ITEM );
            }
            elsif ( $ch == KEY_DOWN ) {
                menu_driver( $cmenu, REQ_DOWN_ITEM );
            }
            elsif ( $ch == KEY_PPAGE ) {
                menu_driver( $cmenu, REQ_SCR_UPAGE );
            }
            elsif ( $ch == KEY_NPAGE ) {
                menu_driver( $cmenu, REQ_SCR_DPAGE );
            }
            elsif ( $ch == KEY_HOME ) {
                menu_driver( $cmenu, REQ_FIRST_ITEM );
            }
            elsif ( $ch == KEY_END ) {
                menu_driver( $cmenu, REQ_LAST_ITEM );
            }
            elsif ( $ch == $keys{redraw}{code} ) {
                refresh(curscr);
            }
            elsif ( $ch == $keys{back}{code} or ord($ch) == 27 ) {
                $es = $ES_CANCEL;
                last;
            }
            elsif ( $ch == $keys{shell_escape}{code} ) {
                if ( valid_shell($USER_SHELL) ) {
                    curs_set($ON) if $HIDE_CURSOR;
                    call_shell;
                    curs_set($OFF) if $HIDE_CURSOR;
                    refresh($win);
                }
                else {
                    disp_msg( $win, $BAD_SHELL_MSG, $BAD_SHELL_TITLE );
                }
            }
            elsif ( $ch == $keys{exit}{code} ) {
                $es = $ES_EXIT;
                last;
            }
            elsif ( $ch eq "\r" or $ch eq "\n" ) {
                $ci           = item_index( current_item($cmenu) );
                $last_item_id = $menu{items}[$ci]{id};
                if ( $menu{items}[$ci]{action} ) {
                    ( $action, $args ) = split /:/, $menu{items}[$ci]{action},
                      2;
                    $action = lc $action;
                    $action =~ /^([a-zA-Z]+)\(?([a-zA-Z_,]*)\)?$/;
                    $action = $1;
                    @actopts = split /,\s*/, $2;

                    $wait_key      = $NO;
                    $LOG_REQUESTED = $NO;
                    foreach $opt (@actopts) {
                      SWITCH: {
                            $_ = $opt;
                            if (/^confirm$/) {
                                my $title = $menu{items}[$ci]{descr};
                                my $val;
                                ( $es, $val ) =
                                  do_list( $win, $title, 'single-val',
                                    \@CONFIRM_ITEMS, undef );
                                if ( $val ne $BFIELD_YES ) {
                                    $action = 'ABORTED';
                                }
                                last SWITCH;
                            }
                            elsif (/^log$/) {
                                $LOG_REQUESTED = $YES;
                                last SWITCH;
                            }
                            elsif (/^wait_key$/) {
                                $wait_key = $YES;
                                last SWITCH;
                            }
                            else {
                                trace("unknown action option \"$_\"");
                            }
                        }
                    }

                    if ( $action eq 'menu' ) {
                        ( $es, undef, undef ) =
                          do_menu( $args, $menu{items}[$ci]{descr} );
                        if ( $es and $es < $ES_USER_REQ ) {
                            trace(
"WARNING: $es_str[$es] while reading menu \"$args\""
                            );
                            disp_msg( $win,
                                "$es_str[$es] $LOAD_MENU_ERR_MSG \"$args\"",
                                $MENU_ERR_TITLE );
                        }
                        else {
                            refresh($win);
                        }
                    }
                    elsif ( $action eq 'form' ) {
                        curs_set($ON) if $HIDE_CURSOR;
                        ( $called_form, $args ) = split /\s+/, $args, 2;
                        $args =~ s/^\s+//;
                        $args =~ s/\s+$//;
                        trace( "call form \"$called_form\", args \"$args\"",
                            $LOG_ACTION_CMD );
                        $es = do_form( $called_form, $menu{items}[$ci]{descr},
                            split /\s+/, $args );
                        curs_set($OFF) if $HIDE_CURSOR;
                        if ( $es and $es < $ES_USER_REQ ) {
                            trace(
"WARNING: $es_str[$es] while reading form \"$args\""
                            );
                            disp_msg( $win,
                                "$es_str[$es] $LOAD_FORM_ERR_MSG \"$args\"",
                                $FORM_ERR_TITLE );
                        }
                        else {
                            refresh($win);
                        }
                    }
                    elsif ( $action eq 'system' ) {
                        curs_set($ON) if $HIDE_CURSOR;
                        call_system( $wait_key, $args );
                        curs_set($OFF) if $HIDE_CURSOR;
                        refresh($win);
                    }
                    elsif ( $action eq 'exec' ) {
                        $exec_args = $args;
                    }
                    elsif ( $action eq 'run' ) {
                        $es = run_browse( $menu{items}[$ci]{descr},
                            $args, $menuname, $menu{path} );
                        refresh($win);
                    }
                    elsif ( $action eq 'ABORTED' ) {
                        trace("user not confirmed action!");
                    }
                    else {
                        trace("unknown action \"$action\"");
                    }
                    last if $es == $ES_EXIT;
                }
                else {
                    $exit_id    = $menu{items}[$ci]{id};
                    $exit_descr = $menu{items}[$ci]{descr};
                    trace(
"No action for option \"$exit_id\" of menu \"$menuname\""
                    );
                    if ( $LAYOUT != $SIMPLE ) {
                        $exit_descr =~ s/^\s+//;
                        $exit_descr =~ s/\s+$//;
                    }
                    last;
                }
                $LOG_REQUESTED = $NO;
            }
            elsif ( $ch =~ /^\S$/ ) {
                menu_driver( $cmenu, $ch );
            }
            else {
                beep();
            }
        }

        unpost_menu($cmenu);
        free_menu($cmenu);
        foreach $i ( 0 .. $#{ $menu{items} } ) {
            free_item( $menu{items}[$i]{ptr} );
        }
        @fset = ();
        %menu = ();
        undef %menu;

        del_panel($pan);
        delwin($win);
    }
    return ( $es, $exit_id, $exit_descr );
}

sub in {
    my ( $el, @list ) = @_;

    foreach my $scan (@list) {
        return $YES if "$scan" eq "$el";
    }
    return $NO;
}

sub do_list {
    my ( $pwin, $title, $type, $ilist_ref, $selected_ref ) = @_;
    my @il;
    my @fset;
    my @junk;
    my @selected;
    my @items;
    my ( $i, $item, $cmenu, $mpanel, $mwin, $ci, $ciname );
    my ( $rows, $cols, $srch_pattern, $mark );
    my ( $pos_msg, $saveY, $saveX );
    my @top_msg;
    my @lw_keys;
    my $title_y   = ( $LAYOUT == $SIMPLE ) ? 1 : 0;
    my $top_msg_y = ( $LAYOUT == $SIMPLE ) ? 3 : 2;
    my $nselected = 0;
    my ( $mpad, $px, $mpad_x0, $mpad_y0, $mpad_x1, $mpad_y1 );
    my ( $lflag, $rflag );

    my $es = 0;
  SWITCH: {
        $_ = $type;
        if (/^single\-val$/) {
            @top_msg = @LW_SINGLEVAL_TOP_MSG;
            if ( scalar @$ilist_ref < $MIN_ITEMS_FOR_FIND ) {
                @lw_keys = qw( help redraw back exit );
            }
            else {
                @lw_keys = qw( help redraw back exit find find_next );
            }
            $mark = ' ';
            last SWITCH;
        }
        if (/^multi\-val$/) {
            @top_msg = @LW_MULTIVAL_TOP_MSG;
            if ( scalar @$ilist_ref < $MIN_ITEMS_FOR_FIND ) {
                @lw_keys =
                  qw( help redraw back sel_items exit sel_all unsel_all );
            }
            else {
                @lw_keys =
                  qw( help redraw back sel_items exit find find_next sel_all unsel_all );
            }
            $mark = ( $LAYOUT == $SIMPLE ) ? '>' : ' ';
            last SWITCH;
        }
        if (/^display$/) {
            @top_msg = @LW_DISPLAY_TOP_MSG;
            @lw_keys = qw( help redraw back );
            $mark    = ' ';
            my ( $i, $subln1, $subln2 );
            while ( $i <= $#$ilist_ref ) {
                $subln2 = $$ilist_ref[$i];
                while ( length($subln2) > $LW_COLS - 4 ) {
                    $subln1 = substr( $subln2, 0, $LW_COLS - 4 - 1 );
                    $subln2 = substr( $subln2, $LW_COLS - 4 - 1 );
                    $$ilist_ref[$i] = $subln2;
                    splice @$ilist_ref, $i++, 0, $subln1;
                }
                $i++;
            }
            foreach $i ( 0 .. $#$ilist_ref ) {
                $$ilist_ref[$i] = ' ' if !$$ilist_ref[$i];
            }
            last SWITCH;
        }
        if (/^menu$/) {
            last SWITCH;
        }
        else {
            trace("unknown list type \"$type\"");
            return $es, undef;
        }
    }
    my $y0 = $LW_ROW0;
    my $y1 = $LINES;
    my $x0 = int( ( $COLS - $LW_COLS ) / 2 );
    my $list_height =
      $y1 - $y0 - 2 - $LW_FOOTER_ROWS - $top_msg_y - scalar @top_msg;
    if ( scalar @$ilist_ref < $list_height ) {
        $y0 += $list_height - scalar @$ilist_ref;
        $list_height = scalar @$ilist_ref;
    }
    my $win_height =
      $top_msg_y + ( scalar @top_msg ) + $list_height + $LW_FOOTER_ROWS;
    $win_height += 2;

    my $win_fg_attr  = $LAYOUT == $SIMPLE ? A_NORMAL  : A_NORMAL;
    my $win_bg_attr  = $LAYOUT == $SIMPLE ? A_NORMAL  : A_REVERSE;
    my $menu_fg_attr = $LAYOUT == $SIMPLE ? A_REVERSE : A_NORMAL;
    my $menu_bg_attr = $LAYOUT == $SIMPLE ? A_NORMAL  : A_REVERSE;

    $type = lc($type);
    undef(@selected);
    undef(@il);
    undef(@fset);
    undef(@junk);
    undef(@items);
    foreach $i ( 0 .. $#$ilist_ref ) {
        if ( $type ne 'display' ) {
            ( $items[$i]{name}, $items[$i]{descr} ) = split /(?<!\\) /,
              $$ilist_ref[$i], 2;
            $items[$i]{name} =~ s/\\ / /g;
            $items[$i]{name} = ' ' if $items[$i]{name} eq '';
        }
        else {
            $items[$i]{name}  = $$ilist_ref[$i];
            $items[$i]{descr} = '';
        }
        $item = new_item( $items[$i]{name}, $items[$i]{descr} );
        if ( $item eq '' ) {
            fatal(
                "new_item('$items[$i]{name}','$items[$i]{descr}') failed: $item"
            );
        }
        push @il,   $item;
        push @fset, ${$item};
    }
    push @fset, 0;

    $cmenu = new_menu( pack 'L!*', @fset );
    if ( $cmenu eq '' ) { fatal("do_list.new_menu() failed") }

    set_menu_mark( $cmenu, $mark );
    set_menu_back( $cmenu, $menu_bg_attr );
    set_menu_fore( $cmenu, $menu_fg_attr );
    if ( $type eq 'multi-val' ) {
        menu_opts_off( $cmenu, O_ONEVALUE );
    }
    else {
        menu_opts_on( $cmenu, O_ONEVALUE );
    }
    set_menu_format( $cmenu, $list_height, 1 );

    $mwin = newwin( $win_height, $LW_COLS, $y0, $x0 );
    bkgd( $mwin, $menu_bg_attr );
    box( $mwin, 0, 0 );
    if ( defined($title) ) {
        $title = " $title " if $LAYOUT == $NORMAL;
    }
    addstr( $mwin, $title_y, int( ( $LW_COLS - length($title) ) / 2 ), $title );
    init_top( $mwin, $YES, $top_msg_y, scalar @top_msg, @top_msg );
    init_footer( $mwin, $YES, $LW_FOOTER_ROWS, @lw_keys );
    scale_menu( $cmenu, $rows, $cols );

    $mpanel = new_panel($mwin);
    if ( $LAYOUT == $NORMAL ) {
        $mlmargin = int( ( $LW_COLS - $cols ) / 2 );
        $mlmargin = 1 if $mlmargin < 1;
    }
    else {
        $mlmargin = 2;
    }

    $mpad_x0 = $x0 + $mlmargin;
    $mpad_y0 = $y0 + ( scalar @top_msg ) + $top_msg_y + 1;
    $mpad_x1 = $x0 + $LW_COLS - 2;
    $mpad_y1 = $mpad_y0 + $list_height;

    $mpad = newpad( $list_height, $LW_PAD_COLS );
    bkgd( $mpad, $menu_bg_attr );
    doupdate();

    set_menu_win( $cmenu, $mwin );
    set_menu_sub( $cmenu, $mpad );
    keypad( $mwin, $ON );

    post_menu($cmenu);
    if ( $type eq 'multi-val' ) {
        foreach $i ( 0 .. $#il ) {
            foreach $scan (@$selected_ref) {
                if ( $scan eq $items[$i]{name} ) {
                    set_item_value( $il[$i], $YES );
                    $nselected++;
                }
            }
        }
    }
    refresh($mwin);
    $px = 0;
    while (1) {
        prefresh( $mpad, 0, $px, $mpad_y0, $mpad_x0, $mpad_y1, $mpad_x1 );
        $rflag = $lflag = ' ';
        $rflag = '>' if $mlmargin + $cols - $LW_COLS - $px >= 0;
        $lflag = '<' if $px > 0;
        $pos_msg = sprintf( "  %s%d/%d%s%s",
            $lflag, item_index( current_item($cmenu) ) + 1,
            item_count($cmenu),
            ( $type eq 'multi-val' ) ? ":$nselected" : '', $rflag );
        getyx( $mwin, $saveY, $saveX );
        addstr( $mwin, $title_y + 1, $LW_COLS - length($pos_msg) - 1,
            $pos_msg );
        move( $mwin, $saveY, $saveX );
        my $ch = getch($mwin);

        if ( $ch == KEY_UP ) {
            menu_driver( $cmenu, REQ_UP_ITEM );
        }
        elsif ( $ch == KEY_DOWN ) {
            menu_driver( $cmenu, REQ_DOWN_ITEM );
        }
        elsif ( $ch == KEY_LEFT ) {
            $px-- if $px > 0;
        }
        elsif ( $ch == KEY_RIGHT ) {
            $px++ if $mlmargin + $cols - $LW_COLS - $px >= 0;
        }
        elsif ( $ch == KEY_HOME ) {
            menu_driver( $cmenu, REQ_FIRST_ITEM );
        }
        elsif ( $ch == KEY_END ) {
            menu_driver( $cmenu, REQ_LAST_ITEM );
        }
        elsif ( $ch == KEY_PPAGE ) {
            menu_driver( $cmenu, REQ_SCR_UPAGE );
        }
        elsif ( $ch == KEY_NPAGE ) {
            menu_driver( $cmenu, REQ_SCR_DPAGE );
        }
        elsif ( $ch eq '/' and in( 'find', @lw_keys ) ) {
            ( $es, $srch_pattern ) =
              ask_string( $SEARCH_PTRN_TITLE, $SEARCH_PTRN_PROMPT );
            if ( $es == $ES_EXIT ) {
                $ch = $keys{exit}{code};
                last;
            }
            noutrefresh($pwin);
            noutrefresh($mwin);
            doupdate;
            set_menu_pattern( $cmenu, $srch_pattern );
        }
        elsif ( $ch eq 'n' and in( 'find_next', @lw_keys ) ) {
            menu_driver( $cmenu, REQ_NEXT_MATCH );
        }
        elsif ( $ch == $keys{redraw}{code} ) {
            refresh(curscr);
        }
        elsif ( ( $ch == $keys{back}{code} or ord($ch) == 27 )
            and in( 'back', @lw_keys ) )
        {
            $es = $ES_CANCEL;
            last;
        }
        elsif ( $ch == $keys{exit}{code} and in( 'exit', @lw_keys ) ) {
            $es = $ES_EXIT;
            last;
        }
        elsif ( ( $ch == $keys{sel_items}{code} or $ch eq ' ' )
            and $type eq 'multi-val' )
        {

            $ci = current_item($cmenu);
            set_item_value( $ci, !item_value($ci) );
            $nselected += item_value($ci) ? 1 : -1;
            menu_driver( $cmenu, REQ_DOWN_ITEM );
        }
        elsif ( uc($ch) eq 'A' and in( 'sel_all', @lw_keys ) ) {
            foreach $i ( 0 .. $#il ) {
                set_item_value( $il[$i], $YES );
            }
            $nselected = $#il + 1;
        }
        elsif ( uc($ch) eq 'U' and in( 'unsel_all', @lw_keys ) ) {
            foreach $i ( 0 .. $#il ) {
                set_item_value( $il[$i], $NO );
            }
            $nselected = 0;
        }
        elsif ( $ch eq "\r" or $ch eq "\n" ) {
            @selected = ();
            if ( $type eq 'single-val' ) {
                $ci     = current_item($cmenu);
                $ciname = item_name($ci);
                push @selected, $ciname if $type eq 'single-val';
            }
            else {
                foreach $i ( 0 .. $#il ) {
                    if ( item_value( $il[$i] ) ) {
                        $ciname = item_name( $il[$i] );
                        $ciname =~ s/^\s+//;
                        $ciname =~ s/\s+$//;
                        push @selected, $ciname;
                    }
                }
            }
            last;
        }
        else {
            beep();
        }
    }

    del_panel($mpanel);
    unpost_menu($cmenu);
    delwin($mpad);
    delwin($mwin);
    free_menu($cmenu);
    map { free_item($_) } @il;
    refresh($pwin);
    @selected = () if ( $ch == $keys{back}{code} or ord($ch) == 27 );
    return $es, @selected;
}

sub do_form {
    my ( $formname, $title, @argv ) = @_;

    my @fset;
    local @fp;
    my ( $es, $rows, $cols, $i, $nfields, $field, $ch, $fsub, $y, $npages );
    local $cform;
    my ( $action, $args, $wait_key );
    my @actopts;
    my ($pan);
    my ( $win, $mwinr, $dots, $c );
    my ( $exit_id, $exit_descr );
    my (
        $id,     $all_ids, $label,  $len, $type, $default,
        $hidden, $hscroll, $script, $val, $form_dir
    );
    my ($fpad);
    local %field_vals;
    local %form;
    my ( @fields_to_remove, @fields_to_enable, @fields_to_disable );

    sub sync_fields_val {
        form_driver( $cform, REQ_VALIDATION );
        foreach my $i ( 0 .. $#{ $form{fields} } ) {
            $form{fields}[$i]{value} =
              field_buffer( $form{fields}[$i]{ptr}, 0 );
            $form{fields}[$i]{value} =~ s/\s+$//;
            if ( $form{fields}[$i]{type} & $BOOLEAN ) {
                $form{fields}[$i]{value} =~ s/^\s+//;
            }
        }
    }

    sub set_field_attr {
        my $lptr = $fp[ field_index( current_field($cform) ) - 6 ];
        my $vptr = $fp[ field_index( current_field($cform) ) ];
        my $fidx = int( field_index( current_field($cform) ) / 7 );
        set_field_fore( $lptr, $labelFg );
        set_field_back( $lptr, $labelBg );
        set_field_fore( $vptr, $form{fields}[$fidx]{valueFg} );
        set_field_back( $vptr, $form{fields}[$fidx]{valueBg} );
    }

    sub set_field_active_attr {
        my ( $bg, $fg );
        my $fidx = int( field_index( current_field($cform) ) / 7 );
        if ( $SHOW_CHGD_FIELDS and $form{fields}[$fidx]{changed} ) {
            $fg = $acf_valueFg;
            $bg = $acf_valueBg;
        }
        else {
            $fg = $af_valueFg;
            $bg = $af_valueBg;
        }
        set_field_fore( $fp[ field_index( current_field($cform) ) - 6 ],
            $af_labelFg );
        set_field_back( $fp[ field_index( current_field($cform) ) - 6 ],
            $af_labelBg );
        set_field_fore( $fp[ field_index( current_field($cform) ) ], $fg );
        set_field_back( $fp[ field_index( current_field($cform) ) ], $bg );
    }

    sub check_val_changes {
        form_driver( $cform, REQ_VALIDATION );
        my $curr_val = field_buffer( current_field($cform), 0 );
        $curr_val =~ s/\s+$//;
        my $fi = int( field_index( current_field($cform) ) / 7 );
        if ($SHOW_CHGD_FIELDS) {
            if ( $curr_val ne $form{fields}[$fi]{value} ) {
                $form{fields}[$fi]{changed} = $YES;
                set_field_fore( $fp[ field_index( current_field($cform) ) ],
                    $acf_valueFg );
                set_field_back( $fp[ field_index( current_field($cform) ) ],
                    $acf_valueBg );
                $form{fields}[$fi]{valueFg} = $cf_valueFg;
                $form{fields}[$fi]{valueBg} = $cf_valueBg;
            }
            else {
                set_field_fore( $fp[ field_index( current_field($cform) ) ],
                    $af_valueFg );
                set_field_back( $fp[ field_index( current_field($cform) ) ],
                    $af_valueBg );
                $form{fields}[$fi]{valueFg} = $valueFg;
                $form{fields}[$fi]{valueBg} = $valueBg;
            }
        }
    }

    sub prepare_action {
        my ($action_ref) = @_;

        my ( $id, $val );

        foreach my $i ( 0 .. $#{ $form{fields} } ) {
            $val = '';
            $id  = $form{fields}[$i]{id};
            unless ( !$form{fields}[$i]{changed}
                and $form{fields}[$i]{ignore_unchgd} )
            {
                if ( $form{fields}[$i]{type} == $BOOLEAN ) {
                    my ( $yes_opt, $no_opt ) = split /\s*,\s*/,
                      $form{fields}[$i]{option}, 2;
                    if ( $form{fields}[$i]{value} eq $BFIELD_YES ) {
                        $val = " $yes_opt";
                    }
                    elsif ( defined($no_opt) ) {
                        $val = " $no_opt";
                    }
                }
                elsif ( $form{fields}[$i]{type} == $NULLBOOLEAN ) {
                  SWITCH: {
                        if ( $form{fields}[$i]{value} eq $BFIELD_YES ) {
                            $val = " $form{fields}[$i]{option} y";
                            last SWITCH;
                        }
                        if ( $form{fields}[$i]{value} eq $BFIELD_NO ) {
                            $val = " $form{fields}[$i]{option} n";
                            last SWITCH;
                        }
                    }
                }
                else {
                    $val = $form{fields}[$i]{value};
                    $val =~ s/^\s+//;
                    $val =~ s/\s+$//;
                    if ( $form{fields}[$i]{option} and $val ne '' ) {
                        my $option = $form{fields}[$i]{option};
                        my $quote = substr( $option, -1, 1, '' )
                          if $option =~ /(['"])$/;
                        my $sep = ( $option !~ /=$/ ) ? ' ' : '';
                        $val = "$quote$val$quote" if $quote;
                        if ( $val =~ /\s+/ and !$quote ) {
                            my $vals = '';
                            foreach $s ( split /\s+/, $val ) {
                                $vals .= $option . $sep . "$s ";
                            }
                            $val = $vals;
                        }
                        else {
                            $val = $option . $sep . "$val ";
                        }
                        $val =~ s/\s+$//;
                        $val = ' ' . $val if $val;
                    }
                }
            }
            $$action_ref =~ s/%\{$id\}/$val/g;
        }

        $$action_ref =~ s/^\s+//;
        $$action_ref =~ s/\s+$//;
    }

    sub save_persistent {
        my ( $fname, $hash, $c );

        $c = 0;
        foreach my $i ( 0 .. $#{ $form{fields} } ) {
            $c++ if ( $form{fields}[$i]{persist} );
        }
        trace("Found $c persistent field(s)");
        return 0 if $c eq 0;

        $hash  = md5_hex("$SCREEN_DIR/$formname$FORMEXT");
        $fname = "$PERS_DIR/$hash";

        foreach my $sd ( $PRIV_DIR, $PERS_DIR ) {
            unless ( -e $sd and -d $sd ) {
                if ( mkdir "$sd", 0700 ) {
                    trace("Created subdir $sd");
                }
                else {
                    my $errstr = $!;
                    trace("Error creating subdir $sd: $errstr");
                    disp_msg( $win, "$errstr $PERS_WRITE_ERROR_MSG",
                        $PERS_WRITE_ERROR_TITLE );
                    return 1;
                }
            }
        }

        eval {
            open( OUTF, ">$fname" ) or die("$!\n");
            print OUTF "# $SCREEN_DIR/$formname$FORMEXT\n";
            foreach my $i ( 0 .. $#{ $form{fields} } ) {
                if ( $form{fields}[$i]{persist} ) {
                    $id  = $form{fields}[$i]{id};
                    $val = $form{fields}[$i]{value};
                    print OUTF "$id=$val\n";
                }
                $i++;
            }
            close(OUTF) or die("$!");
            chmod 0600, $fname;
        };
        if ($@) {
            chop($@);
            disp_msg( $win, "$@ $PERS_WRITE_ERROR_MSG",
                $PERS_WRITE_ERROR_TITLE );
            trace( "$@ error writing persistent data to $fname:",
                $LOG_FIELDS_VAL );
        }
        else {
            trace( "Persistent data written to $fname", $LOG_FIELDS_VAL );
        }
    }

    sub load_persistent {
        my @res = ();
        my ( $fname, $hash );

        $hash  = md5_hex("$SCREEN_DIR/$formname$FORMEXT");
        $fname = "$PERS_DIR/$hash";
        eval {
            open( INF, "$fname" ) or die("$!\n");
            @res = <INF>;
            close(INF) or die("$!\n");
        };
        if ( int($!) != 2 ) {
            if ($@) {
                chop($@);
                trace("Error loading persistent data of form $fname: $@");
            }
            else {
                trace( "Loaded persistent data from $fname:", $LOG_FIELDS_VAL );
                foreach (@res) {
                    next if /^\s*#/;
                    chop;
                    my ( $id, $val ) = split /\s*=\s*/;
                    $field_vals{$id} = $val;
                    trace( "  $id=\"$val\"", $LOG_FIELDS_VAL );
                }
            }
        }
    }

    unless ( $es = load_form( $formname, \$form_dir ) ) {
        undef(@fields_to_remove);
        undef(@fields_to_enable);
        undef(@fields_to_disable);
        my $ch_boolean = '';
        my $ch_string  = '[[:ascii:]]';
        my $ch_numeric = '[0-9\-\+,\.]';
        my $ch_set;

        $mwinr =
          $LINES -
          ( $FS_HEADER_ROWS +
              $FS_TOP_ROWS +
              $FS_BOTTOM_ROWS +
              $FS_FOOTER_ROWS );
        $win = newwin( $LINES, $COLS, 0, 0 );
        $pan = new_panel($win);

        foreach $c ( 1 .. $#argv + 1 ) {
            trace(
                "argument %\{$FORM_ARGV_ID$c\} substituted with \"$argv[$c-1]\""
            );
            $form{init}   =~ s/%\{$FORM_ARGV_ID$c\}/$argv[$c-1]/g;
            $form{action} =~ s/%\{$FORM_ARGV_ID$c\}/$argv[$c-1]/g;
        }
        $form{init}   =~ s/%\{$FORM_ARGV_ID[1-9][0-9]*\}//g;
        $form{action} =~ s/%\{$FORM_ARGV_ID[1-9][0-9]*\}//g;

        if ( $form{init} ) {
            my ( $action, $args ) = split /:/, $form{init}, 2;
            if ( $action eq 'command' ) {
                curs_set($OFF) if $HIDE_CURSOR;
                my ( $wpan, $wwin ) = open_wait_msg;
                undef %field_vals;
                my $prev_path = $ENV{PATH};

                my @res = ();
                my @err = ();
                trace( "init form: executing \"$args\"", $LOG_INITFORM_OUT );
                my $cmd_ok = exec_command( $args, $form{path}, \@res, \@err );
                trace( "init form exit status: $child_es", $LOG_INITFORM_OUT );
                trace( "init form stdout:",                $LOG_INITFORM_OUT );
                foreach $s (@res) {
                    trace( "  \"$s\"", $LOG_INITFORM_OUT );
                }
                if (@err) {
                    ($es) = do_list( $win, $INIT_FORM_ERR_MSG, 'display', \@err,
                        undef );
                    trace( "init form stderr:", $LOG_INITFORM_OUT );
                    foreach $s (@err) {
                        trace( "  $s", $LOG_INITFORM_OUT );
                    }
                }
                trace( "init field value(s) \"$formname\":", $LOG_FIELDS_VAL );
                foreach $s (@res) {
                    my ( $id, $val ) = split /\s*=\s*/, $s, 2;
                    if (
                        in(
                            $id,
                            (
                                $INIT_REMOVE_FIELDS, $INIT_ENABLE_FIELDS,
                                $INIT_DISABLE_FIELDS
                            )
                        )
                      )
                    {
                        my @fl = split /\s*,\s*/, $val;
                        if ( $id =~ /^$INIT_REMOVE_FIELDS$/ ) {
                            push( @fields_to_remove, @fl );
                        }
                        elsif ( $id =~ /^$INIT_ENABLE_FIELDS$/ ) {
                            push( @fields_to_enable, @fl );
                        }
                        elsif ( $id =~ /^$INIT_DISABLE_FIELDS$/ ) {
                            push( @fields_to_disable, @fl );
                        }
                        trace( "$id is \"" . join( ',', @fl ) . "\"" )
                          ;    #$LOG_FIELDS_VAL
                    }
                    else {
                        $field_vals{$id} = $val;
                        trace( "  $s=\"$val\"", $LOG_FIELDS_VAL );
                    }
                }
                close_wait_msg( $wpan, $wwin, $win );
                curs_set($ON) if $HIDE_CURSOR;
                if ($child_es) {
                    del_panel($pan);
                    delwin($win);
                    return;
                }
            }
            else {
                trace("unknown form init type \"$action\"");
            }
        }
        load_persistent;

        $y           = 0;
        $npages      = 0;
        $lflags_size = $FIELD_LMARGIN;
        $rflags_size = $FIELD_RMARGIN;
        $i           = 0;
        $nfields     = $#{ $form{fields} };
        while ( $i <= $#{ $form{fields} } ) {
            $id = $form{fields}[$i]{id};
            unless ( in( $id, @fields_to_remove ) ) {
                if ( in( $id, @fields_to_enable ) ) {
                    $form{fields}[$i]{enabled} = $YES;
                    trace("$INIT_ENABLE_FIELDS enabled field ID \"$id\"")
                      ;    #$LOG_FIELDS_VAL
                }
                if ( in( $id, @fields_to_disable ) ) {
                    $form{fields}[$i]{enabled} = $NO;
                    trace("$INIT_DISABLE_FIELDS disabled field ID \"$id\"")
                      ;    #$LOG_FIELDS_VAL
                }
                $label   = $form{fields}[$i]{label};
                $len     = $form{fields}[$i]{len};
                $hscroll = $form{fields}[$i]{hscroll};
                $hidden  = $form{fields}[$i]{hidden};
                $type    = $form{fields}[$i]{type};
                $default = $form{fields}[$i]{default};
                $script  = $form{fields}[$i]{help_script};
                $fpad    = $hidden ? $HFIELD_PAD : $FIELD_PAD;

                $all_ids .= " " if !( $form{fields}[$i]{option} );
                $all_ids .= "%{$id}" if $id !~ /^$FSEP_ID_PRFX/;
                if ( $type == $SEPARATOR and !defined($label) ) {
                    $label = $field_vals{$id} ? $field_vals{$id} : 'ERROR!';
                }
                if ( $LAYOUT == $SIMPLE ) {
                    $len = $COLS - ( 52 + $rflags_size + 2 )
                      if ( 52 + $len + $rflags_size + 2 > $COLS );
                }
                my $lflags_x = 0;
                my $label_x =
                  $lflags_x +
                  $lflags_size +
                  $form{fields}[$i]{htab} * $HTAB_COLS;
                my $dots_x = $label_x + length($label);
                my $val_x  = $FIELD_VALUE_POS;
                if ( $val_x == -1 ) {
                    $val_x = $COLS - $len - 1 - $rflags_size;
                }
                my $lvald_x  = $val_x - 1;
                my $rvald_x  = $val_x + $len;
                my $rflags_x = $COLS - $rflags_size;
                $val = '';
                $val = $default if defined($default);
                $val = $field_vals{$id} if defined( $field_vals{$id} );
                $val = substr( $val, 0, $len )
                  if ( $hscroll == $NO )
                  and ( length($val) > $len );

                $y += $form{fields}[$i]{vtab};
                $y = 0 if ( $y >= $mwinr );
                $field = new_field( 1, length($label), $y, $label_x, 0, 0 );
                if ( $field eq '' ) { fatal("new_field(LABEL $label) failed") }
                set_field_buffer( $field, 0, $label );
                field_opts_off( $field, O_ACTIVE );
                field_opts_off( $field, O_EDIT );
                set_field_fore( $field, $labelFg );
                set_field_back( $field, $labelBg );

                if ( !$y ) {
                    set_new_page( $field, 1 );
                    $npages++;
                }
                push @fp,   $field;
                push @fset, ${$field};

                $field = new_field( 1, $lflags_size, $y, $lflags_x, 0, 0 );
                if ( $field eq '' ) {
                    fatal("new_field(PRE_FLAGS $label) failed");
                }
                set_field_buffer( $field, 0,
                    sprintf( "%s ", $form{fields}[$i]{required} ? '*' : ' ' ) );
                field_opts_off( $field, O_ACTIVE );
                if ( !$SHOW_FIELD_FLAGS ) {
                    field_opts_off( $field, O_VISIBLE );
                }
                field_opts_off( $field, O_VISIBLE ) if ( $type == $SEPARATOR );
                push @fp,   $field;
                push @fset, ${$field};

                $field = new_field( 1, $rflags_size, $y, $rflags_x, 0, 0 );
                if ( $field eq '' ) {
                    fatal("new_field(POST_FLAGS $label) failed");
                }
                set_field_buffer(
                    $field, 0,
                    sprintf( "%s%s",
                        $form{fields}[$i]{list_cmd}             ? '+' : ' ',
                        ( $form{fields}[$i]{type} == $NUMERIC ) ? '#' : ' ' )
                );
                field_opts_off( $field, O_ACTIVE );
                if ( !$SHOW_FIELD_FLAGS ) {
                    field_opts_off( $field, O_VISIBLE );
                }
                field_opts_off( $field, O_VISIBLE ) if ( $type == $SEPARATOR );
                push @fp,   $field;
                push @fset, ${$field};

                $field = new_field( 1, 1, $y, $lvald_x, 0, 0 );
                if ( $field eq '' ) {
                    fatal("new_field(BEGIN_DELIMITER $label) failed");
                }
                if ( $form{fields}[$i]{enabled} ) {
                    set_field_buffer( $field, 0, $fval_delim[0] );
                }
                else {
                    set_field_buffer( $field, 0, ' ' );
                }
                field_opts_off( $field, O_ACTIVE );
                field_opts_off( $field, O_EDIT );
                set_field_fore( $field, A_STDOUT );
                set_field_back( $field, A_NORMAL );
                field_opts_off( $field, O_VISIBLE ) if ( $type == $SEPARATOR );
                push @fp,   $field;
                push @fset, ${$field};
                $field = new_field( 1, 1, $y, $rvald_x, 0, 0 );

                if ( $field eq '' ) {
                    fatal("new_field(END_DELIMITER $label) failed");
                }
                if ( $form{fields}[$i]{enabled} ) {
                    if ( length($val) > $len ) {
                        set_field_buffer( $field, 0, '>' );
                    }
                    else {
                        set_field_buffer( $field, 0, $fval_delim[1] );
                    }
                }
                else {
                    set_field_buffer( $field, 0, ' ' );
                }
                field_opts_off( $field, O_ACTIVE );
                field_opts_off( $field, O_EDIT );
                set_field_fore( $field, A_STDOUT );
                set_field_back( $field, A_NORMAL );
                field_opts_off( $field, O_VISIBLE ) if ( $type == $SEPARATOR );
                push @fp,   $field;
                push @fset, ${$field};

                if ($SHOW_DOTS) {
                    $dots = '';
                    for ( $c = $dots_x - 1 ; $c < $lvald_x - 2 ; $c++ ) {
                        $dots .= ( $c % 2 ) ? '.' : ' ';
                    }
                    $dots .= ': ';
                }
                else {
                    $dots = ' ';
                }
                $field = new_field( 1, length($dots), $y, $dots_x, 0, 0 );
                if ( $field eq '' ) { fatal("new_field(DOTS $label) failed") }
                set_field_buffer( $field, 0, $dots );
                field_opts_off( $field, O_ACTIVE );
                field_opts_off( $field, O_EDIT );
                field_opts_off( $field, O_VISIBLE ) if ( $type == $SEPARATOR );
                push @fp,   $field;
                push @fset, ${$field};

                $field = new_field( 1, $len, $y, $val_x, 0, 1 );
                if ( $field eq '' ) { fatal("new_field(VAL $label) failed") }
                field_opts_off( $field, O_AUTOSKIP );
                unless ( $form{fields}[$i]{enabled} ) {
                    field_opts_off( $field, O_ACTIVE );
                }
                elsif ( !( $type & $BOOLEAN ) ) {
                    set_field_pad( $field, $fpad );
                }
                if ($hscroll) {
                    field_opts_off( $field, O_STATIC );
                }
                else {
                    field_opts_on( $field, O_STATIC );
                }
                if ($hidden) {
                    field_opts_off( $field, O_PUBLIC );
                }
                else {
                    field_opts_on( $field, O_PUBLIC );
                }
                set_field_buffer( $field, 0, $val );
                set_field_buffer( $field, 1, $val );
                $form{fields}[$i]{value} = $val;
                if ( $LAYOUT == $NORMAL and $type == $NUMERIC ) {
                    set_field_just( $field, JUSTIFY_RIGHT );
                }

                if ( $form{fields}[$i]{enabled} ) {
                    set_field_fore( $field, $form{fields}[$i]{valueFg} );
                    set_field_back( $field, $form{fields}[$i]{valueBg} );
                }
                else {
                    set_field_fore( $field, $labelFg );
                    set_field_back( $field, $labelBg );
                }
                $y++;
                field_opts_off( $field, O_VISIBLE ) if ( $type == $SEPARATOR );
                push @fp, $field;
                $form{fields}[$i]{ptr} = $field;
                push @fset, ${$field};
                $i++;
            }
            else {
                splice @{ $form{fields} }, $i, 1;
                trace("$INIT_REMOVE_FIELDS removed field ID \"$id\"")
                  ;    #$LOG_FIELDS_VAL
            }
        }
        push @fset, 0;

        $cform = new_form( pack 'L!*', @fset );
        if ( $cform eq '' ) { fatal("do_form.new_form() failed") }

        scale_form( $cform, $rows, $cols );
        $fsub =
          derwin( $win, $mwinr, $COLS, $FS_HEADER_ROWS + $FS_TOP_ROWS, 0 );

        set_form_win( $cform, $win );
        set_form_sub( $cform, $fsub );

        form_opts_off( $cform, O_BS_OVERLOAD );
        keypad( $win, $ON );

        $form{action} =~ s/%{$ALL_FIELDS_IDS_TAG}/$all_ids/;
        $i = 0;
        while ( !$form{fields}[$i]{enabled} ) {
            $i++;
        }
        set_field_fore( $fp[ $i * 7 ], $af_labelFg );
        set_field_back( $fp[ $i * 7 ], $af_labelBg );
        set_field_fore( $fp[ $i * 7 + 6 ], $af_valueFg );
        set_field_back( $fp[ $i * 7 + 6 ], $af_valueBg );

        $title = $form{title} if $form{title};
        init_title( $win, $FS_HEADER_ROWS, $title );
        disp_page( $win, form_page($cform) + 1, $npages, 'form', $formname );
        init_top( $win, $NO, $FS_HEADER_ROWS, $FS_TOP_ROWS, @{ $form{top} } );
        init_footer( $win, $NO, $FS_FOOTER_ROWS, @FSKeys );
        post_form($cform);
        if ($ovl_mode) {
            form_driver( $cform, REQ_OVL_MODE );
        }
        else {
            form_driver( $cform, REQ_INS_MODE );
        }
        form_driver( $cform, REQ_END_LINE );
        refresh($win);
        curs_set($ON) if $HIDE_CURSOR;

        $es = $OK_ES;
        while ( $es != $ES_EXIT and !defined($exec_args) ) {
          SWITCH: {
                my $fi    = int( field_index( current_field($cform) ) / 7 );
                my $ftype = $form{fields}[$fi]{type};
                if ( $ftype & $BOOLEAN ) {
                    $ch_set = $ch_boolean;
                    last SWITCH;
                }
                if ( $ftype & $STRING ) {
                    $ch_set = $ch_string;
                    last SWITCH;
                }
                if ( $ftype & $NUMERIC ) {
                    $ch_set = $ch_numeric;
                    last SWITCH;
                }
            }

            if ( data_behind($cform) ) {
                set_field_buffer(
                    $fp[ field_index( current_field($cform) ) - 3 ],
                    0, '<' );
            }
            else {
                set_field_buffer(
                    $fp[ field_index( current_field($cform) ) - 3 ],
                    0, $fval_delim[0] );
            }
            if ( data_ahead($cform) ) {
                set_field_buffer(
                    $fp[ field_index( current_field($cform) ) - 2 ],
                    0, '>' );
            }
            else {
                set_field_buffer(
                    $fp[ field_index( current_field($cform) ) - 2 ],
                    0, $fval_delim[1] );
            }

            $ch = getch($win);

            if ( $ch == KEY_UP or $ch == KEY_DOWN ) {
                set_field_attr;
                form_driver( $cform, REQ_NEXT_FIELD ) if $ch == KEY_DOWN;
                form_driver( $cform, REQ_PREV_FIELD ) if $ch == KEY_UP;
                set_field_active_attr;
                form_driver( $cform, REQ_END_LINE );
            }
            elsif ( $ch == KEY_LEFT ) {
                form_driver( $cform, REQ_LEFT_CHAR );
            }
            elsif ( $ch == KEY_RIGHT ) {
                form_driver( $cform, REQ_RIGHT_CHAR );
            }
            elsif ( $ch == KEY_NPAGE ) {
                set_field_attr;
                form_driver( $cform, REQ_NEXT_PAGE );
                set_field_active_attr;
                form_driver( $cform, REQ_END_LINE );
                disp_page( $win, form_page($cform) + 1,
                    $npages, 'form', $formname );
                refresh($fsub);
            }
            elsif ( $ch == KEY_PPAGE ) {
                if ( $npages > 1 ) {
                    set_field_attr;
                    form_driver( $cform, REQ_PREV_PAGE );

                    $i = field_index( current_field($cform) ) + 1;
                    while ( $i <= $#fp && !new_page( $fp[$i] ) ) {
                        $i++;
                    }
                    set_current_field( $cform, $fp[ $i - 1 ] );

                    set_field_active_attr;
                    form_driver( $cform, REQ_END_LINE );
                    disp_page( $win, form_page($cform) + 1,
                        $npages, 'form', $formname );
                    refresh($fsub);
                }
            }
            elsif ( $ch == KEY_HOME ) {
                form_driver( $cform, REQ_BEG_FIELD );
            }
            elsif ( $ch == KEY_END ) {
                form_driver( $cform, REQ_END_FIELD );
            }
            elsif ( $ch == KEY_BACKSPACE ) {
                form_driver( $cform, REQ_DEL_PREV );
                check_val_changes;
            }
            elsif ( $ch == KEY_DC ) {
                form_driver( $cform, REQ_DEL_CHAR );
                check_val_changes;
            }
            elsif ( $ch == KEY_IC ) {
                if ($ovl_mode) {
                    $ovl_mode = $FALSE;
                    form_driver( $cform, REQ_INS_MODE );
                }
                else {
                    $ovl_mode = $TRUE;
                    form_driver( $cform, REQ_OVL_MODE );
                }
                disp_page( $win, form_page($cform) + 1,
                    $npages, 'form', $formname );
            }
            elsif ( $ch eq "\t" or $ch == KEY_BTAB ) {
                my ( $name, $newidx );
                my $fi     = int( field_index( current_field($cform) ) / 7 );
                my @vals   = ();
                my @list   = ();
                my $actval = field_buffer( current_field($cform), 0 );
                $actval =~ s/\s+$//;
                $actval =~ s/^\s+//;
                my ( $action, $type, $args ) = split /:/,
                  $form{fields}[$fi]{list_cmd}, 3;

                if ( lc($action) eq 'const' and lc($type) eq 'single-val' ) {
                    $args =~ s/^ *"//;
                    $args =~ s/" *$//;
                    @list = split /" *, *"/, $args;
                    foreach my $s (@list) {
                        ( $name, undef ) = split /(?<!\\) /, $s, 2;
                        $name =~ s/\\ / /g;
                        $name = ' ' if $name eq '';
                        push @vals, $name;
                    }
                    if ( $ch eq "\t" ) {
                        $newidx = 0;
                        for $i ( 0 .. $#vals ) {
                            $newidx++;
                            last if $vals[ $newidx - 1 ] eq $actval;
                        }
                        $newidx = 0 if ( $newidx > $#vals );
                    }
                    elsif ( $ch == KEY_BTAB ) {
                        $newidx = $#vals;
                        for $i ( 0 .. $#vals ) {
                            $newidx--;
                            last if $vals[ $newidx + 1 ] eq $actval;
                        }
                        $newidx = $#vals if ( $newidx < 0 );
                    }
                    if ( $form{fields}[$fi]{type} & $BOOLEAN ) {
                        set_field_buffer( current_field($cform), 0,
                            ralign( $vals[$newidx], $BOOLEAN_FIELD_SIZE ) );
                    }
                    else {
                        set_field_buffer( current_field($cform), 0,
                            $vals[$newidx] );
                    }
                    form_driver( $cform, REQ_END_FIELD );
                    check_val_changes;
                }
                else {
                    trace("unknown list_cmd action/type \"$action\"/\"$type\"");
                    beep();
                }
            }
            elsif ( $ch eq "\r" or $ch eq "\n" ) {
                sync_fields_val;

                my $empty_required = $NO;
                foreach $i ( 0 .. $#{ $form{fields} } ) {
                    if (    $form{fields}[$i]{required}
                        and $form{fields}[$i]{value} eq '' )
                    {
                        $empty_required = $YES;
                        curs_set($OFF) if $HIDE_CURSOR;
                        disp_msg(
                            $win,
                            "\"$form{fields}[$i]{label}\" $ERR_EMPTY_FIELD_MSG",
                            $ERR_EMPTY_FIELD_TITLE
                        );
                        curs_set($ON) if $HIDE_CURSOR;
                        last;
                    }
                }

                unless ($empty_required) {
                    ( $action, $args ) = split /:/, $form{action}, 2;
                    $action =~ s/^\s+//;
                    $action = lc $action;

                    $action =~ /^([a-zA-Z]+)\(?([a-zA-Z_,]*)\)?$/;
                    $action = $1;
                    @actopts = split /,\s*/, $2;

                    $wait_key      = $NO;
                    $LOG_REQUESTED = $NO;
                    foreach $opt (@actopts) {
                      SWITCH: {
                            $_ = $opt;
                            if (/^confirm$/) {
                                my $val;
                                ( $es, $val ) =
                                  do_list( $win, $CONFIRM_TITLE, 'single-val',
                                    \@CONFIRM_ITEMS, undef );
                                if ( $val ne $BFIELD_YES ) {
                                    $action = 'ABORTED';
                                }
                                last SWITCH;
                            }
                            elsif (/^log$/) {
                                $LOG_REQUESTED = $YES;
                                last SWITCH;
                            }
                            elsif (/^wait_key$/) {
                                $wait_key = $YES;
                                last SWITCH;
                            }
                            else {
                                trace("unknown action option \"$_\"");
                            }
                        }
                    }
                    save_persistent;
                    if ( $action eq 'run' ) {
                        prepare_action( \$args );

                        trace("action: \"$action\":\n");
                        trace( "\n\n" . '-' x 80,
                            $LOG_ACTION_CMD + $LOG_NORMAL );
                        my ( $ss, $mm, $hh, $dd, $mt, $yy ) = localtime(time);
                        trace(
                            "DATE  : "
                              . sprintf( "%02d/%02d/%d, %02d:%02d:%02d\n",
                                $dd, ++$mt, 1900 + $yy, $hh, $mm, $ss )
                              . "SCREEN: $title  [$formname]\n"
                              . "DESCR : Action executed",
                            $LOG_ACTION_CMD + $LOG_NORMAL
                        );
                        trace( '-' x 80, $LOG_ACTION_CMD + $LOG_NORMAL );
                        trace( $args,    $LOG_ACTION_CMD + $LOG_NORMAL );
                        $es =
                          run_browse( $title, $args, $formname, $form{path} );
                        curs_set($ON) if $HIDE_CURSOR;
                    }
                    elsif ( $action eq 'form' ) {
                        foreach $i ( 0 .. $#{ $form{fields} } ) {
                            $id  = $form{fields}[$i]{id};
                            $val = $form{fields}[$i]{value};
                            $val  =~ s/^\s+//;
                            $val  =~ s/\s+$//;
                            $args =~ s/%\{$id\}/$val/g;
                        }

                        ( $called_form, $args ) = split /\s+/, $args, 2;
                        $args =~ s/^\s+//;
                        $args =~ s/\s+$//;
                        trace( "call form \"$called_form\", args \"$args\"",
                            $LOG_ACTION_CMD );
                        $es =
                          do_form( $called_form, $title, split /\s+/, $args );
                        if ( $es and $es < $ES_USER_REQ ) {
                            trace(
"WARNING: $es_str[$es] reading form \"$called_form\""
                            );
                            curs_set($OFF) if $HIDE_CURSOR;
                            disp_msg(
                                $win,
"$es_str[$es] $LOAD_FORM_ERR_MSG \"$called_form\"",
                                $FORM_ERR_TITLE
                            );
                            curs_set($ON) if $HIDE_CURSOR;
                        }
                    }
                    elsif ( $action eq 'system' ) {
                        prepare_action( \$args );
                        call_system( $wait_key, $args );
                    }
                    elsif ( $action eq 'exec' ) {
                        prepare_action( \$args );
                        $exec_args = $args;
                    }
                    else {
                        trace("unknown form action type \"$action\"");
                    }
                    $LOG_REQUESTED = $NO;
                }
            }
            elsif ( $ch == $keys{back}{code} or ord($ch) == 27 ) {
                $es = $ES_CANCEL;
                last;
            }
            elsif ( $ch == $keys{list}{code} ) {
                curs_set($OFF) if $HIDE_CURSOR;
                my $ci = int( field_index( current_field($cform) ) / 7 );
                if ( $form{fields}[$ci]{list_cmd} ) {
                    my $val;
                    my @list          = ();
                    my @err           = ();
                    my $multi_val_sep = $form{fields}[$ci]{list_sep};
                    my ( $action, $type, $args ) = split /:/,
                      $form{fields}[$ci]{list_cmd}, 3;
                    if ( lc($action) eq 'command' ) {
                        my ( $wpan, $wwin ) = open_wait_msg;
                        trace( "raw list_cmd: \"$args\"", $LOG_LIST_CMD );

                        foreach $i ( 0 .. $#{ $form{fields} } ) {
                            my $id  = $form{fields}[$i]{id};
                            my $val = '';
                            unless ( $form{fields}[$i]{type} & $BOOLEAN ) {
                                $val =
                                  field_buffer( $form{fields}[$i]{ptr}, 0 );
                                $val =~ s/^\s+//;
                                $val =~ s/\s+$//;
                            }
                            $args =~ s/%\{$id\}/$val/g;
                        }
                        trace(
"list_cmd after field(s) value substitution: \"$args\"",
                            $LOG_LIST_CMD
                        );

                        unless (
                            exec_command( $args, $form{path}, \@list, \@err ) )
                        {
                            trace( "error generating list:", $LOG_LIST_CMD );
                            trace( "\"" . join( "\"\n\"", @err ) . "\"",
                                $LOG_LIST_CMD );
                            ($es) =
                              do_list( $win, 'Error', 'display', \@err, undef );
                            @list = ();
                        }
                        close_wait_msg( $wpan, $wwin, $win );
                    }
                    elsif ( lc($action) eq 'const' ) {
                        $args =~ s/^ *"//;
                        $args =~ s/" *$//;
                        @list = split /" *, *"/, $args;
                    }
                    else {
                        trace("unknown list_cmd action type \"$action\"");
                    }
                    if (@list) {
                        my @selected = ();
                        if ( $type eq 'multi-val' ) {
                            $_ = field_buffer( current_field($cform), 0 );
                            s/\s+$//;
                            @selected = split /$multi_val_sep/;
                        }
                        ( $es, @selected ) =
                          do_list( $win, $form{fields}[$ci]{label},
                            $type, \@list, \@selected );
                        $val = join( $multi_val_sep, @selected );
                        if ( $es == $ES_EXIT ) {
                            $ch = $keys{exit}{code};
                            last;
                        }
                    }
                    else {
                        trace( "empty list by list_cmd", $LOG_LIST_CMD );
                        disp_msg( $win, $NULL_LIST_MSG, $NULL_LIST_TITLE );
                    }
                    if ( $form{fields}[$ci]{type} & $BOOLEAN ) {
                        $val = ralign( $val, $BOOLEAN_FIELD_SIZE );
                    }
                    if ( $es != $ES_CANCEL and $es != $ES_EXIT ) {
                        set_field_buffer( current_field($cform), 0, $val );
                        check_val_changes;
                        form_driver( $cform, REQ_END_FIELD );
                    }
                }
                else {
                    disp_msg( $win, $NULL_LIST_MSG, $NULL_LIST_TITLE );
                }
                curs_set($ON) if $HIDE_CURSOR;
            }
            elsif ( $ch == $keys{show_action}{code} ) {
                sync_fields_val;
                my $args = $form{action};
                $args =~ s/^(\b*[a-zA-Z]+)\(?([a-zA-Z_,]*)\)?/$1/;
                if ($args) {
                    prepare_action( \$args );
                    my @cmd = split /\n/, $args;
                    curs_set($OFF) if $HIDE_CURSOR;
                    ($es) = do_list( $win, $SHOW_ACTION_TITLE, 'display', \@cmd,
                        undef );
                    curs_set($ON) if $HIDE_CURSOR;
                }
                else {
                    trace("ERROR: empty form action");
                    disp_msg( $win, $NULL_FACTION_MSG, $NULL_FACTION_TITLE );
                }
            }
            elsif ( $ch == $keys{reset_field}{code} ) {
                my $fi = int( field_index( current_field($cform) ) / 7 );
                set_field_buffer( current_field($cform), 0,
                    field_buffer( current_field($cform), 1 ) );
                $form{fields}[$fi]{changed} = $NO;
                $form{fields}[$fi]{valueFg} = $valueFg;
                $form{fields}[$fi]{valueBg} = $valueBg;
                set_field_fore( $fp[ field_index( current_field($cform) ) ],
                    $af_valueFg );
                set_field_back( $fp[ field_index( current_field($cform) ) ],
                    $af_valueBg );
                form_driver( $cform, REQ_END_LINE );
            }
            elsif ( $ch == $keys{save}{code} ) {
                sync_fields_val;
                $LOG_REQUESTED = $YES;
                trace( "\n\n" . '-' x 80, $LOG_NORMAL );
                my ( $ss, $mm, $hh, $dd, $mt, $yy ) = localtime(time);
                trace(
                    "DATE  : "
                      . sprintf( "%02d/%02d/%d, %02d:%02d:%02d\n",
                        $dd, ++$mt, 1900 + $yy, $hh, $mm, $ss )
                      . "SCREEN: $title  [$formname]\n"
                      . "DESCR : Save fields value",
                    $LOG_NORMAL
                );
                trace( '-' x 80, $LOG_NORMAL );
                my $maxlen = 0;
                foreach $i ( 0 .. $#{ $form{fields} } ) {
                    my $len = length( $form{fields}[$i]{label} )
                      if $form{fields}[$i]{type} != $SEPARATOR;
                    $maxlen = $len if $len > $maxlen;
                }
                foreach $i ( 0 .. $#{ $form{fields} } ) {
                    if ( $form{fields}[$i]{type} != $SEPARATOR ) {
                        my $buff = eval
                          "sprintf \"%-${maxlen}s\",\$form{fields}[\$i]{label}";
                        trace(
                            sprintf( "%s:'%s'",
                                $buff, $form{fields}[$i]{value} ),
                            $LOG_NORMAL
                        );
                    }
                }
                $LOG_REQUESTED = $NO;
                if ($@) {
                    chop($@);
                    disp_msg( $win, "$@ $LOG_WRITE_ERROR_MSG",
                        $LOG_WRITE_ERROR_TITLE );
                }
                else {
                    disp_msg( $win, $SAVE_FIELDVAL_MSG, $SAVE_FIELDVAL_TITLE );
                }
            }
            elsif ( $ch == $keys{shell_escape}{code} ) {
                if ( valid_shell($USER_SHELL) ) {
                    call_shell;
                    refresh($win);
                }
                else {
                    disp_msg( $win, $BAD_SHELL_MSG, $BAD_SHELL_TITLE );
                }
            }
            elsif ( $ch == $keys{redraw}{code} ) {
                refresh(curscr);
            }
            elsif ( $ch == $keys{exit}{code} ) {
                $es = $ES_EXIT;
                last;
            }
            elsif ( $ch >= KEY_F(1) and $ch <= KEY_F(12) ) {
                beep();
            }
            elsif ( $ch =~ /$ch_set/ ) {
                form_driver( $cform, REQ_VALIDATION );
                my $ci = int( field_index( current_field($cform) ) / 7 );
                if ( $form{fields}[$ci]{type} == $UCSTRING ) {
                    form_driver( $cform, ord( uc($ch) ) );
                }
                else {
                    form_driver( $cform, ord($ch) );
                }
                check_val_changes;
            }
            else {
                beep();
            }
        }

        unpost_form($cform);
        del_panel($pan);
        delwin($win);
        free_form($cform);
        map { free_field($_) } @fp;
        @fp   = ();
        @fset = ();
        %form = ();
        undef %form;

    }
    return $es;
}

sub round {
    my ($num) = @_;
    return sprintf( "%.0f", $num );
}

sub run_browse {
    my ( $title, $cmd, $save_fname, $extra_path ) = @_;

    local ($search_string);
    my ( $infh, $outfh, $errfh, $buff, $srbuff, $fh, $nr, $sel );
    my $is_partial = 0;
    my $outprev;
    my $errprev;
    my ( $out_lines, $err_lines );
    my ( $npages, $pg, $src );
    my @lines;
    my @ready;
    my ( $py, $c, $pan, $ch, $win, $hwin );
    my ( $es,         $status_fg_attr, $status_bg_attr );
    my ( $start_time, $end_time,       $exec_time );
    my ( $prev_path,  $prev_wdir );
    local ( $exec_ss, $exec_mm, $exec_hh );
    local ( $p, $mwin, $twin, $mwinr );
    my $cmd_descr = $title;

    sub get_search_buff {
        my ($row) = @_;
        my ( $buff, $chbuff, $row1, $c, $ln );

        $buff = '';
        $row1 = $row + ( $row < $pad_lines ? 1 : 0 );
        for $ln ( $row .. $row1 ) {
            for $c ( 0 .. $COLS - 1 ) {
                inchnstr( $p, $ln, $c, $chbuff, 1 );
                $buff .= $chbuff;
            }
        }
        return $buff;
    }

    sub search_next {
        my ($row_ptr) = @_;
        my ( $buff, $pos0, $prev_row );

        $prev_row = $$row_ptr;
        $pos0     = -1;
        while ( $$row_ptr <= $pad_lines and $pos0 <= 0 ) {
            $$row_ptr++;
            $buff = get_search_buff($$row_ptr);
            $buff =~ m/$search_string/g;
            $pos0 = pos($buff) - length($search_string);
            $pos0 = -1 if ( $pos0 > $COLS );
        }
        if ( $$row_ptr > $pad_lines ) {
            $$row_ptr = $prev_row;
            disp_msg( $p, $FOUND_NONE_MSG, $FOUND_NONE_TITLE );
        }
    }

    sub search_all {
        my ( $buff, $pos0, $row, $nfound );

        $nfound = 0;
        for $row ( 0 .. $pad_lines ) {
            $pos0 = -1;
            $buff = get_search_buff($row);
            do {
                $buff =~ m/$search_string/g;
                $pos0 = pos($buff) - length($search_string);
                $pos0 = -1 if ( $pos0 > $COLS );
                if ( $pos0 >= 0 ) {
                    $nfound++;
                    chgat( $p, $row, $pos0, length($search_string), A_REVERSE,
                        NULL, NULL );
                    if ( $pos0 + length($search_string) >= $COLS ) {
                        chgat( $p, $row + 1, 0,
                            $pos0 + length($search_string) - $COLS,
                            A_REVERSE, NULL, NULL );
                    }
                }
            } while ( $pos0 >= 0 );
        }
        if ( !$nfound and ( $pad_lines <= $mwinr ) ) {
            disp_msg( $p, $FOUND_NONE_MSG, $FOUND_NONE_TITLE );
        }
    }

    sub load_pad {
        my ( $src, $buff );
        my $c = 0;

        move( $p, 0, 0 );
        seek( $tmpfh, 0, 0 );
        while ( $buff = <$tmpfh> and $c <= $pad_lines ) {
            $c++;
            ( $src, $buff ) = split /:/, $buff, 2;
            if ( length($buff) == $COLS + 1 ) {
                chop($buff);
                $pad_lines--;
            }
            if ( $src eq $RS_STDOUT_ID ) {
                attrset( $p, $RS_STDOUT_ATTR );
            }
            elsif ( $src eq $RS_STDERR_ID ) {
                attrset( $p, $RS_STDERR_ATTR );
            }
            elsif ( $src eq $RS_INFO_ID ) {
                attrset( $p, $RS_INFO_ATTR );
            }
            addstr( $p, $buff );
        }
    }

    $child_es = 0;

    if ( $LAYOUT == $SIMPLE ) {
        $status_fg_attr = A_NORMAL;
        $status_bg_attr = A_NORMAL;
    }
    else {
        $status_fg_attr = A_REVERSE;
        $status_bg_attr = A_REVERSE;
    }

    $prev_path = $ENV{PATH};
    chomp( $prev_wdir = `pwd` );
    chdir "$SCREEN_DIR";
    trace( "Changed CWD from $prev_wdir to " . substr( `pwd`, 0, -1 ) );
    $ENV{PATH} = sprintf "%s%s:.", $MAIN_PATH, $MAIN_PATH ? ":$PATH" : '';
    if ($extra_path) {
        my @dirs = split /:/, $extra_path;
        foreach $i ( 0 .. $#dirs ) {
            $dirs[$i] = "$SCREEN_DIR/$dirs[$i]" unless $dirs[$i] =~ /^\//;
        }
        $extra_path = join( ':', @dirs );
    }
    $ENV{PATH} .= ":$extra_path" if $extra_path;
    $ENV{COLUMNS} = $COLS;
    trace( "PATH=\"$ENV{PATH}\"", $LOG_SYSCALL_ENV );
    trace("run \"$cmd\"");

    $mwinr = $LINES -
      ( $RS_HEADER_ROWS + $RS_TOP_ROWS + $RS_BOTTOM_ROWS + $RS_FOOTER_ROWS );
    $win = newwin( $LINES, $COLS, 0, 0 );
    $mwin = subwin( $win, $mwinr, $COLS, $RS_HEADER_ROWS + $RS_TOP_ROWS, 0 );
    $hwin = subwin( $win, $RS_HEADER_ROWS, $COLS, 0,               0 );
    $twin = subwin( $win, $RS_TOP_ROWS,    $COLS, $RS_HEADER_ROWS, 0 );
    $pan  = new_panel($win);

    init_title( $hwin, $RS_HEADER_ROWS, $RB_TITLE );
    init_footer( $win, $NO, $RS_FOOTER_ROWS, qw(int) );

    scrollok( $mwin, 1 );
    keypad( $mwin, $ON );
    nodelay( $mwin, 1 );

    bkgd( $twin, $status_bg_attr );
    addstr( $twin, 0, 0, "Status: $RB_RUNNING_MSG" );
    refresh($win);
    refresh($mwin);

    my $save_crsr = curs_set($OFF);
    curs_set($ON);

    $start_time = time;
    $errfh      = gensym();
    eval { $cpid = open3( $infh, $outfh, $errfh, $OPEN3_SHELL, '-c', $cmd ); };
    fatal($@) if $@;
    trace("successfully forked child PID $cpid");
    $sel = new IO::Select;
    $sel->add( $outfh, $errfh );

    $tmpfh = tempfile( 'ccfeXXXXX', DIR => '/tmp' );
    if ( !defined($tmpfh) ) {
        fatal("Error creating temporary file: $!");
    }
    trace( "----BEGIN OUTPUT" . '-' x 54, $LOG_ACTION_OUT );
    print $tmpfh "$RS_INFO_ID:\n";
    addstr( $mwin, "\n" );
    refresh($mwin);
    $pad_lines = 1;

    $err_lines = $out_lines = 0;
    while ( @ready = $sel->can_read ) {
        foreach $fh (@ready) {
            $nr = sysread $fh, $srbuff, $SR_BUFF_SIZE;
            $srbuff =~ s/\r//g;
            if ( not defined $nr ) {
                fatal("Error from child $pid: $!");
            }
            elsif ( $nr == 0 ) {
                $sel->remove($fh);
                next;
            }
            else {
                if ( $fh == $outfh ) {
                    $src        = $RS_STDOUT_ID;
                    $buff       = $outprev . $srbuff;
                    $is_partial = ( $buff !~ /\n$/ );
                    @lines      = split /\n/, $buff . ".";
                    $lines[$#lines] =~ s/\.$//;
                    pop @lines if !$lines[$#lines];
                    $outprev = $is_partial ? pop @lines : undef;
                    $out_lines += scalar @lines;
                    attrset( $mwin, $RS_STDOUT_ATTR );
                }
                elsif ( $fh == $errfh ) {
                    $src        = $RS_STDERR_ID;
                    $buff       = $errprev . $srbuff;
                    $is_partial = ( $buff !~ /\n$/ );
                    @lines      = split /\n/, $buff . ".";
                    $lines[$#lines] =~ s/\.$//;
                    pop @lines if !$lines[$#lines];
                    $errprev = $is_partial ? pop @lines : undef;
                    $err_lines += scalar @lines;
                    attrset( $mwin, $RS_STDERR_ATTR );
                }
                else {
                    fatal("Unknown filehandle");
                }
            }
            foreach $s (@lines) {
                $pad_lines += length($s) ? round( length($s) / $COLS + .5 ) : 1;
                print $tmpfh "$src:$s\n";
                trace( "$src:$s", $LOG_ACTION_OUT );
            }
            addstr( $mwin, $srbuff );
            refresh($mwin);
        }
    }
    if ( defined($outprev) ) {
        $out_lines++;
        $pad_lines +=
          length($outprev) ? round( length($outprev) / $COLS + .5 ) : 1;
        print $tmpfh "$RS_STDOUT_ID:$outprev\n";
        trace( "$RS_STDERR_ID:$s", $LOG_ACTION_OUT );
        addstr( $mwin, $outprev );
    }
    if ( defined($errprev) ) {
        $err_lines++;
        $pad_lines +=
          length($errprev) ? round( length($errprev) / $COLS + .5 ) : 1;
        print $tmpfh "$RS_STDERR_ID:$errprev\n";
        trace( "$RS_STDERR_ID:$s", $LOG_ACTION_OUT );
        addstr( $mwin, $errprev );
    }
    refresh($mwin);

    waitpid $cpid, 0;
    undef $cpid;
    $end_time  = time;
    $exec_time = $end_time - $start_time;

    $exec_ss = $exec_time % 60;
    $exec_time /= 60;
    $exec_mm = $exec_time % 60;
    $exec_hh = $exec_time / 60;

    trace( "----END OUTPUT" . '-' x 56, $LOG_ACTION_OUT );
    $ENV{PATH} = $prev_path;
    chdir "$prev_wdir";
    trace( "Restored CWD to " . substr( `pwd`, 0, -1 ) );
    if ($END_MARKER) {
        print $tmpfh "$RS_INFO_ID:$END_MARKER";
        $pad_lines++;
    }

    if ( $pad_lines > $MAX_PAD_LINES ) {
        disp_msg( $win, $BIG_OUTPUT_MSG, $BIG_OUTPUT_TITLE );
        $pad_lines = $MAX_PAD_LINES;
    }
    elsif ( $pad_lines < $mwinr ) {
        $pad_lines = $mwinr;
    }
    trace("Allocating ${pad_lines}x$COLS pad buffer");
    $p = newpad( $pad_lines, $COLS );
    keypad( $p, 1 );
    load_pad;

    delwin($mwin);
    init_footer( $win, $NO, $RS_FOOTER_ROWS, @RSKeys );
    curs_set($OFF) if $HIDE_CURSOR;
    addstr( $twin, 0, 0, "Status: " );
    attron( $twin, A_REVERSE ) if ( $LAYOUT == $SIMPLE );
    addstr( $twin, $child_es ? $RB_FAILED_MSG : $RB_OK_MSG );
    attroff( $twin, A_REVERSE ) if ( $LAYOUT == $SIMPLE );
    addstr( $twin, $child_es ? ' ' : '     ' );
    addstr(
        $twin,
        sprintf(
            "[ES=%d]   stdout: %d %s   " . "stderr: %d %s   %s: %02d:%02d:%02d",
            $child_es,  $out_lines,    $RB_LINES_MSG,
            $err_lines, $RB_LINES_MSG, $RB_TIME_MSG,
            $exec_hh,   $exec_mm,      $exec_ss
        )
    );
    clrtoeol($twin);
    refresh($twin);
    refresh($win);

    $search_string = '';
    $npages = round( $pad_lines / $mwinr + ( $pad_lines % $mwinr ? .5 : 0 ) );
    $py     = 0;
    while (1) {
        $pg = round( ( $py + 1 ) / $mwinr + ( ( $py + 1 ) % $mwinr ? .5 : 0 ) );
        disp_page( $hwin, $pg, $npages, 'browser', '' );
        refresh($hwin);
        move( $p, $py + $mwinr - 1, $COLS - 1 );
        prefresh(
            $p, $py, 0, $RS_HEADER_ROWS + $RS_TOP_ROWS,
            0, $RS_HEADER_ROWS + $RS_TOP_ROWS + $mwinr - 1,
            $COLS - 1
        );
        $ch = getch($p);
        if ( $ch == KEY_UP ) {
            $py-- if $py > 0;
        }
        if ( $ch == KEY_DOWN ) {
            $py++ if $py < $pad_lines - $mwinr;
        }
        elsif ( $ch == KEY_PPAGE ) {
            my $c = $mwinr;
            while ( $py > 0 and $c > 0 ) {
                $py--;
                $c--;
            }
        }
        elsif ( $ch == KEY_NPAGE ) {
            my $c = $mwinr;
            while ( $py < $pad_lines - $mwinr and $c > 0 ) {
                $py++;
                $c--;
            }
        }
        elsif ( $ch == KEY_HOME ) {
            $py = 0;
        }
        elsif ( $ch == KEY_END ) {
            $py = $pad_lines - $mwinr;
            $py = 0 if $py < 0;
        }
        elsif ( $ch == $keys{shell_escape}{code} ) {
            if ( valid_shell($USER_SHELL) ) {
                curs_set($ON) if $HIDE_CURSOR;
                call_shell;
                curs_set($OFF) if $HIDE_CURSOR;
                refresh($win);
            }
            else {
                disp_msg( $win, $BAD_SHELL_MSG, $BAD_SHELL_TITLE );
            }
        }
        elsif ( $ch == $keys{show_action}{code} ) {
            my @buff = split /\n/, $cmd;
            ($es) =
              do_list( $win, $SHOW_ACTION_TITLE, 'display', \@buff, undef );
        }
        elsif ( $ch == $keys{back}{code} or ord($ch) == 27 ) {
            last;
        }
        elsif ( $ch == $keys{exit}{code} ) {
            $es = $ES_EXIT;
            last;
        }
        elsif ( $ch == $keys{redraw}{code} ) {
            refresh(curscr);
        }
        elsif ( $ch == $keys{save}{code} ) {
            trim( \$cmd_descr );
            $save_fname = basename($save_fname);
            my $val;
            ( $es, $val ) = do_list(
                $win,
                $SAVE_TYPE_TITLE,
                'single-val',
                [
                    "$SAVE_SIMPLE $SAVE_SIMPLE_DESCR",
                    "$SAVE_DETAILED $SAVE_DETAILED_DESCR",
                    "$SAVE_SCRIPT $SAVE_SCRIPT_DESCR"
                ],
                undef
            );
            prefresh(
                $p, $py, 0, $RS_HEADER_ROWS + $RS_TOP_ROWS,
                0, $RS_HEADER_ROWS + $RS_TOP_ROWS + $mwinr - 1,
                $COLS - 1
            );
            if ($val) {
                my $fname = "$ENV{HOME}/$save_fname.out";
                $fname = "$ENV{HOME}/$save_fname." . basename($OPEN3_SHELL)
                  if ( $val eq $SAVE_SCRIPT );
                ( $es, $fname ) =
                  ask_string( $SAVE_FNAME_TITLE, $SAVE_FNAME_PROMPT, $fname );
                if ( $es == $ES_EXIT ) {
                    $ch = $keys{exit}{code};
                    last;
                }
                refresh($win);
                if ( $es != $ES_CANCEL ) {
                    seek( $tmpfh, 0, 0 );
                    eval {
                        open( OUTF, ">$fname" ) or die('DIED');
                        if ( $val eq $SAVE_SIMPLE ) {
                            while (<$tmpfh>) {
                                print OUTF
                                  if s/(^$RS_STDOUT_ID:)|(^$RS_STDERR_ID:)//;
                            }
                        }
                        elsif ( $val eq $SAVE_DETAILED ) {
                            print OUTF '=' x 80 . "\n";
                            print OUTF "DESCRIPTION: $cmd_descr\n";
                            print OUTF "EXTRA PATH : ",
                              $extra_path ? $extra_path : 'none', "\n";
                            print OUTF "START TIME : ",
                              scalar localtime($start_time), "\n";
                            print OUTF "END TIME   : ",
                              scalar localtime($end_time), "\n";
                            printf OUTF "EXEC TIME  : %02dh %02dm %02ds\n",
                              $exec_hh, $exec_mm,
                              $exec_ss;
                            print OUTF "EXIT STATUS: ", $child_es, "\n";
                            print OUTF "STDOUT     : ", $out_lines,
                              " line(s)\n";
                            print OUTF "STDERR     : ", $err_lines,
                              " line(s)\n";
                            print OUTF
                              "LINE PREFIX: std(O)ut  std(E)rr  (C)CFE\n";
                            print OUTF "COMMAND:\n$cmd\n";
                            print OUTF '=' x 80 . "\n";

                            while (<$tmpfh>) {
                                print OUTF or die('DIED');
                            }
                        }
                        elsif ( $val eq $SAVE_SCRIPT ) {
                            print OUTF "#!$OPEN3_SHELL\n";
                            print OUTF "# $cmd_descr\n";
                            print OUTF "$cmd\n";
                            chmod 0755, $fname;
                        }
                        close(OUTF) or die('DIED');
                        if ( $val eq $SAVE_SCRIPT ) {
                            chmod 0755, $fname;
                        }
                        else {
                            chmod 0644, $fname;
                        }
                    };
                    if ($@) {
                        prefresh(
                            $p,
                            $py,
                            0,
                            $RS_HEADER_ROWS + $RS_TOP_ROWS,
                            0,
                            $RS_HEADER_ROWS + $RS_TOP_ROWS + $mwinr - 1,
                            $COLS - 1
                        );
                        my $err = $!;
                        trace("WARNING: error opening file $fname: $err");
                        disp_msg( $win, "$err $SAVE_ERROR_MSG $fname",
                            $SAVE_ERROR_TITLE );
                    }
                }
            }
            if ( $es == $ES_EXIT ) {
                $ch = $keys{exit}{code};
                last;
            }
        }
        elsif ( $ch eq '/' ) {
            ( $es, $search_string ) =
              ask_string( $SEARCH_PTRN_TITLE, $SEARCH_PTRN_PROMPT,
                $search_string );
            if ( $es == $ES_EXIT ) {
                $ch = $keys{exit}{code};
                last;
            }
            refresh($win);
            prefresh(
                $p, $py, 0, $RS_HEADER_ROWS + $RS_TOP_ROWS,
                0, $RS_HEADER_ROWS + $RS_TOP_ROWS + $mwinr - 1,
                $COLS - 1
            );
            unless ( $es == $ES_CANCEL ) {
                load_pad if ($search_string);
                search_all;
                search_next( \$py ) if $pad_lines > $mwinr;
            }
        }
        elsif ( $ch eq 'n' ) {
            search_next( \$py );
            $py = $pad_lines - $mwinr if $py > $pad_lines - $mwinr;
            $py = 0 if $py < 0;
        }
        else {
            beep();
        }
    }
    close($tmpfh);

    del_panel($pan);
    delwin($p);
    delwin($hwin);
    delwin($twin);
    delwin($win);
    curs_set($save_crsr);

    return $es;
}

sub get_shortcut {
    my ($shcut) = @_;

    foreach my $dir (@mf_path) {
        return $MENUEXT if -e "$dir/$shcut$MENUEXT";
        return $FORMEXT if -f "$dir/$shcut$FORMEXT";
    }
    return;
}

sub list_shortcuts {
    my @unique = ();
    my @all    = ();
    my @buff   = ();
    my ( $s, $dir, $val, $name, $fname, $fullpath, $nfound );
    my @sc_names;
    my %sc_descrs;
    my %sc_priv;

    for $dir (@mf_path) {
        opendir( DIR, $dir );
        while ( $fname = readdir(DIR) ) {
            next if $fname =~ /^\.\.?$/;
            next if $fname !~ /($MENUEXT|$FORMEXT)$/;
            next if $fname eq "$REALNAME$MENUEXT";
            my @lines = ();
            $fullpath = "$dir/$fname";
            $fullpath .= "/$DMENU_DEF_FNAME" if ( -d $fullpath );
            push @all, $fullpath;
        }
        closedir(DIR);
    }

    @unique = @all;
    foreach $s (@all) {
        $s =~ s/($MENUEXT|$FORMEXT)$//;
        $nfound = scalar grep /^$s$/, @all;
        if ( $nfound eq 2 ) {
            @unique = grep( !/^$s$FORMEXT$/, @unique );
        }
    }

    @all = @unique;
    foreach $s (@all) {
        ( $fname, undef, undef ) = fileparse( $s, ( $MENUEXT, $FORMEXT ) );
        $nfound = scalar grep /\/$fname($MENUEXT|$FORMEXT)$/, @all;
        if ( $nfound ge 2 ) {
            my $rmfname = "$PRIV_DIR/$CALLNAME/$fname";
            @unique = grep( !/^$rmfname/, @unique );
        }
    }

    foreach $s (@unique) {
        @lines = ();
        if ( open( INF, $s ) ) {
            while (<INF>) {
                next if /^\s*#/;
                push @lines, $_;
            }
            close(INF);
            $text = join( '', @lines );

            ( $val, undef, undef ) =
              extract_bracketed( $text, '{', '\s*title*\s*' );
            $val =~ s/^\{\s*//;
            $val =~ s/\s*\n?\s*\}$//;
            $val = 'N/A' if !$val;

            $s =~ s/\/$DMENU_DEF_FNAME$//;
        }
        else {
            print STDERR "$CALLNAME: error opening file $fullpath\n";
            print STDERR "$CALLNAME: $!\n";
            $val = "READ ERROR: $!";
        }
        ( $name, $dir, undef ) = fileparse( $s, ( $MENUEXT, $FORMEXT ) );
        push @buff, $name;
        $sc_descrs{$name} = $val;
        $sc_priv{$name} = ( $dir =~ /^$PRIV_DIR/ );
    }

    @sc_names = sort @buff;

    if (@unique) {
        my $maxllen = 8;
        my $maxrlen = 11;
        foreach my $i ( 0 .. $#sc_names ) {
            $maxllen = length( $sc_names[$i] )
              if length( $sc_names[$i] ) > $maxllen;
            $maxrlen = length( $sc_descrs{ $sc_names[$i] } )
              if length( $sc_descrs{ $sc_names[$i] } ) > $maxrlen;
        }

        eval
          "printf \"%${maxllen}s  %-${maxrlen}s\\n\",'Shortcut','Description'";
        print '-' x ${maxllen} . '  ' . '-' x ${maxrlen} . "\n";
        foreach my $i ( 0 .. $#unique ) {
            eval
"printf \"%${maxllen}s%1s %-${maxrlen}s\\n\",\$sc_names[\$i],(\$sc_priv\{\$sc_names[\$i]\} and \$MARK_PRIV_SHCUTS)?'~':'',\$sc_descrs\{\$sc_names[\$i]\}";
        }
    }
    else {
        print "$CALLNAME: no shortcut(s) available.\n";
    }
    exit;
}

sub HELP_MESSAGE {
    usage;
}

sub VERSION_MESSAGE {
    usage;
}

$Getopt::Std::STANDARD_HELP_VERSION = $TRUE;
$Getopt::Std::OUTPUT_HELP_VERSION   = '';
%options                            = ();
getopts( "vhsdcl:", \%options ) or usage();
if ( defined $options{v} ) {
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my ( $dd, $mm, $yy ) = split /\//, $VERSION_DATE;

    print << "EOT";
$REALNAME version $VERSION ($months[$mm-1] $dd, $yy)
Copyright (C) $VERSION_YEAR Massimo Loschi

This program comes with ABSOLUTELY NO WARRANTY.  You may redistribute copies of
it under the terms of the GNU General Public License.
For more information about these matters, see the file named COPYING.
EOT
    exit 0;
}
if ( defined( $options{l} ) ) {
    $LIBDIR  = $options{l};
    $WRKDIR  = "$LIBDIR";
    @mf_path = ("$LIBDIR");
}
if ( defined( $ENV{'CCFE_LIB_DIR'} ) ) {
    $LIBDIR  = $ENV{'CCFE_LIB_DIR'};
    $WRKDIR  = "$LIBDIR";
    @mf_path = ("$LIBDIR");
}
usage()        if defined $options{h};
list_shortcuts if defined $options{s};
print_config   if defined $options{c};
$DEBUG = $YES if defined $options{d};
$LANG_ID = get_lang_id;
load_msgs;
$es_str[$ES_NO_ERR]     = $ES_NO_ERR_MSG;
$es_str[$ES_SYNTAX_ERR] = $ES_SYNTAX_ERR_MSG;
$es_str[$ES_FOPEN_ERR]  = $ES_FOPEN_ERR_MSG;
$es_str[$ES_NOT_FOUND]  = $ES_NOT_FOUND_MSG;
$es_str[$ES_NO_ITEMS]   = $ES_NO_ITEMS_MSG;

%keys = (
    help => {
        code  => -1,
        label => $KEY_F1_LABEL
    },
    redraw => {
        code  => -1,
        label => $KEY_F2_LABEL
    },
    back => {
        code  => -1,
        label => $KEY_F3_LABEL
    },
    list => {
        code  => -1,
        label => $KEY_F4_LABEL
    },
    reset_field => {
        code  => -1,
        label => $KEY_F5_LABEL
    },
    show_action => {
        code  => -1,
        label => $KEY_F6_LABEL
    },
    sel_items => {
        code  => -1,
        label => $KEY_F7_LABEL
    },
    save => {
        code  => -1,
        label => $KEY_F8_LABEL
    },
    shell_escape => {
        code  => -1,
        label => $KEY_F9_LABEL
    },
    exit => {
        code  => -1,
        label => $KEY_F10_LABEL
    },
    do => {
        key   => 'Enter',
        label => $KEY_ENTER_LABEL
    },
    int => {
        key   => '^C',
        label => $KEY_INTR_LABEL
    },
    find => {
        key   => '/',
        label => $KEY_FIND_LABEL
    },
    find_next => {
        key   => 'n',
        label => $KEY_FNEXT_LABEL
    },
    sel_all => {
        key   => 'a',
        label => $KEY_SELALL_LABEL
    },
    unsel_all => {
        key   => 'u',
        label => $KEY_UNSELALL_LABEL
    }
);
@MSKeys = qw( help redraw back shell_escape exit do );
@FSKeys =
  qw( help redraw back list reset_field show_action save shell_escape exit do );
@RSKeys =
  qw( help redraw back show_action save shell_escape exit find find_next);

initscr;
if ( ( $COLS < 80 ) or ( $LINES < 24 ) ) {
    endwin();
    print STDERR "$CALLNAME: $ERR_LITTLE_SCREEN[0]\n";
    print STDERR "$CALLNAME: $ERR_LITTLE_SCREEN[1]\n";
    exit 1;
}

eval { new_form() };
if ( $@ =~ /not defined by your vendor/ ) {
    print STDERR "Curses was not compiled with form support.\n";
    exit 1;
}
eval { new_menu() };
if ( $@ =~ /not defined by your vendor/ ) {
    print STDERR "Curses was not compiled with menu support.\n";
    exit 1;
}

umask 0077;
chomp( $ENV{'CCFE_IWD'} = `pwd` );
$ENV{'CCFE_LIB_DIR'} = $LIBDIR;
$WRKDIR = "$LIBDIR/$CALLNAME" if !defined($WRKDIR);
my $shcut = $ARGV[0] ? $ARGV[0] : $REALNAME;
trace(
    sprintf "Starting $REALNAME called as \"$CALLNAME\", PID $$; Fastpath: %s",
    $shcut ne $REALNAME ? "\"$shcut\"" : 'NONE'
);

chdir "$WRKDIR";
trace( 'Changed CWD to ' . substr( `pwd`, 0, -1 ) );

$HIDE_CURSOR      = $YES;
$SHOW_SCREEN_NAME = $YES;
$INITIAL_OVL_MODE = $NO;
$FIELD_PAD        = 95;
$HFIELD_PAD       = 42;
$SHOW_CHGD_FIELDS = $YES;
$SHOW_FIELD_FLAGS = $YES;
$SHOW_DOTS        = $YES;
$MARK_NOACT_ITEMS = $NO;
$MAX_PAD_LINES    = 5000;
$RS_INFO_ATTR     = A_REVERSE;
$RS_STDERR_ATTR   = A_BOLD;
$RS_STDOUT_ATTR   = A_NORMAL;
$END_MARKER       = '';
$OPEN3_SHELL      = '/bin/sh';
$USER_SHELL       = ( getpwuid($>) )[8];
@fval_delim       = ( ' ', ' ' );
$FIELD_VALUE_POS  = -1;

if ( $res = load_config ) {
    trace("$es_str[$res] loading configuration file");
}
if ( !$PERMIT_DEBUG ) {
    trace('debugging disabled by configuration!');
    $DEBUG = $NO;
}
trace("Using \"$USER_SHELL\" for user shell escape");
trace("Using \"$OPEN3_SHELL\" for commands execution");

if ( $keys{back}{code} == -1 ) {
    $keys{back}{code}  = KEY_F(10);
    $keys{back}{key}   = 'F10';
    $keys{back}{label} = ':Back';
    trace("\"Back\" fn key not defined - force F10=Back");
}

$ovl_mode       = $INITIAL_OVL_MODE;
$ASKS_FIELD_PAD = $FIELD_PAD;

if ( $shcut_type = get_shortcut($shcut) ) {
    noecho;
    curs_set($OFF) if $HIDE_CURSOR;

  SWITCH: {
        $_ = $shcut_type;
        if (/$MENUEXT/) {
            ( $es, $id, $descr ) = do_menu($shcut);
            if ( $es and $es < $ES_USER_REQ ) {
                trace("FATAL: $es_str[$es] while reading menu \"$shcut\"");
            }
            last SWITCH;
        }
        if (/$FORMEXT/) {
            $es = do_form($shcut);
            if ( $es and $es < $ES_USER_REQ ) {
                trace("FATAL: $es_str[$es] while reading form \"$shcut\"");
            }
            last SWITCH;
        }
    }

    clear();
    refresh();
    endwin();
    system("clear") if $es == $ES_NO_ERR or $es >= $ES_USER_REQ;
    if ( defined($exec_args) ) {
        chdir "$SCREEN_DIR";
        trace( "Changed CWD from $prev_wdir to " . substr( `pwd`, 0, -1 ) );
        trace("exec \"$exec_args\"");
        exec($exec_args);
    }
}
else {
    refresh();
    endwin();
    trace("Initial menu or form \"$shcut\" not found - Abort");
    print STDERR "$CALLNAME: $ERR_WRONG_FPATH[0] \"$shcut\".\n";
    print STDERR "$CALLNAME: $ERR_WRONG_FPATH[1]\n";
}
if ( $es and $es < $ES_USER_REQ ) {
    refresh();
    endwin();
    print STDERR "$CALLNAME: $es_str[$es] $ERR_LOAD_INITIAL_OBJ \"$shcut\"\n";
}
exit $es;
