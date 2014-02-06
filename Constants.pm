package Constants;
use ThisSite;
use FindBin qw($Bin);

#
# This version number applies to all the software in this directory,
# including the ScanSwitch and SwitchMap programs.
#
$VERSION = '13.1';

$WARNING = 2;
$SUCCESS = 1;
$FAILURE = 0;

$TRUE  = 1;
$FALSE = 0;

#
# This package defines constants used by the Switchmap programs.
#

$MAX_DEBUGGING_MESSAGE_DEPTH = 7;
$MAX_INFORMATIONAL_MESSAGE_DEPTH = 3;
$MAX_WARNING_MESSAGE_DEPTH = 1;

#
# These values are used in Entity MIBs.
#
$CHASSIS = 3;
$MODULE  = 9;
$PORT    = 10;

# These values are used in the POWER-ETHERNET MIB.

$DELIVERING_POWER = 3;

#
# SNMP table types.
#
$INTERFACE   = 0;
$PORT        = 1;
$IP_ADDRESS  = 2;
$MAC_ADDRESS = 3;
$TABLE_ROW   = 4;
@OidPatterns = ();
$OidPatterns[$INTERFACE]   = '\.(\d+)$';                           # just the last octet
$OidPatterns[$PORT]        = '\.(\d+\.\d+)$';                      # last two octets
$OidPatterns[$IP_ADDRESS]  = '\.(\d+\.\d+\.\d+\.\d+)$';            # last four octets
$OidPatterns[$MAC_ADDRESS] = '\.(\d+\.\d+\.\d+\.\d+\.\d+\.\d+)$';  # last six octets
$OidPatterns[$TABLE_ROW]   = '\.(\d+)\.\d+$';                      # second-to-last octet

# The $CsvDirectory variable is the path to the directory that
# the code writes the output CSV files (similar to map files).
$CsvDirectory = File::Spec->catfile($ThisSite::DestinationDirectory, 'csv');

# The $GigePerVlansDirectory variable is the path to the directory
# that the code writes the HTML files for Gigabit Ethernet ports per
# Vlan to.
$GigePerVlansDirectory = File::Spec->catfile($ThisSite::DestinationDirectory, 'ports', 'gigeportspervlan');

# The $IdleSinceDirectory variable is the path to the directory
# that the code writes the .idlesince files to.
$IdleSinceDirectory = File::Spec->catfile($ThisSite::StateFileDirectory, 'idlesince');

# The $PortsDirectory variable is the path to the directory that
# the code writes the HTML files for unused ports and spare
# ports to.
$PortsDirectory = File::Spec->catfile($ThisSite::DestinationDirectory, 'ports');

# The $SwitchesDirectory variable is the path to the directory
# that the code writes the HTML files for switches to.
$SwitchesDirectory = File::Spec->catfile($ThisSite::DestinationDirectory, 'switches');

# The UnusedDirectory variable is the path to the directory
# that the code writes the HTML files for Unused Ports to.
$UnusedDirectory = File::Spec->catfile($ThisSite::DestinationDirectory, 'ports', 'unused');

# The $VlansDirectory variable is the path to the directory that
# the code writes the HTML files for Vlans to.
$VlansDirectory = File::Spec->catfile($ThisSite::DestinationDirectory, 'vlans');

# The $PLookupDirectory variable is the path to the directory that
# the code writes the index files for the PLookupDirectory to.
$PLookupDirectory            = File::Spec->catfile($ThisSite::DestinationDirectory, 'plookup');
$PLookupIpAddressesDirectory = File::Spec->catfile($PLookupDirectory              , 'ip-addresses');

# This $CommunityDirectory variable is the path to the directory
# that holds a cache for SNMP communities found to be working.
#
# If you have a site with multiple SNMP communities, SwitchMap will try
# each community string until it finds one that matches.  Once it's
# learned the working community string for a device, we save the string
# so that next time we won't have to take time trying all the strings.
# The working community string for each device is stored as one file
# per device.
$CommunityDirectory = File::Spec->catfile($ThisSite::StateFileDirectory, 'community');

$ModulesBySwitchFile          = 'modulesbyswitch.html';
$PortLabelAnalysisFile        = 'portlabelanalysis.html';
$CssFile                      = 'SwitchMap.css';
$SearchHelpFile               = 'helpsearch.html';
$SparePortsFile               = 'spareports.html';
$SwitchStatsFile              = 'switchstats.html';
$PoeFile                      = 'poeports.html';
$SuspiciousFile               = 'suspiciousports.html';
$CiscoProductsMibFile         = File::Spec->catfile($Bin, 'CISCO-PRODUCTS-MIB.my');
$CiscoStackMibFile            = File::Spec->catfile($Bin, 'CISCO-STACK-MIB.my');
$CiscoEntityVendortypeMibFile = File::Spec->catfile($Bin, 'CISCO-ENTITY-VENDORTYPE-OID-MIB.my');
$HpProductsMibFile            = File::Spec->catfile($Bin, 'hh3c-product-id.mib');
$OuiCodesFile                 = File::Spec->catfile($Bin, 'OuiCodes.txt');
$IeeeFile                     = File::Spec->catfile($Bin, 'oui.txt');
$MacListFile                  = File::Spec->catfile($ThisSite::StateFileDirectory, 'MacList');

$DISABLED = 2;                           # possible value for ifAdminStatus

$SecondsPerDay   = 60 * 60 * 24;         # number of seconds in a day
$SecondsPerMonth = 30 * $SecondsPerDay;  # number of seconds in a 30-day month

#
# To get Foundry MIBs, go to http://www.foundrynet.com -> "Service &
# Support" -> "Knowledge Portal", log in, then "Software".  I couldn't
# log in without registering as a Foundry customer, which requires the
# serial number of a Foundry Switch, so I telephoned Foundry support
# and they emailed me the MIBs.  The file they emailed was named
# something like SXR03100a.mib, and contained a concatenation of 19
# BEGIN-END blocks with names like FOUNDRY-SN-ROOT-MIB.  I broke them
# out into separate files.
#
# Foundry oids
#   1.3.6.1.4.1 = iso.org.dod.internet.private.enterprises
#   1991.1.3.36 = foundry.products.snSwitch.???
#
%FoundrySwitchObjectOids = (
                         '1.3.6.1.4.1.1991.1.2'            => 'Foundry router',
                         '1.3.6.1.4.1.1991.1.3.36.2.2'     => 'Foundry SuperX',
                         '1.3.6.1.4.1.1991.1.3.36.2.2'     => 'Foundry Router',
                         '1.3.6.1.4.1.1991.1.3.36.6.2'     => 'Foundry SX 1600',
                         '1.3.6.1.4.1.1991.1.3.52.1.4.1.1' => 'FWS624G-POE',
                          );


#
# Some of these OIDs are found in the standard MIB-II MIB named
# $OV_SNMP_MIBS/Standard/rfc1213-MIB-II or the Bridge MIB,
# $OV_SNMP_MIBS/Standard/rfc4188-BRIDGE.  Others are found in the
# Cisco Stack MIB, $OV_SNMP_MIBS/Vendor/Cisco/CISCO-STACK-MIB.my,
# which you can get from
# http://www.cisco.com/public/sw-center/netmgmt/cmtk/mibs.shtml.
# Others are found in the Grand Junction/Cisco ESSWITCH MIB,
# $OV_SNMP_MIBS/Vendor/Cisco/ESSWITCH-MIB.my, which you can get from
# http://www.cisco.com/public/sw-center/netmgmt/cmtk/mibs.shtml.
#

%SnmpOids = (
             #
             # The SNMP OID of an ARP table is:
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #   4.22.1.2    = ip.ipNetToMediaTable.ipNetToMediaEntry.ipNetToMediaPhysAddress
             'ipNetToMediaIfIndex'     => '.1.3.6.1.2.1.4.22.1.1',
             'ipNetToMediaPhysAddress' => '.1.3.6.1.2.1.4.22.1.2',

             # The SNMP OID of the Juniper
             #   1.3.6.1.2.1 = iso.org.dod.internet.private.enterprise
             #   2636.3.40.1 = 2636.jnxMibs.jnxExMibRoot.jnxExSwitching
             #   5.1.7       = jnxExVlan.jnxVlanMIBObjects.jnxExVlanPortGroupTable
             #   1.5         = jnxExVlanPortGroupEntry.jnxExVlanPortAccessMode
#            'jnxExVlanPortStatus'     => '1.3.6.1.4.1.2636.3.40.1.5.1.7.1.3',
             'jnxExVlanPortAccessMode' => '1.3.6.1.4.1.2636.3.40.1.5.1.7.1.5',

             # The SNMP OID of the Juniper
             #   1.3.6.1.2.1 = iso.org.dod.internet.private.enterprise
             #   2636.3.40.1 = 2636.jnxMibs.jnxExMibRoot.jnxExSwitching
             #   5.1.5       = jnxExVlan.jnxVlanMIBObjects.jnxExVlanTable
             #   1.5         = jnxExVlanEntry.jnxExVlanTag
             'jnxExVlanName'           => '1.3.6.1.4.1.2636.3.40.1.5.1.5.1.2',
             'jnxExVlanTag'            => '1.3.6.1.4.1.2636.3.40.1.5.1.5.1.5',

             #
             # The SNMP OID of an ARP table (deprecated) is:
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #   3.1.1       = at.atTable.atEntry
             'arpTable' => '.1.3.6.1.2.1.3.1.1.2',

             #
             # The SNMP oid of the chassisModel value is
             #   1.3.6.1.4.1 = iso.org.dod.internet.private.enterprises
             #   9.5.1.2.16 = cisco.wkgrpProducts.stack.chassisGrp.chassisModel
             'chassisModel' => '1.3.6.1.4.1.9.5.1.2.16.0',

             #
             # The SNMP oid of the dot1dBasePortIfIndex table isb
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #       17      dot1dBridge            bridge MIB, RFC 4188
             #       1       dot1dBase
             #       4       dot1dBasePortTable
             #       1       dot1dBasePortEntry
             #       2       dot1dBasePortIfIndex   MIB-II ifIndex
             #
             'dot1dBasePortIfIndex' => '1.3.6.1.2.1.17.1.4.1.2',

             #
             # The SNMP oid of the dot1dTpFdbPort table is
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #     17      dot1dBridge            bridge MIB, RFC 4188
             #     4       dot1dTp                transparent bridging
             #     3       dot1dTpFdbTable        forwarding table
             #     1       dot1dTpFdbEntry        entry for 1 MAC
             #     2       dot1dTpFdbPort         bridge port number
             #
             'dot1dTpFdbPort' => '1.3.6.1.2.1.17.4.3.1.2',

             #
             # 1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #     17   dot1dBridge            bridge MIB, RFC 4188
             #     7    qBridgeMIB             qbridge MIB, RFC 4363
             #     1    qBridgeMIBObjects
             #     1    dot1qBase
             #     4    dot1qNumVlans
             'dot1qNumVlans'   => '1.3.6.1.2.1.17.7.1.1.4',

             #
             # 1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #     17   dot1dBridge            bridge MIB, RFC 4188
             #     7    qBridgeMIB             qbridge MIB, RFC 4363
             #     1    qBridgeMIBObjects
             #     2    dot1qTp
             #     2    dot1qTpFdbTable
             #
             'dot1qTpFdbTable' => '1.3.6.1.2.1.17.7.1.2.2',


             #
             # The SNMP oid of the ifAdminStatus table is
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2 (RFC 1213)
             #   2.2.1.7 = interfaces.ifTable.ifEntry.ifAdminStatus
             'ifType'         => '1.3.6.1.2.1.2.2.1.3',
             'ifSpeed'        => '1.3.6.1.2.1.2.2.1.5',
             'ifPhysAddress'  => '1.3.6.1.2.1.2.2.1.6',
             'ifAdminStatus'  => '1.3.6.1.2.1.2.2.1.7',
             'ifOperStatus'   => '1.3.6.1.2.1.2.2.1.8',

             #
             # The SNMP oid of the ifName table is
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #   31        ifMIB (added mib-2 interface MIB items, RFC 2863)
             #   1.1.1.1   ifMIBObjects.ifTable.ifEntry.ifName
             #
             'ifName'  => '1.3.6.1.2.1.31.1.1.1.1',
             'ifAlias' => '1.3.6.1.2.1.31.1.1.1.18',
             #
             # From Standard/rfc2863-IF-MIB, the SNMP oid of the ifStackStatus table is
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #   31        ifMIB (interface MIB, RFC 2863)
             #   1.2.1.3   ifMIBObjects.ifStackTable.ifStackEntry.ifStackStatus
             #
             'ifStackStatus' => '.1.3.6.1.2.1.31.1.2.1.3',

             #
             # These SNMP oids mean
             #   1.3.6.1.4.1   iso.org.dod.internet.private.enterprises
             #   9.5.1.3       cisco.wkgrpProducts.stack.moduleGrp
             #   1.1.2         moduleTable.moduleEntry.moduleType
             #
             'moduleType'               => '1.3.6.1.4.1.9.5.1.3.1.1.2',
             'moduleSerialNumber'       => '1.3.6.1.4.1.9.5.1.3.1.1.3',
             'moduleName'               => '1.3.6.1.4.1.9.5.1.3.1.1.13',
             'moduleModel'              => '1.3.6.1.4.1.9.5.1.3.1.1.17',
             'moduleHwVersion'          => '1.3.6.1.4.1.9.5.1.3.1.1.18',
             'moduleFwVersion'          => '1.3.6.1.4.1.9.5.1.3.1.1.19',
             'moduleSwVersion'          => '1.3.6.1.4.1.9.5.1.3.1.1.20',
             'moduleSerialNumberString' => '1.3.6.1.4.1.9.5.1.3.1.1.26',

             #
             # This oid is defined in the standard POWER-ETHERNET-MIB,
             # defined in RFC 3621, not by Cisco.
             # This SNMP oid means
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #   105.1       = powerEthernetMIB.pethObjects
             #   1.1         = pethPsePortTable.pethPsePortEntry
             #   6           = pethPsePortDetectionStatus
             'pethPsePortDetectionStatus' => '.1.3.6.1.2.1.105.1.1.1.6',

             #
             # These SNMP oids mean
             #   1.3.6.1.4.1.9 = iso.org.dod.internet.private.enterprises
             #   5.1.4.1 = wkgrpProducts.stack.portGrp.portTable
             #   1.9 = portEntry.portAdminSpeed
             #
             'portName'       => '1.3.6.1.4.1.9.5.1.4.1.1.4',
             'portAdminSpeed' => '1.3.6.1.4.1.9.5.1.4.1.1.9',
             'portDuplex'     => '1.3.6.1.4.1.9.5.1.4.1.1.10',
             'portIfIndex'    => '1.3.6.1.4.1.9.5.1.4.1.1.11',

             #
             # The SNMP oid of the sysObjectID is .1.3.6.1.2.1.1
             #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             #
             'sysObjectID'  => '1.3.6.1.2.1.1.2.0',

             #
             #   1.3.6.1.4.1.9  = iso.org.dod.internet.private.enterprises.cisco
             #   5.1.9.3.1.3    = wkgrpProducts.stack.vlanGrp.vlanPortTable.vlanPortEntry.vlanPortVlan
             'vlanPortVlan'           => '1.3.6.1.4.1.9.5.1.9.3.1.3',
             'vlanPortIslAdminStatus' => '1.3.6.1.4.1.9.5.1.9.3.1.7',
             'vlanPortIslOperStatus'  => '1.3.6.1.4.1.9.5.1.9.3.1.8',

             #
             #   1.3.6.1.4.1.9  = iso.org.dod.internet.private.enterprises.cisco
             #   9.46.1.6       = ciscoMgmt.ciscoVtpMIB.vtpMIBObjects.vlanTrunkPorts
             #   1.1.5          = vlanTrunkPortTable.vlanTrunkPortEntry.vlanTrunkPortNativeVlan
             'vtpVlanState'                => '1.3.6.1.4.1.9.9.46.1.3.1.1.2',
	     'vlanTrunkPortVlansEnabled'   => '1.3.6.1.4.1.9.9.46.1.6.1.1.4',
             'vlanTrunkPortNativeVlan'     => '1.3.6.1.4.1.9.9.46.1.6.1.1.5',
             'vlanTrunkPortDynamicState'   => '1.3.6.1.4.1.9.9.46.1.6.1.1.13',
             'vlanTrunkPortDynamicStatus'  => '1.3.6.1.4.1.9.9.46.1.6.1.1.14',
	     'vlanTrunkPortVlansEnabled2k' => '1.3.6.1.4.1.9.9.46.1.6.1.1.17',
	     'vlanTrunkPortVlansEnabled3k' => '1.3.6.1.4.1.9.9.46.1.6.1.1.18',
	     'vlanTrunkPortVlansEnabled4k' => '1.3.6.1.4.1.9.9.46.1.6.1.1.19',

             #   1.3.6.1.4.1.9  = iso.org.dod.internet.private.enterprises.cisco
             #   9.68.1         = ciscoMgmt.ciscoVlanMembershipMIB.ciscoVlanMembershipMIBObjects
             #   5.1.1.1        = vmVoiceVlan.vmVoiceVlanTable.vmVoiceVlanEntry,vmVoiceVlanId
             'vmVoiceVlanId' => '1.3.6.1.4.1.9.9.68.1.5.1.1.1',
             'vmVlan'        => '1.3.6.1.4.1.9.9.68.1.2.2.1.2', # Trunk ports won't appear in this table



             #   1.3.6.1.4.1.9 = iso.org.dod.internet.private.enterprises.cisco
             #   9.87.1.4      = ciscoMgmt.ciscoC2900MIB.c2900MIBObjects.c2900Port
             #   1.1.32        = c2900PortTable.c2900PortEntry.c2900PortDuplexStatus
             'c2900PortLinkbeatStatus' => '1.3.6.1.4.1.9.9.87.1.4.1.1.18',
             'c2900PortDuplexState'    => '1.3.6.1.4.1.9.9.87.1.4.1.1.31',
             'c2900PortDuplexStatus'   => '1.3.6.1.4.1.9.9.87.1.4.1.1.32',
             'c2900PortVoiceVlanId'    => '1.3.6.1.4.1.9.9.87.1.4.1.1.37',

             #
             # The Cisco Discovory Protocol (CDP) cdpCachePlatform
             #
             #   1.3.6.1.4.1.9 = iso.org.dod.internet.private.enterprises.cisco
             #   9.23.1.2      = ciscoMgmt.ciscoCdpMIB.ciscoCdpMIBObjects.cdpCache
             #   1.1.8         = cdpCacheTable.cdpCacheEntry.cdpCachePlatform
             'cdpCacheDeviceId' => '1.3.6.1.4.1.9.9.23.1.2.1.1.6',
             'cdpCachePlatform' => '1.3.6.1.4.1.9.9.23.1.2.1.1.8',

             #
             # 1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
             # .47   entityMIB
             # .1    entityMIBObjects
             # .1    entityPhysical
             # .1    entPhysicalTable
             # .1    entPhysicalEntry
             # .5    entPhysicalClass
             'entPhysicalDescr'       => '1.3.6.1.2.1.47.1.1.1.1.2',
             'entPhysicalContainedIn' => '1.3.6.1.2.1.47.1.1.1.1.4',
             'entPhysicalClass'       => '1.3.6.1.2.1.47.1.1.1.1.5',
             'entPhysicalName'        => '1.3.6.1.2.1.47.1.1.1.1.7',
             'entPhysicalHardwareRev' => '1.3.6.1.2.1.47.1.1.1.1.8',
             'entPhysicalFirmwareRev' => '1.3.6.1.2.1.47.1.1.1.1.9',
             'entPhysicalSoftwareRev' => '1.3.6.1.2.1.47.1.1.1.1.10',
             'entPhysicalSerialNum'   => '1.3.6.1.2.1.47.1.1.1.1.11',
             'entPhysicalModelName'   => '1.3.6.1.2.1.47.1.1.1.1.13',

             #
             #   1.3.6.1.4.1 = iso.org.dod.internet.private.enterprises
             #   1991.1.3. = foundry.products.snSwitch
             #   3.5.1.24 = ???
#             'snSwPortVlanId' => '1.3.6.1.4.1.1991.1.1.3.3.5.1.24',

             #
             # The SNMP OID of the ESSWITCH swPortName table is:
             #   1.3.6.1.4.1.437. = iso.org.dod.internet.private.enterprises.grandjunction.
             #         1.1.3.3.1. = products.fastLink.series2000.port.switchPortTable.
             #                1.3 = swPortEntry.swPortName
             'swPortName'         => '1.3.6.1.4.1.437.1.1.3.3.1.1.3',
             'swPortDuplexStatus' => '1.3.6.1.4.1.437.1.1.3.3.1.1.30',

            #
            # The SNMP OID of the EtherLike-MIB dot3StatsTable table is:
            # 1.3.6.1.2.1.10.7. = iso.org.dod.internet.mgmt.mib-2.transmission.dot3
            #            2.1.19 = dot3StatsTable.dot3StatsEntry.dot3StatsDuplexStatus
            'dot3StatsDuplexStatus' => '1.3.6.1.2.1.10.7.2.1.19',
            );


#
# These interface types come right out of the IANAifType-MIB.
#
%ifTypeStrings = (
'1' => 'other',           # none of the following
'2' => 'regular1822',
'3' => 'hdh1822',
'4' => 'ddnX25',
'5' => 'rfc877x25',
'6' => 'ethernetCsmacd',  # for all ethernet-like interfaces, regardless of speed, as per RFC3635
'7' => 'iso88023Csmacd',  # Deprecated via RFC-draft-ietf-hubmib-etherif-mib-v3  ethernetCsmacd (6) should be used instead
'8' => 'iso88024TokenBus',
'9' => 'iso88025TokenRing',
'10' => 'iso88026Man',
'11' => 'starLan',        # Deprecated via RFC-draft-ietf-hubmib-etherif-mib-v3  ethernetCsmacd (6) should be used instead
'12' => 'proteon10Mbit',
'13' => 'proteon80Mbit',
'14' => 'hyperchannel',
'15' => 'fddi',
'16' => 'lapb',
'17' => 'sdlc',
'18' => 'ds1',            # DS1-MIB
'19' => 'e1',             # Obsolete see DS1-MIB
'20' => 'basicISDN',
'21' => 'primaryISDN',
'22' => 'propPointToPointSerial', # proprietary serial
'23' => 'ppp',
'24' => 'softwareLoopback',
'25' => 'eon',            # CLNP over IP
'26' => 'ethernet3Mbit',
'27' => 'nsip',           # XNS over IP
'28' => 'slip',           # generic SLIP
'29' => 'ultra',          # ULTRA technologies
'30' => 'ds3',            # DS3-MIB
'31' => 'sip',            # SMDS, coffee
'32' => 'frameRelay',     # DTE only.
'33' => 'rs232',
'34' => 'para',           # parallel-port
'35' => 'arcnet',         # arcnet
'36' => 'arcnetPlus',     # arcnet plus
'37' => 'atm',            # ATM cells
'38' => 'miox25',
'39' => 'sonet',          # SONET or SDH
'40' => 'x25ple',
'41' => 'iso88022llc',
'42' => 'localTalk',
'43' => 'smdsDxi',
'44' => 'frameRelayService',  # FRNETSERV-MIB
'45' => 'v35',
'46' => 'hssi',
'47' => 'hippi',
'48' => 'modem',          # Generic modem
'49' => 'aal5',           # AAL5 over ATM
'50' => 'sonetPath',
'51' => 'sonetVT',
'52' => 'smdsIcip',       # SMDS InterCarrier Interface
'53' => 'propVirtual',    # proprietary virtual/internal
'54' => 'propMultiplexor',# proprietary multiplexing
'55' => 'ieee80212',      # 100BaseVG
'56' => 'fibreChannel',   # Fibre Channel
'57' => 'hippiInterface', # HIPPI interfaces
'58' => 'frameRelayInterconnect', # Obsolete use either frameRelay(32) or frameRelayService(44).
'59' => 'aflane8023',     # ATM Emulated LAN for 802.3
'60' => 'aflane8025',     # ATM Emulated LAN for 802.5
'61' => 'cctEmul',        # ATM Emulated circuit
'62' => 'fastEther',      # Obsoleted via RFC-draft-ietf-hubmib-etherif-mib-v3  ethernetCsmacd (6) should be used instead
'63' => 'isdn',           # ISDN and X.25
'64' => 'v11',            # CCITT V.11/X.21
'65' => 'v36',            # CCITT V.36
'66' => 'g703at64k',      # CCITT G703 at 64Kbps
'67' => 'g703at2mb',      # Obsolete see DS1-MIB
'68' => 'qllc',           # SNA QLLC
'69' => 'fastEtherFX',    # Obsoleted via RFC-draft-ietf-hubmib-etherif-mib-v3  ethernetCsmacd (6) should be used instead
'70' => 'channel',        # channel
'71' => 'ieee80211',      # radio spread spectrum
'72' => 'arChan',         # IBM System 360/370 OEMI Channel
'73' => 'escon',          # IBM Enterprise Systems Connection
'74' => 'dlsw',           # Data Link Switching
'75' => 'isdns',          # ISDN S/T interface
'76' => 'isdnu',          # ISDN U interface
'77' => 'lapd',           # Link Access Protocol D
'78' => 'ipSwitch',       # IP Switching Objects
'79' => 'rsrb',           # Remote Source Route Bridging
'80' => 'atmLogical',     # ATM Logical Port
'81' => 'ds0',            # Digital Signal Level 0
'82' => 'ds0Bundle',      # group of ds0s on the same ds1
'83' => 'bsc',            # Bisynchronous Protocol
'84' => 'async',          # Asynchronous Protocol
'85' => 'cnr',            # Combat Net Radio
'86' => 'iso88025Dtr',    # ISO 802.5r DTR
'87' => 'eplrs',          # Ext Pos Loc Report Sys
'88' => 'arap',           # Appletalk Remote Access Protocol
'89' => 'propCnls',       # Proprietary Connectionless Protocol
'90' => 'hostPad',        # CCITT-ITU X.29 PAD Protocol
'91' => 'termPad',        # CCITT-ITU X.3 PAD Facility
'92' => 'frameRelayMPI',  # Multiproto Interconnect over FR
'93' => 'x213',           # CCITT-ITU X213
'94' => 'adsl',           # Asymmetric Digital Subscriber Loop
'95' => 'radsl',          # Rate-Adapt. Digital Subscriber Loop
'96' => 'sdsl',           # Symmetric Digital Subscriber Loop
'97' => 'vdsl',           # Very H-Speed Digital Subscrib. Loop
'98' => 'iso88025CRFPInt', # ISO 802.5 CRFP
'99' => 'myrinet',        # Myricom Myrinet
'100' => 'voiceEM',       # voice recEive and transMit
'101' => 'voiceFXO',      # voice Foreign Exchange Office
'102' => 'voiceFXS',      # voice Foreign Exchange Station
'103' => 'voiceEncap',    # voice encapsulation
'104' => 'voiceOverIp',   # voice over IP encapsulation
'105' => 'atmDxi',        # ATM DXI
'106' => 'atmFuni',       # ATM FUNI
'107' => 'atmIma',        # ATM IMA
'108' => 'pppMultilinkBundle', # PPP Multilink Bundle
'109' => 'ipOverCdlc',    # IBM ipOverCdlc
'110' => 'ipOverClaw',    # IBM Common Link Access to Workstn
'111' => 'stackToStack', # IBM stackToStack
'112' => 'virtualIpAddress', # IBM VIPA
'113' => 'mpc',           # IBM multi-protocol channel support
'114' => 'ipOverAtm',    # IBM ipOverAtm
'115' => 'iso88025Fiber', # ISO 802.5j Fiber Token Ring
'116' => 'tdlc',	       # IBM twinaxial data link control
'117' => 'gigabitEthernet', # Obsoleted via RFC-draft-ietf-hubmib-etherif-mib-v3  ethernetCsmacd (6) should be used instead
'118' => 'hdlc',         # HDLC
'119' => 'lapf', 	       # LAP F
'120' => 'v37', 	       # V.37
'121' => 'x25mlp',       # Multi-Link Protocol
'122' => 'x25huntGroup', # X25 Hunt Group
'123' => 'trasnpHdlc',   # Transp HDLC
'124' => 'interleave',   # Interleave channel
'125' => 'fast',         # Fast channel
'126' => 'ip', 	       # IP (for APPN HPR in IP networks)
'127' => 'docsCableMaclayer',  # CATV Mac Layer
'128' => 'docsCableDownstream', # CATV Downstream interface
'129' => 'docsCableUpstream',  # CATV Upstream interface
'130' => 'a12MppSwitch', # Avalon Parallel Processor
'131' => 'tunnel',       # Encapsulation interface
'132' => 'coffee',       # coffee pot
'133' => 'ces',          # Circuit Emulation Service
'134' => 'atmSubInterface', # ATM Sub Interface
'135' => 'l2vlan',       # Layer 2 Virtual LAN using 802.1Q
'136' => 'l3ipvlan',     # Layer 3 Virtual LAN using IP
'137' => 'l3ipxvlan',    # Layer 3 Virtual LAN using IPX
'138' => 'digitalPowerline', # IP over Power Lines
'139' => 'mediaMailOverIp', # Multimedia Mail over IP
'140' => 'dtm',        # Dynamic syncronous Transfer Mode
'141' => 'dcn',    # Data Communications Network
'142' => 'ipForward',    # IP Forwarding Interface
'143' => 'msdsl',       # Multi-rate Symmetric DSL
'144' => 'ieee1394', # IEEE1394 High Performance Serial Bus
'145' => 'if-gsn',       #   HIPPI-6400
'146' => 'dvbRccMacLayer', # DVB-RCC MAC Layer
'147' => 'dvbRccDownstream',  # DVB-RCC Downstream Channel
'148' => 'dvbRccUpstream',  # DVB-RCC Upstream Channel
'149' => 'atmVirtual',   # ATM Virtual Interface
'150' => 'mplsTunnel',   # MPLS Tunnel Virtual Interface
'151' => 'srp', 	# Spatial Reuse Protocol
'152' => 'voiceOverAtm',  # Voice Over ATM
'153' => 'voiceOverFrameRelay',   # Voice Over Frame Relay
'154' => 'idsl', 		# Digital Subscriber Loop over ISDN
'155' => 'compositeLink',  # Avici Composite Link Interface
'156' => 'ss7SigLink',     # SS7 Signaling Link
'157' => 'propWirelessP2P',  #  Prop. P2P wireless interface
'158' => 'frForward',    # Frame Forward Interface
'159' => 'rfc1483', 	# Multiprotocol over ATM AAL5
'160' => 'usb', 		# USB Interface
'161' => 'ieee8023adLag',  # IEEE 802.3ad Link Aggregate
'162' => 'bgppolicyaccounting', # BGP Policy Accounting
'163' => 'frf16MfrBundle', # FRF .16 Multilink Frame Relay
'164' => 'h323Gatekeeper', # H323 Gatekeeper
'165' => 'h323Proxy', # H323 Voice and Video Proxy
'166' => 'mpls', # MPLS
'167' => 'mfSigLink', # Multi-frequency signaling link
'168' => 'hdsl2', # High Bit-Rate DSL - 2nd generation
'169' => 'shdsl', # Multirate HDSL2
'170' => 'ds1FDL', # Facility Data Link 4Kbps on a DS1
'171' => 'pos', # Packet over SONET/SDH Interface
'172' => 'dvbAsiIn', # DVB-ASI Input
'173' => 'dvbAsiOut', # DVB-ASI Output
'174' => 'plc', # Power Line Communtications
'175' => 'nfas', # Non Facility Associated Signaling
'176' => 'tr008', # TR008
'177' => 'gr303RDT', # Remote Digital Terminal
'178' => 'gr303IDT', # Integrated Digital Terminal
'179' => 'isup', # ISUP
'180' => 'propDocsWirelessMaclayer', # Cisco proprietary Maclayer
'181' => 'propDocsWirelessDownstream', # Cisco proprietary Downstream
'182' => 'propDocsWirelessUpstream', # Cisco proprietary Upstream
'183' => 'hiperlan2', # HIPERLAN Type 2 Radio Interface
'184' => 'propBWAp2Mp', # PropBroadbandWirelessAccesspt2multipt
'185' => 'sonetOverheadChannel', # SONET Overhead Channel
'186' => 'digitalWrapperOverheadChannel', # Digital Wrapper
'187' => 'aal2', # ATM adaptation layer 2
'188' => 'radioMAC', # MAC layer over radio links
'189' => 'atmRadio', # ATM over radio links
'190' => 'imt', # Inter Machine Trunks
'191' => 'mvl', # Multiple Virtual Lines DSL
'192' => 'reachDSL', # Long Reach DSL
'193' => 'frDlciEndPt', # Frame Relay DLCI End Point
'194' => 'atmVciEndPt', # ATM VCI End Point
'195' => 'opticalChannel', # Optical Channel
'196' => 'opticalTransport', # Optical Transport
'197' => 'propAtm', #  Proprietary ATM
'198' => 'voiceOverCable', # Voice Over Cable Interface
'199' => 'infiniband', # Infiniband
'200' => 'teLink', # TE Link
'201' => 'q2931', # Q.2931
'202' => 'virtualTg', # Virtual Trunk Group
'203' => 'sipTg', # SIP Trunk Group
'204' => 'sipSig', # SIP Signaling
'205' => 'docsCableUpstreamChannel', # CATV Upstream Channel
'206' => 'econet', # Acorn Econet
'207' => 'pon155', # FSAN 155Mb Symetrical PON interface
'208' => 'pon622', # FSAN622Mb Symetrical PON interface
'209' => 'bridge', # Transparent bridge interface
'210' => 'linegroup', # Interface common to multiple lines
'211' => 'voiceEMFGD', # voice E&M Feature Group D
'212' => 'voiceFGDEANA', # voice FGD Exchange Access North American
'213' => 'voiceDID', # voice Direct Inward Dialing
'214' => 'mpegTransport', # MPEG transport interface
'215' => 'sixToFour', # 6to4 interface (DEPRECATED)
'216' => 'gtp', # GTP (GPRS Tunneling Protocol)
'217' => 'pdnEtherLoop1', # Paradyne EtherLoop 1
'218' => 'pdnEtherLoop2', # Paradyne EtherLoop 2
'219' => 'opticalChannelGroup', # Optical Channel Group
'220' => 'homepna', # HomePNA ITU-T G.989
'221' => 'gfp', # Generic Framing Procedure (GFP)
'222' => 'ciscoISLvlan', # Layer 2 Virtual LAN using Cisco ISL
'223' => 'actelisMetaLOOP', # Acteleis proprietary MetaLOOP High Speed Link
'224' => 'fcipLink', # FCIP Link
'225' => 'rpr', # Resilient Packet Ring Interface Type
'226' => 'qam', # RF Qam Interface
'227' => 'lmp', # Link Management Protocol
'228' => 'cblVectaStar', # Cambridge Broadband Limited VectaStar
'229' => 'docsCableMCmtsDownstream', # CATV Modular CMTS Downstream Interface
'230' => 'adsl2', # Asymmetric Digital Subscriber Loop Version 2
'231' => 'macSecControlledIF', # MACSecControlled
'232' => 'macSecUncontrolledIF', # MACSecUncontrolled
'233' => 'aviciOpticalEther', # Avici Optical Ethernet Aggregate
'234' => 'atmbond'  # atmbond
                    );

1;
