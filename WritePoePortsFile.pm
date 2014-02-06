package WritePoePortsFile;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;


my %ApprovedDevicesCounts;
my %ApprovedManufacturersCounts;
my %PortsWithApprovedMacs;
my @UnapprovedPoeHtmlLines;


sub DeviceTypeIsApproved($) {
  my $DeviceType = shift;
  #  my $logger = get_logger('log6');
  #  $logger->debug("called");
  #  $logger->debug("\$DeviceType = \"$DeviceType\"");
  if (grep /^$DeviceType$/, @ThisSite::DevicesApprovedForPoe) {
    #    $logger->debug("returning true");
    return 1;
  }
  #  $logger->debug("returning false");
  return 0;
}


sub MacIsApproved($) {
  my $Mac = shift;
  #  my $logger = get_logger('log6');
  #  $logger->debug("called");
  #  $logger->debug("\$Mac = \"$Mac\"");
  if (exists $ThisSite::MacsApprovedForPoe{$Mac}) {
    #    $logger->debug("returning true");
    return 1;
  }
  #  $logger->debug("returning false");
  return 0;
}


sub ManufacturerIsApproved($) {
  my $Manufacturer = shift;
  #  my $logger = get_logger('log6');
  #  $logger->debug("called");
  #  $logger->debug("\$Mac = \"$Mac\", \$Manufacturer = \"$Manufacturer\"");
  if (exists $ThisSite::ManufacturersApprovedForPoe{$Manufacturer}) {
    #    $logger->debug("returning true");
    return 1;
  }
  #  $logger->debug("returning false");
  return 0;
}


sub getUnapprovedPoePorts($@) {
  my $Switch             = shift;
  my $UnapprovedPoePorts = shift;
  my $logger = get_logger('log5');
  my $SwitchName = GetName $Switch;
  $logger->debug("called");

  my @returnedUnapprovedPoePorts;
  foreach my $PortName (Portically::PortSort keys %{$Switch->{Ports}}) {
#    $logger->debug("processing \"$SwitchName\", $PortName");
    my $Port = $Switch->{Ports}{$PortName};
    if ($Port->{PoeStatus} == $Constants::DELIVERING_POWER) {
      my $DeviceType = $Port->{CdpCachePlatform};
      my $Mac = '';
      my $NbrMacs = keys %{$Port->{Mac}};
      if ($NbrMacs == 1) { # if exactly one MAC exists on the port (we just don't handle more than one)
        foreach my $PortMac (keys %{$Port->{Mac}}) {
          next if $PortMac eq '';
          $Mac = $PortMac;
          last;
        }
      }
      if ($Mac ne '') {
#        $logger->debug("Mac = $Mac");
        my $Manufacturer = substr $Mac, 0, 6;
        if (DeviceTypeIsApproved($DeviceType)) {
#          $logger->debug("$Mac: device type is approved");
          $ApprovedDevicesCounts{$DeviceType}++;
        } elsif (ManufacturerIsApproved($Manufacturer)) {
#          $logger->debug("$Mac: manufacturer is approved");
          $ApprovedManufacturersCounts{$Manufacturer}++;
        } elsif (MacIsApproved($Mac)) {
#          $logger->debug("$Mac: MAC is approved");
          $PortsWithApprovedMacs{$Mac} = "$SwitchName#$PortName";
        } else {
#          $logger->debug("unapproved");
          push @returnedUnapprovedPoePorts, $Port;
        }
      }
    }
  }
  $logger->debug("returning");
  return @returnedUnapprovedPoePorts;
}


sub addBlockToUnapprovedPoeHtmlLines($@) {
  my $Switch             = shift;
  my $MacIpAddrRef       = shift;
  my $MacHostNameRef     = shift;
  my $UnapprovedPoePorts = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  if (@$UnapprovedPoePorts) {
    my $SwitchName = GetName $Switch;
    $logger->debug("for switch \"$SwitchName\", appending lines...");
    push @UnapprovedPoeHtmlLines, <<POE1;
<h2>Switch $SwitchName</h2>
<p>
POE1
    push @UnapprovedPoeHtmlLines, SwitchUtils::HtmlPortTableHeader();
    foreach my $Port (@$UnapprovedPoePorts) {
      my $PortName = $Port->{Name};
      $logger->debug("for switch \"$SwitchName\", appending a line for port $PortName");
      push @UnapprovedPoeHtmlLines, SwitchUtils::MakeHtmlRow($Switch,
                                                             $Port,
                                                             $MacIpAddrRef,
                                                             $MacHostNameRef,
                                                             SwitchUtils::GetDirectoryDepth($Constants::PortsDirectory));
    }
    push @UnapprovedPoeHtmlLines, "</table>\n";
  }
  $logger->debug("returning");
}


sub MakePoeTable ($) {
  my $SwitchesRef = shift;      # passed in
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $MacIpAddrRef   = MacIpTables::getMacIpAddr();
  my $MacHostNameRef = MacIpTables::getMacHostName();
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/; # skip it if it's a group name
    my @UnapprovedPoePorts;
    getUnapprovedPoePorts($Switch, \@UnapprovedPoePorts);
    foreach my $uport (@UnapprovedPoePorts) {
      $logger->debug("uport = \"$uport\"");
    }
    addBlockToUnapprovedPoeHtmlLines($Switch, $MacIpAddrRef, $MacHostNameRef, \@UnapprovedPoePorts);
  }
  $logger->debug("returning");
}


sub BuildApprovedManufacturersTable () {
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $RetVal;
  if (keys %ThisSite::ManufacturersApprovedForPoe == 0) {
    $RetVal = "The list of explicitly approved manufacturer OIDs is empty\n";
  } elsif (keys %ApprovedManufacturersCounts == 0) {
    $RetVal = "No devices match the list of explicitly approved manufacturer OIDs\n";
  } else {
    $RetVal = <<POE2;
<h3>Counts of ports delivering Power-over-Ethernet to devices whose manufacturer OIDs are approved for PoE:</h3>
<table class="Stats">
<tr class="tblhead"><th>Count</th><th>Manufacturer Oid</th><th>comment (from list of approved manufacturer OIDs)</th></tr>
POE2
    foreach my $Oid (keys %ThisSite::ManufacturersApprovedForPoe) {
      my $Count = (exists $ApprovedManufacturersCounts{$Oid}) ? $ApprovedManufacturersCounts{$Oid} : 0;
      my $Comment = (exists $ThisSite::ManufacturersApprovedForPoe{$Oid}) ? $ThisSite::ManufacturersApprovedForPoe{$Oid} : '&nbsp;';
      $RetVal .= <<POE3;
<tr><td>$Count</td><td>$Oid</td><td>$Comment</td></tr>
POE3
    }
    $RetVal .= "</table>\n";
  }
  $logger->debug("returning");
  return $RetVal;
}


sub BuildApprovedDevicesTable () {
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $RetVal = <<POE4;
<h3>Counts of ports delivering Power-over-Ethernet to devices that are approved for PoE:</h3>
<table class="Stats">
<tr class="tblhead"><th>Count</th><th>device type</th></tr>
POE4
  foreach my $DeviceType (@ThisSite::DevicesApprovedForPoe) {
    my $Count = (exists $ApprovedDevicesCounts{$DeviceType}) ? $ApprovedDevicesCounts{$DeviceType} : 0;
    $RetVal .= <<POE5;
<tr><td>$Count</td><td>$DeviceType</td></tr>
POE5
  }
  $RetVal .= "</table>\n";
  $logger->debug("returning");
  return $RetVal;
}


sub BuildApprovedMacsTable () {
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $RetVal = <<POE6;
<h3>Ports delivering Power-over-Ethernet to explicit MAC addresses that are approved for PoE:</h3>
<table class="Stats">
<tr class="tblhead"><th>Switch</th><th>Port</th><th>MAC address</th><th>comment (from list of approved MACs)</th></tr>
POE6
  foreach my $Mac (sort keys %PortsWithApprovedMacs) {
    my ($SwitchName, $PortName) = split /#/, $PortsWithApprovedMacs{$Mac};
    my $Comment = (exists $ThisSite::MacsApprovedForPoe{$Mac}) ? $ThisSite::MacsApprovedForPoe{$Mac} : '&nbsp';
    $RetVal .= <<POE7;
<tr><td>$SwitchName</td><td>$PortName</td><td>$Mac</td><td>$Comment</td></tr>
POE7
  }
  $RetVal .= "</table>\n";
  $logger->debug("returning");
  return $RetVal;
}


sub printPoeHtmlFileContents() {
  my $logger = get_logger('log3');
  $logger->debug("called");

  print POEHTMLFILE SwitchUtils::HtmlHeader("Power-over-Ethernet ports");
  print POEHTMLFILE BuildApprovedManufacturersTable();
  print POEHTMLFILE BuildApprovedDevicesTable();
  print POEHTMLFILE BuildApprovedMacsTable();
  if (@ThisSite::DevicesApprovedForPoe) { # if there is an approved devices list
    print POEHTMLFILE "<hr><h3>Ports delivering Power-over-Ethernet to unapproved devices or MACs:</h3>\n";
    if (@UnapprovedPoeHtmlLines) {
      print POEHTMLFILE @UnapprovedPoeHtmlLines;
    } else {
      print POEHTMLFILE "None.\n";
    }
  } else {
    print POEHTMLFILE "The list of approved devices in ThisSite.pm is empty, so there are no unapproved POE devices.\n";
  }
  print POEHTMLFILE SwitchUtils::HtmlTrailer();
  $logger->debug("returning");
}


sub WriteTheFile () {
  my $logger = get_logger('log2');
  $logger->debug("called");

  my $PoeFile = File::Spec->catfile($Constants::PortsDirectory, $Constants::PoeFile);
  $logger->debug("writing $PoeFile");
  open POEHTMLFILE, ">$PoeFile" or do {
    $logger->fatal("Couldn't open $PoeFile for writing, $!");
    exit;
  };
  printPoeHtmlFileContents();
  close POEHTMLFILE;
  SwitchUtils::AllowAllToReadFile $PoeFile;
  $logger->debug("returning");
}


sub WritePoePortsFile ($) {
  my $SwitchesRef = shift;      # passed in
  my $logger = get_logger('log2');
  $logger->debug("called");

  MakePoeTable($SwitchesRef);   # fill all the global arrays
  WriteTheFile();

  $logger->debug("returning");
}

1;
