package WritePLookupDirectory;

use strict;
use Log::Log4perl qw(get_logger);

use File::Copy;


sub HtmlFileHeader ($) {
my $title = shift;

my $RetVal = <<HEAD;
<!doctype html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta name="ROBOTS" content="NOINDEX, NOFOLLOW">
<meta Http-Equiv="Pragma" Content="no-cache">
<meta Http-Equiv="Expires" Content="-100">
<title>$title</title>
<link href="../SwitchMap.css" rel="stylesheet" type="text/css">
</head>
<body>

<div class="page-title">$title</div>
<hr>

HEAD
return $RetVal;
}


sub WriteIpAddressesIndexFile() {
  my $logger = get_logger('log4');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::PLookupIpAddressesDirectory; # create or empty out the directory
  my $IndexFileName = File::Spec->catfile($Constants::PLookupIpAddressesDirectory, 'index.html');
  $logger->info("writing $IndexFileName");
  open INDEXFILE, ">$IndexFileName" or do {
    $logger->fatal("Couldn't open $IndexFileName for writing, $!");
    exit;
  };
  print INDEXFILE HtmlFileHeader 'IP Addresses in Port Lists';
  print "";
  print INDEXFILE SwitchUtils::HtmlTrailer;
  close INDEXFILE;
  SwitchUtils::AllowAllToReadFile $IndexFileName;

  $logger->debug("returning");
}


sub WriteIpAddressesFiles($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $IpAddressFileName = File::Spec->catfile($Constants::PLookupIpAddressesDirectory, 'ip-addresses.html');
  $logger->info("writing $IpAddressFileName");
  open IPADDRESSFILE, ">$IpAddressFileName" or do {
    $logger->fatal("Couldn't open $IpAddressFileName for writing, $!");
    exit;
  };
  print IPADDRESSFILE HtmlFileHeader 'IP Addresses in Port Lists';
  
  print IPADDRESSFILE "<table>\n";
  my $MacIpAddrRef = MacIpTables::getMacIpAddr();
  my $MacHostNameRef = MacIpTables::getMacHostName();
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/; # skip it if it's a group name
    $logger->debug("\$SwitchName = $SwitchName");
    foreach my $PortName (Portically::PortSort keys %{$Switch->{Ports}}) {
      $logger->debug("\$PortName = \"$PortName\"");
      my $Port = $Switch->{Ports}{$PortName};
      if (keys %{$Port->{Mac}} != 0) {
        my $HtmlRow = SwitchUtils::MakeHtmlRow($Switch,
                                               $Port,
                                               $MacIpAddrRef,
                                               $MacHostNameRef,
                                               0);
        print IPADDRESSFILE $HtmlRow;
      }
    }
  }
  print IPADDRESSFILE "</table>\n";

  print IPADDRESSFILE SwitchUtils::HtmlTrailer;
  close IPADDRESSFILE;
  SwitchUtils::AllowAllToReadFile $IpAddressFileName;
    

  $logger->debug("returning");
}


sub WriteIpAddressesDirectory($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  WriteIpAddressesIndexFile();
  WriteIpAddressesFiles($SwitchesRef);

  $logger->debug("returning");
}


sub WriteSwitchMapCssFile() {
  my $SrcCssFileName = File::Spec->catfile($ThisSite::DestinationDirectory, $Constants::CssFile);
  my $DstCssFileName = File::Spec->catfile($Constants::PLookupDirectory,    $Constants::CssFile);
  copy($SrcCssFileName, $DstCssFileName);
}


sub WritePLookupDirectory ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log2');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::PLookupDirectory; # create or empty out the directory
#  WriteCiscoSerialNumbersDirectory($SwitchesRef);
  WriteSwitchMapCssFile;
  WriteIpAddressesDirectory($SwitchesRef);
  # WriteLocationLabelsDirectory($SwitchesRef);
  # WriteMacAddressesDirectory($SwitchesRef);
  # WriteStringsDirectory($SwitchesRef);
  # WriteVlansDirectory($SwitchesRef);

  $logger->debug("returning");
}

1;
