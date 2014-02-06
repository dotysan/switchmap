#!/usr/bin/perl -w
#
#   ScanSwitch.pl
#
# This program works with SwitchMap.pl as described in the README
# file.
#
# This program's version number is in file Constants.pm.
#
#--------------------------------------------------------------------------
# Copyright 2010 University Corporation for Atmospheric Research
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.
#
# For more information, please contact
# Pete Siemsen, siemsen@ucar.edu
#--------------------------------------------------------------------------
#
# This script uses SNMP to query each Ethernet switch about it's
# ports.  The script outputs an "idlesince" file for each switch.  The
# file contains one line for each port on the switch.  Each line
# contains the port name and an "idlesince" value, which is a Unix
# timestamp of the first time that this script noticed that the port
# was idle.  If the port isn't idle, the value is 0.
#
# It is intended that this script be run at regular intervals via
# cron.  The files it maintains are then examined by another script
# named SwitchMap.pl.  See the SwitchMap.pl script for more
# information.
#
use strict;
use Log::Log4perl qw(get_logger :levels);
use Net::SNMP 5.2.0 qw(:snmp);
use Getopt::Std;
use English;
use Socket;
use File::Spec;
use FindBin;
use lib $FindBin::Bin;
use Constants;
use MibConstants;
use SnmpCommunities;
use MacIpTables;                # define GetMacIpTables
use PetesUtils;                 # define InitializeLogging

#
# Global variables...
#
sub version { $Constants::VERSION; }


sub Usage () {
  my $MyName = PetesUtils::ThisScriptName();
  die <<WARNING;

 Usage: scanswitch.pl [-d n] [-i n] [-w n] [-f] [-v] [switchname]

 This program updates .idlesince files, which are used by
 the SwitchMap.pl program.

     -d n        Emit debugging messages.  n is how verbose to be,
                 from 0 (none) to $Constants::MAX_DEBUGGING_MESSAGE_DEPTH (most verbose).  The default is 0.
                 Use a higher numbers to get more debugging messages.
                 Turning on debugging messages turns on informational
                 and warning messages.

     -i n        Emit informational messages.  n is how verbose to
                 be, from 0 (none) to $Constants::MAX_INFORMATIONAL_MESSAGE_DEPTH (most verbose).  Numbers mean
                   0 - don't emit any messages (the default)
                   1 - "open" calls (files or net connections)
                   2 - 1, and data counts like "got 200 values"
                 Turning on informational messages turns on warning
                 messages.

     -w n        Emit warning messages.  n is how verbose to be, from
                 0 (none) to $Constants::MAX_WARNING_MESSAGE_DEPTH (most verbose).  The default is 0.
                 Currently there are only 2 possible values, 0 and 1.
                 At warning level 1, you'll get messages about things
                 that that are potentially harmful, but that the
                 program knows how to deal with, and that you probably
                 don't care about, like "switch returned unrecognized
                 port speed, using 'unknown'".

     -f          Write messages to a file named $MyName.log

     -v          Display the version and exit.

     switchname  The name of a switch.  The name must be
                 composed of only lowercase letters,
                 digits, dashes and periods.

                 If no switch name is given, all switches
                 are processed.  In this case, the list
                 of switches is retrieved from HP Network
                 Node Manager or the hard-coded list in
                 ThisSite.pm.

WARNING
}


#
# Get the name of the switch from the command line.  If there is no
# switch name, then do all switches.
#
sub ParseCommandLineAndInitializeLogging ($) {
  my $SwitchNameRef = shift;

  my %options;
  if (getopts('d:i:w:vf', \%options) == 0) {
    Usage();
  }
  my $opt_d = 0;
  my $opt_i = 0;
  my $opt_w = 0;
  if (exists $options{'d'}) {
    $opt_d = $options{'d'};
    Usage unless $opt_d =~ /^\d+$/ and $opt_d >= 0 and $opt_d <= $Constants::MAX_DEBUGGING_MESSAGE_DEPTH;
  } elsif (exists $options{'i'}) {
    $opt_i = $options{'i'};
    Usage unless $opt_i =~ /^\d+$/ and $opt_i >= 0 and $opt_i <= $Constants::MAX_DEBUGGING_MESSAGE_DEPTH;
  } elsif (exists $options{'w'}) {
    $opt_w = $options{'w'};
    Usage unless $opt_w =~ /^\d+$/ and $opt_w >= 0 and $opt_w <= $Constants::MAX_WARNING_MESSAGE_DEPTH;
  }
  if (exists $options{'v'}) {
    my $version = version();
    die "ScanSwitch version $version\n";
  }
  my $LogToFile = 0;
  if (exists $options{'f'}) {
    $LogToFile = 1;
  }
  if ($#ARGV == -1) {           # if no arguments
    ;
  } elsif ($#ARGV == 0) {       # if there's one argument
    $$SwitchNameRef = $ARGV[0]; # must be a switch name
  } else {                      # else, too many arguments
    Usage();
  }
  PetesUtils::InitializeLogging($LogToFile, $opt_d, $opt_i, $opt_w, $Constants::MAX_DEBUGGING_MESSAGE_DEPTH);
}


#
# The possible states of each ifOperStatus table entry.
#
my $UP = 1;
my $DOWN = 2;
my $TESTING = 3;
my $UNKNOWN = 4;
my $DORMANT = 5;
my $NOT_PRESENT = 6;

#
################################################ Main.
#
my $SwitchName = '';
ParseCommandLineAndInitializeLogging(\$SwitchName);
my $logger = get_logger('log1');

$logger->debug("ScanSwitch version $Constants::VERSION starting...");
if (!-d $Constants::IdleSinceDirectory) { # if the idlesince directory doesn't exist
  $logger->debug("creating $Constants::IdleSinceDirectory");
  mkdir $Constants::IdleSinceDirectory or do {
    $logger->fatal("Couldn't create $Constants::IdleSinceDirectory, $!");
    exit;
  };
}

MibConstants::initialize();
SnmpCommunities::initialize();

my @SwitchNames;
if ($SwitchName) {
  @SwitchNames = ( $SwitchName );
} else {
  MacIpTables::initialize(0);                 # 0 means "don't do DNS to get host names"
  @SwitchNames = MacIpTables::getAllSwitchNames();
}

my $NbrSwitches = $#SwitchNames + 1;
$logger->info("getting data from $NbrSwitches switch(es)...");
foreach my $FullName (sort @SwitchNames) {
  next if $FullName =~ /^---/;                # skip it if it's a group name
  my $SwitchName = $FullName;
  $SwitchName =~ s/$ThisSite::DnsDomain//;    # remove the trailing DNS domain
  srand();
  $logger->info("opening SNMP session to $SwitchName");
  my $Session;
  my $dummyCommunity;
  my $dummySysObjectID;
  if (!SwitchUtils::OpenSnmpSession($SwitchName, \$Session, \$dummyCommunity, \$dummySysObjectID)) {
    $logger->warn("couldn't open an SNMP session with $SwitchName, skipping");
    next;
  }

  my %IfToIfName;
  my %IfNameToIf;
  my $status = SwitchUtils::GetNameTables($Session, \%IfToIfName, \%IfNameToIf);
  if (!$status) {
    $logger->warn($SwitchName . ": couldn't get the ifName table, skipping");
    next;
  }

  my %ifOperStatus;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'ifOperStatus',
                                      $Constants::INTERFACE,
                                      \%ifOperStatus);
  if ($status != $Constants::SUCCESS) {
    $logger->warn($SwitchName . ": couldn't get the ifOperStatus table, skipping");
  } else {
    # SwitchUtils::DbgPrintHash('IfOperStatus', \%ifOperStatus);
    my $IdleSinceFile = File::Spec->catfile($Constants::IdleSinceDirectory, $SwitchName . '.idlesince');
    my %IdleSince;
    $status = SwitchUtils::ReadIdleSinceFile($IdleSinceFile, \%IdleSince);
    # ignore the status - if it doesn't exist, don't complain, we'll create it
    foreach my $ifNbr (keys %ifOperStatus) {
      next if !exists $IfToIfName{$ifNbr};
      my $PortName = $IfToIfName{$ifNbr};
      if ($ifOperStatus{$ifNbr} == $UP) {
        $IdleSince{$PortName} = 0;                # 0 means "Active"
      } else {
        if ((!defined $IdleSince{$PortName}) or   # it's a brand new port or
            ($IdleSince{$PortName} == 0)) {       #    it was new
          $IdleSince{$PortName} = time;           # record "now"
        }
      }
    }
    # SwitchUtils::DbgPrintHash('IdleSince', \%IdleSince);
    $status = SwitchUtils::WriteIdleSinceFile($IdleSinceFile, \%IdleSince);
    if ($status ne "") {
      $logger->fatal($status);
      exit;
    }
  }
  $Session->close;
}
$logger->info("exiting normally...");
