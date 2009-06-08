#!/usr/bin/perl

#---------------------------------------------------------------------------------------------------
# $RCSfile: lfiles.pl,v $                       
# $Revision$                                        
# $Date$                         
# $Author$                                       
# $Locker: mucha $                                            
#---------------------------------------------------------------------------------------------------


use strict;
use warnings;

use Getopt::Long;
use BaseHelper('usage','do_sh_cmd');

my $version = '0.1';

$BaseHelper::usage_text =<<END;

usage:

lfiles.pl
[-d  --dir verzeichnis]  -Startdir find
[-v  --version]        -Programmversion ausgeben
[-h  --help]           -Hilfe

END

our $G_start_dir='.';

GetOptions(
	   'd|dir=s'     => \$G_start_dir,
	   'v|version'   => sub{print "\nlfiles.pl Version: $version\n\n"; exit},
	   'h|help|?'    => \&usage,
	  );

if($G_start_dir eq ''){
  $G_start_dir = '.';
}

main();

exit;

#   find . -type f -exec du -s {} \; | perl -n -e'@a=split /\s/; $a[0] = sprintf("%10.10d",$a[0]);print "$a[0]  $a[1]\n}";' | sort

sub main{
  my ($status, $ret, $cmd, $source, $dest);

  if(! -e $G_start_dir or 
     ! -r $G_start_dir or
     ! -x $G_start_dir){

    die "Can't change dir '$G_start_dir'\nerror directory NO EXISTS or NO READABLE or NO ACCESS!\n";
  }

  my @files = `find $G_start_dir -type f -exec du -s {} \\;`;

  foreach my $fdata (@files) {

    my @a=split /\s/, $fdata, 2; 
    $a[0] = sprintf("%10.10d",$a[0]);
    $a[0] =~ s/(...)(...)$/\.$1\.$2/;
    $fdata = "$a[0]K  $a[1]";
  }

  foreach my $fdata (sort @files){

    $fdata     =~ s/^([0\.]*)//;
    my $prefix = ' ' x length $1;
    $fdata     = $prefix . $fdata;
    print $fdata;
  }
}
