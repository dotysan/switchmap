#!/usr/bin/perl -w
#
#       GetArp.pl
#
#--------------------------------------------------------------------------
# Copyright 2010 University Corporation for Atmospheric Research
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundaation; either version 2 of the License, or
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
# Scot Colburn, colburn@ucar.edu or
# Pete Siemsen, siemsen@ucar.edu
# --------------------------------------------------------------------------
#
# This program reads ARP tables from routers and update a list of ARP
# entries in a file named "MacList".  This program also removes from the
# file any entries that are more than a month old.  Run GetArp often to
# keep the MacList file fresh.
#
use strict;
use Getopt::Std;
use Time::HiRes;
use Log::Log4perl qw(get_logger :levels);
use Net::SNMP 5.2.0 qw(:snmp);
#use Data::Dumper;
use FindBin;
use lib $FindBin::Bin;     # find modules in the same dir as this file
use PetesUtils;            # define InitializeLogging
use Constants;
use SnmpCommunities;
use SwitchUtils;                # OpenSnmpSession

sub version { $Constants::VERSION; }


sub Usage () {
  my $MyName = PetesUtils::ThisScriptName();
  die <<WARNING;

 Usage: GetArp.pl [-d n] [-i n] [-w n] [-f] [-v]

  This program gets ARP caches from routers and stores the data in
  a file named $Constants::MacListFile.  Later, the SwitchMap.pl
  program will read the file in order to learn the mappings between
  IP and MAC addresses.

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

WARNING
}


#
# Parse the command line for options, if any, and initialize
# the Log4Perl logging system so we can generate logging
# messages.
#
sub ParseCommandLineAndInitializeLogging () {

  my %options;
  if (getopts('d:fi:w:sv', \%options) == 0) {
    Usage();
  }
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
    die "GetArp version $version\n";
  }
  my $LogToFile = 0;
  if (exists $options{'f'}) {
    $LogToFile = 1;
  }
  PetesUtils::InitializeLogging($LogToFile, $opt_d, $opt_i, $opt_w, $Constants::MAX_DEBUGGING_MESSAGE_DEPTH);
}


# Set $purgenotify to 1 to learn of purged records
my $purgenotify = 1;

my %OldMAC;                     # hash of HostNames by IP
my %OldName;                    # hash of Timestamps by IP.MAC
my %OldTime;                    # address into OldTime hash
my $ipmac;

#Purged records
my %purgedMAC;
my %purgedTime;
my $purgedcount=0;


sub ReadMacListFile () {
  my $logger = get_logger('log2');
  $logger->debug("called");

  open MACLIST, "<$Constants::MacListFile" or do {
    warn "Can't open $Constants::MacListFile for reading: $!\n" .
      "The file will be created\n";
    return;
  };

  my $OneMonthAgo = time() - $Constants::SecondsPerMonth;
  my $count = 0;
  while (<MACLIST>) {
    /(\S+)\t(\S+)\t(\S+)\n/;
    my $oldmac = $1;
    my $oldip = $2;
    my $oldtime = $3;
    if ($oldtime > $OneMonthAgo) { # if the MAC is younger than a month old
      $OldMAC{$oldip} = $oldmac;
      $ipmac = "$oldip.$oldmac";
      $OldTime{$ipmac} = $oldtime;
      $count++;
    } elsif ($purgenotify==1) { # it's older than a month, cull it
      $purgedMAC{$oldip} = $oldmac;
      $ipmac = "$oldip.$oldmac";
      $purgedTime{$ipmac} = $oldtime;
      $purgedcount++;
    }
    #    $logger->debug("<$oldmac> <$oldip> <$oldtime>");
  }
  close MACLIST;
  $logger->debug("Read in $count MACs from $Constants::MacListFile");
  #    if ($purgedcount>=1) {
  #      my $purgedtime = ctime($cull);
  #      chop $purgedtime;
  #      print "GetArp purged the following MACs not seen since $purgedtime:\n";
  #      foreach (keys %purgedMAC) {
  #     $ipmac = "$_.$purgedMAC{$_}";
  #     print "$purgedMAC{$_}\t$_\t$purgedTime{$ipmac}\n" if exists($purgedTime{$ipmac});
  #      }
  #    }
  $logger->debug("returning");
}


sub ReadArpWatchFile () {      # as written by arpwatch(1), which comes with some Linux distributions
  my $logger = get_logger('log2');
  $logger->debug("called");

  open MACLIST, "<$ThisSite::ArpWatchFile" or do {
    warn "Can't open $ThisSite::ArpWatchFile for reading: $!\n" .
      "Input from arpwatch application will be ignored!";
    return;
  };

  my $OneMonthAgo = time() - $Constants::SecondsPerMonth;
  my $count = 0;
  while (<MACLIST>) {
    /(\S+)\t(\S+)\t(\S+)/      or next;
    my $oldmac = $1;
    my $oldip = $2;
    my $oldtime = $3;

    # convert from 1:ab:c:.. format to 01ab0c...
    $oldmac = join "", map { sprintf "%02s", $_; } split /:/, $oldmac;

    if ($oldtime > $OneMonthAgo) { # if the MAC is younger than a month old
      $OldMAC{$oldip} = $oldmac;
      $ipmac = "$oldip.$oldmac";
      $OldTime{$ipmac} = $oldtime;
      $count++;
    } elsif ($purgenotify==1) { # it's older than a month, cull it
      $purgedMAC{$oldip} = $oldmac;
      $ipmac = "$oldip.$oldmac";
      $purgedTime{$ipmac} = $oldtime;
      $purgedcount++;
    }
    ### $logger->debug("<$oldmac> <$oldip> <$oldtime>");
  }
  close MACLIST;
  $logger->debug("Read in $count MACs from arpwatch data at $ThisSite::ArpWatchFile");
  $logger->debug("returning");
}


sub GetMacTables() {
  my $logger = get_logger('log2');
  my $logger4 = get_logger('log4');
  foreach my $RouterName (@ThisSite::routers) {
    $logger->debug("getting ARP table from $RouterName...");
    my $Session;
    my $dummyCommunity;
    my $dummySysObjectID;
    if (!SwitchUtils::OpenSnmpSession($RouterName,
                                      \$Session,
                                      \$dummyCommunity,
                                      \$dummySysObjectID)) {
      $logger->debug("couldn't open SNMP session, skipping");
      next;
    }

    my %arpTable;
    my $status = SwitchUtils::GetSnmpTable($Session,
                                           'arpTable',
                                           $Constants::IP_ADDRESS,
                                           \%arpTable);
    if ($status != $Constants::SUCCESS) {
      $logger->debug("couldn't read atTable, trying ipNetToMediaPhysAddress");
      $status = SwitchUtils::GetSnmpTable($Session,
                                          'ipNetToMediaPhysAddress',
                                          $Constants::IP_ADDRESS,
                                          \%arpTable);
      if ($status != $Constants::SUCCESS) {
        my $hname = $Session->hostname();
        $logger->warn("couldn't read ARP table from $hname, " . $Session->error() . ", skipping this device");
      }
    }
    $Session->close;

    # Merge the old and new tables
    foreach my $ip (keys %arpTable) {
      my $mac = unpack 'H12', $arpTable{$ip};
      $logger4->debug("arpTable\{$ip\} = \"$mac\"");
      $OldMAC{$ip} = $mac;
      $ipmac = "$ip.$mac";
      $OldTime{$ipmac} = time();
    }
  }
}


#
# Main.  ======================================================================
#

ParseCommandLineAndInitializeLogging();
my $logger = get_logger('log1');
my $logger3 = get_logger('log3');
$logger->debug("GetArp version $Constants::VERSION starting...");

SnmpCommunities::initialize();
ReadMacListFile();
ReadArpWatchFile()   if $ThisSite::ArpWatchFile;

my ($Seconds, $MicroSeconds) = Time::HiRes::gettimeofday;
GetMacTables();
my $elapsed = Time::HiRes::tv_interval([$Seconds, $MicroSeconds]);

my $NbrRouters = $#ThisSite::routers;

my @outarray;
foreach my $ip (keys %OldMAC) {
  $ipmac = "$ip.$OldMAC{$ip}";
  $logger3->debug("pushing this onto outarray: \"$OldMAC{$ip}\t$ip\t$OldTime{$ipmac}\"");
  if ($OldMAC{$ip} !~ /^[0-9a-z]{12}$/) {
    $logger->warn("bogus MAC: \"$OldMAC{$ip}\"");
  }
  push @outarray, "$OldMAC{$ip}\t$ip\t$OldTime{$ipmac}\n";
}

# Write the new MacList file.
$logger->debug("writing new MacList file...");
open NEWARP, ">$Constants::MacListFile" or do {
  $logger->fatal("Couldn't open $Constants::MacListFile for writing, $!");
  exit;
};
print NEWARP sort @outarray;
close NEWARP;
