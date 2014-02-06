package Port;

use strict;
#use Data::Dumper;
use Log::Log4perl qw(get_logger);


sub new {
  my $type     = shift;
  my $PortName = shift;
  my $logger = get_logger('log6');
  $logger->debug("called, PortName = \"$PortName\"");

  #  $logger->info("creating port object for $PortName");

  my $this = {};
  $this->{ArpMacCount} = 0;
  $this->{AuxiliaryVlanNbr} = 0;
  $this->{CdpCacheDeviceId} = '';
  $this->{CdpCachePlatform} = '';
  $this->{DaysInactive} = 0;
  $this->{Duplex} = 'unknown';
  $this->{EtherChannel} = 0;    # reference to an EtherChannel object, if this port is etherchanneled
  $this->{IdleSince} = -1;
  $this->{IfNbr} = 0;
  $this->{IsConnectedToIpPhone} = 0;
  $this->{IsSwitching} = 0;     # ... as opposed to routing
  $this->{IsTrunking} = 0;
  $this->{IsVirtual} = 0;
  $this->{Label} = '';
  $this->{Mac} = {};            # a hash holding one or more MACs
  $this->{Name} = $PortName;
  $this->{PoeStatus} = 0;
  $this->{Speed} = 0;
  $this->{State} = 'Unknown';
  $this->{Type} = 0;
  $this->{Unused} = 0;          # boolean: has the port been IdleSince for UnusadAfter days?
  $this->{VlansOnTrunk} = '';   # if a port is a trunk, this contains all the vlans defined on the port
  # $this->{VlanNbr}            # explicitly not initialized, ports not in a VLAN don't have this
  $logger->debug("returning");
  return bless $this;
}


sub AddMac ($$) {
  my $this = shift;
  my $Mac = shift;
  $this->{Mac}{$Mac}++;
}

1;
