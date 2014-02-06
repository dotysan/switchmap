package HpMibConstants;

#
# This module exists to encapsulate the 2 hashes you'll find defined
# below.  They are static lists of chassis and module information that
# is buried in HP MIB files.  The main ScanSwitch and SwitchMap
# programs call the initialize subroutine once when they start up.
# That subroutine parses the HP MIB files to initialize the hashes.
# Later, the programs call the "get" subroutines as needed to access
# the data in the hashes.
#


use strict;
use Log::Log4perl qw(get_logger);
#use Data::Dumper;


my %HpSwitches;
my %HpRouters;


#
# Read the HP MIB file to define the sysObject OIDs that HP uses.
# Return hashes containing the names and descriptions.
#
sub initialize () {
  my $logger = get_logger('log1');
  my $logger7 = get_logger('log7');
  $logger->debug("called");

# load the chassis HP Products OIDs
  $logger->info("reading $Constants::HpProductsMibFile");

# The MIB file came from the MIBs_V5_MIBs_V5/HP(hh3c)/MIBs directory
# of the MIBs_V5_MIBs_V5.zip file that I downloaded from
# https://h10145.www1.hp.com/Downloads/SoftwareReleases.aspx?ProductNumber=JD239A&lang=en,en&cc=us,us&prodSeriesId=4177519
# (under Other - MIBs_V5 near the bottom of the page)

  open HP_PRODUCTS_MIB_FILE, "<$Constants::HpProductsMibFile" or do {
    $logger->fatal("Couldn't open $Constants::HpProductsMibFile for reading, $!");
    exit;
  };
  while (<HP_PRODUCTS_MIB_FILE>) {
    chomp;
    if (/(\w+)\s+OBJECT IDENTIFIER\s+::=\s+\{\s+hpSwitch\s+(\d+)\s+}/) {
      my $SwitchName = $1;
      my $Number = $2;
      my $oid = '1.3.6.1.4.1.25506.11.1.' . $Number;
      $HpSwitches{$oid} = $SwitchName;
      $logger7->info("Switch: $oid = \"$SwitchName\"");
    } elsif (/(\w+)\s+OBJECT IDENTIFIER\s+::=\s+\{\s+hpRouter\s+(\d+)\s+}/) {
      my $RouterName = $1;
      my $Number = $2;
      my $oid = '1.3.6.1.4.1.25506.11.2.' . $Number;
      $HpRouters{$oid} = $RouterName;
      $logger7->info("Router: $oid = \"$RouterName\"");
    }
  }
  close HP_PRODUCTS_MIB_FILE;

  my $hpSwitchCount = keys %HpSwitches;
  my $hpRouterCount = keys %HpRouters;
  $logger->info("got $hpSwitchCount HP switch descriptions");
  $logger->info("got $hpRouterCount HP router descriptions");

  $logger->debug("returning");
}


sub getHpDeviceName ($) {
  my $sysObjectID = shift;
  if (exists $HpSwitches{$sysObjectID}) {
    return $HpSwitches{$sysObjectID};
  } elsif (exists $HpRouters{$sysObjectID}) {
    return $HpRouters{$sysObjectID};
  } else {
    return '';
  }
}

1;
