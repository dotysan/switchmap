package OuiCodes;
use strict;
use Constants;

#
# This module contains GetOuiCodeMap, a function that returns a hash
# containing the contents of the OuiCodes.txt file.
#

my %OuiCodeMap;


sub GetOuiCodeMap () {
  if (!%OuiCodeMap) {           # if it's the first time we've been called
    open OUICODES, "<$Constants::OuiCodesFile" or
      die "Couldn't open $Constants::OuiCodesFile for reading, $!\n";
    while (<OUICODES>) {
      my ($oui, $org) = unpack 'A6 @7 A*', $_;
      $oui =~ tr/A-F/a-f/;
      $OuiCodeMap{$oui} = $org;
    }
    close OUICODES;
  }
  return \%OuiCodeMap;
}

1;
