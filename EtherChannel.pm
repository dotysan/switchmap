package EtherChannel;

use strict;
#use Data::Dumper;
use Log::Log4perl qw(get_logger);


#
# An EtherChannel object has the ifIndex of the parent virtual
# etherchannel port and an array of references to Port objects.
# The reason that we don't store the parent's port is that
# we don't store port infermation for portchannel ports.
#
sub new {
  my $type          = shift;
  my $ChildPort     = shift;

  my $this = {};
  $this->{ChildPorts} = [ $ChildPort ];   # initialize the array of ports
  return bless $this;
}

sub AddChildPort {
  my $this      = shift;
  my $ChildPort = shift;
  push @{$this->{ChildPorts}}, $ChildPort;
}
1;
