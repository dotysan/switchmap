package CiscoMibConstants;

#
# This module exists to encapsulate the 4 hashes you'll find defined
# below.  They are static lists of chassis and module information
# that is buried in Cisco MIB files.  The main ScanSwitch and SwitchMap
# programs call the initialize subroutine once when they start up.
# That subroutine parses the Cisco Product and Stack MIB files to
# initialize the hashes.  Later, the programs call the "get"
# subroutines as needed to access the data in the hashes.
#


use strict;
use Log::Log4perl qw(get_logger);
#use Data::Dumper;


my %CiscoChassisNames;
my %CiscoChassisComments;
my %CiscoModuleNames;
my %CiscoModuleComments;
my %CiscoModuleStatus = (
  1, 'other',
  2, 'ok',
  3, 'minorFault',
  4, 'majorFault'
);
my %CiscoSwitchRoles = (
  1, 'master',
  2, 'member',
  3, 'notMember'
);


#
# Read Cisco MIB files to define the sysObject OIDs that Cisco uses.
# Return hashes containing the names and descriptions.
#
# I used to hard-code the chassis values in an array in Constants.pm.
# In September 2005, Peter Harrison sent me an email suggesting that I
# parse the relevant MIBs instead, to avoid stupid typos and make it
# easy to update when new Products or Stack MIB files come out of
# Cisco.  He even provided some code, which I turned into the
# following.  Thanks, Peter Hamilton!
#
sub initialize () {
  my $logger = get_logger('log1');
  my $logger7 = get_logger('log7');
  $logger->debug("called");

  # load the chassis ciscoProducts OIDs, indexed by ciscoProduct (1) OIDs
  $logger->info("reading $Constants::CiscoProductsMibFile");
  open PRODUCTS_MIB_FILE, "<$Constants::CiscoProductsMibFile" or do {
    $logger->fatal("Couldn't open $Constants::CiscoProductsMibFile for reading, $!");
    exit;
  };
  my $pcount = 0;
  while (<PRODUCTS_MIB_FILE>) {
    chomp;
    next if !/(\w+)\s+OBJECT IDENTIFIER\s+::=\s+\{\s+ciscoProducts\s+(\d+)\s+}/;
    my $ChassisName = $1;
    my $Number = $2;
    my $Comment = $';
    $Comment =~ s/^\s+--\s+//;
    $Comment =~ s/\s+$//;
    my $oid = '1.3.6.1.4.1.9.1.' . $Number;
    $CiscoChassisNames{$oid} = $ChassisName;
    $CiscoChassisComments{$oid} = $Comment;
    $pcount++;
    $logger7->info("Chassis: $oid = \"$ChassisName\", \"$Comment\"");
  }
  close PRODUCTS_MIB_FILE;
  $logger->info("got $pcount chassis descriptions");

  # load the chassis workgroup OIDs, indexed by workgroup (5) OIDs
  $logger->info("reading $Constants::CiscoStackMibFile");
  open STACK_MIB_FILE, "<$Constants::CiscoStackMibFile" or do {
    $logger->fatal("Couldn't open $Constants::CiscoStackMibFile for reading, $!");
    exit;
  };
  my $scount = 0;
  while (<STACK_MIB_FILE>) {
    last if /^moduleType OBJECT-TYPE/;
    chomp;
    next if !/(\w+)\s+OBJECT IDENTIFIER\s+::=\s+\{\s+workgroup\s+(\d+)\s+}/;
    my $ChassisName = $1;
    my $Number = $2;
    my $Comment = $';
    $Comment =~ s/^\s+--\s+//;
    $Comment =~ s/\s+$//;
    my $oid = '1.3.6.1.4.1.9.5.' . $Number;
    $CiscoChassisNames{$oid} = $ChassisName;
    $CiscoChassisComments{$oid} = $Comment;
    $scount++;
    $logger7->debug("Chassis: $oid = \"$ChassisName\", \"$Comment\"");
  }
  $logger->info("got $scount chassis descriptions");

  # load the module names and descriptions, indexed by module number
  my $mcount = 0;
  while (!/^\s+}/) {
    chomp;
    if (/^\s+(\w+)\((\d+)\),?\s*-- *(.+)/) {
      my $ModuleName = $1;
      my $ModuleNumber = $2;
      my $ModuleComment = $3;
      $ModuleComment = 'unknown' if $ModuleComment eq 'none of the following';
      while (<STACK_MIB_FILE>) {
        last if /^\s+-- the following modules/;
        last if !/^\s+-- *(.*)/;
        chomp;
        my $CommentContinuation = $1;
        $ModuleComment .= ' ' . $CommentContinuation;
      }
      $CiscoModuleNames{$ModuleNumber} = $ModuleName;
      $CiscoModuleComments{$ModuleNumber} = $ModuleComment;
      $mcount++;
      $logger7->debug("Module: $ModuleNumber = \"$ModuleName\", \"$ModuleComment\"");
    } else {
      $_ = <STACK_MIB_FILE>;
    }
  }
  close STACK_MIB_FILE;
  $logger->info("got $mcount module descriptions");


  # load the cevChassis and cevModule entity vendortype OIDs
  $logger->info("reading $Constants::CiscoEntityVendortypeMibFile");
  open ENTITY_VENDORTYPE_MIB_FILE, "<$Constants::CiscoEntityVendortypeMibFile" or do {
    $logger->fatal("Couldn't open $Constants::CiscoEntityVendortypeMibFile for reading, $!");
    exit;
  };
  my $ecount = 0;
  while (<ENTITY_VENDORTYPE_MIB_FILE>) {
    last if /cevMIBObjects 3/;   # find cevChassis section
  }
  while (<ENTITY_VENDORTYPE_MIB_FILE>) {
    last if /cevMIBObjects 4/;   # done with cevChassis section?
    chomp;
    next if !/(\w+)\s+OBJECT IDENTIFIER\s+::=\s+\{\s+cevChassis\s+(\d+)\s+}/;
    my $ChassisName = $1;
    my $Number = $2;
    my $Comment = $';
    $Comment =~ s/^\s+--\s+//;
    $Comment =~ s/\s+$//;
    my $oid = '1.3.6.1.4.1.9.12.3.1.3.' . $Number;
    $CiscoChassisNames{$oid} = $ChassisName;
    $CiscoChassisComments{$oid} = $Comment;
    $ecount++;
    $logger7->debug("Chassis: $oid = \"$ChassisName\", \"$Comment\"");
  }
  $logger->info("got $ecount chassis descriptions");

  while (<ENTITY_VENDORTYPE_MIB_FILE>) {
    last if /cevMIBObjects 9/;   # find cevModule section
  }
  my $ccount = 0;
  my $ModuleSection = 0;
  my $baseOid = '';
  while (<ENTITY_VENDORTYPE_MIB_FILE>) {
    last if /cevMIBObjects 10/; # done with cevModule section?
    chomp;
    next if !/(\w+)\s+OBJECT IDENTIFIER\s+::=\s+\{\s+(\w+)\s+(\d+)\s+}/;
    my $ModuleName = $1;
    my $ModuleParent = $2;
    my $ModuleNumber = $3;
    my $ModuleComment = $';
    $ModuleComment =~ s/^\s+--\s+//;
    $ModuleComment =~ s/\s+$//;
    if ($ModuleParent eq 'cevModule') {
      $baseOid = "1.3.6.1.4.1.9.12.3.1.9.$ModuleNumber.";
    } else {
      my $oid = $baseOid . $ModuleNumber;
      $CiscoModuleNames{$oid} = $ModuleName;
      $CiscoModuleComments{$oid} = $ModuleComment;
      $ccount++;
      $logger7->debug("Module: $oid = \"$ModuleName\", \"$ModuleComment\"");
    }
  }
  close ENTITY_VENDORTYPE_MIB_FILE;
  $logger->info("got $ccount module descriptions");

  $logger->debug("returning");
}


sub getCiscoSysObjectIDs () {
  return keys %CiscoChassisNames;
}


sub getCiscoChassisName ($) {
  my $sysObjectID = shift;
  return '' if !exists $CiscoChassisNames{$sysObjectID};
  return $CiscoChassisNames{$sysObjectID};
}


sub getCiscoChassisComment ($) {
  my $sysObjectID = shift;
  return '' if !exists $CiscoChassisComments{$sysObjectID};
  return $CiscoChassisComments{$sysObjectID};
}


sub getCiscoModuleName ($) {
  my $sysObjectID = shift;
  return '' if !exists $CiscoModuleNames{$sysObjectID};
  return $CiscoModuleNames{$sysObjectID};
}


sub getCiscoModuleComment ($) {
  my $sysObjectID = shift;
  return '' if !exists $CiscoModuleComments{$sysObjectID};
  return $CiscoModuleComments{$sysObjectID};
}


sub getCiscoModuleStatus ($) {
  my $sysObjectID = shift;
  return '' if !exists $CiscoModuleStatus{$sysObjectID};
  return $CiscoModuleStatus{$sysObjectID};
}


sub getCiscoSwitchRole ($) {
  my $sysObjectID = shift;
  return '' if !exists $CiscoSwitchRoles{$sysObjectID};
  return $CiscoSwitchRoles{$sysObjectID};
}


1;
