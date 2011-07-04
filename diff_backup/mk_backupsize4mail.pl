#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  mk_backupsize_mail.pl
#
#===============================================================================

use strict;
use warnings;
use Getopt::Long;

# ------ Version -------------------------------

my $RCSVersion='$Revision$';
$RCSVersion=~s/^[^0-9]*([0-9]+\.[0-9]+).*$/$1/;

# ------ Versionsdatum -------------------------

my $RCSDate='$Date$';
$RCSDate=~s/^[^0-9]*(.+)\s*\$$/$1/;

my $version = '1.0.0';

my ($log_file, $subject, $mail_adress, $G_debug);

my $prog_name = 'my_backupsize4mail.pl';

GetOptions(
	   'verbose',
	   'l|logfile=s' => \$log_file,
	   's|subject=s' => \$subject,
	   'm|mailadr=s' => \$mail_adress,
	   'debug'       => sub{$G_debug = 1},
	   'v|version'   => sub{print "\n$prog_name Version: $version ($RCSDate)\n\n"; exit},
	   'h|help|?'    => \&usage,
	  );

print "Args:\nsubject:'$subject'\nlog_file:'$log_file'\nmail_adress:'$mail_adress'\n\n" 
  if $G_debug;

if($log_file eq '')  {
  warn "Das Logfile fehlt!";
  usage();
}

if($subject eq '')  {
  warn "Das Mail Subject fehlt!";
  usage();
}

if($mail_adress eq '')  {
  warn "Die Mailadresse fehlt!";
  usage();
}


main();

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

sub main{
  my $file = $log_file;
  open FH, $file 
    or die "$! err open file '$file'\n";

  while (<FH>){
    chomp;
    last if(/^Backupfile/);
  }    

  my $line = <FH>; 
  $line =~ /^\s*(\d+)(.) /;

  $subject .= " ($1 $2)";

  print "Size: $1 $2\nsubject: $subject\n" if $G_debug;

  my $cmd = "cat $log_file | mail -s \"$subject\" $mail_adress";
  print "cmd: $cmd\n";

  my $ret = `$cmd`;
}

sub usage {
  my (%data) = @_;

  my $exit_value = $data{exit_value} || 0;

  print <<END;

usage:

$prog_name

-l, --logfile file        -Logfile
-s, --subject text        -Subject Statusmail
-m, --mailadr adress      -Adresse fuer die Statusmail 
[-v  --version]           -Programmversion ausgeben
[-h  --help]              -Hilfe

END

  exit $exit_value;
}

