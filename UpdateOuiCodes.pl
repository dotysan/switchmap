#!/usr/bin/perl -w
#
#    UpdateOuiCodes.pl
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
# This script updates the OuiCodes.txt file, which contains a list of
# the Organizationally Unique Identifiers used in MAC addresses.  The
# file is used by the SwitchMap.pl script.  See the SwitchMap.pl script
# for more information.
#
# The OuiCodes.txt file contains a list of Organizationally Unique
# Identifiers (the codes used in the first three bytes of MAC
# addresses).  These codes are officially assigned by the IEEE.  The
# IEEE provides a list of OUI information in a file named oui.txt,
# avaliable from http://standards.ieee.org/develop/regauth/oui/oui.txt
# The IEEE's oui.txt file is incomplete, since the IEEE doesn't list
# OUIs of organizations that have asked the IEEE to not publically
# list their OUIs.  The OuiCodes.txt file contains all the OUIs listed
# in the IEEE's oui.txt file, and several more that were learned
# elsewhere.  It is a more complete list than the one provided by the
# IEEE.  It also uses lowercase and uppercase, instead of the all
# uppercase used in the IEEE oui.txt file.  In other words, it's a
# better list.  The IEEE list, however, reflects OUIs that were
# recently assigned by the IEEE.  The following code reads the
# existing OuiCodes.txt file, then reads the oui.txt file downloaded
# from the IEEE, then merges in any new codes from the oui.txt file
# and produces a new OuiCodes.txt file.  It doesn't disturb any codes
# that existed in the old OuiCodes.txt file.
#

use strict;
use Log::Log4perl qw(get_logger :levels);
use Net::SNMP 5.2.0 qw(:snmp);
use FindBin;
use lib $FindBin::Bin;
use Constants;
use SwitchUtils;
use OuiCodes;

sub trimBS($) {
  my $oldOrg = shift;
  my $newOrg = $oldOrg;
  $newOrg =~ s/ +$//;
  $newOrg =~ s/^ +//;
  $newOrg =~ s/&/&amp;/;
  $newOrg =~ s/ Co\.,? ?Ltd\.?//i;
  $newOrg =~ s/ Co\. ? ,Ltd\.?//i;
  $newOrg =~ s/ Co,\.$//i;
  $newOrg =~ s/ Ltd\.,? Co\.$//i;
  $newOrg =~ s/,? ?Ltda?\.?,? ?//;
  $newOrg =~ s/,? Inc\.$//;
  $newOrg =~ s/,? Ind\.$//;
  $newOrg =~ s/ AB$//i;
  $newOrg =~ s/ Ag$//i;
  $newOrg =~ s/ Computer$//;
  $newOrg =~ s/ Corporation$//i;
  $newOrg =~ s/ Corp\.$//i;
  $newOrg =~ s/ Digital Technology$//i;
  $newOrg =~ s/ Enterprises$//;
  $newOrg =~ s/ GMBH$//i;
  $newOrg =~ s/ Information & Communications$//;
  $newOrg =~ s/ ,? LLC$//;
  $newOrg =~ s/ Manufacturing$//;
  $newOrg =~ s/ Networks$//;
  $newOrg =~ s/ Pte$//;
  $newOrg =~ s/ Pty\.?$//;
  $newOrg =~ s/ Pvt\.?$//;
  $newOrg =~ s/ SA$//i;
  $newOrg =~ s/ Systems$//;
  $newOrg =~ s/ Technologies$//i;
  $newOrg =~ s/ ?Technology$//i;
  $newOrg =~ s/ Electronics?$//;
  $newOrg =~ s/ Communications?$//;
#  if ($newOrg ne $oldOrg) {
#    print "$newOrg\n";
#  }
  return $newOrg;
}

# Read the existing OuiCodes.txt file.
my $OuiCodeMapRef = OuiCodes::GetOuiCodeMap;
my $tmp = $$OuiCodeMapRef{'080056'};
print "debug: it's \"$tmp\"\n";

#
#  Read oui.txt, populate $OuiCodeMapRef.
#
open IEEE, "<$Constants::IeeeFile" or
  die "Couldn't open $Constants::IeeeFile for reading, $!\n";
while (<IEEE>) {
  if (/\s+([0-9a-fA-F-]{6})\s+\(base 16\)\s+(.*)/) {
    my $oui = $1;
    $oui =~ tr/A-F/a-f/;
    my $org = $2;
    next if $org =~ /^\s*$/;    # skip "PRIVATE" ones
    my $trimmedOrg = trimBS($org);
    if (exists $$OuiCodeMapRef{$oui}) {
      my $oldOrg = trimBS($$OuiCodeMapRef{$oui});
      if (($oldOrg !~ /\(/) and
          ($trimmedOrg !~ /^$oldOrg/i)) {
        print "mismatch: oui = $oui\n";
        print "       old = $oldOrg\n";
        print "       new = $trimmedOrg\n";
        $$OuiCodeMapRef{$oui} = $trimmedOrg;
      }
    } else {
      $$OuiCodeMapRef{$oui} = $trimmedOrg;
    }
  }
}
close IEEE;


#
# Write OuiCodes.txt.
#
open OUICODES, ">$Constants::OuiCodesFile" or
  die "Couldn't open $Constants::OuiCodesFile for writing, $!\n";
foreach my $oui (sort keys %{$OuiCodeMapRef}) {
  print OUICODES "$oui $$OuiCodeMapRef{$oui}\n";
}
close OUICODES;
SwitchUtils::AllowAllToReadFile $Constants::OuiCodesFile;
