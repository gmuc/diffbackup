#---------------------------------------------------------------------------------------------------
# $Id$
# $URL$
# $Author$
# $Revision$
# $Date$
#---------------------------------------------------------------------------------------------------

package BaseHelper;

use strict;
use warnings;
use Carp;

use vars qw($VERSION @ISA @EXPORT_OK @EXPORT %EXPORT_TAGS);

use Exporter;
use Config::General;
use Mail::Mailer;

our ($usage_text);

@ISA = qw(Exporter);
@EXPORT_OK = qw(get_config usage do_sh_cmd print_or_log die_or_logdie warn_or_logwarn defaultvalue getDate_ddmmyyyy send_email);

$VERSION="0.02";

#---------------------------------------------------------------------------------------------------
# function: do_sh_cmd
#
# description:
#
# Execute shell on command. 
# ATTENTION: Don't use more than ONE shell command, to prevent mysterious programm behavior!!!
#
# Interface
#    
# Input (O = optional)
# 1. \%args - Hash of parameternames & paramvalues
#               sh_cmd        - command string for execution
#               die_on_error - boolean flag whether die prgramm on error     (default: yes)
#               debug        - boolean flag whether print debug output       (default: no)  
#               log_level    - Loglevel for log4perl logger                  (default: debug)
#               noaction     - boolean flag whether execute sh-command       (default: no)
#               success      - value of successstatus OR array ref of values (default: 0)
#
# Output 
# 1. $ - status of sh-command
# 2. $ - return output of sh-command
#---------------------------------------------------------------------------------------------------
sub do_sh_cmd {
  my (%args) = @_;

  # defaultvalues for subroutins parameters
  defaultvalue(\%args,'die_on_error',1);
  defaultvalue(\%args,'debug',0);
  defaultvalue(\%args,'log_level','debug');
  defaultvalue(\%args,'noaction',0);
  defaultvalue(\%args,'err_output',1);
  defaultvalue(\%args,'handle_stderr','2>&1');

  my $success = defaultvalue(\%args,'success',0); # state value of $cmd on success
  my $logger  = defaultvalue(\%args,'logger',0);

  # ??? print debug-output ???
  if($args{debug}){
    print_or_log("doShCmd:\n$args{sh_cmd}\n\n",$logger,$args{log_level});
  }

  # ??? no execute of sh-command ???
  if($args{noaction}) {
    return undef,"";
  }

  # execute command and extract returnstatus
  my $ret = `$args{sh_cmd} $args{handle_stderr}`;
  my $status = $? >> 8;

  my $error_occur = 0;
  if(ref $success eq 'ARRAY'){
    $error_occur = 1;

    for my $success_value (@$success){
      if($status eq $success_value){
	$error_occur = 0;
	last;
      }
    }
  }
  elsif($status ne $success){
    $error_occur = 1;
  }

  # ??? sh-command status is not successful ???
  if($error_occur) {

    my $work_dir = `pwd`;

    my $msg =<<END;
do_sh_cmd Error!!!\n\n
Command:\n$args{sh_cmd}\n\n
Workdir: $work_dir\n\n
Script: $0\n\n
Command Output:\n$ret\n\n
Command Status:$status\n\n
END

    # ??? die on Error ??? 
    if($args{die_on_error}){
      die_or_logdie($msg, $logger, $args{log_level});
    }
    elsif($args{err_output}){
      warn_or_logwarn($msg, $logger, $args{log_level});
    }
  }

  # ??? prevent perl warnings on undefinied values ???
  if(!defined $ret){
    $ret = '';
  }

  if(wantarray()){
    return $status,$ret;
  }
  else{
    return $status;
  }
}

#---------------------------------------------------------------------------------------------------
# function: print_or_log
#
# description:
#
# Output message by print or $logger->info or $logger->debug.
#
# Interface
#    
# Input (O = optional)
# 1. $msg           - output message
# 2. $logger (O)    - used Log4perl logger
# 3. $log_level (O) - logger loglevel 
#                     default: debug
#
# Output 
# none
#---------------------------------------------------------------------------------------------------
sub print_or_log{
  my $msg = shift;
  my $logger = shift || 0;
  my $log_level = shift || 'debug';

  if(!defined $msg or $msg eq ''){
    my $sub_name = (caller(0))[3];
    confess "$sub_name: msg is required parameter";
  }

  if($logger){
    if($log_level eq 'info'){
      $logger->info($msg);
    }
    else{
      $logger->debug($msg);
    }
  }
  else{
    print $msg;
  }
}

#---------------------------------------------------------------------------------------------------
# function: die_or_logdie
#
# description:
#
# Output message by die or $logger->logdie or confess
#
# Interface
#    
# Input (O = optional)
# 1. $msg           - output message
# 2. $logger (O)    - used Log4perl logger
# 3. $mode (O)      - mode for output if no logger is used 
#                     default: die
#                     die = output by die
#                     croak = output by croak
#
# Output 
# none
#---------------------------------------------------------------------------------------------------
sub die_or_logdie{
  my $msg = shift;
  my $logger = shift || 0;
  my $mode = shift || 'die';

  if(!defined $msg or $msg eq ''){
    my $sub_name = (caller(0))[3];
    confess "$sub_name: msg is required parameter";
  }

  if($logger){
    $logger->logdie($msg);
  }
  elsif($mode eq 'confess'){
    croak $msg;
  }
  else{
    die $msg;
  }
}

#---------------------------------------------------------------------------------------------------
# function: warn_or_logwarn
#
# description:
#
# Output message by warn or $logger->warn or carp
#
# Interface
#    
# Input (O = optional)
# 1. $msg           - output message
# 2. $logger (O)    - used Log4perl logger
# 3. $mode (O)      - mode for output if no logger is used 
#                     default: die
#                     warn = output by warn
#                     carp = output by carp
#
# Output 
# none
#---------------------------------------------------------------------------------------------------
sub warn_or_logwarn{
  my $msg = shift;
  my $logger = shift;
  my $mode = shift || 'warn';

  if(!defined $msg or $msg eq ''){
    my $sub_name = (caller(0))[3];
    confess "$sub_name: msg is required parameter";
  }

  if($logger){
    $logger->warn($msg);
  }
  elsif($mode eq 'carp'){
    carp $msg;
  }
  else{
    warn $msg;
  }
}

#---------------------------------------------------------------------------------------------------
# function: defaultvalue
#
# description:
#
# Set a default value if hash entry has no content.
#
# Interface
#    
# Input (O = optional)
# 1. \%hash - Hash of parameternames & paramvalues
# 2. $key   - Key of inspecting value
# 3. $defaultvalue - default value if hash entry has no content
#
# Output 
# 1. $ - current value of hash entry
#---------------------------------------------------------------------------------------------------
sub defaultvalue{
  my ($hash,$key,$defaultvalue) = @_;

  if(!defined $hash or ref $hash ne 'HASH'){
    my $sub_name = (caller(0))[3];
    confess "$sub_name: hash is required parameter. Please use a hash ref!";
  }

  if(!defined $key or $key eq ''){
    my $sub_name = (caller(0))[3];
    confess "$sub_name: key is required parameter!";
  }

  if(!defined $defaultvalue or $defaultvalue eq ''){
    $defaultvalue = '';
  }

  #??? hash entry has no content ???
  if(!exists $hash->{$key} or 
     !defined($hash->{$key}) or
     $hash->{$key} eq ''){

    $hash->{$key} = $defaultvalue;
  }

  return $hash->{$key};
}

#---------------------------------------------------------------------------------------------------
# function: usage
#
# description:
#
# Output a usage message for programm
#
# Interface
#    
# Input (O = optional)
# 1. \%args - Hash of parameternames & paramvalues
#               mode - mode of processing
#                      noexit = don't exit on subroutins end
#
# Output 
# none
#---------------------------------------------------------------------------------------------------
sub usage {
  my (%args) = @_;

  my $exit_value = $args{exit_value} || 0;
  my $mode       = $args{mode} || 'exit';

  print $usage_text;

  if($mode eq 'noexit'){
    return;
  }
  else{
    exit $exit_value;
  }
}

#---------------------------------------------------------------------------------------------------
# function: check_sub_required_params
#
# description:
#
# Check if all required params are assigned to subroutine
#
# Interface
#    
# Input (O = optional)
# 1. \%required_params - Hash of parameternames & paramvalues
# 2. $err_nr           - Errornumber of current parameter
# 3. $logger           - current used Log4perl logger to log errors
#
# Output 
# 1. $ - boolean flag whether all ok or not
#---------------------------------------------------------------------------------------------------

sub check_sub_required_params{
  my (%args) = @_;

  if(!exists $args{required_params} or 
     !defined $args{required_params} or 
     ref $args{required_params} ne 'HASH'){

    my $sub_name = (caller(0))[3];
    confess "$sub_name: required_params is required parameter. Please use a hash ref!";
  }

  defaultvalue(\%args,'err_nr','');
  defaultvalue(\%args,'logger',0);

  if($args{err_nr}){
    $args{err_nr} .= ':';
  }

  my $sub_name = (caller(1))[3];

  my %required_params = %{$args{required_params}};

  # checking required parameters
  foreach my $param_name (keys %required_params){

    if(!defined $required_params{$param_name} or $required_params{$param_name} eq ''){
      
      warn_or_logwarn("$args{err_nr}Parameter '$param_name' in subroutine '$sub_name' is required!",$args{logger}); 

      return 0;
    }
  }

  return 1;
}

#---------------------------------------------------------------------------------------------------
# function: defaultvaues
#
# description:
#
# Init all members of $args with default values from %default_values, if the $args key in %default_values
#
# Interface
#    
# Input (O = optional)
# 1. \%args          - Hash of parameternames & paramvalues
# 2. %default_values - Hash of parameter default values
#
# Output 
# none
#---------------------------------------------------------------------------------------------------

sub defaultvaues{
  my ($args,%default_values) = @_;

  foreach my $param_name (keys %default_values){

    defaultvalue($args,$param_name,$default_values{$param_name});
  }
}

#---------------------------------------------------------------------------------------------------
# function: get_config
#
# description:
#
# Get config from a Config::General config file
#
# Interface
#    
# Input (O = optional)
# 1. \%args - Hash of parameternames & paramvalues
#             config_file            - name of configfile
#             debug                  - output all read config values
#                                      1 = output data, 0 = don't output data (default value)
#             log_level              - log4perl Loglevel for print_or_log output
#             required_param_err_txt - error text if miss required parameter
#             undef_params_defaults  - $% hash with default params if config values undef
#             missing_params_err_txt - errortext if required params missing
#             required_config_param  - $@ list of required params
#
#             Config::General parameters see man page
#             InterPolateVars        default = 1
#             MergeDuplicateOptions  default = 1
#             MergeDuplicateBlocks   default = 1
#
# Output 
# 1. \%config_data - config data
#                    on error return undef
#---------------------------------------------------------------------------------------------------

sub get_config {
  my (%args) = @_;

  # defaultvalues for subroutins parameters
  defaultvaues(\%args,('debug'                  => 0,
		       'log_level'              => 'debug',
		       'required_param_err_txt' => 'Error: get_config',
		       'InterPolateVars'        => 1,
		       'MergeDuplicateOptions'  => 1,
		       'MergeDuplicateBlocks'   => 1,
		       'init_undef_params'      => 1,
		       'undef_params_defaults'  => {},
		       'missing_params_err_txt' => '',
		       'required_config_param'  => [])
	      );

  my $logger = defaultvalue(\%args,'logger',0);

  if(!check_sub_required_params( 
				required_params => { config_file => $args{config_file} },
			       )
    ){

    return;
  }

  my $config_file = shift;

  my $conf = new Config::General(
				 -ConfigFile            => $args{config_file},
				 -InterPolateVars       => $args{InterPolateVars},
				 -MergeDuplicateOptions => $args{MergeDuplicateOptions},
				 -MergeDuplicateBlocks  => $args{MergeDuplicateBlocks},
				);

  my %config_data = $conf->getall;
    

  # ------ check for required parameters
  my @missing_params;
  my @required_config_param = @{$args{required_config_param}};

  foreach my $param_name (@required_config_param){

    if(!exists $config_data{$param_name} or $config_data{$param_name} =~ /^\s*$/){
      push @missing_params, $param_name;
    }
  }

  if(@missing_params){
    warn_or_logwarn ("Required parameter missing:\n\n" . eval{join "\n",@missing_params} . $args{missing_params_err_txt});
    return;
  }
  # ------ end

  # ??? init undefined config values ???
  if($args{init_undef_params} == 1){

    # init all undefined config values
    foreach my $param_name (keys %config_data ){

      if(!defined $config_data{$param_name}){

	# ??? can init parameter from default values hash ???
	if(exists $args{undef_params_defaults}->{$param_name}){
	  $config_data{$param_name} = $args{undef_params_defaults}->{$param_name};
	}
	else{ # use defaultinit ''
	  $config_data{$param_name} = '';
	}
      }
    }
  }

  # ??? ist der Baselogger aktiv und ist der Debugmode eingeschalten ???
  # ja: alle Configdaten werden ausgegeben

  if($args{debug}) {
    my $confdata;
    
    foreach (sort keys %config_data) {
      $confdata .= "$_:$config_data{$_}:\n";
    }

    print_or_log("configdata: $confdata",$logger,$args{log_level});
  }

  return \%config_data;
}


#---------------------------------------------------------------------------------------------------
# function: getDate_ddmmyyyy
#
# description:
#
# Get date of current time.
#
# Interface
#    
# Input (O = optional)
# none
#
# Output 
# 1. $ - current date in format ddmmyyyy
#---------------------------------------------------------------------------------------------------

sub getDate_ddmmyyyy {

  my @gentime = localtime(time);

  my $day = $gentime[3];
  $day =~ s/^([0-9])$/0$1/;
  
  my $month = eval {$gentime[4] + 1};
  $month =~ s/^([0-9])$/0$1/;

  return "$day$month" . eval {$gentime[5]+1900};
}

# --------------------------------------------------------------------------------------------------

=head2 Funktion: send_email

=for comment Dokstatus: ok   Version: 1.38

=head3 Beschreibung:

Versenden einer Mail an den Defaultmailserver

=head3 Interface:

=head4 Input (O = optional)

 1. %        - Daten fuer die Versendung der Mail
               Keys:
               from - E-Mail Absender
               to   - E-Mail Empfaenger
               subject     - Subject der Mail
               mailcontent - Content der Mail

=head4 Output

 keiner

=for html <hr/>

=cut


sub send_email {
    my (%data) = @_;

    my $mailserver = $data{mailserver};

#    print("mailserver:'$mailserver'\n" .
#	  "from:'$data{from}'\n" .
#	  "to:'$data{to}'\n" .
#	  "subject:'$data{subject}'\n" .
#	  "mailcontent:'$data{mailcontent}'");

    #my $mailer = new Mail::Mailer 'smtp', Server => $mailserver;
    my $mailer = new Mail::Mailer;

    foreach my $to (split / +/,$data{to}) {
      my %header = (
		    'From' => $data{from},
		    'To' => $to,
		    'Subject' => $data{subject},
		   );

      # ??? konnte der Mailserver korrekt angesprochen werden ???
      if($mailer->open(\%header)) {
	# Versenden der Mail an den Mailserver
	print $mailer $data{mailcontent};
      }
      else {
	die("Mailer (mailserver:'$mailserver') open failed: $!\n");
      }
    }

    $mailer->close;
}


1;

__END__

=pod

=head1 NAME

BaseHelper - Basic helper subroutines for perl programming

=head1 SYNOPSIS

 use BaseHelper('usage','do_sh_cmd');

 my $version = '0.1';

 $BaseHelper::usage_text =<<END;

 usage:

 cp_old_svn.pl
 [-t  --test]           -nur Test, d.h. kein cp o. mkdir wird ausgeführt
 [    --verbose]        -Debugoutput an
 [-v  --version]        -Programmversion ausgeben
 [-h  --help]           -Hilfe

 END

 $cmd = "mkdir -p $dest_dir";

 ($status, $ret) = do_sh_cmd(sh_cmd => $cmd, noaction => $G_noaction);

 ($status, $ret) = do_sh_cmd(sh_cmd => "diff $source $dest", success => [0, 1]);

=head1 DESCRIPTION


=head1 AUTOR

G. Mucha

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2009 by Gerd Mucha

This code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 



