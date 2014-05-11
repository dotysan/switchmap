package WriteUnusedDirectory;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;
#use Data::Dumper;


sub WriteUnusedRow ($$) {
  my $Switch = shift;
  my $Port   = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $PortName     = $Port->{Name};
  my $VlanNbr      = (exists $Port->{VlanNbr}) ? $Port->{VlanNbr} : '&nbsp;';
  my $DaysInactive = $Port->{DaysInactive};
  my $Speed        = (defined $Port->{Speed}) ? $Port->{Speed} : 'n/a';
  my $Duplex       = (exists $Port->{Duplex}) ? $Port->{Duplex} : '&nbsp;';
  my $Label        = (defined $Port->{Label} and ($Port->{Label} ne '')) ? $Port->{Label} : '&nbsp;';

  my $RetVal = <<UROW;
<tr class="cellUnused">
<td>$PortName</td>
<td>$VlanNbr</td>
<td>$DaysInactive</td>
<td>$Speed</td>
<td>$Duplex</td>
<td>$Label</td>
</tr>
UROW
  $logger->debug("returning");
  return $RetVal;
}


sub HtmlUnusedPortTableHeader () {
  return <<UPTH;
<tr class="tblHead">
<th>Port</th>
<th>VLAN</th>
<th>Days<br>Inactive</th>
<th>Speed</th>
<th>Duplex</th>
<th>Port Label</th>
</tr>
UPTH
}


sub WriteUnusedByVlanFiles ($) {
  my $VlansRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  foreach my $VlanNbr (sort {$a <=> $b} keys %$VlansRef) {
    my $Vlan = $$VlansRef{$VlanNbr};
    my $VlanName= $ThisSite::VlanNames[$VlanNbr]? $ThisSite::VlanNames[$VlanNbr] : '[unknown]';
    next if $Vlan->{NbrUnusedPorts} == 0; # skip this VLAN if it has no unused ports on any switch
    my $UbvFileName = 'vlan' . $VlanNbr . '-unused.html';
    my $UnusedByVlanFileName = File::Spec->catfile($Constants::UnusedDirectory, $UbvFileName);
    $logger->info("writing $UnusedByVlanFileName");
    open UBVFILE, ">$UnusedByVlanFileName" or do {
      $logger->fatal("Couldn't open $UnusedByVlanFileName for writing, $!");
      exit;
    };
    print UBVFILE SwitchUtils::HtmlHeader("Unused Ports (idle for > $ThisSite::UnusedAfter days) on VLAN $VlanNbr: $VlanName");
    foreach my $SwitchName (sort keys %{$Vlan->{Switches}}) {
      print UBVFILE "<h2>$SwitchName</h2>";
      print UBVFILE "<table class=\"UnusedPorts\">\n";
      print UBVFILE HtmlUnusedPortTableHeader();
      my $Switch = $Vlan->{Switches}{$SwitchName};
      foreach my $PortName (Portically::PortSort keys %{$Switch->{Ports}}) {
        my $Port = $Switch->{Ports}{$PortName};
        if ((defined $Port->{VlanNbr}) and
            ($Port->{VlanNbr} == $VlanNbr)) {
          print UBVFILE WriteUnusedRow($Switch, $Port) if $Port->{Unused};
        }
      }
      print UBVFILE "</table>\n";
    }
    close UBVFILE;
    SwitchUtils::AllowAllToReadFile $UnusedByVlanFileName;
  }

  $logger->debug("returning");
}


sub WriteUnusedBySwitchData ($) {
  my $Switch = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");
  my $RetVal = '';
  foreach my $PortName (Portically::PortSort keys %{$Switch->{Ports}}) {
    my $Port = $Switch->{Ports}{$PortName};
    if ($Port->{Unused}) {
      $RetVal .= WriteUnusedRow($Switch, $Port);
    }
  }
  $logger->debug("returning");
  return $RetVal;
}


sub WriteUnusedBySwitchFiles ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  foreach my $Switch (sort @$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/;          # skip this switch if it's a group name
    next if $Switch->{NbrUnusedPorts} == 0; # skip this switch if it doesn't have any unused ports
    my $UbsFileName = $SwitchName . '.html';
    my $UnusedBySwitchFileName = File::Spec->catfile($Constants::UnusedDirectory, $UbsFileName);
    $logger->info("writing $UnusedBySwitchFileName");
    open UBSFILE, ">$UnusedBySwitchFileName" or do {
      $logger->fatal("Couldn't open $UnusedBySwitchFileName for writing, $!");
      exit;
    };
    print UBSFILE SwitchUtils::HtmlHeader("Unused Ports (idle for > $ThisSite::UnusedAfter days) on $SwitchName");
    print UBSFILE "<table class=\"UnusedPorts\">\n";
    print UBSFILE HtmlUnusedPortTableHeader();
    print UBSFILE WriteUnusedBySwitchData($Switch);
    print UBSFILE "</table>\n\n";
    print UBSFILE SwitchUtils::HtmlTrailer;
    close UBSFILE;
    SwitchUtils::AllowAllToReadFile $UnusedBySwitchFileName;
  }
  $logger->debug("returning");
}


sub UnusedByVlanIndex ($) {
  my $VlansRef = shift;         # passed in
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $i = 0;
  my $columns = 4;
  my $NbrVlans = keys %$VlansRef;
  my $rows = ($NbrVlans / $columns) + 1;
  my @OutList = ();
  my $RetVal .= "<h3>Unused Ports Organized By Vlan</h3>\n" .
    "<table class=\"noborder\" width=1200>\n";
  foreach my $VlanNbr (sort {$a <=> $b} keys %$VlansRef) {
    my $Vlan = $$VlansRef{$VlanNbr};
    my $VlanName= $ThisSite::VlanNames[$VlanNbr]? $ThisSite::VlanNames[$VlanNbr] : '[unknown]';

    if ($Vlan->{NbrUnusedPorts} == 0) {
      $OutList[$i] .= "<td>$VlanNbr: $VlanName&nbsp;<small>(</small>0<small>&nbsp;unused)</small></td>";
    } else {
      my $UbvFileName = 'vlan' . $VlanNbr . '-unused.html';
      $OutList[$i] .= "<td><a href=\"$UbvFileName\">$VlanNbr: $VlanName</a>&nbsp;<small>(</small>$Vlan->{NbrUnusedPorts}<small>&nbsp;unused)</small></td>";
    }
    $i = 0 if ++$i >= $rows;
  }
  foreach my $Row (@OutList) {
    $RetVal .= "<tr>$Row</tr>\n";
  }
  $RetVal .=  "</table>\n";

  $logger->debug("returning");
  return $RetVal;
}


sub UnusedBySwitchIndex ($) {
  my $SwitchesRef = shift;      # passed in
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $i = 0;
  my $columns = 3;
  my $rows = ($#{$SwitchesRef} / $columns) + 1;
  my @OutList = ();
  my $RetVal .= "<h3>Unused Ports Organized By Switch</h3>\n" .
    "<table class=\"noborder\">\n";
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/;     # skip it if it's a group name
    if ($Switch->{NbrUnusedPorts} == 0) {
      $OutList[$i] .= "<td>$SwitchName <small>(</small>0<small> unused)</small></td>";
    } else {
      $OutList[$i] .= "<td><a href=\"$SwitchName.html\">$SwitchName</a> <small>(</small>$Switch->{NbrUnusedPorts}<small> unused)</small></td>";
    }
    $i = 0 if ++$i >= $rows;
  }
  foreach my $Row (@OutList) {
    $RetVal .= "<tr>$Row</tr>\n";
  }
  $RetVal .=  "</table>\n";

  $logger->debug("returning");
  return $RetVal;
}


sub WriteUnusedIndex ($$) {
  my $SwitchesRef = shift;      # passed in
  my $VlansRef    = shift;      # passed in
  my $logger = get_logger('log3');
  my $IndexFileName = File::Spec->catfile($Constants::UnusedDirectory, 'index.html');
  $logger->debug("called, writing $IndexFileName");
  $logger->info("writing $IndexFileName");
  open INDEXFILE, ">$IndexFileName" or do {
    $logger->fatal("Couldn't open $IndexFileName for writing, $!");
    exit;
  };
  print INDEXFILE SwitchUtils::HtmlHeader("Unused Ports (idle for > $ThisSite::UnusedAfter days)");
  print INDEXFILE UnusedBySwitchIndex($SwitchesRef);
  print INDEXFILE UnusedByVlanIndex($VlansRef);
  print INDEXFILE SwitchUtils::HtmlTrailer;
  close INDEXFILE;
  SwitchUtils::AllowAllToReadFile $IndexFileName;
  $logger->debug("returning");
}


sub WriteUnusedDirectory ($$) {
  my $SwitchesRef = shift;
  my $VlansRef    = shift;
  my $logger = get_logger('log2');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::UnusedDirectory; # create or empty out the directory
  WriteUnusedBySwitchFiles($SwitchesRef);
  WriteUnusedByVlanFiles($VlansRef);
  WriteUnusedIndex($SwitchesRef, $VlansRef);
  $logger->debug("returning");
}

1;
