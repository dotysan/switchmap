package ThisSite;

#
# This package defines site-specific constants used by the SwitchMap
# programs.
#

# Set $GetSwitchListFromHpOpenView to 1 (true) if you have HP OpenView
# Network Node Manager (NNM) running on a machine at your site, and
# you want SwitchMap to get the list of your switches from OpenView.
# This is a good thing to do if you can, because as you add/remove
# switches from your network, SwitchMap automatically adjusts.  If you
# leave $GetSwitchListFromHpOpenView set to 0 (false), SwitchMap will
# use the static @LocalSwitches array defined below.
$GetSwitchListFromHpOpenView = 0;

# Set $GetMacIpAddrFromHpOpenView to 1 (true) if you have HP OpenView
# Network Node Manager (NNM) running on a machine at your site, and
# you want SwitchMap to get the MAC-to-IP mapping tables from
# OpenView.  This is a good thing to do if you have OpenView and you
# have OpenView configured to manage all your hosts on all your
# networks.  Otherwise, leave $GetMacIpAddrFromHpOpenView set to 0
# (false) and SwitchMap will get the data from the MacList file (see
# the README file for an explanation of the MacList file)
$GetMacIpAddrFromHpOpenView = 0;

# Set $GetSnmpCommunitiesFromHpOpenView to 1 (true) if you have HP
# OpenView Network Node Manager (NNM) running on a machine at your
# site, and you want SwitchMap to get SNMP community strings from
# OpenView.  If you have OpenView and you have configured OpenView
# with SNMP community strings, setting this variable to true lets you
# avoid maintaining 2 lists of SNMP community strings.  Otherwise,
# leave $GetSnmpCommunitiesFromHpOpenView set to 0 (false) and see the
# comment that describes the $Community variable below.
$GetSnmpCommunitiesFromHpOpenView = 0;

# If you have HP OpenView Network Node Manager at this site (any of
# the previous 3 variables are set to true), then this program will
# get information from NNM.  To do so, this program needs to know the
# DNS name of the machine that is running HP OpenView NNM.  If the
# SwitchMap programs are running on the same machine as HP OpenView
# NNM, set $OpenViewHost to 'localhost'.  If HP Openview NNM is
# running on another machine, put the name here, and this program will
# ssh to the machine.  For this to work, you have to have ssh access
# to the machine defined by $OpenViewHost such that the user that runs
# the SwitchMap scripts is able to ssh to $OpenViewHost without
# supplying a password.  If the previous 3 variables are set to 0
# above, then it doesn't matter what value $OpenViewHost has.
$OpenViewHost = 'nnm.your.domain';

# If you have HP OpenView Network Node Manager at this site and NNM is
# running on another host, then this is the ssh key to use to get the
# switch lists and MAC data and the SNMP community strings file.
# SwitchMap will use this string as the argument of the "-i" option
# when SwitchMap does ssh or scp commands to get data from the remote
# host.
$SshKeyOption = '';

# If you do not have HP OpenView Network Node Manager at this site
# ($Has_HP_OpenView = 0 above), then you'll need to run GetArp.pl
# periodically to get IP and MAC data from your routers.  The @routers
# array lists the routers that the GetArp program will query.
@routers = ();
push @routers, 'router1';
push @routers, 'router2';

# @LocalSwitches provides a static list of switches that's used when
# you don't have HP OpenView ($GetSwitchListFromHpOpenView is set to
# 0).  If you have $GetSwitchListFromHpOpenView set to 1, SwitchMap
# ignores the contents of @LocalSwitches.  This list is used by
# ScanSwitch.pl and SwitchMap.pl.  When the programs run, switches
# will be accessed in the order that they appear in this list.  This
# is also the order that the switches will appear in the main
# "Switches" web page created by SwitchMap,pl.  The list can contain
# just switch names, but you can add special "title" cells.  Title
# cells are extra cells that dress up the switch list.  They are
# typically used to give a name (such as a building name) to a list of
# switch names.  A title cell starts with three dashes to
# differentiate it from normal switch names.  These "switch names" are
# ignored by most of the SwitchMap code, and only have meaning when
# the switches/index.html file is generated.  At that time, the cells
# are output as part of the list of switches, but with a different
# font.  A sample of how you might define them is shown here.  If you
# use title cells, you may be interested in the ReformatSwitchNames
# function described below.
@LocalSwitches = ();
push @LocalSwitches, '---Building1';
push @LocalSwitches, 'switch1-in-building1.abc.com';
push @LocalSwitches, 'switch2-in-building1.abc.com';
push @LocalSwitches, '---Building2';
push @LocalSwitches, 'switch1-in-building2.abc.com';
push @LocalSwitches, 'switch2-in-building2.abc.com';

# @LocalSwitchTrunkPorts provides a static list of trunk ports on
# switches.  It allows you to work around an unfortunate problem - on
# some switches, like Junipers and Cisco 3845s, SwitchMap can't tell
# the trunk ports apart from the non-trunk ports using SNMP.  For such
# switches, SwitchMap will creates web pages that show the trunk ports
# with all the MAC addresses that are reachable on the port - often
# hundreds of addresses.  This clutters the output pages and makes
# searching produce too many hits. I opened a case with Juniper
# support, but they were unable to provide a solution.  So I added the
# @LocalSwitchTrunkPorts array to SwitchMap version 13.1.  The array
# provides a way for you to explicitly name the trunk port(s) on your
# switches.  This is an inelegant, manual solution, and is vulnerable
# to getting out-of-date as you add/move/change your switches and
# trunk ports, but hey, it works.  SwitchMap checks the array when it
# assigns trunk status to ports.  If it finds a match, the port is
# marked as a trunk port.  If it doesn't find a match, SwitchMap tries
# it's usual algorithm for getting the trunk status.  You don't need
# to add all your trunk ports to the array, just add entries for your
# problem switches.
%LocalSwitchTrunkPorts = (
               'switch1'  => [ "ge-0/1/0", "ge-0/1/1" ],
               'switch2'  => [ "xe-0/0/1 ],
             );

# If you have HP OpenView and you've set $GetSwitchListFromHpOpenView
# to 1, it may match some switches that you don't want to appear in
# the port lists.  For example, at my site we have a network
# connection to a Catalyst that we monitor with HP OpenView even
# though we don't have administrative control of the switch.  So when
# SwitchMap finds all the Catalysts known to HP OpenView, it finds the
# switch along with all our other switches.  By putting that switch in
# the @SkipTheseSwitches list, we can make SwitchMap skip that switch.
@SkipTheseSwitches = ('ithaka-router');

# If you use the same community string for all your routers and
# switches, leave $CmstrFile as an empty string and set the $Community
# variable found below.  If you use different community strings in
# different devices, set $CmstrFile to the full pathname of a file
# that defines the strings.  The file should contain one community
# string per line, in double quotes.  Duplicates are ignored, as are
# lines that start with '#'.  On each line of the file, everything
# after the second double-quote character is ignored.  This format is
# identical to that of the netmon.cmstr file used by HP OpenView
# Network Node Manager, so that sites that have NNM can simply use the
# existing file.  If you have HP OpenView, set $CmstrFile to the full
# path name of the netmon.cmstr file, including the 'netmon.cmstr' at
# the end, and this program will try to open the file on the HP
# OpenView machine defined by $OpenViewHost above.  Specify the real
# full path name, without using any environment variables like
# OV_CONF.  If you don't have HP OpenView, set $CmstrFile to the full
# pathname of a file.  For each switch, the programs will try the
# community strings defined in the file, one after the other.  When a
# working community string is found, the programs use another file to
# save the string that worked, so that on subsequent runes they can
# avoid waiting while incorrect communities.
$CmstrFile = '';

# If you use the same SNMP community string in all your switches, set
# $Community to that value.  If your switches have different community
# strings, set the $CmstrFile variable above.  When that variable is
# set to a non-empty value, SwitchMap ignores the value of the
# $Community variable.  Note: the SwitchMap programs do only "get"
# SNMP requests - no SNMP "set" requests are done.
$Community = 'public';

# Your DNS domain.  A typical switch in our network is "abc.ucar.edu",
# so we set this to '.ucar.edu'.
$DnsDomain = '.your.domain';

# The $DestinationDirectory is the full path to the directory where
# the output files will be written.  This should be somewhere that
# your web server can access the files.  At my site, I set this to
# '/usr/web/nets/internal/portlists'.
$DestinationDirectory = '';

# The $DestinationDirectoryRoot is the path to the same directory as
# DestinationDirectory, but from the perspective of the web server.
# At my site, it's '/nets/internal/portlists'.
$DestinationDirectoryRoot = '';

# The $StateFileDirectory is the place that the programs will write
# and read the files that maintain state information from one run to
# the next.  These include the MacList file and the directories named
# 'idlesince' and 'community'.  This should be a different place than
# $DestinationDirectory, because the 'community' directory contains
# SNMP community strings, and we don't want web users to be able to
# browse to those files.  You can be lazy and make $StateFileDirectory
# the same as $DestinationDirectory.  This will work, but for security
# the programs will detect that you have and skip the use of the
# 'community' directory, and the programs won't remember working
# community strings, and may run slower.  On Unix systems, the
# standard place for state files is /var, so a good value is
# '/var/local/switchmap'.  You'll have to create the directory and set
# its ownership.  The directory must be writeable by the users that
# run the SwitchMap program.
$StateFileDirectory = '/var/local/switchmap';

# Set HasConfRooms to 1 if you have a static webpage named
# conference-rooms.html that describes your site's conference rooms.
# Setting it to 1 will cause SwitchMap to include a link to the page
# when it creates the portlists index page.  NCAR has such a page.
# You're not likely to have it, so you should probably leave
# $HasConfRooms set to 0.
$HasConfRooms = 0;

# The $WebPageTrailer variable contains a site-specific trailer that
# SwitchMap will put at the bottom of each web page.  What's here now
# will work, but to improve it I suggest you uncomment the next 5
# lines, put your email address in the obvious spot, and delete the
# 6th line.  my $YourEmailAddress = 'yourname@yourcampany.com';
# $WebPageTrailer = <<TRAILER; Address comments or questions about
# this web page to <a
# href="$YourEmailAddress">$YourEmailAddress</a>.<br> TRAILER
$WebPageTrailer = '';

# The $ExtraHelpText string contains extra site-specific text that is
# written to the help file.  The help file explains how the search
# function is used.  At my site, I initialize this variable with text
# that explains how we use the "name" fields in Cisco switches at our
# site.  You can safely leave this empty.
$ExtraHelpText = '';

# The number of days past which a port is considered "unused".
$UnusedAfter = 60;   # days

# The $UseSysNames variable is a boolean meant to help sites where DNS
# isn't available for switch names.  If your site has DNS names
# defined for each switch (most sites do), leave this variable set to
# 0.  If you don't have DNS names for your switches (you've had to use
# IP address in the LocalSwitches array above), set it to 1 and
# SwitchMap will use list your switches using the SNMP sysName value
# stored in the switches themselves.  Of course, this assumes you've
# set the sysName value in each of your switches using the "set
# hostname" or "set system name" command.
$UseSysNames = 0;

# The list of approved Power-over-Ethernet devices.  If you don't have
# POE devices, leave the @DevicesApprovedForPoe array empty.
#
# This is for sites like mine, that have POE devices like IP phones,
# and have chosen for convenience to configure all their switch ports
# to deliver POE.  We don't want our users to plug in POE devices
# other than phones, because we don't want our switches to have to
# support the power drain of clocks or other POE gadgets.  So we have
# a list of approved POE devices, and SwitchMap generates a web page
# showing all ports that are delivering POE to unapproved devices.  At
# my site, the list of approved devices is
#
# @DevicesApprovedForPoe = (
#                        'AIR-AP350',
#                        'AIR-BR350',
#                        'cisco AIR-AP1121G-A-K9',
#                        'Cisco IP Phone 7910',
#                        'Cisco IP Phone 7945',
#                        'Cisco IP Phone 7960',
#                        'Cisco IP Phone 7965',
#                        'Cisco IP Phone 7970',
#                       );
#
# If you leave the @DevicesApprovedForPoe empty, SwitchMap won't check
# for rogue POE devices.
#
# If you want to use this feature, the best way is to define at least
# one approved device, which can be bogus, in the
# @DevicesApprovedForPoe array.  Then run SwitchMap and see what you
# get in the POE web page, which you'll find under the "Ports" web
# page.  Then decide which of the devices ought to be approved, and
# add the value from the "What (via CDP)" column to the
# @DevicesApprovedForPoe.  When you're done, the POE page should show
# all the devices except the ones that you've decided are "approved".
#
@DevicesApprovedForPoe = ();

# The %MacsApprovedForPoe hash works like @DevicesApprovedForPoe, but
# lets you specify a list of specific MAC addresses that are approved.
# We found that we needed this because when some POE devices (like
# security cameras made by Topview or ACTi) negotiate with the switch
# for POE, they don't give the switch a device name.  To list them as
# "approved", I added this hash.  At my site, I initialize it like so:
#
# %MacsApprovedForPoe = (
#                       '000b67003be0'  => 'IP security camera made by Topview',
#                       '000b67004596'  => 'IP security camera made by Topview',
#                       );
%MacsApprovedForPoe = ();

# The %ManufacturersApprovedForPoe hash works like MacsApprovedForPoe,
# but allows you to specify manufacturers that supply MACs that you
# approve of.  This is more convenient than using %MacsApprovedForPoe,
# but may accidentally allow more devices than you intend.  It might
# be initialized like so:
#
# %ManufacturersApprovedForPoe = (
#                                '000b67' => 'IP security camera made by Topview',
#                                );
%ManufacturersApprovedForPoe = ();

# Some sites may want to improve the looks of the main switch list
# found in the index.html in the "switches" directory.  The following
# items ($UseGroups, WhichGroup and ReformatSwitches) provide ways to
# do that.  If you leave them at their default values, you'll get a
# simple alphabetized list of switch names.
#
# There are several styles you can use in your switch list:
#
# 1. The default, and simplest - just put switch names into the
#    @LocalSwitches list.  SwitchMap will write them to the web page
#    without changing the order, and split into the number of columns
#    defined by SwitchIndexColumns (defined below).
# 2. You can add "title cells" to the @LocalSwitches list.  These
#    strings start with three dashes.  SwitchMap ignores them when it's
#    processing switches, but adds them to the switch list web page, and
#    displays them in a bold font.  You might use these to put building
#    names into the switch list.  As with #1, you still maintain the
#    @LocalSwitches list by hand.
# 3. You can set the $UseGroups variable to 1 to "turn on" automatic
#    insertion of title cells.  This is useful if you can derive the
#    group a switch belongs to by the switch's name.  SwitchMap will
#    call the WhichGroup function to determine the group that each switch
#    belongs to, and add title cells for each group.  It's up to you to
#    define the WhichGroup function (see examples below).
# 4. You can define your own code in the ReformatSwitchNames function.
#    SwitchMap will call the function once, and pass in the
#    @LocalSwitches list by reference, so that you can modify it as
#    you like.  As delivered, ReformatSwitchNames does nothing to the
#    list.  You might use this to simply sort the @LocalSwitches list,
#    so you don't have to bother keeping the list in sorted order
#    yourself.  Or you might leave @LocalSwitches empty, and in
#    ReformatSwitchNames, fill the list with the contents of an
#    external file.

# If you want to split the list of switches in the "switches" index
# file into groups based on the switch names, set $UseRooms to "1",
# and change the code in the WhichGroup function below.
$UseGroups=0;

# If you have set UseGroups to "1" then you must tell Switchmap how to
# derive a group name from a switch name.  This routine takes the
# switch name as it's argument, and returns the group name.  This
# routine can be as simple or complex as needed, since we only call
# this routine once per switch.
# In the example code below, it is assumed that a typical switch name is
# of the form
#     building-room-switchtype-switchID.site.company.com
# and the example code returns
#     building-room
# as the group name.
sub WhichGroup($) {
  $_ = shift;
  # This example assumes names are XX-YY-anythingElse and so returns XX-YY
  # s/([0-9a-z]*)-([0-9a-z]*)-.*/$1-$2/;
  # return $_;

  # This example gets the portion of the domain name after the 1st dot
  # my @fqdn = split /\./;
  # return $fqdn[1];

  # This example returns the first four characters of the hostname
  # return substr $_, 0, 4;
}

#
# The ReformatSwitchNames subroutine is for SwitchMap users who want
# to do some site-specific modification of the @LocalSwitches list
# before SwitchMap uses it.  See the description above.
#
sub ReformatSwitchNames(@) {
  my $SwitchNamesRef = shift;
  # your code goes here to modify the switch name list
}

# The SwitchIndexColumns constant controls the number of columns that
# SwitchMap will use in the table that is created in the index.html
# file in the "switches" directory.
$SwitchIndexColumns = 5;

# When SwitchMap reads ARP caches to get MAC information, some
# interfaces may have too many MACs to display reasonably (like,
# hundreds).  We want to see the MACs on point-to-point interfaces,
# which often have only one MAC, but we don't want to see every MAC on
# crowded VLANs.  $ArpMacLimit is the maximum number of MACs to
# display from the ARP cache.  When there are more than this number of
# MACs in the ARP cache for a given interface, SwitchMap will display
# "<x> MACs in ARP cache, display limit is <n>".
$ArpMacLimit = 10;

# Ancillary ports are ports like "Nu0" (the null port) and "VLAN-nnn",
# which appear in the SNMP data structures in switches, but carry no
# information worth displaying.  To reduce clutter, SwitchMap gathers
# these ports into their own table.  The table is displayed only if
# the following boolean variable is set to true.  It's false by
# default.
$ShowAncillaryPorts = 0;

# If you set $ShowCdpNames to 1 (true), SwitchMap will put the CDP
# name into the "What (via CDP)" column.  This can be useful, but it
# can also make the column rather wide.
$ShowCdpName = 0;

# Historically, Switchmap wrote CSV files that contained only the
# information for active, non-trunk ports.  In 2011, some users
# requested that the CSV files should contain information for all
# ports, including inactive and trunk ports.  It is now the default
# behavior to generate CSV files containing information for all ports.
# If you prefer the old behavior, set
# $ShowOnlyActiveNonTrunkPortsInCsv to 1.
$ShowOnlyActiveNonTrunkPortsInCsv = 0;

# If you're on a Linux machine, you may have the arpwatch program
# installed.  If so, you can make the MacList file a bit more complete
# by feeding arpwatch information to GetApl.pl, which will then
# incorporate it into the MacList file.  See ReadArpWatchFile function
# in GetArp.pl.  Turn it on by setting $AprWatchFile to 1.  Thanks to
# pklausner.
$ArpWatchFile = 0;

# Sometimes it is useful to flag non-trunk ports that have too many
# MAC addresses.  Perhaps you need to hunt for user-installed hubs or
# switches at a site that has a policy against such things.  To make
# SwitchMap highlight such ports, set $PortMacLimit to a low number.
# For example, at my site, non-trunk switch ports are supposed to be
# connected a host, an IP phone, or a IP phone and host, so I'd set
# $PortMacLimit to 2.  The default value is "high", effectively
# turning off this feature of SwitchMap.
$PortMacLimit = 1000;

# The plookup (aka PetesLookup) program is a fast way to look up terms
# that are useful to network engineers (IP addresses, MAC addresses,
# etc.).  Set GeneratePLookupFiles to 1 to make SwitchMap generate
# files that can then be copied over to a PetesLookup repository for
# use by PetesLookup.
$GeneratePLookupFiles = 0;

1;
