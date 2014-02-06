#!/usr/bin/perl -w

package VerifyPortLabels;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;


my $NbrBadPortLabels       = 0;
my $NbrComputerRoomLabels  = 0;
my $NbrInactivePorts       = 0;
my $NbrLabels              = 0;
my $NbrSpareLabels         = 0;
my $NbrStandardDeviceNames = 0;
my $NbrStandardLabels      = 0;
my $NbrUndefinedLabels     = 0;
my $NbrUplinkDeviceNames   = 0;
my $NbrVirtualModuleLabels = 0;
my $NbrWallPhones          = 0;
my @BadConnectionDevices;
my @BadDeviceTypes;
my @BadManufacturers;
my @BadMediaTypes;
my @BadSites;
my @BadSubLocationTypes;
my @BlankLabels;
my @OtherLabels;

my %Sites = (
             'cg1' => "",
             'cg2' => "",
             'cg3' => "",
             'cg4' => "",
             'ml'  => "",
             'fl0' => "",
             'fl1' => "",
             'fl2' => "",
             'fl3' => "",
             'fl4' => "",
             'fla' => "",
             'fb'  => "",
             'jef' => "",
             'mar' => "",
             'raf' => "",
             'wy' => ""
            );
my %DeviceTypes = (
                   'acc'   => "",
                   'acr'   => "",
                   'ap'    => "",
                   'as'    => "",
                   'es'    => "",
                   'env'   => "",
                   'fc'    => "",
                   'fr'    => "",
                   'gs'    => "",
                   'gw'    => "",
                   'sar'   => "",
                   'sc'    => "",
                   'scc'   => "",
                   'sr'    => "",
                   'ts'    => "",
                   'ups'   => "",
                   'vg248' => "",
                   'vpn'   => "",
                   'wb'    => "",
                   'wdm'   => ""
                  );
my %Manufacturers = (
                     'apc' => "",
                     'asi' => "",
                     'at'  => "",
                     'bw'  => "",
                     'c'   => "",
                     'gc'  => "",
                     'j'   => "",
                     'm'   => "",
                     'wd'  => "",
                     'wm'  => ""
                    );
my %SwitchNames      = ( 'mlra' => "", 'flra' => "", 'flrb' => "", 'cgra' => "" );
my %CDNames          = (
                        'B' => "", # pull box
                        'C' => "", # ceiling outlet
                        'E' => "", # equipment (usually a device in a rack
                        'F' => "", # floor outlet
                        'H' => "", # half wallplate
                        'P' => "", # patch panel
                        'U' => "", # utility
                        'W' => "", # wallplate
                        'Z' => ""  # punch block
                       );
my %SubLocationTypes = ( 'C'    => "", 'F'    => "", 'R'    => "", 'M' => "", '#' => "" );
my %MediaTypes = (
                  'AS' => "",
                  'AU' => "",
                  'B3' => "",
                  'BS' => "",
                  'C3' => "",
                  'C5' => "",
                  'C6' => "",
                  'DF' => "",
                  'MF' => "",
                  'MM' => "",
                  'PH' => "",
                  'SF' => "",
                  'SM' => "",
                  'T1' => "",
                  'T2' => "",
                  'VI' => "",
                  'X3' => ""
                 );


# sub ErrorMessage($) {
#       my $msg = shift;
#       print $msg . "\n\n";
# }


sub HtmlLine($$$) {
  my $SwitchName = shift;       # passed in
  my $PortName   = shift;       # passed in
  my $Label      = shift;       # passed in
  return "<tr><td>$SwitchName</td><td>$PortName</td><td>$Label</td></tr>\n";
}


sub ParseNetworkDeviceName ($$$) {
  my $SwitchName = shift;       # passed in
  my $PortName   = shift;       # passed in
  my $Label      = shift;       # passed in
  my $logger     = get_logger('log4');
  if ( $Label =~ /^(\w+)-(\w+)-(\w+)-(\w+)( (\d+\/\d+))?$/ ) {
    $logger->debug("ParseNetworkDeviceName: match.\n");
    my $Site                = $1;
    my $Room                = $2;
    my $ManufacturerAndUnit = $3;
    my $DeviceType          = $4;
    my $RemotePort          = $5;
    if ( !exists $Sites{$Site} ) {

      # ErrorMessage "Bad site: 1st field isn't in " . join ',', sort keys %Sites;
      push @BadSites, HtmlLine( $SwitchName, $PortName, $Label );
    }
    $ManufacturerAndUnit =~ /(^[a-zA-Z]+)/;
    my $Manufacturer = $1;
    $logger->debug("Manufacturer = $Manufacturer\n");
    if ( !exists $Manufacturers{$Manufacturer} ) {

      # ErrorMessage "Bad manufacturer: 3rd field doesn't start with one of " . join ',', sort keys %Manufacturers;
      push @BadManufacturers, HtmlLine( $SwitchName, $PortName, $Label );
    }
    if ( !exists $DeviceTypes{$DeviceType} ) {

      # ErrorMessage "Bad device type: 4th field isn't in " . join ',', sort keys %DeviceTypes;
      push @BadDeviceTypes, HtmlLine( $SwitchName, $PortName, $Label );
    }
    if ( defined $RemotePort ) {

      # ErrorMessage "is an device name uplink";
      $NbrUplinkDeviceNames++;
    } else {

      # ErrorMessage "is a standard device name";
      $NbrStandardDeviceNames++;
    }
  } else {

    # ErrorMessage "couldn't recognize this network device name";
    push @OtherLabels, HtmlLine( $SwitchName, $PortName, $Label );
  }
}


sub ParseLocationLabel ($$$) {
  my $SwitchName = shift;       # passed in
  my $PortName   = shift;       # passed in
  my $Label      = shift;       # passed in
  my $logger     = get_logger('log4');
  if ( $Label =~ /^(\w+)-([#\w\/]+)-(\w+)-([\w:\/]+)( .+)?$/ ) { # standard location label, e.g. ML-220C-W1-C5:2A
    $logger->debug("ParseLocationLabel: match.\n");
    my $Site               = lc($1);
    my $RoomAndSubLocation = $2;
    my $ConnectionDevice   = lc($3);
    my $CardAndPort        = $4;
    $logger->debug("Site = $Site\n");
    $logger->debug("RoomAndSubLocation = $RoomAndSubLocation\n");
    $logger->debug("ConnectionDevice = $ConnectionDevice\n");
    $logger->debug("CardAndPort = $CardAndPort\n");

    if ( !exists $Sites{$Site} ) {

      # ErrorMessage "Bad site: 1st field isn't in " . join ',', sort keys %Sites;
      push @BadSites, HtmlLine( $SwitchName, $PortName, $Label );
    }
    if ( $RoomAndSubLocation =~ /\/(#|\w)/ ) {
      my $SubLocationType = $1;
      if ( !exists $SubLocationTypes{$SubLocationType} ) {

        # ErrorMessage "Bad connection device: 2nd field sublocation doesn't start with one of " . join ',', sort keys %SubLocationTypes;
        push @BadSubLocationTypes, HtmlLine( $SwitchName, $PortName, $Label );
      }
    }
    $ConnectionDevice =~ /^([a-z])/;
    my $CDName = uc($1);
    if ( !exists $CDNames{$CDName} ) {

      # ErrorMessage "Bad connection device: 3rd field doesn't start with one of " . join ',', sort keys %CDNames;
      push @BadConnectionDevices, HtmlLine( $SwitchName, $PortName, $Label );
    }
    my $Card      = "";
    my $MediaType = "";
    my $Port      = "";
    if ( $CardAndPort =~ /^(\w+)$/ ) {
      $Port      = $1;
    } elsif ( $CardAndPort =~ /^(\w+):(\w+)$/ ) {
      $MediaType = $1;
      $Port      = $2;
    } elsif ( $CardAndPort =~ /^([a-z])\/(\w+)$/ ) {
      $Card      = $1;
      $Port      = $2;
    } elsif ( $CardAndPort =~ /^([a-z])\/(\w+):(\w+)$/ ) {
      $Card      = $1;
      $MediaType = $2;
      $Port      = $3;
    } else {
      # ErrorMessage "Bad 4th field: doesn't match [Card/][Media Type:]Port";
      push @OtherLabels, HtmlLine( $SwitchName, $PortName, $Label );
    }

    if ( ( $MediaType ne "" ) && ( !exists $MediaTypes{$MediaType} ) ) {
      # ErrorMessage "Bad media type: 4th field doesn't contain with one of " . join ',', sort keys %MediaTypes;
      # print "ParseLocationLabel: Label = \"$Label\", MediaType = \"$MediaType\"\n";
      push @BadMediaTypes, HtmlLine( $SwitchName, $PortName, $Label );
    }

    # ErrorMessage "is a location label";
    $NbrStandardLabels++;
  } else {

    # ErrorMessage "couldn't recognize this location label";
    push @OtherLabels, HtmlLine( $SwitchName, $PortName, $Label );
  }
  $logger->debug("returning");
}


sub ParseWallPhone ($$$) {
  my $SwitchName = shift;       # passed in
  my $PortName   = shift;       # passed in
  my $Label      = shift;       # passed in
  my $logger     = get_logger('log4');
  $logger->debug("called, Label = \"$Label\"\n");
  if ( $Label =~ /^(\w+)-([\w\/]+) wallphone$/ ) { # site-room wallphone
    $logger->debug("ParseWallPhone: match.\n");
    my $Site               = lc($1);
    my $RoomAndSubLocation = $2;
    $logger->debug("Site = $Site\n");
    $logger->debug("RoomAndSubLocation = $RoomAndSubLocation\n");
    if ( !exists $Sites{$Site} ) {

      # ErrorMessage "Bad site: 1st field isn't in " . join ',', sort keys %Sites;
      push @BadSites, HtmlLine( $SwitchName, $PortName, $Label );
    } else {
      $NbrWallPhones++;
    }
  } else {
    push @OtherLabels, HtmlLine( $SwitchName, $PortName, $Label );
  }
  $logger->debug("returning");
}


sub VerifyPortLabel($$$) {
  my $SwitchName = shift;       # passed in
  my $PortName   = shift;       # passed in
  my $Label      = shift;       # passed in

  my $logger = get_logger('log4');
  $logger->debug("called, Label = \"$Label\"\n");
  if ( $Label =~ /^([a-zA-Z0-9-]+) ([a-zA-Z0-9]+\/\d+)$/ ) { # uplink label, e.g. ml-243b-c1-gs 8/7
      $NbrUplinkDeviceNames++;
  } elsif ( $Label =~ /^\/#?(\w+)\*([\w&]+):([\w# \.-]*)/ ) { # new-style computer room label, e.g. /#BG72*DSG:bs1101
    my $TileCoordinate = $1;
    my $OwningDivision = $2;
    my $MachineName    = $3;
    $NbrComputerRoomLabels++;
  } elsif ( $Label =~ / wallphone$/ ) { # wallphone label, e.g. ML-16C wallphone
    $logger->debug("calling ParseWallPhone\n");
    ParseWallPhone $SwitchName, $PortName, $Label;
  } elsif ( $Label =~ /^\w+-[#A-Z0-9\/:-]+( .+)?$/ ) { # location label, e.g. ML-26B-W1-3B
    $logger->debug("calling ParseLocationLabel\n");
    ParseLocationLabel $SwitchName, $PortName, $Label;
  } elsif ( $Label =~ /^[ a-z0-9-\/]+$/ ) { # device label, e.g. ml-mr-c2-gs
    $logger->debug("calling ParseNetworkDeviceName\n");
    ParseNetworkDeviceName $SwitchName, $PortName, $Label;
  } elsif ( $Label =~ /^BAD PORT/ ) {
    $NbrBadPortLabels++;
  } elsif ( $Label =~ /^SPARE/ ) {
    $NbrSpareLabels++;
  } else {
    # ErrorMessage "unrecognized (hint: mixed case can cause this)";
    push @OtherLabels, HtmlLine( $SwitchName, $PortName, $Label );
  }
  $logger->debug("returning");
}


sub ScanPort($$$) {
  my $SwitchName = shift;
  my $PortName   = shift;
  my $Port       = shift;
  $NbrLabels++;
  if ( !defined $Port->{Label} ) {
    $NbrUndefinedLabels++;
    return;
  }
  if ( ( $PortName eq '15/1' ) or ( $PortName eq '16/1' ) ) { # virtual module
    $NbrVirtualModuleLabels++;
    return;
  }
  if ($Port->{IsVirtual}) {
    return;
  }
  if ( $Port->{Label} eq "" ) {
    if ( $Port->{State} eq 'Active' ) {
      if (($PortName ne 'Lo0'    ) && # loopback?
          ($PortName ne 'Nu0'    ) && # null
          ($PortName ne 'Vo0'    ) && # virtual
          ($PortName ne 'sl0'    ) && # serial console
          ($PortName ne 'CPP'    ) && # Control Plane Policing?
          ($PortName ne 'SPAN RP') && # Switched Port Analyzer (SPAN) route processer?
          ($PortName ne 'SPAN SP')) { # Switched Port Analyzer (SPAN) switch processor?
        push @BlankLabels, HtmlLine( $SwitchName, $PortName, $Port->{Label} );
      }
    } else {
      $NbrInactivePorts++;
    }
  } else {
    VerifyPortLabel $SwitchName, $PortName, $Port->{Label};
  }
}


sub ScanSwitches($) {
  my $SwitchesRef = shift;      # passed in
  foreach my $Switch ( sort @$SwitchesRef ) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName eq 'l3-gw-1.frgp.net';      # hack!
    next if $SwitchName eq 'tcom-gs-1';             # hack!
    next if $SwitchName =~ /frgp-gw-\d.frgp.net/;   # hack!
    foreach my $PortName (Portically::PortSort keys %{ $Switch->{Ports} } ) {
      ScanPort($SwitchName, $PortName, $Switch->{Ports}{$PortName});
    }
  }
}


sub PrintTable($$) {
  my $ArrayRef     = shift;
  my $HeaderString = shift;
  my $num_items    = $#$ArrayRef + 1;
  print PORTLABELANALYSISFILE <<TABL;
<h2>$num_items $HeaderString...</h2>

<table border>
<tr class="tblHead"><th align="center">Switch</th><th align="center">Port</th><th align="center">Label</th></tr>
@$ArrayRef
</table>
TABL
}


sub WritePortLabelAnalysisFile ($) {
  my $SwitchesRef               = shift; # passed in
  my $logger                    = get_logger('log2');
  my $PortLabelAnalysisFileName = File::Spec->catfile( $Constants::PortsDirectory, $Constants::PortLabelAnalysisFile );
  $logger->debug("called");

  ScanSwitches($SwitchesRef);

  $logger->info("writing $PortLabelAnalysisFileName");
  open PORTLABELANALYSISFILE, ">$PortLabelAnalysisFileName" or do {
    $logger->fatal("Couldn't open $PortLabelAnalysisFileName for writing, $!");
    exit;
  };

  print PORTLABELANALYSISFILE SwitchUtils::HtmlHeader("Port label analysis (NCAR labeling rules)");

  my $NbrBadLabels =
    $NbrLabels -
      ( $NbrStandardLabels +
        $NbrInactivePorts +
        $NbrComputerRoomLabels +
        $NbrStandardDeviceNames +
        $NbrUplinkDeviceNames +
        $NbrWallPhones +
        $NbrBadPortLabels +
        $NbrSpareLabels +
        $NbrVirtualModuleLabels +
        $NbrUndefinedLabels );
  print PORTLABELANALYSISFILE <<PLAHEADER;
<p>
  This web page shows switch port labels that don't conform to
  the standards defined in the
  <a href="http://netserver.ucar.edu/nets/docs/labeling/index.shtml#7">NETS Names and Labels document</a>
</p>
<h2>Statistics about labels processed</h2>
<table>
  <tr><td align="right">$NbrStandardLabels</td><td>&nbsp;standard labels like "ML-31G-W1-2A"</td></tr>
  <tr><td align="right">$NbrInactivePorts</td><td>&nbsp;inactive ports</td></tr>
  <tr><td align="right">$NbrComputerRoomLabels</td><td>&nbsp;computer room labels like "/BG72*DSG:bs1101"</td></tr>
  <tr><td align="right">$NbrStandardDeviceNames</td><td>&nbsp;standard device name labels like "ml-mr-c1-gs"</td></tr>
  <tr><td align="right">$NbrUplinkDeviceNames</td><td>&nbsp;uplink labels like "ml-mr-c1-gs 3/4"</td></tr>
  <tr><td align="right">$NbrWallPhones</td><td>&nbsp;ports marked "<em>&lt;something&gt;</em> wallphone"</td></tr>
  <tr><td align="right">$NbrBadPortLabels</td><td>&nbsp;ports marked "BAD PORT"</td></tr>
  <tr><td align="right">$NbrVirtualModuleLabels</td><td>&nbsp;virtual module (15\/x or 16\/x)</td></tr>
  <tr><td align="right">$NbrSpareLabels</td><td>&nbsp;ports marked "SPARE"</td></tr>
  <tr><td align="right">$NbrUndefinedLabels</td><td>&nbsp;ports with undefined labels</td></tr>
  <tr><td align="right">$NbrBadLabels</td><td>&nbsp;ports with other labels (see below)</td></tr>
  <tr><td align="right"><hr></td><td>&nbsp;</td></tr>
  <tr><td align="right">$NbrLabels</td><td>&nbsp;total labels checked</td></tr>
</table>
<h2>Bad port labels</h2>
In the above list, "ports with other labels" includes:
PLAHEADER

  PrintTable( \@BlankLabels,          " labels that were blank, on active ports" );
  PrintTable( \@OtherLabels,          " labels that weren't recognized" );
  PrintTable( \@BadSites,             " labels with unknown sites (not in " . join( ',', sort keys %Sites ) . ")" );
  PrintTable( \@BadSubLocationTypes,  " labels with bad sublocations (2nd field sublocation doesn't start with one of " . join( ',', sort keys %SubLocationTypes ) . ")" );
  PrintTable( \@BadConnectionDevices, " labels with bad connection devices (3rd field doesn't start with one of " . join( ',', sort keys %CDNames ) . ")" );
  PrintTable( \@BadManufacturers,     " labels with bad manufacturers (3rd field doesn't start with one of " . join( ',', sort keys %Manufacturers ) . ")" );
  PrintTable( \@BadDeviceTypes,       " labels with bad device types (4th field doesn't start with one of " . join( ',', sort keys %DeviceTypes ) . ")" );
  PrintTable( \@BadMediaTypes,        " labels with bad media types (4th field media type doesn't start with one of " . join( ',', sort keys %MediaTypes ) . ")" );

  print PORTLABELANALYSISFILE SwitchUtils::HtmlTrailer;
  close PORTLABELANALYSISFILE;
  SwitchUtils::AllowAllToReadFile $PortLabelAnalysisFileName;
  $logger->debug("returning");
}

1;
