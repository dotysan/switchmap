package WriteVlansDirectory;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;


sub WriteVlansIndexFile (%) {
  my $VlanPortCount = shift;
  my $logger = get_logger('log3');
  my $ByVlanIndexFileName = File::Spec->catfile($Constants::VlansDirectory, 'index.html');
  $logger->debug("called, writing $ByVlanIndexFileName");

  open BYVLANINDEXFILE, ">$ByVlanIndexFileName" or do {
    $logger->fatal("Couldn't open $ByVlanIndexFileName for writing, $!");
    exit;
  };
  print BYVLANINDEXFILE SwitchUtils::HtmlHeader("VLANs");
  print BYVLANINDEXFILE "<table class=\"noborder\" width=800>\n";

  #
  # Arrange the list of VLAN pages in a table, 5 per row so that
  # a reasonable number fit on the page without needing to scroll.
  #
  my $i = 0;
  my $columns = 5;
  my @VlanNames = keys %$VlanPortCount; # an unsorted list of VLAN names, perhaps including "0"
  my $rows = ($#VlanNames / $columns) + 1;
  my @RowBody = ();
  foreach my $VlanName ( sort {$a<=>$b} @VlanNames ) {
    $logger->debug("VlanName = \"$VlanName\"");
    my $PortCount = $VlanPortCount->{$VlanName};
    my $VlanDisplayName = ($VlanName == 0) ? "no VLAN" : "VLAN$VlanName";
    $RowBody[$i] .= <<RBODY;
<td><a href="vlan$VlanName.html">$VlanDisplayName</a>&nbsp;<small>(</small>$PortCount<small>&nbsp;ports)</small></td>
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
}


#
# Given a hash of hashes, write the Vlan tables.
#
sub WriteVlansDataFiles ($) {
  my $VlanBodiesRef = shift;    # passed in hash of hashes
  my $logger = get_logger('log3');
  $logger->debug("called");

  foreach my $VlanNbr (sort keys %$VlanBodiesRef ) {
    my $ByVlanFileName = File::Spec->catfile($Constants::VlansDirectory, 'vlan' . $VlanNbr . '.html');
    $logger->debug("writing $ByVlanFileName");
    open VLANHTMLFILE, ">$ByVlanFileName" or do {
      $logger->fatal("Couldn't open $ByVlanFileName for writing, $!");
      exit;
    };
    my $Title = ($VlanNbr == 0) ? "Ports in no VLAN" : "Ports in VLAN $VlanNbr";
    print VLANHTMLFILE SwitchUtils::HtmlHeader($Title);
    my $VlanBodies = $$VlanBodiesRef{$VlanNbr};
    foreach my $SwitchName (sort keys %$VlanBodies) {
      print VLANHTMLFILE "<h2>Switch <a href=\"../switches/$SwitchName.html\">$SwitchName</a></h2>\n";
      print VLANHTMLFILE "<p>\n";
      print VLANHTMLFILE SwitchUtils::HtmlPortTableHeader();
      print VLANHTMLFILE $$VlanBodies{$SwitchName};
      print VLANHTMLFILE "</table>\n";
      print VLANHTMLFILE "</p>\n\n";
    }
    print VLANHTMLFILE SwitchUtils::HtmlTrailer();
    close VLANHTMLFILE;
    SwitchUtils::AllowAllToReadFile $ByVlanFileName;
  }
  $logger->debug("returning");
}


sub WriteVlansDirectory ($) {
  my $SwitchesRef = shift;      # passed in
  my $logger = get_logger('log2');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::VlansDirectory; # create or empty out the directory

  my %VlanPortCount;
  my %VlanBodies;
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
      my $VlanNbr = (exists $Port->{VlanNbr}) ? $Port->{VlanNbr} : 0; # for ports that aren't in a VLAN, call it VLAN 0 for now
      $VlanBodies{$VlanNbr} = {} if !defined $VlanBodies{$VlanNbr};
      $VlanBodies{$VlanNbr}{$SwitchName} .= SwitchUtils::MakeHtmlRow($Switch,
                                                                     $Port,
                                                                     $MacIpAddrRef,
                                                                     $MacHostNameRef,
                                                                     SwitchUtils::GetDirectoryDepth($Constants::VlansDirectory));
      $VlanPortCount{$VlanNbr}++;
    }
  }

  WriteVlansDataFiles(\%VlanBodies);
  WriteVlansIndexFile(\%VlanPortCount);
  $logger->debug("returning");
}

1;
