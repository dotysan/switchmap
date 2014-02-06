package WriteSuspiciousPortsFile;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;


sub PortsInWrongBuildingTable (%) {
 my $SwitchesRef = shift;      # passed in
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $TableContents = '';
  my $MacIpAddrRef = MacIpTables::getMacIpAddr();
  my $MacHostNameRef = MacIpTables::getMacHostName();
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/;          # skip it if it's a group name
    next if $SwitchName eq 'tcom-gs-1';     # tcom-gs-1 doesn't follow our labeling standard
    next if $SwitchName =~ /\.frgp\.net$/;  # l3-gw-1, frgp-gw-2 and frgp-gw-3 don't follow our labeling standard
    $SwitchName =~ /([^\-]+)\-/;            # match the building part (the characters before the first dash)
    my $SwitchBuilding = $1;
    $SwitchBuilding = 'ml'  if $SwitchName eq 'mlra';      # wotta hack
    $SwitchBuilding = 'cg2' if $SwitchName eq 'cgra';      # wotta hack
    $SwitchBuilding = 'fl2' if $SwitchName eq 'flra';      # another hack
    my @GoofyPorts;
    foreach my $PortName (Portically::PortSort keys %{$Switch->{Ports}}) {
      $logger->debug("$SwitchName = \"$SwitchName\", \$PortName = \"$PortName\"");
      my $Port = $Switch->{Ports}{$PortName};
      next if $Port->{IsTrunking};          # skip trunk ports
      next if $Port->{State} eq 'Disabled'; # skip disabled ports
      my $PortLabel = $Port->{Label};
      next if $PortLabel eq '';             # skip ports with blank labels
      next if $PortLabel =~ /^\//;          # skip ports with labels that start with a slash (they connect to machines in computer rooms)
      next if $PortLabel !~ /([^\-]+)\-/;   # skip it if there's no building part (characters before the first dash)
      my $PortBuilding = lc($1);            # lowercase it
      if ((defined $SwitchBuilding) and ($PortBuilding ne $SwitchBuilding)) {
        push @GoofyPorts, $Port;
      }
    }
    if (@GoofyPorts) {
      $TableContents .= "<h2>Switch $SwitchName</h2>\n";
      $TableContents .= "<p>\n";
      $TableContents .= SwitchUtils::HtmlPortTableHeader();
      foreach my $GoofyPort (@GoofyPorts) {
        $TableContents .= SwitchUtils::MakeHtmlRow($Switch,
                                            $GoofyPort,
                                            $MacIpAddrRef,
                                            $MacHostNameRef,
                                            SwitchUtils::GetDirectoryDepth($Constants::PortsDirectory));
      }
      $TableContents .= "</table>\n";
    }
  }

  my $RetVal = '';
  if ($TableContents ne '') {
    $RetVal = "<h3>Non-trunking ports with labels that indicate a building that doesn't match the switch's building</h3>\n" . $RetVal;
  }

  $logger->debug("returning");
  return $RetVal;
}


sub WriteSuspiciousPortsFile ($) {
  my $SwitchesRef = shift;      # passed in
  my $logger = get_logger('log2');
  $logger->debug("called");

  my $SuspiciousFile = File::Spec->catfile($Constants::PortsDirectory, $Constants::SuspiciousFile);
  $logger->debug("writing $SuspiciousFile");
  open SUSPICIOUSHTMLFILE, ">$SuspiciousFile" or do {
    $logger->fatal("Couldn't open $SuspiciousFile for writing, $!");
    exit;
  };
  print SUSPICIOUSHTMLFILE SwitchUtils::HtmlHeader("Suspicious Ports");
  print SUSPICIOUSHTMLFILE PortsInWrongBuildingTable($SwitchesRef);
#  print SUSPICIOUSHTMLFILE PortsWithBadLabelsTable($SwitchesRef);
  print SUSPICIOUSHTMLFILE SwitchUtils::HtmlTrailer();
  close SUSPICIOUSHTMLFILE;
  SwitchUtils::AllowAllToReadFile $SuspiciousFile;
  $logger->debug("returning");
}

1;
