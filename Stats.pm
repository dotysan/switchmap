package Stats;

use strict;
use Log::Log4perl qw(get_logger :levels);
use ModuleList;

my %ModuleModelCounts;
my %ModuleModelDescriptions;
my %SwitchModelCounts;
my @SwitchDetails;
my $TotalActivePorts =
  my $TotalActiveVirtualPorts =
  my $TotalAncillaryPorts =
  my $TotalDisabledPorts =
  my $TotalDisabledVirtualPorts =
  my $TotalEmptyPortLabels =
  my $TotalEtherChannelPorts =
  my $TotalInactivePorts =
  my $TotalInactiveVirtualPorts =
  my $TotalPorts =
  my $TotalPortsConnectedToIpPhone =
  my $TotalPortsWithAuxiliaryVlans =
  my $TotalTrunkPorts = 0;
my %TotalPortsPerVlan; # each key is a VLAN number and each value is the total number of ports in the VLAN


#
# Scan the Switches array and collect some statistics.
#
sub CollectStats ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $TotalExaminedPorts = 0;
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/;     # skip it if it's a group name
    my $Details = {};
    push @SwitchDetails, $Details;
    $Details->{Name} = $SwitchName;
    my $SwitchModel = $Switch->GetChassisModel;
    $logger->debug("$SwitchName: SwitchModel = \"$SwitchModel\"");
    $SwitchModelCounts{$SwitchModel}++;

    # collect module statistics
    if ($Switch->{NbrModules} > 1) { # if it has modules (i.e. 6509s have modules, 3524s don't)
      foreach my $ModNbr (keys %{$Switch->{ModuleList}{Model}}) { # for each module in the switch
        my $ModuleModel = $Switch->{ModuleList}->GetModuleModel($ModNbr);
        $ModuleModelCounts{$ModuleModel}++;
        $ModuleModelDescriptions{$ModuleModel} = $Switch->{ModuleList}->GetModuleDescription($ModNbr);
      }
    }

    # collect port statistics
    my $active = 0;
    my $inactive = 0;
    my $disabled = 0;
    my $ancillary = 0;
    foreach my $PortName (keys %{$Switch->{Ports}}) {
#      $logger->debug("port name = $PortName");
      my $Port = $Switch->{Ports}{$PortName};
      $TotalExaminedPorts++;
      if (SwitchUtils::IsAncillaryPort($Port)) {
        $TotalAncillaryPorts++;
        $ancillary++;
      } else {
        my $State = $Port->{State};
        if ($State eq 'Active') {
          if ($Port->{IsVirtual}) {
            $TotalActiveVirtualPorts++;
          } else {
            $TotalActivePorts++;
          }
          $active++;
          if ($State eq '') {
            $TotalEmptyPortLabels++;
          }
        } elsif ($State eq 'Inactive') {
          if ($Port->{IsVirtual}) {
            $TotalInactiveVirtualPorts++;
          } else {
            $TotalInactivePorts++;
          }
          $inactive++;
        } elsif ($State eq 'Disabled') {
          if ($Port->{IsVirtual}) {
            $TotalDisabledVirtualPorts++;
          } else {
            $TotalDisabledPorts++;
          }
          $disabled++;
        } elsif ($State eq 'Unknown') {
          $logger->warn("port in \"unknown\" state encountered");
        } else {
          $logger->warn("internal error: unexpected port state \"$State\" encountered");
        }
        $TotalPortsWithAuxiliaryVlans++ if $Port->{AuxiliaryVlanNbr};
        $TotalPortsConnectedToIpPhone++ if $Port->{IsConnectedToIpPhone};
        $TotalTrunkPorts++              if $Port->{IsTrunking};
        $TotalEtherChannelPorts++       if $Port->{EtherChannel};
        $TotalPortsPerVlan{$Port->{VlanNbr}}++ if defined $Port->{VlanNbr};
      }
    }
    $Details->{active}    = $active;
    $Details->{inactive}  = $inactive;
    $Details->{disabled}  = $disabled;
    $Details->{ancillary} = $ancillary;
    $Details->{total}     = $active + $inactive + $disabled;
  }
  $logger->debug("TotalActivePorts   = $TotalActivePorts");
  $logger->debug("TotalInactivePorts = $TotalInactivePorts");
  $logger->debug("TotalDisabledPorts = $TotalDisabledPorts");
  my $tmps = $TotalActivePorts + $TotalInactivePorts + $TotalDisabledPorts;
  $logger->debug("tmps               = $tmps");
  $logger->debug("returning, examined $TotalExaminedPorts ports");
}


#
# Output a table summarizing the number of each switch type.
#
sub WriteSwitchesTable () {
  my $logger = get_logger('log3');
  $logger->debug("called");

  print SWITCHSTATSFILE <<TTABLE;

<table class="Stats">
<caption class="stats">Switches</caption>
<tr class="tblHead"><th>Count</th><th>Model</th></tr>
TTABLE
  my $TotalSwitches = 0;
  foreach my $stype (sort keys %SwitchModelCounts) {
    print SWITCHSTATSFILE "<tr><td>$SwitchModelCounts{$stype}</td><td>$stype</td></tr>\n";
    $TotalSwitches += $SwitchModelCounts{$stype};
  }
  print SWITCHSTATSFILE
    "<tr><td>$TotalSwitches</td><td><b>Total</b></td></tr>\n" .
      "</table>\n";
  $logger->debug("returning");
}


sub WriteModulesTable () {
  my $logger = get_logger('log3');
  $logger->debug("called");

  print SWITCHSTATSFILE <<MTABLE;

<table class="Stats">
<caption class="stats">Modules</caption>
<tr class="tblHead"><th>Count</th><th>Model</th><th>Description</th></tr>
MTABLE
  my $TotalModules = 0;
  foreach my $Model (sort keys %ModuleModelCounts) {
    print SWITCHSTATSFILE <<MTABLE2;
<tr>
<td>$ModuleModelCounts{$Model}</td>
<td>$Model</td>
<td>$ModuleModelDescriptions{$Model}</td>
</tr>
MTABLE2
    $TotalModules += $ModuleModelCounts{$Model};
  }
  print SWITCHSTATSFILE <<MTABLE3;
<tr>
<td>$TotalModules</td>
<td colspan="2"><b>Total</b></td>
</tr>
</table>

MTABLE3
  $logger->debug("returning");
}


sub WritePortStatesTable () {
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $TotalVlans = keys %TotalPortsPerVlan; # in scalar context, keys returns the number of keys in a hash
  my $TotalPorts = $TotalActivePorts + $TotalInactivePorts + $TotalDisabledPorts;
  my $TotalVirtualPorts = $TotalActiveVirtualPorts + $TotalInactiveVirtualPorts + $TotalDisabledVirtualPorts;
  print SWITCHSTATSFILE <<TOTALS;
<table class="Stats">
<caption class="stats">Port by State</caption>
<tr class="tblhead"><th>&nbsp;</th><th>virtual</th><th>non-virtual</th></tr>
<tr><td>active ports</td><td>$TotalActiveVirtualPorts</td><td>$TotalActivePorts</td></tr>
<tr><td>inactive ports</td><td>$TotalInactiveVirtualPorts</td><td>$TotalInactivePorts</td></tr>
<tr><td>disabled ports</td><td>$TotalDisabledVirtualPorts</td><td>$TotalDisabledPorts</td></tr>
<tr><td><b>Total</b></td><td>$TotalVirtualPorts</td><td>$TotalPorts</td></tr>
</table>

TOTALS
  $logger->debug("returning");
}


sub WritePortCountsTable () {
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $TotalVlans = keys %TotalPortsPerVlan; # in scalar context, keys returns the number of keys in a hash
  print SWITCHSTATSFILE <<TOTALS;
<table class="Stats">
<caption class="stats">Port Types</caption>
<tr class="tblhead"><th>Count</th><th>What</th></tr>
<tr><td>$TotalPortsWithAuxiliaryVlans</td><td>ports with a defined auxiliary VLAN</td></tr>
<tr><td>$TotalPortsConnectedToIpPhone</td><td>ports connected to an IP phone</td></tr>
<tr><td>$TotalTrunkPorts</td><td>trunk ports</td></tr>
<tr><td>$TotalEtherChannelPorts</td><td>etherchannel ports</td></tr>
<tr><td>$TotalEmptyPortLabels</td><td>active ports with empty "Port Label" fields</td></tr>
</table>

TOTALS
  $logger->debug("returning");
}


sub WriteVlansTable () {
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $TotalVlans = keys %TotalPortsPerVlan; # in scalar context, keys returns the number of keys in a hash
  print SWITCHSTATSFILE <<TOTALS;
<table class="Stats">
<caption class="stats">VLANs</caption>
<tr class="tblhead"><th>Count</th><th>What</th></tr>
<tr><td>$TotalVlans</td><td>VLANs</td></tr>
</table>

TOTALS
  $logger->debug("returning");
}


sub WriteIpAddressesTable () {
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $TotalIpAddresses = SwitchUtils::getUniqueIpAddresses(); # in scalar context, keys returns the number of keys in a hash
  print SWITCHSTATSFILE <<TOTALS;
<table class="Stats">
<caption class="stats">Unique IP Addresses</caption>
<tr><td>$TotalIpAddresses</td></tr>
</table>

TOTALS
  $logger->debug("returning");
}


sub getSite($) {
  my $SwitchName = shift;
  return '910'  if $SwitchName =~ /^910/;
  return 'cg'   if $SwitchName =~ /^cg/;
  return 'fb'   if $SwitchName =~ /^fb/;
  return 'fl'   if $SwitchName =~ /^fl/;
  return 'frgp' if $SwitchName =~ /^frgp/;
  return 'l3'   if $SwitchName =~ /^l3/;
  return 'mar'  if $SwitchName =~ /^mar/;
  return 'ml'   if $SwitchName =~ /^ml/;
  return 'raf'  if $SwitchName =~ /^raf/;
  return 'ral'  if $SwitchName =~ /^ral/;
  return 'tcom' if $SwitchName =~ /^tcom/;
  return 'wy'   if $SwitchName =~ /^wy/;
  return substr $SwitchName, 0, 2;
}


sub WriteSwitchDetailTable () {
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $TotalVlans = keys %TotalPortsPerVlan; # in scalar context, keys returns the number of keys in a hash
  print SWITCHSTATSFILE <<DTOTALS;
<table class="Stats">
<caption class="stats">Switch Details</caption>
<tr class="tblhead"><th>Switch</th><th>active</th><th>inactive</th><th>disabled</th><th>total</th></tr>
DTOTALS

  my $site = '';
  my $lastSite = '';
  my $GrandActive = 0;
  my $GrandInactive = 0;
  my $GrandDisabled = 0;
  my $GrandAncillary = 0;
  my $GrandTotal = 0;
  my $SiteActive = 0;
  my $SiteInactive = 0;
  my $SiteDisabled = 0;
  my $SiteAncillary = 0;
  my $SiteTotal = 0;
  foreach my $SwitchDetail (@SwitchDetails) {
    my $SwitchName = $SwitchDetail->{Name};
    if ($ThisSite::DnsDomain eq '.ucar.edu') { # if we're at NCAR
      $site = getSite($SwitchName);
      $lastSite = $site if $lastSite eq '';
      if ($site ne $lastSite) {
        print SWITCHSTATSFILE "<tr class=\"sitetotals\"><td><b>$lastSite totals</b></td><td>$SiteActive</td><td>$SiteInactive</td><td>$SiteDisabled</td><td>$SiteTotal</td></tr>";
        $GrandActive    += $SiteActive;
        $GrandInactive  += $SiteInactive;
        $GrandDisabled  += $SiteDisabled;
        $GrandAncillary += $SiteAncillary;
        $GrandTotal     += $SiteTotal;
        $SiteActive = $SiteInactive = $SiteDisabled = $SiteAncillary = $SiteTotal = 0;
        $lastSite = $site;
      }
    }
    print SWITCHSTATSFILE "<tr>";
    print SWITCHSTATSFILE "<td>$SwitchName</td>";
    my $active    = $SwitchDetail->{active};     print SWITCHSTATSFILE "<td>$active</td>";      $SiteActive    += $active;
    my $inactive  = $SwitchDetail->{inactive};   print SWITCHSTATSFILE "<td>$inactive</td>";    $SiteInactive  += $inactive;
    my $disabled  = $SwitchDetail->{disabled};   print SWITCHSTATSFILE "<td>$disabled</td>";    $SiteDisabled  += $disabled;
    my $total     = $SwitchDetail->{total};      print SWITCHSTATSFILE "<td>$total</td>";       $SiteTotal     += $total;
    print SWITCHSTATSFILE "</tr>";
  }
  print SWITCHSTATSFILE "<tr class=\"sitetotals\"><td><b>$lastSite totals</b></td><td>$SiteActive</td><td>$SiteInactive</td><td>$SiteDisabled</td><td>$SiteTotal</td></tr>";

  $GrandActive    += $SiteActive;
  $GrandInactive  += $SiteInactive;
  $GrandDisabled  += $SiteDisabled;
  $GrandAncillary += $SiteAncillary;
  $GrandTotal     += $SiteTotal;

  print SWITCHSTATSFILE "<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>";

  print SWITCHSTATSFILE "<tr><tr class=\"grandtotals\"><td><b>Grand totals</b></td><td>$GrandActive</td><td>$GrandInactive</td><td>$GrandDisabled</td><td>$GrandTotal</td></tr>";

  print SWITCHSTATSFILE "</table>";

  $logger->debug("returning");
}


sub WriteStatisticsFile ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log2');
  my $SwitchStatsFileName = File::Spec->catfile($ThisSite::DestinationDirectory, $Constants::SwitchStatsFile);
  $logger->debug("called, writing $SwitchStatsFileName");

  CollectStats($SwitchesRef);

  open SWITCHSTATSFILE, ">$SwitchStatsFileName" or do {
    $logger->fatal("Couldn't open $SwitchStatsFileName for writing, $!");
    exit;
  };
  print SWITCHSTATSFILE SwitchUtils::HtmlHeader("Statistics");
  print SWITCHSTATSFILE "<table class=\"noborder\"><tr><td>\n";
  WriteSwitchesTable();
  print SWITCHSTATSFILE "</td><td>\n";
  WriteModulesTable();
  print SWITCHSTATSFILE "</td></tr></table>\n";
  print SWITCHSTATSFILE "<p>&nbsp;</p>\n";
  print SWITCHSTATSFILE "<table class=\"noborder\"><tr><td>\n";
  WritePortStatesTable();
  print SWITCHSTATSFILE "</td><td>\n";
  WritePortCountsTable();
  print SWITCHSTATSFILE "</td><td>\n";
  WriteVlansTable();
  print SWITCHSTATSFILE "</td><td>\n";
  WriteIpAddressesTable();
  print SWITCHSTATSFILE "</td></tr></table>\n";
  print SWITCHSTATSFILE "<p>&nbsp;</p>\n";
  WriteSwitchDetailTable();
  print SWITCHSTATSFILE SwitchUtils::HtmlTrailer();
  close SWITCHSTATSFILE;
  SwitchUtils::AllowAllToReadFile $SwitchStatsFileName;
  $logger->debug("returning");
}

1;
