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

my $version = '1.0.2';

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

$DB::single = 1;

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

  $DB::single = 1;

  my $found;
  while (<FH>){
    chomp;
    if(/^Backupfile/){
       $found = 1;
       last;
    }
  }    

  if(not $found){
    print "Pattern 'Backupfile' not found!\n" if $G_debug;
    return;
  }
  
  my $line = <FH>; 
  $line =~ /^\s*(\d+(|\.\d+)[MG]) /;

  if($1){
    $subject .= " ($1)";
  }
  else{
    $subject .= " (???)";
  }

  print "Size: $1\nsubject: $subject\n" if $G_debug;

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
# ------ Doku --------------------------------------------------------------------------------------
# ------ Doku --------------------------------------------------------------------------------------
# ------ Doku --------------------------------------------------------------------------------------

__END__

=pod

=head1 NAME
 
mk_backupsize4mail.pl -l input_log -s subject -m mail_adr
 
 
=head1 VERSION
 
1.0.1
 
 
=head1 SYNOPSIS

mk_backupsize4mail.pl -l /tmp/diffBackup.log -s "diffbackup -ink" -m me@web.com 
  
=head1 DESCRIPTION
 
Ermittelt aus dem Logfile die Größe eines Backups und schickt mit dieser Angabe eine Statusmail.

=head1 AUTHOR
 
G. Mucha
 
 
=head1 LICENCE AND COPYRIGHT
 
Copyright (c) 2011 Gerd Mucha (gerd.devel@gmail.com). All rights reserved.
 
Followed by whatever licence you wish to release it under. 
For Perl code that is often just:
 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

=cut
