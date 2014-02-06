#!/usr/bin/perl -w
#
#   SwitchMap.pl - generate web pages that describe Cisco switches
#
# This program's version number is in file Constants.pm.
#
# AUTHOR
#
# Pete Siemsen, siemsen@ucar.edu, 303-497-1810
#
# AVAILABILITY
#
# The current version should always be available at
#    http://sourceforge.net/projects/switchmap/
#
#-------------------------------------------------------------------------
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
# This script outputs HTML files and CSV files that describe Cisco
# Ethernet switches.  The files show information about each switch
# port, including how long the port has been idle and if possible,
# what machines are connected to each port.  This script can use
# information from a machine running HP Network Node Manager, or
# information from local configuration files.
#
# The basic algorithm is:
#
# Some regular time, usually every hour, a cron job runs the
# ScanSwitch.pl script, which checks every switch to see which ports
# are active.  For each switch, ScanSwitch.pl uses SNMP to download
# the operational status of each port on the switch.  ScanSwitch.pl
# stores the state of each port in "idlesince" files, for later use by
# this script.
#
# Some regular time, usually every hour, another cron job runs
# GetArp.pl, a script that gets the ARP caches from the routers and
# updates MacList, a file that provides MAC-address to IP-address
# information for later use by this script.
#
# Some regular time, usually every day, a cron job runs this script,
# which integrates the data in the idlesince files, data from the
# MacList file, possibly data from HP Network Node Manager, and more
# SNMP data from the switches themselves, and outputs HTML and CSV
# files, which is the main purpose of the SwitchMap scripts.
#
# These are the various files that this script needs, reads or writes:
#
#   A. Source code files, found in the directory with this file.
#   Files in this directory don't change once SwitchMap has been
#   installed and configured.  Source code files are:
#
#   . SwitchMap.pl (this script), which is run in a cron job, usually
#     every day.
#   . ScanSwitch.pl, a Perl script which is run in a cron job, usually
#     every hour.
#   . GetArp.pl, a Perl script which is run in a cron job, usually
#     every hour.
#   . OuiCodes.txt, a text file containing the manufacturer codes that
#     are found in MAC addresses.  OuiCodes.txt is read by this script.
#     It is generated by UpdateOuiCodes.pl.
#   . UpdateOuiCodes.pl, a Perl script that generates the OuiCodes.txt
#     file.  UpdateOuiCodes.pl is run rarely, because the OuiCodes.txt
#     file rarely changes.  Users shouldn't need to run it at all.
#     It's included in the distrbution for completeness.  See comments
#     in UpdateOuiCodes.pl for details.
#
#   B. State files, found in the directory named by the variable named
# $StateFileDirectory, defined in your ThisSite.pm configuration file.
# State files are separated from source code files and output files
# because they are logically distinct from source code files and
# output files.  They include SNMP community strings, which should be
# protected.  On my Unix system, I set $StateFileDirectory to
# '/var/local/switchmap'.  The state files are:
#
#   . MacList, a text file containing IP addresses for every MAC
#     address known to every switch.  This file is updated by
#     GetArp.pl.
#   . "idlesince" files, one for each switch.  These files live in the
#     directory named by the $StateFileDirectory variable in your
#     ThisSite.pm configuration file.  Idlesince files are updated by
#     ScanSwitch.pl.  They are read by SwitchMap.pl.  These files
#     contain, on each line, a port name and Unix timestamp of the
#     most recent time that each port was found to be idle, or 0 if a
#     port was active the last time ScanSwitch.pl was run.  Thus, the
#     port has been "idle since" the given time.
#   . Communities.txt, or a similarly named file, the full name of
#     which is defined by the variable named $CmstrFile in your
#     ThisSite.pm configuration file.  This file is a list of SNMP
#     community strings to try when getting information from switches.
#   . "community" files, one per switch.  These files live in the
#     directory named by the $StateFileDirectory variable in your
#     ThisSite.pm configuration file.  These files exist to make
#     switchMap run a bit faster by remembering which of a set of
#     possible community strings worked the last time SwitchMap ran.
#     With these files, SwitchMap can avoid trying community strings
#     that don't work, and waiting for requests to time out before
#     trying the nxet community string in the list.
#
#   C. Output files, which the SwitchMap.pl script writes to the
# directory named by the variable named $DestinationDirectory, defined
# in your ThisSite.pm configuration file.  Unlike the directories that
# hold source code or state files, the output directory is accessible
# by your web server - the files are readable by web users.  By
# keeping these files separate from source files, security is improved
# - a hacker is not able to breach your security by finding a way to
# modify the SwitchMap programs.  By keeping output files separate
# from state files, you don't have to worry that your SNMP community
# strings might be somehow accessible via a browser.  Output files are:
#
#   . HTML files in the "switches", "ports" and "vlans" subdirectories.
#     The HTML files are the Web pages that are the point of all this :-)
#   . CSV files in the "csv" subdirectory.  These are for people who
#     want access to the raw data gathered by SwitchMap, in a form that
#     is easy to parse by programs.
#
# BUGS
#
# . Suns with multiple network interfaces use the same MAC address
#   on all the interfaces.  This causes incorrect entries in some IP
#   address columns.  Dunno how to fix this.
#
# . Sometimes, a 6509 will report an ifName table that is missing an
#   entry.  Other SNMP tables will refer to the ifIndex for the entry,
#   causing SwitchMap to generate "Warning: no interface name for SNMP
#   ifIndex <n> on <SwitchName>, skipping <Mac>" messages.  Rebooting
#   the switch makes the problem go away.  I opened Cisco TAC case
#   602418175, but the problem switch was rebooted before I could
#   supply enough information to Cisco, so I asked them to close the
#   case.  Two different 6509s did it.  Both were running 7.6(12).
#   This bug existed as of 2005-11-10, and is still seen on some
#   of our switches as of 2007-09-06.
#
# TODO
#
# . Consider the SNMP-BridgeQuery module (Google for it)
#
# . Add "SNMP agent has been up for xxx" to the Model/Contact/Location
#   information at the top of switch web pages.
#
# . In ModuleList.pm, modules are represented by a set of hashes, each
#   of which uses the same keys (module number).  At one time, this
#   seemed cool because GetSnmpTable can read right into these arrays.
#   Now that I've added support for getting module data from the Entity
#   MIB, it would be cleaner to represent modules as an array of module
#   objects.  This would be more natural, and would get rid of the
#   $NbrModules variables, and I could initialize the fields in the
#   objects to 'unknown', which would be cleaner than the tests I do
#   now.
#
# . David Mitchell asked
#   "is it possible to indicate the auto negotiation status on the
#   port lists? I assume you are grabbing the duplex out of portDuplex
#   in the Cisco StackMIB?  If so, grab the previous column
#   portAdminSpeed and if it is a 1 or 2, prepend 'a-' onto the
#   displayed duplex.  Or something like that.  Basically speed and
#   duplex cannot have their negotiation status changed
#   independently.  The portAdminSpeed value indicates whether both
#   of them are auto negotiate or fixed."
#
# . For etherchannels, David Mitchell wants to see MACs on both ports
#   somehow.  The key is that the MAC addresses are hooked to the
#   *parent* port, not the children.
#
# . Lance Vermillion noticed that the Spare Ports pages count
#   trunk ports, which is wrong - trunk ports are not contenders
#   for use as spare ports.
#
# . Show port errors.  There isn't room to add more columns to the
#   existing web pages, so make a new set of web pages under "ports"
#   for "error" ports, which are ports that have errors that exceed
#   some threshold.  Columns in these new pages might include
#
#      FCS
#      runts
#      giants
#      last change counter/bouncing
#      100Mbps but not full duplex
#      admin auto but not full
#      not admin auto
#      input traffic but no output traffic
#      output traffic but no input traffic
#
#   Note that some errors are not shown by the "show ports" command.
#   The "show counters" command shows more errors.
#
#   For some of these, I'll have to put new data into the idlesince
#   files to track state.  Perhaps I should put a single "error" link
#   on each row of the main web pages - if the link exists, there's
#   something wrong with the port.  If I do this, maybe empty
#   "comment" fields shouldn't be indicated with color on the main
#   pages any more - it should be in the "error" pages.
#
# . When SwitchMap reads the MacList file, it does a DNS lookup on
#   every one of the IP addresses in the file.  If a DNS server is
#   down, these DNS lookups can time out on each lookup, causing
#   SwitchMap to appear to hang.  Dunno how to fix this one.
#
# . See the comments about doDNS in MacIpTables.pm.  There's gotta be
#   a better way.
#
# . Make the switch names be links to/from the switch web pages, and
#   make links from those pages back to these Web pages.
#
# . Make links to/from the NOC pages
#
# . Make links from the each switch page to it's corresponding
#   unusedbyswitch page.
#
# . Peter Silva <Peter.Silva@pt.ibm.com> requested that the portlist
#   code be able to get data from the host running OpenView via telnet
#   instead of ssh.
#
# . In the spare port lists:
#     . Change the Spare Ports web page so that it shows how many
#       ports are spare on each VLAN on each switch.  Then mark each
#       place where this number is 0 in red.  This is just an idea,
#       and may not be practical.  If I do this, see if it makes
#       sense to identify the spare ports on each VLAN.
#
# . Start using ifLastOperChange, and stop doing ScanSwitch.pl?  Would
#   this work when switches reboot?
#
# . use a database to store: MACs, idlesince times, SNMPv2 capability.
#

use strict;
use Log::Log4perl qw(get_logger :levels);
#use Net::SNMP 6.0.0 qw(:snmp);   # dbg, requires export PERL5LIB=~/Net-SNMP-v6.0.0/lib/
use Net::SNMP 5.2.0 qw(:snmp);
#use Data::Dumper;
use Getopt::Std;
use File::Copy;
use File::Spec;
use FindBin;
use lib $FindBin::Bin;
use FindBin qw($Bin);
use Constants;
use MibConstants;
use SwitchUtils;
use SnmpCommunities;
use Switch;
use Vlan;
use MacIpTables;
use PetesUtils;                 # InitializeLogging
use Stats;                      # WriteSwitchStats
use WriteCsvDirectory;
use WriteGigePerVlansDirectory;
use WriteModulesFile;
use WriteNcarFiles;
use WritePortsDirectory;
use WritePLookupDirectory;
use WriteSwitchesDirectory;
use WriteVlansDirectory;

sub version { $Constants::VERSION; }

sub Usage () {
  my $MyName = PetesUtils::ThisScriptName();
  die <<USAGE;

 Usage: SwitchMap.pl [-c] [-d n] [-i n] [-w n] [-f] [-v] [switchname]

 This program creates HTML files and CSV files representing
 one or more Cisco Ethernet switches.  For each switch,
 information about each module and port is generated.

     -c          Function as a cgi script.  Requires the
                 switchname argument.

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

     switchname  The name of a switch.  The name must be composed
                 of only lowercase letters, digits, dashes and
                 periods.

                 If no switch name is given, all switches are
                 processed.  The list of switches comes from
                 ThisSite.pm or from HP Network Node Manager.pm.

USAGE
}


#
# Get the switch name from the command line.  If there is no
# switch name, then do all switches.
#
sub ParseCommandLineAndInitializeLogging ($$) {
  my $CgiRef           = shift;
  my $SwitchNameRef    = shift;

  my %options;
  if (getopts('cd:fi:w:sv', \%options) == 0) {
    Usage();
  }
  $$CgiRef = (exists $options{'c'});
  my $opt_d = 0;
  my $opt_i = 0;
  my $opt_w = 0;
  my $opt_s = 0;
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
    die "SwitchMap version $version\n";
  }
  my $LogToFile = 0;
  if (exists $options{'f'}) {
    $LogToFile = 1;
  }
  if ($#ARGV == -1) {           # if no arguments
    if ($$CgiRef) {
      die "-c option requires that a switchname be suppiled, exiting\n";
    }
  } elsif ($#ARGV == 0) {       # if there's one argument
    $$SwitchNameRef = $ARGV[0]; # must be a switch name
  } else {                      # else, too many arguments
    Usage();
  }
  PetesUtils::InitializeLogging($LogToFile, $opt_d, $opt_i, $opt_w, $Constants::MAX_DEBUGGING_MESSAGE_DEPTH);
}


sub WriteSearchHelpFile () {
  my $logger = get_logger('log2');
  my $SearchHelpFileName = File::Spec->catfile($ThisSite::DestinationDirectory, $Constants::SearchHelpFile);
  $logger->debug("called, writing $SearchHelpFileName");

  $logger->info("writing $SearchHelpFileName");
  open SEARCHHELPFILE, ">$SearchHelpFileName" or do {
    $logger->fatal("Couldn't open $SearchHelpFileName for writing, $!");
    exit;
  };

  print SEARCHHELPFILE SwitchUtils::HtmlHeader("Help searching the Cisco port lists");
  print SEARCHHELPFILE <<SBODY;

You can use this to get answers to questions like

<ul>
<li>What ports are active in a given office?
<li>Where is a given MAC address?
<li>What switch/port is the machine named fileserver connected to?
</ul>

$ThisSite::ExtraHelpText
<p>
Case is not significant in the search.
SBODY
  print SEARCHHELPFILE SwitchUtils::HtmlTrailer;
  close SEARCHHELPFILE;
  SwitchUtils::AllowAllToReadFile $SearchHelpFileName;
  $logger->debug("returning");
}


sub WriteCssFile () {
  my $logger = get_logger('log2');
  $logger->debug("called");

  my $SrcCssFileName = File::Spec->catfile($Bin,                            $Constants::CssFile);
  my $DstCssFileName = File::Spec->catfile($ThisSite::DestinationDirectory, $Constants::CssFile);
  if ($SrcCssFileName ne $DstCssFileName) {
    $logger->debug("copying $Constants::CssFile to $ThisSite::DestinationDirectory");
    copy($SrcCssFileName, $DstCssFileName);
  }
  $logger->debug("returning");
}


sub WriteMainIndexFile () {
  my $logger = get_logger('log2');
  my $IndexFileName = File::Spec->catfile($ThisSite::DestinationDirectory, 'index.html');
  $logger->debug("called, writing main $IndexFileName");

  $logger->info("writing $IndexFileName");
  open INDEXFILE, ">$IndexFileName" or do {
    $logger->fatal("Couldn't open $IndexFileName for writing, $!");
    exit;
  };
  print INDEXFILE SwitchUtils::HtmlHeader("Ethernet Switch Port Lists");

  print INDEXFILE <<IDX1;
Information about switches is available in various forms.  You can
<ul>
  <li>
    <a href="SearchPortlists.html">Search the portlist web pages</a>
    for various text strings
  </li>
IDX1

  print INDEXFILE <<IDX3;
  <li>Browse the portlist web pages:
    <ul>
    <li><a href = "switches/index.html">Switches</a></li>
    <li><a href = "$Constants::ModulesBySwitchFile">Modules</a></li>
    <li><a href = "ports/index.html">Ports</a></li>
    <li><a href = "vlans/index.html">VLANs</a></li>
    <li><a href = "$Constants::SwitchStatsFile">Statistics</a></li>
IDX3

  print INDEXFILE <<IDX4;
    </ul>
  </li>
</ul>
IDX4
  print INDEXFILE SwitchUtils::HtmlTrailer;
  close INDEXFILE;
  SwitchUtils::AllowAllToReadFile $IndexFileName;
  $logger->debug("returning");
}


#
# Given a list of switch names, return a list of switch objects.  In
# other words, create a switch object for each switch, and populate
# each object with real data by doing SNMP to the switch.
#
sub CreateSwitches ($) {
  my $SwitchNames = shift;
  my $logger = get_logger('log2');
  $logger->debug("called");

  my @Switches;
  foreach my $SwitchName (@$SwitchNames) {
    $logger->info("getting data from $SwitchName");
    my $Switch = new Switch $SwitchName;
    if (($SwitchName =~ /^---/) or       # if it's a group name or
        ($Switch->PopulateSwitch())) {   #    I was able to get data from the switch
      push @Switches, $Switch;           #   save the switch's data
    }
  }
  my $NbSwitches = $#Switches + 1;
  $logger->debug("returning $NbSwitches switches");
  return @Switches;
}


#
# Go through all the ports in all the switches, to create $VlansRef, a
# hash of Vlan objects.  The keys of the hash serve as a list of all
# VLANs.
#
sub CreateVlans ($$) {
  my $SwitchesRef = shift;    # passed in array of Switch objects
  my $VlansRef    = shift;    # hash of Vlan objects, filled by this subroutine
  my $logger = get_logger('log2');
  $logger->debug("called");

  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/;     # skip it if it's a group name
    foreach my $PortName (keys %{$Switch->{Ports}}) {
      my $Port = $Switch->{Ports}{$PortName};
      if (exists $Port->{VlanNbr}) {
        my $VlanNbr = $Port->{VlanNbr};
        my $Vlan;
        if (exists $$VlansRef{$VlanNbr}) {
          $Vlan = $$VlansRef{$VlanNbr};
        } else {
          $Vlan = new Vlan $VlanNbr;
          $$VlansRef{$VlanNbr} = $Vlan;
        }
        $Vlan->{Switches}{$SwitchName} = $Switch;
        $Vlan->{NbrPorts}++;
        $Vlan->{NbrUnusedPorts}++ if $Port->{Unused};
      }
    }
  }
  my $NbVlans = keys %$VlansRef;
  $logger->debug("returning, created $NbVlans VLANs");
}


sub CheckDirectoryExistence () {
  my $logger = get_logger('log2');
  if (!-d $ThisSite::DestinationDirectory) {
    $logger->fatal("Your ThisSite.pm file defines \$DestinationDirectory as $ThisSite::DestinationDirectory, which doesn't exist.  Exiting.");
    exit;
  }
  if (!-d $ThisSite::StateFileDirectory) {
    $logger->fatal("Your ThisSite.pm file defines \$StateFileDirectory as $ThisSite::StateFileDirectory, which doesn't exist.  Exiting.");
    exit;
  }
  if (!-d $Constants::IdleSinceDirectory) {
    $logger->fatal("Directory $Constants::IdleSinceDirectory doesn't exist, have you run ScanSwitch.pl?  Exiting.");
    exit;
  }
}


#
# Main.  ======================================================================
#
my $Cgi;
my $SwitchName = '';
ParseCommandLineAndInitializeLogging(\$Cgi, \$SwitchName);
my $logger = get_logger('log1');
$logger->debug("SwitchMap version $Constants::VERSION starting up...");

CheckDirectoryExistence();      # the output directories must already exist
MibConstants::initialize();     # read MIB files to get chassis and module types
SnmpCommunities::initialize();  # read SNMP community strings
MacIpTables::initialize(1);     # read MacList file or OpenView file

my @SwitchNames;
if ($SwitchName) {              # if there is a single switch name on the command line
  @SwitchNames = ( $SwitchName );
} else {
  @SwitchNames = MacIpTables::getAllSwitchNames();
}

$logger->info("getting data from switches ...");
my @Switches = CreateSwitches(\@SwitchNames);
if ($#Switches == -1) {
  $logger->fatal("no switches processed, dying");
  exit;
}
my %Vlans;                         # a hash of Vlan objects indexed by Vlan number
CreateVlans(\@Switches, \%Vlans);  # fill the hash of vlan objects

$logger->info("creating output files...");

WriteMainIndexFile();
WriteCssFile();
WriteVlansDirectory::WriteVlansDirectory(\@Switches);
WriteSwitchesDirectory::WriteSwitchesFiles(\@Switches);
WritePortsDirectory::WritePortsDirectory(\@Switches, \%Vlans);
WriteCsvDirectory::WriteSwitchCsvFiles(\@Switches);
if ($ThisSite::DnsDomain eq '.ucar.edu') { # only if we're at NCAR
  WriteNcarFiles::WriteNcarFiles(\@Switches);
}
WriteSearchHelpFile();
WriteModulesFile::WriteModulesFile(\@Switches);
Stats::WriteStatisticsFile(\@Switches);
if ($ThisSite::GeneratePLookupFiles) { # if we should generate files to support the pLookup program
  WritePLookupDirectory::WritePLookupDirectory(\@Switches);
}
$logger->info("exiting normally...");