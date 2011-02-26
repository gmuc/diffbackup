#!/usr/bin/perl

use Test::More tests => 1;

BEGIN {
    use_ok( 'diffBackup' ) || print "Bail out!
";
}

diag( "Testing diffBackup $diffBackup::VERSION, Perl $], $^X" );
