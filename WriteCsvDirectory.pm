package WriteCsvDirectory;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;
#use Data::Dumper;
use VerifyPortLabels;


sub WriteCsvRow ($$$$) {
  my $Switch         = shift;
  my $Port           = shift;
  my $MacIpAddrRef   = shift;
  my $MacHostNameRef = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  # MAC, IP, SwitchName, Mod/Port, Label
  my $SwitchName  = GetName $Switch;
  my $SwitchModel = GetChassisModel $Switch;

  my $PortName     = $Port->{Name};
  my $VlanNbr      = (exists $Port->{VlanNbr}) ? $Port->{VlanNbr} : '';
  my $State        = $Port->{State};
  my $DaysInactive = ($Port->{DaysInactive} ne '') ? $Port->{DaysInactive} : '';
  my $Speed        = (defined $Port->{Speed}) ? $Port->{Speed} : 'n/a';
  my $Duplex       = (exists $Port->{Duplex}) ? $Port->{Duplex} : 'n/a';
  my $PortLabel    = (defined $Port->{Label}) ? $Port->{Label} : '';
  my $WhatViaCdp   = ($Port->{CdpCachePlatform} ne '') ? $Port->{CdpCachePlatform} : '';
  my $Mac          = '';
  my $Nic          = '';
  my $Ip           = '';
  my $Dns          = '';

  my $LeftMostRowCells = "$SwitchName,$PortName,$VlanNbr,$State,$DaysInactive,$Speed,$Duplex,$PortLabel,$WhatViaCdp,";
  if ($Port->{IsTrunking}) {
    if ($ThisSite::ShowOnlyActiveNonTrunkPortsInCsv) {
      print CSVFILE $LeftMostRowCells . "Trunk Port\n";
    }
  } else {
    my $NbrMacs = keys %{$Port->{Mac}};
    if ($NbrMacs == 0) {
      if ($ThisSite::ShowOnlyActiveNonTrunkPortsInCsv) {
        print CSVFILE $LeftMostRowCells . "No Active MAC Addresses\n";
      }
    } else {
      my @MacIps;
      foreach my $PortMac (keys %{$Port->{Mac}}) {
        next if $PortMac eq '';
        next if $PortMac =~ / Etherchannel$/;
        my $first6 = substr $PortMac, 0, 6;
        my $ia = (exists $$MacIpAddrRef  {$PortMac}) ? $$MacIpAddrRef  {$PortMac} : ''  ; # IP Address
        my $hn = (exists $$MacHostNameRef{$PortMac}) ? $$MacHostNameRef{$PortMac} : ''  ; # DNS Name
        push @MacIps, join ';', $PortMac, $ia, $hn;
      }
      foreach (sort @MacIps) {
        ($Mac, $Ip, $Dns) = split ';', $_;
        print CSVFILE $LeftMostRowCells . "$Mac,$Nic,$Ip,$Dns\n";
      }
    }
  }

  $logger->debug("returning");
}


sub WriteCsvFile ($$$) {
  my $Switch         = shift;
  my $MacIpAddrRef   = shift;
  my $MacHostNameRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my @PortNames = Portically::PortSort keys %{$Switch->{Ports}};
  if ($Switch->{NbrModules} > 1) { # if it has modules (i.e. 6509s have modules, 3524s don't)
    foreach my $ModNbr (sort {$a<=>$b} keys %{$Switch->{ModuleList}{Model}}) {
      my $Model = $Switch->{ModuleList}{Model}->{$ModNbr};
      foreach my $PortName (@PortNames) {
        $PortName =~ /[^\d]*(\d+)/; # this has to match "3/4", "Ga9/6" or "Fa2/0/15"
        if ((defined $1) and ($1 eq $ModNbr)) {
          my $Port = $Switch->{Ports}{$PortName};
          WriteCsvRow($Switch, $Port, $MacIpAddrRef, $MacHostNameRef);
        }
      }
    }
  } else {
    foreach my $PortName (@PortNames) {
      my $Port = $Switch->{Ports}{$PortName};
      WriteCsvRow($Switch, $Port, $MacIpAddrRef, $MacHostNameRef);
    }
  }
  $logger->debug("returning");
}


sub WriteCsvFiles ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $MacIpAddrRef = MacIpTables::getMacIpAddr();
  my $MacHostNameRef = MacIpTables::getMacHostName();
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName  = GetName $Switch;
    next if $SwitchName =~ /^---/;     # skip it if it's a group name
    my $CsvFileName = File::Spec->catfile($Constants::CsvDirectory, $SwitchName . '.csv');
    $logger->info("writing $CsvFileName");
    open CSVFILE, ">$CsvFileName" or do {
      $logger->fatal("Couldn't open $CsvFileName for writing, $!");
      exit;
    };
    WriteCsvFile($Switch, $MacIpAddrRef, $MacHostNameRef);
    close CSVFILE;
    SwitchUtils::AllowAllToReadFile $CsvFileName;
  }
  my $timstr = SwitchUtils::TimeStr;

  $logger->debug("returning");
}


sub WriteSwitchCsvFiles ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log2');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::CsvDirectory; # create or empty out the directory

  WriteCsvFiles($SwitchesRef);

  $logger->debug("returning");
}

1;
