#!/usr/bin/perl -w
#
#    FindOffice.pl
#
# This Perl CGI script is executed by a web server when a user chooses
# "Search the portlist web pages for various text strings" on the main
# SwitchMap webpage.  This script searches the port list data files
# displays the result to the user.
#
# To debug problems with this script, you may want to run it from the
# command line.
#
#   Under Unix, try something like this:
#
#     $ export QUERY_STRING="strng=test"
#     $ export QUERY_STRING="strng=test;fmt=csv"
#     $ FindOffice.pl
#
#   Under Windows, try this:
#
#     $ set QUERY_STRING="strng=test"
#     $ FindOffice.pl
#

use strict;
use File::Spec;
use CGI::Pretty ":standard";
use Sys::Hostname;
use lib '/usr/web/nets/internal/portlists';
use Constants;
use ThisSite;
use PetesUtils;
use SwitchUtils;

push @CGI::Pretty::AS_IS, qw(h1); # don't format header tags
my $title = 'Search Results';
my $ThisMachineName = hostname();

my $PORT_NAME_CELL        = 1;
my $VLAN_CELL             = 2;
my $STATE_CELL            = 3;
my $DAYS_INACTIVE_CELL    = 4;
my $SPEED_CELL            = 5;
my $DUPLEX_CELL           = 6;
my $PORT_LABEL_CELL       = 7;
my $WHAT_VIA_CDP_CELL     = 8;
my $MAC_ADDRESS_CELL      = 9;
my $NIC_MANUFACTURER_CELL = 10;
my $IP_ADDRESS_CELL       = 11;
my $DNS_NAME_CELL         = 12;


sub DieNow ($) {
  my $msg = shift;
  my $CssFilePath = $ThisSite::DestinationDirectoryRoot . '/' .$Constants::CssFile;
  print <<DIENOW;
Content-type: text/html

<html>
  <head>
    <title>Error</title>
    <link href="$CssFilePath" rel="stylesheet" type="text/css">
   </head>
  <body bgcolor="#fff5c8">
    <h1>Error</h1>
    <p>
    $msg
    </p>
    <hr>
  </body>
</html>
DIENOW
  exit 0;
}


#
# Added by Paul Dial to support regex metacharacters in search string.
#
sub decode($) {
  my $str = shift;
  $str =~ s/\+/ /g;
  my (@parts) = split /%/, $str;
  my ($returnstring) = "";

  if ($str =~ m/^\%/) {
    shift(@parts);
  } else {
    $returnstring = shift(@parts);
  }

  foreach my $part (@parts) {
    $returnstring .= chr(hex(substr($part,0,2)));
    $returnstring .= substr($part,2);
  }
  return $returnstring;
}


# Given some HTML containing a table cell, return the contents of the cell.
sub GetCellContents ($) {
  my $Html = shift;

  die "no td!!!" if $Html !~ /^<td([^>]*)?>/;
  my $Remainder = $';
  die "no /td in remainder!!!" if $Remainder !~ /<\/td>$/;
  my $Contents = $`;
  $Contents =~ s/<br>/^/g;
  $Contents =~ s/&nbsp;//g;
  $Contents =~ s/<a href="([a-zA-Z0-9-\/\\\.]+)">([a-zA-Z0-9-\/\\\.]+)<\/a>/$2/;
  return ($Contents eq '&nbsp;') ? '' : $Contents;
}


#
# Given an HTML row representing a switch port, return it formatted as
# a CSV line.  To do this, we have to examin the HTML like a browser
# would, and handle "colspan" attributes.
#
sub ConvertHtmlRowToCsvRow (@) {
  my $HtmlRow = shift;

  my @CellValues;
  my $ColSpan = 0;
  for (my $CellIndex=1; $CellIndex<=12; $CellIndex++) {
    my $TD;
    my $CellContents = '';
    if ($ColSpan == 0) {
      $TD = @$HtmlRow[$CellIndex]; # full cell definition, e.g. <td colspan="5">&nbsp;</td>
      if ($TD =~ /td colspan="(\d+)"/) {
        $ColSpan = $1;
      } else {
        $CellContents = GetCellContents($TD);
      }
    } else {
      $ColSpan--;
    }
    $CellContents =~ s/,/ /g;  # We're outputting a CSV file, so we can't have commas in the data
    push @CellValues, $CellContents;
  }
  return join ',', @CellValues;
}


sub ConvertHtmlRowsToCsvRows (@) {
  my $HtmlRows = shift;

  my @CsvRows;
  foreach my $HtmlRow (@$HtmlRows) {
    push @CsvRows, ConvertHtmlRowToCsvRow($HtmlRow);
    #    print "we pushed " . ConvertHtmlRowToCsvRow($HtmlRow);
  }
  return @CsvRows;
}


sub SearchHtmlRow (@$) {
  my $HtmlRow      = shift;
  my $SearchString = shift;

  # return false if it's a follow-on row
  return $Constants::FALSE if @$HtmlRow[1] =~ /etherchanneled with/;

  my $PortName = GetCellContents(@$HtmlRow[$PORT_NAME_CELL]);
  #  print "Port name  = \"$PortName\"\n";
  return $Constants::TRUE if $PortName =~ m#$SearchString#i;

  my $Speed = GetCellContents(@$HtmlRow[$SPEED_CELL]);
  #  print "Speed = \"$Speed\"\n";
  return $Constants::TRUE if $Speed =~ m#$SearchString#i;

  my $Duplex = GetCellContents(@$HtmlRow[$DUPLEX_CELL]);
  #  print "Duplex = \"$Duplex\"\n";
  return $Constants::TRUE if $Duplex =~ m#$SearchString#i;

  my $PortLabel = GetCellContents(@$HtmlRow[$PORT_LABEL_CELL]);
  #  print "PortLabel = \"$PortLabel\"\n";
  return $Constants::TRUE if $PortLabel =~ m#$SearchString#i;

  return $Constants::FALSE if @$HtmlRow[$WHAT_VIA_CDP_CELL] =~ /^<td colspan=/;
  my $WhatViaCdp = GetCellContents(@$HtmlRow[$WHAT_VIA_CDP_CELL]);
  #  print "WhatViaCdp = \"$WhatViaCdp\"\n";
  return $Constants::TRUE if $WhatViaCdp =~ m#$SearchString#i;

  return $Constants::FALSE if @$HtmlRow[$MAC_ADDRESS_CELL] =~ /^<td colspan=/;
  my $MacAddress = GetCellContents(@$HtmlRow[$MAC_ADDRESS_CELL]);
  #  print "MacAddress = \"$MacAddress\"\n";
  foreach (split /<br>/, $MacAddress) {
    return $Constants::TRUE if m#$SearchString#i;
  }

  return $Constants::FALSE if @$HtmlRow[$NIC_MANUFACTURER_CELL] =~ /^<td colspan=/;
  my $NicManufacturer = GetCellContents(@$HtmlRow[$NIC_MANUFACTURER_CELL]);
  #  print "NicManufacturer = \"$NicManufacturer\"\n";
  foreach (split /<br>/, $NicManufacturer) {
    return $Constants::TRUE if m#$SearchString#i;
  }

  return $Constants::FALSE if @$HtmlRow[$IP_ADDRESS_CELL] =~ /^<td colspan=/;
  my $IpAddress = GetCellContents(@$HtmlRow[$IP_ADDRESS_CELL]);
  #  print "IpAddress = \"$IpAddress\"\n";
  foreach (split /<br>/, $IpAddress) {
    return $Constants::TRUE if m#$SearchString#i;
  }

  return $Constants::FALSE if @$HtmlRow[$DNS_NAME_CELL] =~ /^<td colspan=/;
  my $DnsName = GetCellContents(@$HtmlRow[$DNS_NAME_CELL]);
  #  print "DnsName = \"$DnsName\"\n";
  foreach (split /<br>/, $DnsName) {
    return $Constants::TRUE if m#$SearchString#i;
  }

  return $Constants::FALSE;
}


#
# Find all the rows of the table that contain the search string.
#
sub GetHtmlRows($$) {
  my $InputHtmlFileName = shift;
  my $SearchString = shift;
  my $FullName = File::Spec->catfile($Constants::SwitchesDirectory, $InputHtmlFileName);
  open INHTMLFILE, $FullName or
    DieNow "The FindOffice.pl script running on $ThisMachineName couldn't read $FullName\n";

  my @HtmlRows;
  while (<INHTMLFILE>) {
    last if /<strong>Virtual Ports<\/strong>/;  # this counts on the 'Virtual Ports' section coming last!  Yuk!
    if (/^<tr class="cell/) {
      my $CompleteTrCount = 0;
      my $TotalTrs = 1;
      #
      # Build a table row in @HtmlRow, from the <tr> to the </tr>.  If we encounter
      # cells with rowspan attributes, keep reading until we've read all the tr pairs
      # that define the row.
      #
      my @HtmlRow;
      push @HtmlRow, $_;
      while (<INHTMLFILE>) {
        chop;
        next if $_ eq '';
        push @HtmlRow, $_;
        if (/<\/tr>/) {
          $CompleteTrCount++;
          last if $CompleteTrCount == $TotalTrs;
        } elsif (/<tr/) {
        } elsif (/ rowspan="(\d+)"/) {
          $TotalTrs = $1;
        }
      }
      # now that we've built a row, search it for the string
      if (SearchHtmlRow(\@HtmlRow, $SearchString)) {
        # This script outputs an HTML page that sits outside a
        # directory structure, so relative links won't work, so we
        # have to remove a relative link if it exists.
        $HtmlRow[$VLAN_CELL] =~ s/<a href="..\/vlans\/vlan\d+.html">(\d+)<\/a>/$1/;
        push(@HtmlRows, \@HtmlRow);
      }
    }
  }
  close INHTMLFILE;
  return @HtmlRows;
}


# When filling in the search string, the user may have cut-and-pasted
# a MAC address from some source device.  Devices use different formats
# for MAC addresses, including:
#
#       CATOS "show cam"                  => 00-0d-60-9c-b1-ba
#       Windows "arp -a" & "ipconfig -a"  => 00-0d-60-9c-b1-ba
#       IOS "show ip arp"                 => 000d.609c.b1ba
#       Linux "arp -a" & "ifconfig -a"    => 00:0d:60:9c:b1:ba
#
# MAC addresses in the HTML files output by SwitchMap.pl have no dashes,
# colons or periods.  To match the various formats that might have been
# supplied, we have to strip possible "extra" characters from the
# $SearchString before doing the search.
sub CanonicalizeMac($) {
  my $string = shift;
  $string =~ s/\-//g if $string =~ /[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}/;
  $string =~ s/\\\.//g if $string =~ /[0-9a-zA-Z]{4}\\\.[0-9a-zA-Z]{4}\\\.[0-9a-zA-Z]{4}/;
  $string =~ s/\://g if $string =~ /[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}/;
  return $string
}


#
# Return a list of the names of HTML files in the "switches" directory (the
# directory that contains the .html files created by SwitchMap).
#
sub GetFileNames($) {
  my $DirectoryName = shift;

  if (!opendir(DIR,$DirectoryName)) {
    DieNow "The FindOffice.pl script running on $ThisMachineName couldn't read directory DirectoryName\n";
  }
  my @FileNames = readdir(DIR);
  closedir(DIR);
  return @FileNames;
}

#
# Given a row of an html table and a searchstring, put "span" tags
# around the ocurrences of searchstring in the row.  For example, given
#
# <td class="cellActive">this is some text</td>
#
# and a searchstring of "text", return
#
# <td class="cellActive">this is some <span class="searchresult">text</span></td>
#
# This is a little tricky - we don't want to match any of the text in
# the original tags in the row of the table.  So if the searchstring
# is "as", we don't want to match part of "class".  Treat the input
# input HTML row as a sequenco of chunks, each of which is either
# <something>, or simple text.  Only match the searchstring in the
# simple text chunks.
#
# This assumes the tags in the HTML are well-formed :-)
#
sub HighlightFoundStrings($$) {
  my $inStr        = shift;
  my $SearchString = shift;

  my $outStr;
  my $chunk;
  while ($inStr ne '') {
    if (substr($inStr, 0, 1) eq '<') {
      my $rBracket = index $inStr, '>';
      if ($rBracket > -1) {
        $chunk = substr $inStr, 0, $rBracket+1;
        $inStr = substr $inStr, $rBracket+1;
      } else {
        $chunk = $inStr;
        $inStr = '';
      }
    } else {
      my $lBracket = index $inStr, '<';
      if ($lBracket > -1) {
        $chunk = substr $inStr, 0, $lBracket;
        $chunk =~ s#($SearchString)#<span class="searchresult">$1</span>#ig;
        $inStr = substr $inStr, $lBracket;
      } else {
        $chunk = $inStr;
        $inStr = '';
      }
    }
    $outStr .= $chunk;
  }

  return $outStr;
}


#
# Return an array of strings, where each string is a block of HTML
# lines representing the matches found for a single switch.
#
sub GetMatches ($$) {
  my $SearchString = shift;
  my $OutputFormat = shift;

  $SearchString =~ s/\./\\./g; # escape the dots so they aren't interpreted as regex wildcards
  $SearchString = decode($SearchString);
  $SearchString = CanonicalizeMac($SearchString);

  my @FileNames = GetFileNames($Constants::SwitchesDirectory);

  #
  # Search all the files for matches of the SearchString.
  #
  my @matches;
  foreach my $InputHtmlFileName (@FileNames) {
    next if $InputHtmlFileName !~ /\.html$/;
    next if $InputHtmlFileName eq 'index.html';
    my $SwitchName = $InputHtmlFileName;
    $SwitchName =~ s/\.html$//;
    my @HtmlRows = GetHtmlRows($InputHtmlFileName, $SearchString);
    if (@HtmlRows) {
      if ($OutputFormat eq 'csv') {
        foreach my $CsvRow (ConvertHtmlRowsToCsvRows(\@HtmlRows)) {
          push @matches, "$SwitchName,$CsvRow\n";
        }
      } else {
        my $SwitchNameLink = $SwitchName;
        if ($ThisSite::DestinationDirectoryRoot ne '') {
          my $Link = $ThisSite::DestinationDirectoryRoot . '/switches/' . $SwitchName . '.html';
          $SwitchNameLink = "<a href=\"$Link\">$SwitchName</a>";
        }
        push @matches, "<h2>Switch $SwitchNameLink</h2>\n";
        push @matches, "<p>\n";
        push @matches, SwitchUtils::HtmlPortTableHeader();
        foreach my $HRow (@HtmlRows) {
          foreach my $HtmlLine (@$HRow) {
            if ($HtmlLine =~ /<a href="/) {
              # "repair" the link.  (major kludge)
              substr $HtmlLine, index($HtmlLine, '<a href="'), 9, '<a href="' .
                $ThisSite::DestinationDirectoryRoot . '/switches/';
            } else {
              $HtmlLine = HighlightFoundStrings($HtmlLine, $SearchString);
            }
            push @matches, $HtmlLine;
          }
        }
        push @matches, "\n</table></p>\n";
      }
    }
  }
  return @matches;
}


sub SearchResults ($$) {
  my $SearchString = shift;
  my $OutputFormat = shift;
  my @Results;

  my@Matches = GetMatches($SearchString, $OutputFormat);
  return ($#Matches == -1) ? ("<p>No matches found.</p>\n") : @Matches;
}


# ------------------------------------  Main  ----------------------------------------------
#
# Get the string argument that was sent by the Web server
#
my $in = $ENV{'QUERY_STRING'};
if (!defined $in) {
  DieNow "The FindOffice.pl script running on $ThisMachineName couldn't resolve " .
    "the environment variable named QUERY_STRING";
}
my $SearchString;
my $OutputFormat = 'html';
my (@args) = split /;/, $in;
foreach my $arg (@args) {
  if ($arg =~ /^strng=(.+)$/) {
    $SearchString = $1;
  } elsif ($arg =~ /^fmt=(.+)$/) {
    $OutputFormat = $1;
  }
}
if ($SearchString eq '') {
  DieNow "The FindOffice.pl script running on $ThisMachineName couldn't find \"strng=\" in " .
    "the environment variable QUERY_STRING";
}
if (($OutputFormat ne 'html') and ($OutputFormat ne 'csv')) {
  DieNow "The FindOffice.pl script running on $ThisMachineName found \"fmt=xxx\" in the " .
    "environment variable QUERY_STRING, but xxx wasn't \"csv\"";
}

if ($OutputFormat eq 'csv') {
  print
    header('text/plain'),
    SearchResults($SearchString, $OutputFormat);
} elsif ($OutputFormat eq 'html') {
  print
    header(),                   # defaults to Content-type: text/html
    start_html(-title => $title,
               -style => { -src => $ThisSite::DestinationDirectoryRoot .'/SwitchMap.css' },
              ),
    h1('Search Results'),
    SwitchUtils::NavigationBar(),
    SearchResults($SearchString, $OutputFormat),
    SwitchUtils::HtmlTrailer();
}

exit 0;
