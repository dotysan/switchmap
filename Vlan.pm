package Vlan;

use strict;
#use Data::Dumper;
use Log::Log4perl qw(get_logger);


sub new {
  my $type = shift;
  my $number = shift;
  my $logger = get_logger('log3');
  $logger->debug("called to create an object for Vlan $number");

  my $this = {};
  $this->{Number} = $number;     # Vlan number
  $this->{NbrPorts} = 0;         # Total number of ports in the Vlan
  $this->{NbrUnusedPorts} = 0;   # Total number of unused ports in the Vlan
  $this->{Switches} = {};        # Switches that have ports in this Vlan
  $logger->debug("returning");
  return bless $this;
}

1;
