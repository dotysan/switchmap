#!/usr/bin/perl -w

package Portically;

use strict;
use List::Util qw[min max];

# The SwitchMap programs sorts port names in several places, using the
# Perl "sort" function.  It also uses the sort function to sort
# machine names.  By default, the Perl sort algorithm sorts
# "ASCIIbetically", so that "2/11" ends up before "2/1", and "108"
# ends up before "2" and "ml-mr-c10-gs" ends up before "ml-mr-c2-gs".
# The PortSort subroutine sorts Cisco port names in the way that's
# expected by humans.
#
# Example Cisco IOS network interface names that have been
# seen "in the wild":
#
#       5/7
#       As0/1/0
#       Fa2/1
#       Gi0/1
#       Gi11/7/1
#       Lo0
#       Mu1
#       Se0/0/1:0
#       T1 0/0/1
#       Te4/2
#       Tu1
#       FastEthernet0/0.406   (maybe only in configs)
#       SPAN RP
#       CPP
#


sub portically {
  return 0 if (!defined $a) and (!defined $b);
  return -1 if !defined $a;
  return  1 if !defined $b;

  # parse it into pieces: the leading "media" piece like "Gi",
  # followed by the port "numbers" (numbers, colons and dots) pieces
  # that are separated by slashes.

  my $AMedia = '';
  my @APieces;
  if (($a =~ /^(\D*)([\d:\.]+)\/?([\d:\.]*)\/?([\d:\.]*)$/) or
      ($a =~ /^(\w+) ([\d:\.]+)\/?([\d:\.]*)\/?([\d:\.]*)$/)) {
    $AMedia = $1 if defined $1;
    push @APieces, $2, $3, $4;
  } else {
    $AMedia = $a;
  }

  my $BMedia = '';
  my @BPieces;
  if (($b =~ /^(\D*)([\d:\.]+)\/?([\d:\.]*)\/?([\d:\.]*)$/) or
      ($b =~ /^(\w+) ([\d:\.]+)\/?([\d:\.]*)\/?([\d:\.]*)$/)) {
    $BMedia = $1 if defined $1;
    push @BPieces, $2, $3, $4;
  } else {
    $BMedia = $b;
  }

  return -1 if !$AMedia and  $BMedia;
  return  1 if  $AMedia and !$BMedia;

  if (($AMedia and $BMedia) and ($AMedia ne $BMedia)) {
    my $ALen = length $AMedia;
    for (my $i = 0; $i < $ALen; $i++) {
      my $AChar = substr $AMedia, $i, 1;
      my $BChar = substr $BMedia, $i, 1;
      return -1 if ord($AChar) < ord($BChar);
      return  1 if ord($AChar) > ord($BChar);
    }
    return 0;
  }

  # if we made it to here, the "media" pieces are equal, so compare
  # the other pieces.

  my $Index = 0;
  my $MaxPieces = max $#APieces, $#BPieces;
  while ($Index <= $MaxPieces) {
    return -1 if !defined $APieces[$Index];
    return  1 if !defined $BPieces[$Index];
    my @achunks = split /:|\./, $APieces[$Index];
    my @bchunks = split /:|\./, $BPieces[$Index];
    my $CIndex = 0;
    my $MaxChunks = max $#achunks, $#bchunks;
    while ($CIndex <= $MaxChunks) {
      return -1 if !defined $achunks[$CIndex];
      return  1 if !defined $bchunks[$CIndex];
      my $AChunk = $achunks[$CIndex];
      my $BChunk = $bchunks[$CIndex];
      return -1 if $AChunk < $BChunk;
      return  1 if $AChunk > $BChunk;
      $CIndex++;
    }
    $Index++;
  }
  return 0;
}


sub PortSort {
  return sort portically @_;
}


#  Testing:

# my @inlist = (
#                '5/4',
#                'Te4/2',
#                '5/7',
#                '7/13',
#                '7/9',
#                '8/3',
#                'As0/1/0',
#                'Fa2/1',
#                'FastEthernet0/0.406',
#                'Gi0/1',
#                'Gi1/2/1',
#                'Gi1/2/11',
#                'Gi1/2/12',
#                'FastEthernet0/0.700',
#                'Gi1/3/1',
#                'Gi1/3/2',
#                'Gi1/4/1',
#                'Gi1/4/2',
#                'Gi1/5/1',
#                '7/10',
#                'Gi1/7/1',
#                'Gi11/7/1',
#                'Gi11/7/1',
#                'Se0/0/1:0',
#                'Gi12/7/1',
#                'Gi2/2/1',
#                'Gi2/7/2',
#                'Gi22/10/1',
#                'Gi22/17/1',
#                'Gi22/7/1',
#                'Lo0',
#                'Mu1',
#                'Se0/0/12:0',
#                'T1 0/0/1',
#                'Gi22/0/1',
#                'T1 0/0/0',
#                'Tu1',
#                '9/6',
#                '7/29',
#                '1/1',
#                '7/38',
#                '8/14',
#                '7/17',
#                '7/47',
#                '9/20',
#                '8/24',
#                '8/34',
#                '7/21',
#                '8/48',
#                '7/18',
#                '9/43',
#                '8/36',
#                '8/7',
#                '9/36',
#                '9/19',
#                '9/25',
#                '8/44',
#                '7/45',
#                '7/8',
#                '9/27',
#                '8/38',
#                '8/1',
#                '9/38',
#                '9/34',
#                '8/3',
#                '7/10',
#                '7/41',
#                '7/15',
#                '7/32',
#                '8/42',
#                '7/43',
#                '8/8',
#                '9/22',
#                '8/31',
#                '9/17',
#                '7/22',
#                '8/47',
#                '8/4',
#                '7/27',
#                '8/21',
#                '9/23',
#                '9/2',
#                '2/1',
#                '7/13',
#                '8/29',
#                '9/30',
#                '7/30',
#                '7/6',
#                '8/33',
#                '9/42',
#                '8/19',
#                '9/14',
#                '9/32',
#                '7/11',
#                '7/3',
#                '8/35',
#                '8/26',
#                '7/20',
#                '8/5',
#                '7/16',
#                '9/48',
#                '8/12',
#                '9/12',
#                '9/46',
#                '9/40',
#                '7/34',
#                '8/41',
#                '8/17',
#                '9/4',
#                '9/44',
#                '7/25',
#                '7/44',
#                '9/26',
#                '9/37',
#                '8/45',
#                '9/18',
#                '8/23',
#                '9/11',
#                '8/2',
#                '7/19',
#                '7/31',
#                '8/30',
#                '7/48',
#                '9/39',
#                '7/39',
#                '8/9',
#                '8/13',
#                '9/5',
#                '8/15',
#                '9/21',
#                '7/33',
#                '7/1',
#                '8/43',
#                '8/20',
#                '9/13',
#                '8/6',
#                '8/10',
#                '8/18',
#                '9/35',
#                '8/37',
#                '8/39',
#                '7/36',
#                '7/9',
#                '8/25',
#                '9/8',
#                '7/40',
#                '7/14',
#                '9/28',
#                '7/46',
#                '7/12',
#                '9/47',
#                '7/37',
#                '7/26',
#                '8/11',
#                '9/24',
#                '8/28',
#                '9/1',
#                '7/42',
#                '9/29',
#                '7/2',
#                '9/31',
#                '7/7',
#                '9/15',
#                '9/9',
#                '7/4',
#                '9/10',
#                '7/35',
#                '8/27',
#                '8/46',
#                '7/24',
#                '7/23',
#                '1/2',
#                '8/16',
#                '8/32',
#                '8/22',
#                '2/2',
#                '9/33',
#                '9/41',
#                '9/7',
#                '8/40',
#                '7/28',
#                '9/45',
#                '9/16',
#                '7/5',
#                '9/3',
#                'ml-mr-c1-gs',
#                'ml-mr-c10-gs',
#                'ml-mr-c2-gs',
#               );

# print "yo.\n";

# foreach (PortSort(@inlist)) {
#   print "sorted inlist = $_\n";
# }

1;
