# NAME

check_rittal_pdu.pl

# DESCRIPTION

Plugin for Icinga 2 (or Nagios) to check the status of Rittal power distribution units (PDU).

CMC III sensors connected to the CAN bus of these units are also supported.

Developed for and currently tested with:

- DK 7979.2xx -- PDU metered
- DK 7979.713 -- RCM measurement module / inline meter
- DK 7979.714 -- RCM measurement module / inline meter
- DK 7030.110 -- CMC-TMP (temperature sensor) 
- DK 7030.111 -- CMC-HUM (temperature/humidity sensor)

# SYNOPSIS

    check_rittal_pdu.pl -H <hostname> -d <device_id> -C <SNMPv2-community>

# OPTIONS

    -?, --usage
      Print usage information
    -h, --help
      Print detailed help screen
    -V, --version
      Print version information
    --extra-opts=[section][@file]
      Read options from an ini file. See https://www.monitoring-plugins.org/doc/extra-opts.html for usage and examples.
    -H, --hostname=STRING
      hostname or IP address
    -D, --device_id=STRING
      device identifier (1...32)
    -s, --snmp_version=STRING
      SNMP version (1|2c|3)
    -C, --community=STRING
      SNMP community string
    -u, --username=STRING
      SNMPv3 Username
    --authpassword
      SNMPv3 authPassword
    --authkey
      SNMPv3 authKey
    --authprotocol
      SNMPv3 authProtocol
    --privpassword
      SNMPv3 privPassword
    --privkey
      SNMPv3 privKey
    --privprotocol
      SNMPv3 privProtocol
    -t, --timeout=INTEGER
      Seconds before plugin times out (default: 15)
    -v, --verbose
      Show details for command-line debugging (can repeat up to 3 times)

# SAMPLE OUTPUT

All examples shown with default SNMP version **2c** and community string **public**.

## PDU controller

The device id typically used for the PDU controller is 1.

There is no fancy output in OK state and no performance data for the controller.

    $ ./check_rittal_pdu.pl -H my-pdu.local -D 1
    RITTAL_PDU OK - PDU-Controller healthy

## PDU meter

The device id typically used for the PDU meter is 2.

    $ ./check_rittal_pdu.pl -H my-pdu.local -D 2
    RITTAL_PDU OK - PDU-Meter Total_Power_Active is 0 W | Total_Frequency=50Hz;;;0;650 Total_Neutral_Current=0A;0:0;0:0;0;3500 Total_Power_Active=0W;0:0;0:0;0;9100 Total_Energy_Active=0kWh;;;0;2000000000 Total_Energy_Active_Runtime=9446103s;;;0;2000000000 L1_Voltage=234.8V;210:250;200:260;0;4000 L1_Current=0A;0:0;0:0;0;3500 L1_Power_Factor=1;;;-100;100 L1_Power_Active=0W;0:0;0:0;0;9100 L1_Power_Reactive=0var;;;0;9100 L1_Power_Apparent=0VA;;;0;9100 L1_Energy_Active=0kWh;;;0;2000000000 L1_Energy_Apparent=0kVAh;;;0;2000000000

## RCM inline meter
The device id typically used for the RCM inline meter is 2.

    $ ./check_rittal_pdu.pl -H my-pdu-with-rcm.local -D 2
    RITTAL_PDU OK - RCM-Inline-Meter Total_Power_Active is 815 W | Total_Frequency=50Hz;;;0;650 Total_Neutral_Current=3.59A;0:0;0:0;0;3500 Total_Power_Active=815W;0:0;0:0;0;27300 Total_Energy_Active=14479.9kWh;;;0;2000000000 Total_Energy_Active_Runtime=75178684s;;;0;2000000000 L1_Voltage=230.2V;210:250;200:260;0;4000 L1_Voltage_THD=0%;;;0;400 L1_Current=0A;0:0;0:0;0;3500 L1_Current_THD=0%;;;0;400 L1_Power_Factor=1;;;-100;100 L1_Power_Active=0W;0:0;0:0;0;9100 L1_Power_Reactive=0var;;;0;9100 L1_Power_Apparent=0VA;;;0;9100 L1_Energy_Active=0kWh;;;0;2000000000 L1_Energy_Apparent=0kVAh;;;0;2000000000 L2_Voltage=230.6V;210:250;200:260;0;4000 L2_Voltage_THD=0%;;;0;400 L2_Current=0.1A;0:0;0:0;0;3500 L2_Current_THD=0%;;;0;400 L2_Power_Factor=-0.1;;;-100;100 L2_Power_Active=2W;0:0;0:0;0;9100 L2_Power_Reactive=24var;;;0;9100 L2_Power_Apparent=24VA;;;0;9100 L2_Energy_Active=37.2kWh;;;0;2000000000 L2_Energy_Apparent=427kVAh;;;0;2000000000 L3_Voltage=229.8V;210:250;200:260;0;4000 L3_Voltage_THD=0%;;;0;400 L3_Current=3.71A;0:0;0:0;0;3500 L3_Current_THD=0%;;;0;400 L3_Power_Factor=-0.94;;;-100;100 L3_Power_Active=805W;0:0;0:0;0;9100 L3_Power_Reactive=214var;;;0;9100 L3_Power_Apparent=849VA;;;0;9100 L3_Energy_Active=14442.7kWh;;;0;2000000000 L3_Energy_Apparent=15257.3kVAh;;;0;2000000000 RCMs_RCM_01_AC=0.7mA;;;0;1000 RCMs_RCM_01_DC=0mA;;;0;1000

## CMC III sensor

    $ ./check_rittal_pdu.pl -H my-pdu.local -D 3
    RITTAL_PDU OK - CMCIII-HUM Temperature is 20.7 degree_C | Temperature=20.7degree_C;;;-40;80 Humidity=47%;;;0;100 Dew_Point=9degree_C;;;-40;100

# HOW TO START

Gather information about your unit using the verbose switch **-v**.

Then query each device with it's own dedicated check as shown with the sample output above.

    $ ./check_rittal_pdu.pl -H my-pdu.local -v
    $VAR1 = {
          '3' => {
                   'DevName' => 'CMCIII-HUM',
                   'DevArtNr' => '7030.111',
                   'DevAlias' => 'CMCIII-HUM',
                   'DevSerial' => '123456789',
                   'DevType' => '1.3.6.1.4.1.2606.7.7.4.1024',
                   'DevLocation' => 'Datacenter 1, Rack 6'
                 },
          '4' => {
                   'DevLocation' => 'Datacenter 1, raised floor',
                   'DevType' => '1.3.6.1.4.1.2606.7.7.4.1024',
                   'DevSerial' => '23456789',
                   'DevArtNr' => '7030.111',
                   'DevAlias' => 'CMCIII-HUM',
                   'DevName' => 'CMCIII-HUM'
                 },
          '5' => {
                   'DevSerial' => '34567891',
                   'DevType' => '1.3.6.1.4.1.2606.7.7.4.1024',
                   'DevLocation' => 'Datacenter 1, Rack 7',
                   'DevName' => 'CMCIII-HUM',
                   'DevAlias' => 'CMCIII-HUM',
                   'DevArtNr' => '7030.111'
                 },
          '2' => {
                   'DevSerial' => '456789012',
                   'DevLocation' => 'Datacenter 1, Rack 8',
                   'DevType' => '1.3.6.1.4.1.2606.7.7.4.33792',
                   'DevName' => 'PDU-MET',
                   'DevAlias' => 'PDU-MET',
                   'DevArtNr' => '7979202'
                 },
          '1' => {
                   'DevAlias' => 'PDU-Controller',
                   'DevArtNr' => '343069',
                   'DevName' => 'PDU-Controller',
                   'DevType' => '1.3.6.1.4.1.2606.7.7.4.33536',
                   'DevLocation' => 'Datacenter 1, Rack 8',
                   'DevSerial' => '34826537'
                 }
        };
    RITTAL_PDU OK - PDU-Controller healthy

# TEMPLATES FOR ICINGA 2

The provided templates have been created with Icinga Director.

## Service template

    template Service "rittal_pdu" {
        import "standard-service"

        check_command = "check_rittal_pdu"
        vars.rittal_pdu_authkey = "$host.vars.rittal_pdu_authkey$"
        vars.rittal_pdu_authpassword = "$host.vars.rittal_pdu_authpassword$"
        vars.rittal_pdu_authprotocol = "$host.vars.rittal_pdu_authprotocol$"
        vars.rittal_pdu_community = "$host.vars.rittal_pdu_community$"
        vars.rittal_pdu_privkey = "$host.vars.rittal_pdu_privkey$"
        vars.rittal_pdu_privpassword = "$host.vars.rittal_pdu_privpassword$"
        vars.rittal_pdu_privprotocol = "$host.vars.rittal_pdu_privprotocol$"
        vars.rittal_pdu_snmp_version = "$host.vars.rittal_pdu_snmp_version$"
        vars.rittal_pdu_snmpv3_username = "$host.vars.rittal_pdu_snmpv3_username$"
    }

## Command template

   	object CheckCommand "check_rittal_pdu" {
	    import "plugin-check-command"
	    command = [ PluginDir + "/check_rittal_pdu.pl" ]
	    timeout = 15s
	    arguments += {
	        "--authkey" = {
	            description = "SNMPv3 authKey"
	            required = false
	            value = "$rittal_pdu_authkey$"
	        }
	        "--authpassword" = {
	            description = "SNMPv3 authPassword"
	            required = false
	            value = "$rittal_pdu_authpassword$"
	        }
	        "--authprotocol" = {
	            description = "SNMPv3 authProtocol"
	            required = false
	            value = "$rittal_pdu_authprotocol$"
	        }
	        "--community" = {
	            description = "SNMP community string"
	            required = false
	            value = "$rittal_pdu_community$"
	        }
	        "--device_id" = {
	            description = "device identifier (1...32)"
	            required = true
	            value = "$rittal_pdu_device_id$"
	        }
	        "--privkey" = {
	            description = "SNMPv3 privKey"
	            value = "$rittal_pdu_privkey$"
	        }
	        "--privpassword" = {
	            description = "SNMPv3 privPassword"
	            required = false
	            value = "$rittal_pdu_privpassword$"
	        }
	        "--privprotocol" = {
	            description = "SNMPv3 privProtocol"
	            value = "$rittal_pdu_privprotocol$"
	        }
	        "--snmp_version" = {
	            description = "SNMP version (1|2c|3)"
	            required = false
	            value = "$rittal_pdu_snmp_version$"
	        }
	        "--username" = {
	            description = "SNMPv3 Username"
	            required = false
	            value = "$rittal_pdu_snmpv3_username$"
	        }
	        "-H" = {
	            description = "Hostname"
	            required = true
	            value = "$host.name$"
	        }
	    }
   	}

## Service sets
	
There are two service sets. One for the "classic" PDU  possibly with CMC III sensors attached, and one for the PDU with RCM Inline meter.
	
### Service set rittal-pdu
	
	zones.d/director-global/servicesets.conf
	/**
	 * Service Set: rittal-pdu
	 * 
	 * Service-Set for Rittal PDU
	 */
	
	zones.d/my-zone/servicesets.conf
	/**
	 * Service Set: rittal-pdu
	 * on host rittal-pdu-host
	 */
	
	apply Service "PDU-Controller" {
	    import "rittal_pdu"
	
	
	    assign where "rittal-pdu-host" in host.templates
	    vars.rittal_pdu_device_id = "1"
	    zone = "my-zone"
	
	    import DirectorOverrideTemplate
	}
	
	apply Service "PDU-Meter" {
	    import "rittal_pdu"
	
	
	    assign where "rittal-pdu-host" in host.templates
	    vars.rittal_pdu_device_id = "2"
	    zone = "my-zone"
	
	    import DirectorOverrideTemplate
	}

	
### Service set rittal-pdu-rcm
	
	zones.d/director-global/servicesets.conf
	/**
	 * Service Set: rittal-pdu-rcm
	 * 
	 * Service-Set for Rittal PDU with RCM-Inline-Meter
	 */
	
	zones.d/my-zone/servicesets.conf
	/**
	 * Service Set: rittal-pdu-rcm
	 * on host rittal-pdu-rcm-host
	 */
	
	apply Service "PDU-Controller" {
	    import "rittal_pdu"
	
	
	    assign where "rittal-pdu-rcm-host" in host.templates
	    vars.rittal_pdu_device_id = "1"
	    zone = "my-zone"
	
	    import DirectorOverrideTemplate
	}
	
	apply Service "RCM-Inline-Meter" {
	    import "rittal_pdu"
	
	
	    assign where "rittal-pdu-rcm-host" in host.templates
	    vars.rittal_pdu_device_id = "2"
	    zone = "my-zone"
	
	    import DirectorOverrideTemplate
	}


## Host templates

There are two host templates. One for the "classic" PDU  possibly with CMC III sensors attached, and one for the PDU with RCM Inline meter.

### Host template rittal-pdu-host

	zones.d/my-zone/host_templates.conf
	template Host "rittal-pdu-host" {
	    import "standard-host-my-zone"
	
	}

### Host template rittal-pdu-rcm-host

	zones.d/my-zone/host_templates.conf
	template Host "rittal-pdu-rcm-host" {
	    import "standard-host-my-zone"
	
	}

For the service templates to work, it is important to define the following host variables in the two host templates. 

	rittal_pdu_authkey
	rittal_pdu_authpassword
	rittal_pdu_authprotocol
	rittal_pdu_community
	rittal_pdu_privkey
	rittal_pdu_privpassword
	rittal_pdu_privprotocol
	rittal_pdu_snmpv3_username
	rittal_pdu_snmp_version

None of these variables must be a required field. But please make sure that a valid snmp community string (i. e. **public**) is used when creating a host.
