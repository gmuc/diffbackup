#!/usr/bin/perl

#---------------------------------------------------------------------------------------------------
# $RCSfile: cp_old_svn.pl,v $                       
# $Revision: 1.4 $                                        
# $Date: 2009/05/13 11:37:43 $                         
# $Author: mucha $                                       
# $Locker: mucha $                                            
#---------------------------------------------------------------------------------------------------


use strict;
use warnings;

use Cwd;

use Getopt::Long;
use BaseHelper('usage','do_sh_cmd');

my $version = '0.1';

$BaseHelper::usage_text =<<END;

usage:

cp_old_svn.pl
-s  --smodul name      -Source Modulname 
-d  --dmodul name      -Dest Modulname 
[-t  --test]           -nur Test, d.h. kein cp o. mkdir wird ausgeführt
[    --debug level]    -Debugoutput Level
[-v  --version]        -Programmversion ausgeben
[-h  --help]           -Hilfe

END

our $G_smodul ='';
our $G_dmodul ='';
our $G_noaction = 0;
our $G_debug_level = 0;

GetOptions(
	   'debug=s'     => \$G_debug_level,
	   't|test'      => sub{$G_noaction = 1}, # einfache und transparente Universal-Variante
	   's|smodul=s'  => \$G_smodul,
	   'd|smodul=s'  => \$G_dmodul,
	   'v|version'   => sub{print "\ncp_old_svn.pl Version: $version\n\n"; exit},
	   'h|help|?'    => \&usage,
	  );

if($G_smodul eq '')  {
  warn "Der Source Modulname in der Kommandozeile fehlt!\n";
  usage();
}

if($G_dmodul eq '')  {
  warn "Der Dest Modulname in der Kommandozeile fehlt!\n";
  usage();
}

my @G_excl_diff_pattern = (
			   "---\n",
			   "(>|<)\\s+(#|\/\/|-+|\\\*|)\\s*(Changed on |Letzte .nderung am : |)\\\$(Id|Header|:Source|Date|Author|Revision|LastChangedDate): .*?\n",
			   "[0-9a-f,]+?\n",
			   "(>|<)\\s+my \\\$(RCSDate|G_RCSDate)=.*?\n",
			  );

main();

exit;

sub main{
  my ($status, $ret, $cmd, $source, $dest);

  if(!-e $G_smodul){
    die "Source Modul '$G_smodul' existiert nicht!\n";
  }

  if(!-e $G_dmodul){
    die "Dest Modul '$G_dmodul' existiert nicht!\n";
  }
  
  my $cur_dir = getcwd();

  my @files = `find . $G_smodul -type f`;

  foreach my $fname (@files) {

    if ($fname =~ /\/(.settings|.svn|CVS)\// or
	$fname =~ /\.(class|gif|jpg|png|zip|tgz|tar|gz|jar|war|cvsignore|spool|~\d~:)$/ or
	$fname =~ /\/.project$/
       ) {
      next;
    }

    chomp $fname; 
    $source = $fname; 
    $fname=~ s{^.*/}{};

    my $source_subdir = $source;
    $source_subdir =~ s{^$G_smodul}{};
    $source_subdir =~ s{/*[^/]*$}{};

    $dest = "$G_dmodul/$source_subdir/$fname";

    print "\nBearbeite: $source\n" if $G_debug_level > 0;

    print "Dest: $dest\n" if $G_debug_level > 1;

    my $dest_dir = "$G_dmodul/$source_subdir";

    if (!-e $dest_dir) { 
      print "\nmkdir:$dest_dir\n\n" if $G_debug_level > 1;

      $cmd = "mkdir -p $dest_dir";

      ($status, $ret) = do_sh_cmd(sh_cmd => $cmd, noaction => $G_noaction);
    }

    my $fexists = '';

    if (-e $dest) { 

      my ($cksum1, $cksum2);
      ($status, $cksum1) = do_sh_cmd(sh_cmd => "cksum $dest");
      ($status, $cksum2) = do_sh_cmd(sh_cmd => "cksum $source");

      $cksum1 =~ s{(^\d+ \d+) .*}{$1}g;
      $cksum2 =~ s{(^\d+ \d+) .*}{$1}g;

      if ($cksum1 eq $cksum2) {
	print "Files identisch\n" if $G_debug_level > 1;

	next;
      }

      ($status, $ret) = do_sh_cmd(sh_cmd => "diff $source $dest", success => [0, 1]);

      print "diff:\n$ret\n--- end diff\n\n" if $G_debug_level > 1;

      $DB::single = 1;

      for my $pat (@G_excl_diff_pattern) {
	$ret =~ s/$pat//g;
      }

      print "diff2:\n$ret\n--- end diff\n\n" if $G_debug_level > 1;

      if ($ret =~ /^\s*$/g) {
	print "Files keine relevanten Unterschiede\n" if $G_debug_level > 1;

	next;
      }

      $fexists = "file exists";

      $DB::single = 1;
    }

    print "cp $fexists $source\n" if $G_debug_level > 0;

    $cmd = "cp $source $dest";

    ($status, $ret) = do_sh_cmd(sh_cmd => $cmd, noaction => $G_noaction);
  }
}

__END__

=pod

=head1 NAME

cp_old_svn.pl - Files von einem defekten workspace in funktionierenen workspace kopieren

=head1 SYNOPSIS

=head1 DESCRIPTION

Vor dem scharfen Ablauf immer erst im Debug-Mode schauen welche Unterschiede es gibt. 
Wurde ein Modul schon länger nicht mehr mir svn update aktualisiert, können nervige Überschreibungen geschehen.

Beispiel Preview:

cp_old_svn.pl -s workspace.bak/RL_2_5_0_BugFix_ts_templating/ -d workspace/RL_2_5_0_BugFix_ts_templating/ --debug 2 -t > tmp.gm        

=head1 AUTOR

G. Mucha

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Gerd Mucha

This code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 



