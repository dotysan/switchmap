package WriteGigePerVlansDirectory;

# This module was created to satisfy a one-time need at my site.  It's
# not really a well-planned part of the SwitchMap scripts, and was
# created by copying-and-modifying WriteVlansDirectory.pm.  After all,
# WriteVlansDirectory produces the "Ports By Vlan" page, so it was
# reasonable to modify it slightly to produce "Gige Ports by Vlan".
# It's likely that this module will be deleted in the future.
# Pete Siemsen. 2005-10-17.

use strict;
use Log::Log4perl qw(get_logger);
use Portically;

sub WriteGigePerVlansIndexFile ($$) {
  my $VlansRef = shift;
  my $GigePortsPerVlanRef = shift;
  my $logger = get_logger('log3');
  my $ByVlanIndexFileName = File::Spec->catfile($Constants::GigePerVlansDirectory, 'index.html');
  $logger->debug("called, writing $ByVlanIndexFileName");

  open BYVLANINDEXFILE, ">$ByVlanIndexFileName" or do {
    $logger->fatal("Couldn't open $ByVlanIndexFileName for writing, $!");
    exit;
  };
  print BYVLANINDEXFILE SwitchUtils::HtmlHeader("Gigabit Ports Organized By VLAN");
  print BYVLANINDEXFILE "<table class=\"noborder\" width=640>\n";

  my $i = 0;
  my $columns = 4;
  my @Vlans = keys %$VlansRef;  # an unsorted list of all VLANs
  my $rows = ($#Vlans / $columns) + 1;
  my @RowBody = ();
  foreach my $VlanNbr ( sort {$a<=>$b} keys %$VlansRef ) {
    my $Vlan = $$VlansRef{$VlanNbr};
    my $PortCount = (exists $GigePortsPerVlanRef->{$VlanNbr}) ? $GigePortsPerVlanRef->{$VlanNbr} : 0;
    $RowBody[$i] .= <<RBODY;
<td>
<a href="vlan$VlanNbr.html">VLAN$VlanNbr</a>&nbsp;<small>(</small>$PortCount<small>&nbsp;ports)</small>
</td>
RBODY
    $i = 0 if ++$i >= $rows;
  }
  foreach my $row (@RowBody) {
    print BYVLANINDEXFILE "<tr>$row </tr>\n";
  }
  print BYVLANINDEXFILE "</table>\n";
  print BYVLANINDEXFILE SwitchUtils::HtmlTrailer();
  close BYVLANINDEXFILE;
  SwitchUtils::AllowAllToReadFile $ByVlanIndexFileName;
  $logger->debug("returning");
}                               # WriteGigePerVlansIndexFile


#
# Given a hash of hashes, write the Vlan tables.
#
sub WriteGigePerVlansDataFiles ($) {
  my $VlanBodiesRef = shift;   # passed in hash of hashes
  my $logger = get_logger('log3');
  $logger->debug("called");

  foreach my $VlanNbr (sort keys %$VlanBodiesRef ) {
    my $ByVlanFileName = File::Spec->catfile($Constants::GigePerVlansDirectory, 'vlan' . $VlanNbr . '.html');
    $logger->debug("writing $ByVlanFileName");
    open VLANHTMLFILE, ">$ByVlanFileName" or do {
      $logger->fatal("Couldn't open $ByVlanFileName for writing, $!");
      exit;
    };
    print VLANHTMLFILE SwitchUtils::HtmlHeader("Gigabit ports on VLAN $VlanNbr");
    my $VlanBodies = $$VlanBodiesRef{$VlanNbr};
    foreach my $SwitchName (sort keys %$VlanBodies) {
      print VLANHTMLFILE "<h2>Switch $SwitchName</h2>\n";
      print VLANHTMLFILE SwitchUtils::HtmlPortTableHeader();
      print VLANHTMLFILE $$VlanBodies{$SwitchName};
      print VLANHTMLFILE "</table></p>\n\n";
    }
    print VLANHTMLFILE SwitchUtils::HtmlTrailer();
    close VLANHTMLFILE;
    SwitchUtils::AllowAllToReadFile $ByVlanFileName;
  }
  $logger->debug("returning");
}


sub WriteGigePerVlansDirectory ($$) {
  my $SwitchesRef = shift;   # passed in
  my $VlansRef    = shift;   # passed in
  my $logger = get_logger('log2');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::GigePerVlansDirectory; # create or empty out the directory

  # Create a local hash of empty anonymous hashes, one for each VLAN.
  my %VlanBodies;
  foreach my $Vlan (keys %$VlansRef) {
    $VlanBodies{$Vlan} = {};
  }

  my %GigePortsPerVlan;
  my $MacIpAddrRef = MacIpTables::getMacIpAddr();
  my $MacHostNameRef = MacIpTables::getMacHostName();

  # Go through all the ports in all the switches, filling in the local
  # anonymous hashes.  In each local anonymous hash, each key is a
  # switch name and each value is a text string that is the body of
  # the HTML table that represents the ports that are in the VLAN.
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/;     # skip it if it's a group name
    foreach my $PortName (Portically::PortSort keys %{$Switch->{Ports}}) {
      my $Port = $Switch->{Ports}{$PortName};
      next if (!defined $Port->{Speed}) or ($Port->{Speed} ne '1G');
      my $VlanNbr = (exists $Port->{VlanNbr}) ? $Port->{VlanNbr} : 0; # for ports that aren't in a VLAN, call it VLAN 0 for now
      $VlanBodies{$VlanNbr}{$SwitchName} .=
        SwitchUtils::MakeHtmlRow($Switch,
                                 $Port,
                                 $MacIpAddrRef,
                                 $MacHostNameRef,
                                 SwitchUtils::GetDirectoryDepth($Constants::GigePerVlansDirectory));
      $GigePortsPerVlan{$VlanNbr}++;
    }
  }

  WriteGigePerVlansDataFiles(\%VlanBodies);
  WriteGigePerVlansIndexFile($VlansRef, \%GigePortsPerVlan);
  $logger->debug("returning");
}

1;
