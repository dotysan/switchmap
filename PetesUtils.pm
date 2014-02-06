package PetesUtils;
#
# PetesUtils.pm
#
# This Perl module defines Pete's utility functions, like the
# code that sets up Log4Perl loggers.
#

use strict;
use Log::Log4perl qw(get_logger :levels);
use File::Spec;

#
# Return the name of this script, without paths or suffixes.  For
# instance, if this script was executed when the user typed
# '/abc/def/testscript.pl', then this function would return
# 'testscript'.
#
sub ThisScriptName () {
  my ($volume, $directories, $ThisScriptName) = File::Spec->splitpath( $0 );
  my $DotAddr = rindex $ThisScriptName, '.';
  if ($DotAddr != -1) {
    $ThisScriptName = substr $ThisScriptName, 0, $DotAddr;
  }
  return $ThisScriptName;
}

#
# Set up log levels.  For each logger, set its level based on the -d,
# -i and -w command-line options, as follows:
#
#   -d command-line option (implies -i and -w):
#     Set the logger to DEBUG, so that debug, info, warning, error and
#     fatal messages are output.
#   -i command-line option (implies -w):
#     Set the logger to INFO, so that info, warning, error and fatal
#     messages are output.
#   -w command-line option
#     Set the logger to WARNING, so that warning, error and fatal
#     messages are output.
#   No -d, -i or -w command-line options:
#     Set the logger to ERROR, so that only error and fatal messages
#     are output.
#
# This code is in its own function so that when debugging, you can
# temporarily change logging levels elsewhere in the code than at
# startup.  This can be useful for cutting down the amount of logging
# that you get - you can "bracket" problem code with calls to
# SetLogLevels like:
#
#   PetesUtils::SetLogLevels(1, 3, 5, 7);
#
# If you do this, remember that you must use a -d command-line option
# of at least 1, or the output format won't get properly initialized
# by the InitializeLogging function.

sub SetLogLevels ($$$$) {
  my $DDepth     = shift; # from the -d command-line switch, debugging depth
  my $IDepth     = shift; # from the -i command-line switch, informational depth
  my $WDepth     = shift; # from the -w command-line switch, warning logging depth
  my $MaxDDepths = shift; # maximum number of debugging levels used in this program

  # Set the logging level for each depth.
  for (my $depth=1; $depth<=$MaxDDepths; $depth++) {
    # if no command-line options have been specified, log only ERROR and FATAL messages
    my $level = $ERROR;
    # if any command-line options have been specified, log at least WARNING, ERROR and FATAL messages
    if (($DDepth > 0) or ($IDepth > 0) or ($WDepth > 0)) {
      $level = $WARN;
    }
    # Set higher levels based on the command-line options.
    if ($depth <= $DDepth) {
      $level = $DEBUG;
    } elsif ($depth <= $IDepth) {
      $level = $INFO;
    } elsif ($depth <= $WDepth) {
      $level = $WARN;
    }
    my $logger = get_logger("log$depth");
    $logger->level($level);
  }
}


#
# Define logger objects.  Later, the rest of the program will call
# get_logger to get access to the logger objects, and use the objects
# to control generation of log messages.  If the -d option is
# specified, this function adds a "cspec" named "i" for "indent", so
# that when log messages are generated, the "i" in the format string
# will get replaced with spaces representing the depth of the call
# stack, as measured from the main program.
#
sub InitializeLogging ($$$$$) {
  my $LogToFile  = shift;   # from the -f command-line switch, boolean
  my $DDepth     = shift;   # from the -d command-line switch, debugging depth
  my $IDepth     = shift;   # from the -i command-line switch, informational depth
  my $WDepth     = shift;   # from the -w command-line switch, warning depth
  my $MaxDDepths = shift;   # maximum depth used in this run

  # Define the destination of log messages: a file or stdout.
  my $LogFileAppender;
  if ($LogToFile) {
    my $MyName = ThisScriptName();
    my $LogFileName = "$MyName.log";
    if (-e $LogFileName) {
      unlink $LogFileName or die "couldn't unlink $LogFileName\n";
    }
    $LogFileAppender = Log::Log4perl::Appender->new(
                                                    "Log::Dispatch::File",
                                                    filename => $LogFileName
                                                   );
  } else {
    $LogFileAppender = Log::Log4perl::Appender->new(
                                                    "Log::Dispatch::Screen"
                                                   );
  }

  # Define the format of log messages.  If debugging is turned on, use
  # a detailed format, where each line shows:
  #
  #   1. a date and time
  #   2. indentation based on the call stack depth
  #   3. package::function name
  #   4. text, including INFO, DEBUG, WARN, FATAL messages
  #
  my $mylayout;
  if ($DDepth > 0) {
    #
    # Define a new "cspec" named "i", which means "indent".  Later,
    # when we refer to "%i" in a format string, the "%i" will get
    # replaced by the output of the function we define here.  The
    # function outputs a string of spaces that reflects the depth of
    # the call stack, with 2 spaces for every call.  For example, if
    # we're 3 function calls away from the main program, the "%i" will
    # get replaced with a string of 3x2=6 spaces.
    #
    Log::Log4perl::Layout::PatternLayout::add_global_cspec('i',
                                                           sub {
                                                             my $lvl = 0;
                                                             $lvl++ while caller($lvl);
                                                             return '  ' x ($lvl-5);
                                                           }
                                                          );
    # Reminder:
    #
    #        %d means date
    #        %i means the string of spaces that do the indenting
    #        %M means subroutine name
    #        %m means the message text
    #        %n means newline
    #
    $mylayout = "%d%i %M: %m%n"; # log format, indented with function name
  } else {
    my $MyName = ThisScriptName();
    $mylayout = "$MyName: %m%n";
  }
  my $layout = Log::Log4perl::Layout::PatternLayout->new($mylayout);

  $LogFileAppender->layout($layout);
  for (my $depth=1; $depth<=$MaxDDepths; $depth++) {
    my $logger = get_logger("log$depth");
    $logger->add_appender($LogFileAppender);
  }
  SetLogLevels($DDepth, $IDepth, $WDepth, $MaxDDepths);
}

1;
