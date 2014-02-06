package GetCiscoPortTrunkStatuses;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;
#use Data::Dumper;

#
# values in the vlanPortIslAdminStatus table
#
my $TRUNKING_ON            = 1;
my $TRUNKING_OFF           = 2;
my $TRUNKING_DESIRABLE     = 3;
my $TRUNKING_AUTO          = 4;
my $TRUNKING_ONNONEGOTIATE = 5;

#
# values in the vlanPortIslOperStatus table
#
my $TRUNKING     = 1;
my $NOT_TRUNKING = 2;


my @trunkAdminStatusStrings = ('undefined!',
                               'on',
                               'off',
                               'desireable',
                               'auto',
                               'onNoNegotiate'
                              );
my @trunkOperStatusStrings = ('undefined!',
                              'trunking',
                              'notTrunking',
                             );


sub DbgPrintTrunkAdminStatus ($) {
  my $TrunkAdminStatus = shift;
  my $logger = get_logger('log7');

  foreach my $PortName (Portically::PortSort keys %$TrunkAdminStatus) {
    my $binvalue = $TrunkAdminStatus->{$PortName};
    my $str = (defined $trunkAdminStatusStrings[$binvalue]) ? $trunkAdminStatusStrings[$binvalue] : 'undefined!';
    $logger->debug("TrunkAdminStatus->{$PortName} = $str\n");
  }
}

sub DbgPrintTrunkOperStatus ($) {
  my $TrunkOperStatus = shift;
  my $logger = get_logger('log7');

  foreach my $PortName (Portically::PortSort keys %$TrunkOperStatus) {
    my $binvalue = $TrunkOperStatus->{$PortName};
    my $str = (defined $trunkOperStatusStrings[$binvalue]) ? $trunkOperStatusStrings[$binvalue] : 'undefined!';
    $logger->debug("TrunkOperStatus{$PortName} = $str");
  }
}


sub GetVlanTrunkPortDynamicState($$$) {
  my $Session             = shift;   # passed in
  my $IfToIfNameRef       = shift;   # passed in
  my $TrunkAdminStatusRef = shift;   # filled in by this subroutine
  my $logger = get_logger('log7');
  my %vlanTrunkPortDynamicState;
  $logger->info("trying vlanTrunkPortDynamicState from Cisco Stack MIB...");
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'vlanTrunkPortDynamicState',
                                         $Constants::INTERFACE,
                                         \%vlanTrunkPortDynamicState);
  if ($status == $Constants::SUCCESS) {
    my $nbr = keys %vlanTrunkPortDynamicState;
    $logger->debug("got $nbr entries from vlanTrunkPortDynamicState");
    foreach my $ifNbr (keys %vlanTrunkPortDynamicState) {
      my $ifName = $$IfToIfNameRef{$ifNbr};
      $$TrunkAdminStatusRef{$ifName} = $vlanTrunkPortDynamicState{$ifNbr};
    }
  }
}


sub GetVlanPortIslAdminStatus($$$$) {
  my $Session             = shift;   # passed in
  my $PortIfIndexRef      = shift;   # passed in
  my $IfToIfNameRef       = shift;   # passed in
  my $TrunkAdminStatusRef = shift;   # filled in by this subroutine
  my $logger = get_logger('log7');
  my %vlanPortIslAdminStatus;
  $logger->info("trying vlanTrunkPortDynamicState from Cisco Stack MIB...");
  my $status = SwitchUtils::GetSnmpTable($Session,
                                      'vlanPortIslAdminStatus',
                                      $Constants::PORT,
                                      \%vlanPortIslAdminStatus);
  if ($status == $Constants::SUCCESS) {
    my $nbr = keys %vlanPortIslAdminStatus;
    $logger->debug("got $nbr entries from vlanPortIslAdminStatus");
    foreach my $ifNbr (keys %vlanPortIslAdminStatus) {
      if ((exists $PortIfIndexRef->{$ifNbr}) and ($PortIfIndexRef->{$ifNbr} != 0)) {
        my $ifName = $$IfToIfNameRef{$PortIfIndexRef->{$ifNbr}};
        $$TrunkAdminStatusRef{$ifName} = $vlanPortIslAdminStatus{$ifNbr};
      }
    }
  }
}


sub GetVlanTrunkPortDynamicStatus($$$) {
  my $Session            = shift;   # passed in
  my $IfToIfNameRef      = shift;   # passed in
  my $TrunkOperStatusRef = shift;   # filled in by this subroutine
  my $logger = get_logger('log7');
  my %vlanTrunkPortDynamicStatus;
  $logger->debug("debug: trying vlanTrunkPortDynamicStatus...");
  my $status = SwitchUtils::GetSnmpTable($Session,
                                      'vlanTrunkPortDynamicStatus',
                                      $Constants::INTERFACE,
                                      \%vlanTrunkPortDynamicStatus);
  if ($status == $Constants::SUCCESS) {
    my $nbr = keys %vlanTrunkPortDynamicStatus;
    $logger->debug("debug: got $nbr entries from vlanTrunkPortDynamicStatus");
    foreach my $ifNbr (keys %vlanTrunkPortDynamicStatus) {
      my $ifName = $$IfToIfNameRef{$ifNbr};
      if (defined $ifName) {
        $$TrunkOperStatusRef{$ifName} = $vlanTrunkPortDynamicStatus{$ifNbr};
      }
    }
  }
}


sub GetVlanPortIslOperStatus($$$$) {
  my $Session            = shift;   # passed in
  my $PortIfIndexRef     = shift;   # passed in
  my $IfToIfNameRef      = shift;   # passed in
  my $TrunkOperStatusRef = shift;   # filled in by this subroutine
  my $logger = get_logger('log7');
  my %vlanPortIslOperStatus;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                      'vlanPortIslOperStatus',
                                      $Constants::PORT,
                                      \%vlanPortIslOperStatus);
  if ($status == $Constants::SUCCESS) {
    my $nbr = keys %vlanPortIslOperStatus;
    $logger->debug("got $nbr entries from vlanPortIslOperStatus");
    foreach my $ifNbr (keys %vlanPortIslOperStatus) {
      if ((exists $PortIfIndexRef->{$ifNbr}) and ($PortIfIndexRef->{$ifNbr} != 0)) {
        my $ifName = $$IfToIfNameRef{$PortIfIndexRef->{$ifNbr}};
        $$TrunkOperStatusRef{$ifName} = $vlanPortIslOperStatus{$ifNbr};
      }
    }
  }
}


# Ports with Auxiliary VLANs are connected to VOIP phones, and are
# considered "not trunking" by this function, because we want to see
# the MAC addresses that are bound to ports connected to phones.
#
sub GetCiscoPortTrunkStatuses ($$$$) {
  my $Switch         = shift;   # passed in, this function fills $Switch->{Port}
  my $Session        = shift;   # passed in
  my $PortIfIndexRef = shift;   # passed in
  my $IfToIfNameRef  = shift;   # passed in
  my $logger = get_logger('log6');
  $logger->debug("called");

  # There are 2 possible places to get the trunking status of ports on a
  # Cisco switch:
  #
  #   1. The VTP MIB's vlanTrunkPortDynamicStatus
  #   2. The STACK MIB's vlanPortIslOperStatus
  #
  # Some Cisco switches support both tables.  On those that do, you'd
  # expect that the two tables would contain the same number of
  # entries, but testing switches reveals some interesting problems.
  # On a 6513 running CatOS 8.6(4), the first MIB doesn't contain
  # entries for the ports on the supervisor modules, but the second
  # MIB does.  On a 3560E running 12.2(44r)SE3, I got 31 entries from
  # the vlanTrunkPortDynamicStatus table and 30 entries from the
  # vlanPortIslOperStatus table.  What's weird is that both tables
  # were flawed.  The first had entries for "Po1" and "Po2", which
  # were missing from the second.  But the second had an entry for
  # "Te0/2", which the first didn't.  Te0/2 was the "last" port on the
  # switch, and it happened to have no configuration of any kind.
  # When I did a "shutdown" on it, it appeared in the second table.
  #
  # With this in mind, I initialize Port->{IsTrunking} to FALSE, and
  # then set it with the following code.  It gets both MIBs from the
  # switch, merging the results.  That way I'll get the trunking
  # status for all the ports, whether they appear in both tables or
  # only one.
  #
  # 6509's support both tables.  3524 support only the VTP table, and
  # may not even support the VTP table if the 3524 has no trunks
  # configured at all, like the mar-26a-c1-es.atd.ucar.edu switch at
  # NCAR.

  my %TrunkAdminStatus;
  GetVlanTrunkPortDynamicState($Session, $IfToIfNameRef, \%TrunkAdminStatus);
  GetVlanPortIslAdminStatus($Session, $PortIfIndexRef, $IfToIfNameRef, \%TrunkAdminStatus);
  if ((keys %TrunkAdminStatus) == 0) {
    my $SwitchName = GetName $Switch;
    $logger->warn("Couldn't get the vlanTrunkPortDynamicState or vlanPortIslAdminStatus tables from $SwitchName, we have no trunk state, returning\n");
    return;
  }
  DbgPrintTrunkAdminStatus(\%TrunkAdminStatus);

  my %TrunkOperStatus;
  GetVlanTrunkPortDynamicStatus($Session, $IfToIfNameRef, \%TrunkOperStatus);
  GetVlanPortIslOperStatus($Session, $PortIfIndexRef, $IfToIfNameRef, \%TrunkOperStatus);
  if ((keys %TrunkOperStatus) == 0) {
    my $SwitchName = GetName $Switch;
    $logger->warn("Couldn't get the vlanTrunkPortDynamicStatus or vlanPortIslOperStatus tables from $SwitchName\n");
    return;
  }
  DbgPrintTrunkOperStatus(\%TrunkOperStatus);

  #
  # Set IsTrunking to true if the port is trunking.  IsTrunking has
  # already been initialized to 0 (false) before this.  The operational
  # trunking status is meaningless if the administrative status is
  # "off", so you have to check the administrative status first and then
  # the operational status.
  #
  foreach my $PortName (keys %TrunkAdminStatus) {
    $logger->debug("top of loop, IsTrunking for \"$PortName\" is off");
    my $Port = $Switch->{Ports}{$PortName};
    # On NCAR's 3524s like fb-12-c1-es, trunking is turned on on all
    # ports, to allow the ports to work whether they're connected to a
    # simple machine or to a VOIP phone.  In the web pages created by
    # SwitchMap, we want to see all the MAC addresses that are bound
    # to such ports, so we want SwitchMap to treat them differently
    # than it treats "true" trunk ports.  So the next line says "leave
    # IsTrunking false if the port has an Auxiliary VLAN, since Auxiliary
    # VLANs are found only on ports that are connected to phones, and
    # those ports aren't really trunking."
    next if $Port->{AuxiliaryVlanNbr};
    # leave IsTrunking false if it's administratively not trunking
    next if (!exists $TrunkAdminStatus{$PortName}) or
            ($TrunkAdminStatus{$PortName} == $TRUNKING_OFF);
    # leave IsTrunking false if it's currently not trunking
    next if (exists $TrunkOperStatus{$PortName}) and
            ($TrunkOperStatus{$PortName} == $NOT_TRUNKING);
    $logger->debug("changing IsTrunking for \"$PortName\" to on");
    $Port->{IsTrunking} = 1;    # it's trunking
  }
  $logger->debug("called, returning");
  return;
}
1;
