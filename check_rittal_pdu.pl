#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Net::SNMP;
use Monitoring::Plugin;

############################################################
# check_rittal_pdu.pl
############################################################
sub ProcessPDUController($$$);
sub ProcessPDUMeter1Phase($$$);
sub ProcessPDUMeter3Phase($$$);
sub ProcessRCMInline($$$);
sub ProcessCMCIIIPUCompact($$$);
sub ProcessCMCIIITmpSensor($$$);
sub ProcessCMCIIIHumSensor($$$);
sub ProcessCMCVariable($$$);
sub ProcessVariable($$$);
sub ProcessVariableWithThresholds($$$);
sub ProcessVariableValue($$);
sub ProcessVariableConstraints($);
sub OID_up($);
############################################################
# Startup

my $Plugin = Monitoring::Plugin->new(
  usage => "This plugin checks Rittal power distribution units\n\n" .
           "Usage: %s -H <hostname> -D <device_id> -C <community>\n\n".
           "Use --help for a full list of parameters\n",
  version => 'Version 1.11 Aug 04 2023, Hajo Kessener'
);

############################################################
# Arguments

$Plugin->add_arg(
  spec => 'hostname|H=s',
  help => 'hostname or IP address',
  required => 1
);

$Plugin->add_arg(
  spec => 'device_id|D=s',
  help => 'device identifier (1...32)',
  default => 1,
  required => 0
);

$Plugin->add_arg(
  spec => 'snmp_version|s=s',
  help => 'SNMP version (1|2c|3)',
  default => '2c',
  required => 0
);

$Plugin->add_arg(
  spec => 'community|C=s',
  help => 'SNMP community string',
  default => 'public',
  required => 0
);

$Plugin->add_arg(
  spec => 'username|u=s',
  help => 'SNMPv3 Username',
  required => 0
);

$Plugin->add_arg(
  spec => 'authpassword',
  help => 'SNMPv3 authPassword',
  required => 0
);

$Plugin->add_arg(
  spec => 'authkey',
  help => 'SNMPv3 authKey',
  required => 0
);

$Plugin->add_arg(
  spec => 'authprotocol',
  help => 'SNMPv3 authProtocol',
  default => 'md5',
  required => 0
);

$Plugin->add_arg(
  spec => 'privpassword',
  help => 'SNMPv3 privPassword',
  required => 0
);

$Plugin->add_arg(
  spec => 'privkey',
  help => 'SNMPv3 privKey',
  required => 0
);

$Plugin->add_arg(
  spec => 'privprotocol',
  help => 'SNMPv3 privProtocol',
  default => 'des',
  required => 0
);

$Plugin->getopts();

############################################################
# SNMP query

my($Session,$Error,$Result);

if($Plugin->opts->snmp_version eq '1' || $Plugin->opts->snmp_version eq '2c') {
  ($Session,$Error) = Net::SNMP->session(
    -version   => $Plugin->opts->snmp_version,
    -hostname  => $Plugin->opts->hostname,
    -community => $Plugin->opts->community,
    -timeout   => $Plugin->opts->timeout,
  );
} elsif($Plugin->opts->snmp_version eq '3') {
  if(defined($Plugin->opts->authkey)) {
    ($Session,$Error) = Net::SNMP->session(
      -version      => $Plugin->opts->snmp_version,
      -hostname     => $Plugin->opts->hostname,
      -username     => $Plugin->opts->username,
      -authkey      => $Plugin->opts->authkey,
      -authprotocol => $Plugin->opts->authprotocol,
      -timeout      => $Plugin->opts->timeout,
    );
  } elsif(defined($Plugin->opts->authpassword)) {
    ($Session,$Error) = Net::SNMP->session(
      -version      => $Plugin->opts->snmp_version,
      -hostname     => $Plugin->opts->hostname,
      -username     => $Plugin->opts->username,
      -authpassword => $Plugin->opts->authpassword,
      -authprotocol => $Plugin->opts->authprotocol,
      -timeout      => $Plugin->opts->timeout,
    );
  } elsif(defined($Plugin->opts->privkey)) {
    ($Session,$Error) = Net::SNMP->session(
      -version      => $Plugin->opts->snmp_version,
      -hostname     => $Plugin->opts->hostname,
      -username     => $Plugin->opts->username,
      -privkey      => $Plugin->opts->privkey,
      -privprotocol => $Plugin->opts->privprotocol,
      -timeout      => $Plugin->opts->timeout,
    );
  } elsif(defined($Plugin->opts->privpassword)) {
    ($Session,$Error) = Net::SNMP->session(
      -version      => $Plugin->opts->snmp_version,
      -hostname     => $Plugin->opts->hostname,
      -username     => $Plugin->opts->username,
      -privpassword => $Plugin->opts->privpassword,
      -privprotocol => $Plugin->opts->privprotocol,
      -timeout      => $Plugin->opts->timeout,
    );
  } else {
  $Error = qq|SNMP credentials incomplete|;
  }
} else {
  $Error = qq|SNMP version unknown|;
}
 
unless(defined $Session) {
  $Plugin->plugin_exit(UNKNOWN,$Error);
}

$Session->max_msg_size(8192);
 
############################################################
# Get list of devices

$Result = $Session->get_table(-baseoid => '1.3.6.1.4.1.2606.7.4.1.2.1');

unless(defined $Result) {
  $Error = $Session->error();
  $Session->close();
  $Plugin->plugin_exit(UNKNOWN,$Error);
}

my $Devices;

for(my $Ix = 1; $Ix <= 99; $Ix++) {
  my $DevName = $Result->{'1.3.6.1.4.1.2606.7.4.1.2.1.2.'.$Ix};
  last unless(defined $DevName);

  $Devices->{$Ix}->{'DevName'}     = $DevName;
  $Devices->{$Ix}->{'DevAlias'}    = $Result->{'1.3.6.1.4.1.2606.7.4.1.2.1.3.'.$Ix};
  $Devices->{$Ix}->{'DevType'}     = $Result->{'1.3.6.1.4.1.2606.7.4.1.2.1.4.'.$Ix};
  $Devices->{$Ix}->{'DevArtNr'}    = $Result->{'1.3.6.1.4.1.2606.7.4.1.2.1.7.'.$Ix};
  $Devices->{$Ix}->{'DevLocation'} = $Result->{'1.3.6.1.4.1.2606.7.4.1.2.1.8.'.$Ix};
  $Devices->{$Ix}->{'DevSerial'}   = $Result->{'1.3.6.1.4.1.2606.7.4.1.2.1.13.'.$Ix};
}

($Plugin->opts->verbose >= 1) and print Dumper($Devices);

# get count of devices attached
my $DevCount = keys(%$Devices);

# query all devices unless certain ID specified
my $DevIdent = defined($Plugin->opts->device_id) ? $Plugin->opts->device_id : 0;

# check if requested device is available
if($DevIdent > $DevCount) {
  $Session->close();
  $Plugin->plugin_exit(UNKNOWN,"Device $DevIdent is not available");
}

############################################################
# Process devices

$Result = $Session->get_table(-baseoid => '1.3.6.1.4.1.2606.7.4.2.2.1');

unless(defined $Result) {
  $Error = $Session->error();
  $Session->close();
  $Plugin->plugin_exit(UNKNOWN,$Error);
}

my $ok_msg;

for(my $Ix = 1; $Ix <= $DevCount; $Ix++) {
  # query just this device or all devices?
  next if(($DevIdent > 0)&& ($DevIdent != $Ix));

       if($Devices->{$Ix}->{'DevArtNr'} eq '343069') {
    $ok_msg = ProcessPDUController($Plugin,$Result,$Ix);
  } elsif($Devices->{$Ix}->{'DevArtNr'} eq '7979202') {
    $ok_msg = ProcessPDUMeter1Phase($Plugin,$Result,$Ix);
  } elsif($Devices->{$Ix}->{'DevArtNr'} eq '7955.232') {
    $ok_msg = ProcessPDUMeter3Phase($Plugin,$Result,$Ix);
  } elsif($Devices->{$Ix}->{'DevArtNr'} eq '7030.010') {
    $ok_msg = ProcessCMCIIIPUCompact($Plugin,$Result,$Ix);
  } elsif($Devices->{$Ix}->{'DevArtNr'} eq '7030.110') {
    $ok_msg = ProcessCMCIIITmpSensor($Plugin,$Result,$Ix);
  } elsif($Devices->{$Ix}->{'DevArtNr'} eq '7030.111') {
    $ok_msg = ProcessCMCIIIHumSensor($Plugin,$Result,$Ix);
  } elsif($Devices->{$Ix}->{'DevArtNr'} eq '7979713') {
    $ok_msg = ProcessRCMInline($Plugin,$Result,$Ix);
  } elsif($Devices->{$Ix}->{'DevArtNr'} eq '7979714') {
    $ok_msg = ProcessRCMInline($Plugin,$Result,$Ix);
  } else {
    # rest without a clue
    $ok_msg = qq|Unsupported device $Ix ($Devices->{$Ix}->{'DevName'}, $Devices->{$Ix}->{'DevArtNr'})|;
  }
}

# SNMP query done
$Session->close();

############################################################
# output Results

my($code,$msgs) = $Plugin->check_messages();

if($code != OK) {
  $Plugin->plugin_exit($code,$msgs);
}

$Plugin->plugin_exit(OK, $ok_msg);

############################################################
sub ProcessPDUController($$$) {
  my($Plugin,$Result,$Ix) = @_ or return(undef);

  ($Plugin->opts->verbose >= 2) and print qq|ProcessPDUController: $Ix\n|;

  # Input.Status (just informational yet)
  my $InputDescName = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.1'};
  my $InputStatus   = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.5'};

  # Output.Status (just informational yet)
  my $OutputDescName = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.7'};
  my $OutputStatus   = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.10'};

  # System Health.Temperature
  my $SystemHealthTemperatureErrorInfo = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.21'};
  my $SystemHealthTemperatureStatus    = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.22'};
  
  if($SystemHealthTemperatureStatus ne 'OK') {
    $Plugin->add_message(WARNING, $SystemHealthTemperatureErrorInfo);
  }
  
  # System Health.Current
  my $SystemHealthCurrentErrorInfo = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.26'};
  my $SystemHealthCurrentStatus    = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.27'};
  
  if($SystemHealthCurrentStatus ne 'OK') {
    $Plugin->add_message(WARNING, $SystemHealthCurrentErrorInfo);
  }
  
  # System Health.Supply
  my $SystemHealthSupplyErrorInfo = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.30'};
  my $SystemHealthSupplyStatus    = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.31'};

  if($SystemHealthSupplyStatus ne 'OK') {
    $Plugin->add_message(WARNING, $SystemHealthSupplyErrorInfo);
  }

  my $ok_msg = 'healthy';
  return('PDU-Controller '.$ok_msg);
}
############################################################
sub ProcessPDUMeter1Phase($$$) {
  my($Plugin,$Result,$Ix) = @_ or return(undef);

  ($Plugin->opts->verbose >= 2) and print qq|ProcessPDUMeter1Phase: $Ix\n|;

  # Total.Frequency
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.1');
  
  # Total.Neutral Current
  ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.3');
  my $TotalNeutralCurrentStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.9'};
  
  if($TotalNeutralCurrentStatus ne 'OK') {
    $Plugin->add_message(WARNING, $TotalNeutralCurrentStatus);
  }
  
  # Total.Power.Active
  my $ok_msg = ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.12');
  my $TotalPowerActiveStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.18'};
  
  if($TotalPowerActiveStatus ne 'OK') {
    $Plugin->add_message(WARNING, $TotalPowerActiveStatus);
  }
  
  # Total.Energy.Active
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.20');
  
  # Total.Energy.Active.Runtime
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.21');
  
  # Phase L1.Voltage
  ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.26');
  # Phase L1.Current
  ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.36');
  # Phase L1.Power.Factor
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.44');
  # Phase L1.Power.Active
  ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.46');
  # Phase L1.Power.Reactive
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.54');
  # Phase L1.Power.Apparent
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.55');
  # Phase L1.Energy.Active
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.56');
  # Phase L1.Energy.Apparent
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.58');

  # Phase L1.Voltage.Status
  my $PhaseVoltageStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.32'};
  if($PhaseVoltageStatus ne 'OK') {
    $Plugin->add_message(WARNING, qq|L1: $PhaseVoltageStatus|);
  }

  # Phase L1.Current.Status
  my $PhaseCurrentStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.42'};
  if($PhaseCurrentStatus ne 'OK') {
    $Plugin->add_message(WARNING, qq|L1: $PhaseCurrentStatus|);
  }

  # Phase L1.Power.Active.Status
  my $PhasePowerActiveStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.52'};
  if($PhasePowerActiveStatus ne 'OK') {
    $Plugin->add_message(WARNING, qq|L1: $PhasePowerActiveStatus|);
  }

  return('PDU-Meter '.$ok_msg);
}
############################################################
sub ProcessPDUMeter3Phase($$$) {
  my($Plugin,$Result,$Ix) = @_ or return(undef);

  ($Plugin->opts->verbose >= 2) and print qq|ProcessPDUMeter3Phase: $Ix\n|;

  # Unit.Frequency
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.1');
  
  # Unit.Neutral Current
  ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.3');
  my $UnitNeutralCurrentStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.9'};
  
  if($UnitNeutralCurrentStatus ne 'OK') {
    $Plugin->add_message(WARNING, $UnitNeutralCurrentStatus);
  }
  
  # Unit.Power.Active
  my $ok_msg = ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.12');
  my $UnitPowerActiveStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.18'};
  
  if($UnitPowerActiveStatus ne 'OK') {
    $Plugin->add_message(WARNING, $UnitPowerActiveStatus);
  }
  
  # Unit.Energy.Active
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.20');
  
  # Unit.Energy.Active.Runtime
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.21');
  
  # Phases L1...L3
  for(my $Lx = 1; $Lx <= 3; $Lx++) {
  
    # OID base:
    my $bx = '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix;
    # OID offset:
    # L1 values start at OID '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.25'
    # L2 values start at OID '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.60'
    # L3 values start at OID '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.95'
    my $ox = ($Lx - 1) * 33 + 25;
  
    # Phase Lx.Voltage
    ProcessVariableWithThresholds($Plugin,$Result,sprintf("%s.%u",$bx,$ox+ 1)); #26
    # Phase Lx.Current
    ProcessVariableWithThresholds($Plugin,$Result,sprintf("%s.%u",$bx,$ox+10)); #35
    # Phase Lx.Power.Factor
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+18)); #43
    # Phase Lx.Power.Active
    ProcessVariableWithThresholds($Plugin,$Result,sprintf("%s.%u",$bx,$ox+20)); #45
    # Phase Lx.Power.Reactive
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+28)); #53
    # Phase Lx.Power.Apparent
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+29)); #54
    # Phase Lx.Energy.Active
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+30)); #55
    # Phase Lx.Energy.Apparent
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+32)); #57
  
    # Phase Lx.Voltage.Status
    my $PhaseVoltageStatus = $Result->{sprintf("%s.%u",$bx,$ox+ 7)}; # 32
    if($PhaseVoltageStatus ne 'OK') {
      $Plugin->add_message(WARNING, qq|L$Lx: $PhaseVoltageStatus|);
    }
  
    # Phase Lx.Current.Status
    my $PhaseCurrentStatus = $Result->{sprintf("%s.%u",$bx,$ox+16)}; # 41
    if($PhaseCurrentStatus ne 'OK') {
      $Plugin->add_message(WARNING, qq|L$Lx: $PhaseCurrentStatus|);
    }
  
    # Phase Lx.Power.Active.Status
    my $PhasePowerActiveStatus = $Result->{sprintf("%s.%u",$bx,$ox+26)}; # 51
    if($PhasePowerActiveStatus ne 'OK') {
      $Plugin->add_message(WARNING, qq|L$Lx: $PhasePowerActiveStatus|);
    }
  }
  return('PDU-Meter '.$ok_msg);
  
}
############################################################
sub ProcessRCMInline($$$) {
  my($Plugin,$Result,$Ix) = @_ or return(undef);
  
  ($Plugin->opts->verbose >= 2) and print qq|ProcessRCMInline: $Ix\n|;

  # Total.Frequency
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.1');
  
  # Total.Neutral Current
  ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.3');
  my $TotalNeutralCurrentStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.9'};
  
  if($TotalNeutralCurrentStatus ne 'OK') {
    $Plugin->add_message(WARNING, $TotalNeutralCurrentStatus);
  }
  
  # Total.Power.Active
  my $ok_msg = ProcessVariableWithThresholds($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.12');
  my $TotalPowerActiveStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.18'};
  
  if($TotalPowerActiveStatus ne 'OK') {
    $Plugin->add_message(WARNING, $TotalPowerActiveStatus);
  }
  
  # Total.Energy.Active
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.20');
  
  # Total.Energy.Active.Runtime
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.3.'.$Ix.'.21');
  
  # Phases L1...L3
  for(my $Lx = 1; $Lx <= 3; $Lx++) {
  
    # OID base:
    my $bx = '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix;
    # OID offset:
    # L1 values start at OID '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.25'
    # L2 values start at OID '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.60'
    # L3 values start at OID '1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.95'
    my $ox = ($Lx - 1) * 35 + 25;
  
    # Phase Lx.Voltage
    ProcessVariableWithThresholds($Plugin,$Result,sprintf("%s.%u",$bx,$ox+ 1)); #26
    # Phase Lx.Voltage.THD
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+ 9)); #34
    # Phase Lx.Current
    ProcessVariableWithThresholds($Plugin,$Result,sprintf("%s.%u",$bx,$ox+11)); #36
    # Phase Lx.Current.THD
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+19)); #44
    # Phase Lx.Power.Factor
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+20)); #45
    # Phase Lx.Power.Active
    ProcessVariableWithThresholds($Plugin,$Result,sprintf("%s.%u",$bx,$ox+22)); #47
    # Phase Lx.Power.Reactive
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+30)); #55
    # Phase Lx.Power.Apparent
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+31)); #56
    # Phase Lx.Energy.Active
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+32)); #57
    # Phase Lx.Energy.Apparent
    ProcessVariable($Plugin,$Result,sprintf("%s.%u",$bx,$ox+34)); #59
  
    # Phase Lx.Voltage.Status
    my $PhaseVoltageStatus = $Result->{sprintf("%s.%u",$bx,$ox+ 7)}; # 32
    if($PhaseVoltageStatus ne 'OK') {
      $Plugin->add_message(WARNING, qq|L$Lx: $PhaseVoltageStatus|);
    }
  
    # Phase Lx.Current.Status
    my $PhaseCurrentStatus = $Result->{sprintf("%s.%u",$bx,$ox+17)}; # 42
    if($PhaseCurrentStatus ne 'OK') {
      $Plugin->add_message(WARNING, qq|L$Lx: $PhaseCurrentStatus|);
    }
  
    # Phase Lx.Power.Active.Status
    my $PhasePowerActiveStatus = $Result->{sprintf("%s.%u",$bx,$ox+28)}; # 53
    if($PhasePowerActiveStatus ne 'OK') {
      $Plugin->add_message(WARNING, qq|L$Lx: $PhasePowerActiveStatus|);
    }
  }
  
  ############################################################
  # Process section "RCM 01"
  
  # RCMs.RCM 01.General.Status
  my $RCMsRCM01GeneralStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.134'};
  if($RCMsRCM01GeneralStatus ne 'OK') {
    $Plugin->add_message(WARNING, qq|RCM01 General-Status: $RCMsRCM01GeneralStatus|);
  }
  
  # RCMs.RCM 01.AC
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.137');
  # RCMs.RCM 01.AC.Status
  my $RCMsRCM01ACStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.141'};
  
  if($RCMsRCM01ACStatus ne 'OK') {
    $Plugin->add_message(WARNING, qq|RCM01 AC-Status: $RCMsRCM01ACStatus|);
  }
  
  # RCMs.RCM 01.DC
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.144');
  # RCMs.RCM 01.DC.Status
  my $RCMsRCM01DCStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.148'};
  
  if($RCMsRCM01DCStatus ne 'OK') {
    $Plugin->add_message(WARNING, qq|RCM01 DC-Status: $RCMsRCM01DCStatus|);
  }

  return('RCM-Inline-Meter '.$ok_msg);
}
############################################################
sub ProcessCMCIIIPUCompact($$$) {
  my($Plugin,$Result,$Ix) = @_ or return(undef);

  ($Plugin->opts->verbose >= 2) and print qq|ProcessCMCIIIPUCompact: $Ix\n|;

  # Temperature
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.2');
  my $TemperatureStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.9'};
  
  if($TemperatureStatus ne 'OK') {
    $Plugin->add_message(WARNING, $TemperatureStatus);
  }

  # System.Temperature
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.54');
  my $SystemTemperatureStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.61'};
  
  if($SystemTemperatureStatus ne 'OK') {
    $Plugin->add_message(WARNING, $SystemTemperatureStatus);
  }

  # System.Supply 24V
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.64');
  my $SystemSupply24VStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.70'};
  
  if($SystemSupply24VStatus ne 'OK') {
    $Plugin->add_message(WARNING, $SystemSupply24VStatus);
  }

  # System.Supply 5V
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.73');
  my $SystemSupply5VStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.79'};
  
  if($SystemSupply5VStatus ne 'OK') {
    $Plugin->add_message(WARNING, $SystemSupply5VStatus);
  }

  # System.Supply 3V3
  ProcessVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.82');
  my $SystemSupply3V3Status = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.88'};
  
  if($SystemSupply3V3Status ne 'OK') {
    $Plugin->add_message(WARNING, $SystemSupply3V3Status);
  }

  # Webcam
  my $SystemWebcamStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.104'};
  
  if($SystemWebcamStatus ne 'OK') {
    $Plugin->add_message(WARNING, $SystemWebcamStatus);
  }

  my $ok_msg = ' ';
  return('CMCIII-PU '.$ok_msg);
}
############################################################
sub ProcessCMCIIITmpSensor($$$) {
  my($Plugin,$Result,$Ix) = @_ or return(undef);

  ($Plugin->opts->verbose >= 2) and print qq|ProcessCMCIIITmpSensor: $Ix\n|;

  # Temperature
  my $ok_msg = ProcessCMCVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.2');
  my $TemperatureStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.9'};
  
  if($TemperatureStatus ne 'OK') {
    $Plugin->add_message(WARNING, $TemperatureStatus);
  }

  return('CMCIII-TMP '.$ok_msg);
}
############################################################
sub ProcessCMCIIIHumSensor($$$) {
  my($Plugin,$Result,$Ix) = @_ or return(undef);

  ($Plugin->opts->verbose >= 2) and print qq|ProcessCMCIIIHumSensor: $Ix\n|;

  # Temperature
  my $ok_msg = ProcessCMCVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.2');
  my $TemperatureStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.9'};
  
  if($TemperatureStatus ne 'OK') {
    $Plugin->add_message(WARNING, $TemperatureStatus);
  }

  # Humidity
  ProcessCMCVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.12');
  my $HumidityStatus = $Result->{'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.19'};
  
  if($HumidityStatus ne 'OK') {
    $Plugin->add_message(WARNING, $HumidityStatus);
  }

  # Dew Point
  ProcessCMCVariable($Plugin,$Result,'1.3.6.1.4.1.2606.7.4.2.2.1.10.'.$Ix.'.22');

  return('CMCIII-HUM '.$ok_msg);
}
############################################################
sub ProcessCMCVariable($$$) {
  my($Plugin,$Result,$SubOID) = @_ or return(undef);

  # the variable itself
  my($label,$uom,$value,$min,$max) = ProcessVariableValue($Result,$SubOID);

  # replace spaces with underlines
  $uom =~ s/ /\_/g;

  # put all this together into a perfdata item
  # label=value[uom];;;[min];[max]
  $Plugin->add_perfdata(
    label => $label,
    value => $value,
    uom   => $uom,
    min   => $min/100,
    max   => $max/100
  );

  return(qq|$label is $value $uom|);
}
############################################################
sub ProcessVariable($$$) {
  my($Plugin,$Result,$SubOID) = @_ or return(undef);

  # the variable itself
  my($label,$uom,$value,$min,$max) = ProcessVariableValue($Result,$SubOID);

  # put all this together into a perfdata item
  # label=value[uom];;;[min];[max]
  $Plugin->add_perfdata(
    label => $label,
    value => $value,
    uom   => $uom,
    min   => $min,
    max   => $max
  );

  return(qq|$label is $value $uom|);
}
############################################################
sub ProcessVariableWithThresholds($$$) {
  my($Plugin,$Result,$SubOID) = @_ or return(undef);

  # the variable itself
  my($label,$uom,$value,$min,$max) = ProcessVariableValue($Result,$SubOID);

  # critical high
  $SubOID = OID_up($SubOID);
  my($ch_label,$ch_uom,$ch_value,$ch_min,$ch_max) = ProcessVariableValue($Result,$SubOID);

  # warning high
  $SubOID = OID_up($SubOID);
  my($wh_label,$wh_uom,$wh_value,$wh_min,$wh_max) = ProcessVariableValue($Result,$SubOID);

  # warning low
  $SubOID = OID_up($SubOID);
  my($wl_label,$wl_uom,$wl_value,$wl_min,$wl_max) = ProcessVariableValue($Result,$SubOID);

  # critical low
  $SubOID = OID_up($SubOID);
  my($cl_label,$cl_uom,$cl_value,$cl_min,$cl_max) = ProcessVariableValue($Result,$SubOID);

  my $warning  = "$wl_value:$wh_value";
  my $critical = "$cl_value:$ch_value";

  # put all this together into a perfdata item
  # label=value[uom];[warn];[crit];[min];[max]
  $Plugin->add_perfdata(
    label    => $label,
    value    => $value,
    uom      => $uom,
    warning  => $warning,
    critical => $critical,
    min      => $min,
    max      => $max
  );

  return(qq|$label is $value $uom|);
}
############################################################
sub ProcessVariableValue($$) {
  my($Result,$SubOID) = @_ or return(undef);

  my($oid,@list);

  # get cmcIIIVarName
  @list = split(/\./,$SubOID); $list[12] = 3; $oid = join('.',@list);
  my $label = $Result->{$oid};

  # replace dots with spaces
  $label =~ s/\./ /g;
  # remove leading 'Phase '
  $label =~ s/^Phase //;
  # remove trailing ' Value'
  $label =~ s/ Value$//;
  # replace spaces with underlines
  $label =~ s/ /\_/g;

  # get cmcIIIVarUnit
  @list = split(/\./,$SubOID); $list[12] = 5; $oid = join('.',@list);
  my $uom = $Result->{$oid};

  # get cmcIIIVarScale
  @list = split(/\./,$SubOID); $list[12] = 7; $oid = join('.',@list);
  my $scale = $Result->{$oid};

  # get cmcIIIVarConstraints
  @list = split(/\./,$SubOID); $list[12] = 8; $oid = join('.',@list);
  my $constraints = $Result->{$oid};

  # get cmcIIIVarSteps
  @list = split(/\./,$SubOID); $list[12] = 9; $oid = join('.',@list);
  my $steps = $Result->{$oid};

  # get cmcIIIVarValueInt
  @list = split(/\./,$SubOID); $list[12] = 11; $oid = join('.',@list);
  my $value = $Result->{$oid};

  # do value scaling
  $value = ($scale < 0) ? $value / abs($scale) : $value * $scale;

  # get constraints
  my($min,$max) = ProcessVariableConstraints($constraints);

  return($label,$uom,$value,$min,$max);
}
############################################################
sub ProcessVariableConstraints($) {
  my $string = shift(@_) or return(undef);

  # the string presented by RCM looks like this:
  # "integer: min 0, max 2000000000, scale /10, step 1"
  #
  # for now, we want to extract 'min' and 'max' values

  my $min = '';
  my $max = '';

  # first remove ':' and ','
  $string =~ s/:|,//g;

  # split remaining items into list
  my @items = split(/ /,$string);

  # extract min and max values
  for(my $i = 0; $i < @items; $i++) {
    $min = $items[$i+1] if($items[$i] eq 'min');
    $max = $items[$i+1] if($items[$i] eq 'max');
  }

  return($min,$max);
}
############################################################
sub OID_up($) {
  my($oid) = shift(@_) or return(undef);

  my @list = split('\.',$oid);
  my $ix = pop(@list); $ix++; push(@list,$ix);

  $oid = join('.',@list);

  return($oid);
}
############################################################
1;
