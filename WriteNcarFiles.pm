package WriteNcarFiles;

#
# This module contains code to write files that are used only at NCAR,
# where Pete (the author of SwitchMap) works.  As of 2006-06-27, when
# I wrote this module, it writes only one file, which contains
# information needed by Jim's Cisco VOIP Call Manager database.
#

use strict;
use Log::Log4perl qw(get_logger);
use Portically;
#use Data::Dumper;
use VerifyPortLabels;

my %seenMacs;

sub WriteCsvRow ($$$) {
  my $Switch       = shift;
  my $Port         = shift;
  my $MacIpAddrRef = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $SwitchModel = GetChassisModel $Switch;
  my $PortName    = $Port->{Name};
  my $SwitchName  = GetName $Switch;

  if ($Port->{IsSwitching} and
      (!$Port->{IsVirtual}) and
      ($Port->{State} eq 'Active') and
      (!SwitchUtils::IsAncillaryPort($Port)) and
      ((!$Port->{IsTrunking}) or (($SwitchModel =~ /3524/) and ($PortName !~ /^G/)))) {
    my $NbrMacs = keys %{$Port->{Mac}};
    if ($NbrMacs > 0) {         # one or more MACs exist on the port
      my @MacIps;
      foreach my $PortMac (keys %{$Port->{Mac}}) {
        next if $PortMac eq '';
        next if $PortMac eq '000000000000';
        next if $PortMac =~ / Etherchannel$/;
        my $first6 = substr $PortMac, 0, 6;
        if (exists $$MacIpAddrRef{$PortMac}) {
          push @MacIps, join ';', $$MacIpAddrRef{$PortMac}, $PortMac;
        } else {
          push @MacIps, join ';', '', $PortMac;
        }
      }
      my $PortLabel = (defined $Port->{Label}) ? $Port->{Label} : '';
      foreach (sort @MacIps) {
        my ($Ip, $Mac) = split ';', $_;
        if (exists $seenMacs{$Mac}) {
          $logger->debug("skipping output of a line for MAC = \"$Mac\", we've already output a line for this MAC");
        } else {
          $seenMacs{$Mac}++;
          print NCARCSVFILE "$Mac,$Ip,$SwitchName,$PortName,$PortLabel\n";
        }
      }
    }
  }

  $logger->debug("returning");
}


#
# These models of switches will never have phones attached, because
# they have only fiber or 10Gig interfaces.  We'll skip them because
# it confuses Jim Van Dyke's code if entries from these guys appear in
# the output file.
#
my @SkipModels = ( 'WS-X6408-GBIC',
                   'WS-X6408A-GBIC',
                   'WS-X6416-GBIC',
                   'WS-X6704-10GE',
                   'WS-X6748-SFP');

sub WriteNcarCallManagerCsvFileBody ($) {
  my $SwitchesRef  = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $MacIpAddrRef = MacIpTables::getMacIpAddr();
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---(.+)/;   # if it's a group name, not a switch
    my @PortNames = Portically::PortSort keys %{$Switch->{Ports}};
    if ($Switch->{NbrModules} > 1) { # if it has modules (i.e. 6509s have modules, 3524s don't)
      foreach my $ModNbr (sort {$a<=>$b} keys %{$Switch->{ModuleList}{Model}}) {
        my $Model = $Switch->{ModuleList}{Model}->{$ModNbr};
        next if (grep (/^$Model$/, @SkipModels) == 1);
        foreach my $PortName (@PortNames) {
          $PortName =~ /[^\d]*(\d+)/; # this has to match "3/4", "Ga9/6" or "Fa2/0/15"
          if ((defined $1) and ($1 eq $ModNbr)) {
            my $Port = $Switch->{Ports}{$PortName};
            WriteCsvRow($Switch, $Port, $MacIpAddrRef);
          }
        }
      }
    } else {
      foreach my $PortName (@PortNames) {
        my $Port = $Switch->{Ports}{$PortName};
        WriteCsvRow($Switch, $Port, $MacIpAddrRef);
      }
    }
  }
  $logger->debug("returning");
}


sub WriteNcarCallManagerCsvFile ($) {
  my $SwitchesRef  = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $CsvFileName = File::Spec->catfile($ThisSite::DestinationDirectory, 'NcarCallManager.csv');
  $logger->info("writing $CsvFileName");
  open NCARCSVFILE, ">$CsvFileName" or do {
    $logger->fatal("Couldn't open $CsvFileName for writing, $!");
    exit;
  };
  WriteNcarCallManagerCsvFileBody($SwitchesRef);
  close NCARCSVFILE;
  SwitchUtils::AllowAllToReadFile $CsvFileName;

  $logger->debug("returning");
}


sub WriteNcarFiles ($) {
  my $SwitchesRef  = shift;
  my $logger = get_logger('log2');
  $logger->debug("called");

  WriteNcarCallManagerCsvFile($SwitchesRef);
  VerifyPortLabels::WritePortLabelAnalysisFile($SwitchesRef);

  $logger->debug("returning");
}

1;
