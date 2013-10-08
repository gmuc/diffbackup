#!/usr/bin/perl

use strict;
use warnings;

my $version = '0.1';

use CGI;

my $page  = new CGI;

my $file = '/tmp/test.cgi_data'; # -- test --

# wiederherstellen
#open(FH,$file) or die "open >$file Error!\n$!"; # -- test --
#$page = new CGI(*FH); # -- test --

# sichern
#open(FH,">$file") or die "open >$file Error!\n$!"; # -- test --
#$page->save(*FH); # -- test --


print $page->header('text/html');


my $tab_style=<<END;
<style>


            body {
                font-family:Arial, Helvetica, sans-serif;
                font-size:14px;
				color: 000;
            }
			
            table {
                border: 0px solid #aaa;
                border-collapse: collapse;
            }
			
            tr:nth-child(even) {
                background-color: #fff;
            }
             
            tr:nth-child(odd) {
                background-color: #eee;
            }
            
            td, th {
                padding:6px 12px;
                text-align:left;
            }
			
			td {
                border: 1px solid #aaa;
            }
            
            th {
                background-color: #aaa;
                color: fff;
                font-weight: bold;
                border: 1px solid #000;
            }

            table.qform td { border: 0px; }

</style>
END

my %connect = ( 
	       devel => '-hdb-devel-sin-1.mm.br.de -Dwetter_koorin -uwetter_koorin -pwEtTer5',
	       qs    => '-hdb-qs-sin-2.mm.br.de -Dwetter_koorin -uwetter_koorin -pwEtTer5'
);

my %script = (
	      sele_regio_reports => { 
				     pfad =>'/home/mucha/idea/wetter-trunk/database/reports/sele_regio_reports.sql',
				     titel => 'Liste der aktuellen Regionalwetterberichte'

				    },

	      sele_single_regio_report => { 
					   pfad =>' /home/mucha/idea/wetter-trunk/database/reports/sele_single_regio_report.sql',
					   titel => 'Inhalt einzelner Regionalwetterbericht',
					   parameter => {
							 valid_from => { name => "Validierungszeit" }, 
							 basetype => { name => "Regions ID" },
							},
					  }
	     );
	      
$DB::single = 1;

my $db_name = $page->param('db') || 'devel';

if(! exists $connect{$db_name} ){
  print "Ungültiger DB Name '$db_name'!";
  print $page->end_html;
  exit;
}

my $script_name = $page->param('script');

if(! exists $script{$script_name} ){
  print "Ungültiger Script Name '$script_name'!";
  print $page->end_html;
  exit;
}

my $parameter = $script{ $script_name }{ parameter };

my %mysql_param_values;
my $mysql_param_data = '';
my $param_substitution = '';

if($parameter){
  foreach my $mysql_param_name ( keys $parameter ){

    my $param_value = $page->param( $mysql_param_name );

    if( !$param_value ){
      print "Fehler: Parameter '$mysql_param_name' hat keinen Wert!<br>";
      print $page->end_html;
      exit;
    }

    $mysql_param_values{ $mysql_param_name } = $param_value;

    $mysql_param_data .= "set \@$mysql_param_name=\"$param_value\"; ";

  }

  $param_substitution = $mysql_param_data . " source  $script{ $script_name }{ pfad };";

  if($param_substitution){
    $param_substitution = "-e'$param_substitution'";
  }
}


print $page->start_html;

#print $page->start_html(-head=>=>meta({-http_equiv => 'Content-Type', -content    => 'text/html'}));

print $tab_style;

print "<div class=\"qform\">\n";

print "<b>$script{ $script_name }{ titel }</b>\n<br><br>\n";

print $page->start_form(
        -name    => 'MySQL Report',
        -method  => 'PUT',
        -enctype => &CGI::URL_ENCODED,
#        -onsubmit => 'return javascript:validation_function()',
        -action => '/cgi-bin/mysql-report/mysql_report_cgi.pl', # Defaults to 
                                                 # the current program
        -style => 'border: 0px' ,
    ) . "\n";

my @values = ( 
	      'devel', 
	      'qs', 
#	      'live' 
	     );

my $labels = {
	      'devel' => 'Devel', 
	      'qs' => 'QS', 
#	      'live' => 'Live'
	     };

print $page->start_table( {-class => 'qform'} ) . "\n";
print $page->Tr(
		$page->td('Datenbank:'),
		$page->td(
			  $page->popup_menu(
					    -name    => 'db',
					    -values  => \@values,
					    -labels  => $labels,
					    -default => $db_name
					   )
			 )
	       ) . "\n";

print $page->hidden(
		    -name      => 'script',
		    -default   => $script_name
		   );

print $page->Tr(
		$page->td(''),
		$page->td(
			  $page->submit(
					-name     => 'submit_form',
					-value    => 'Suche starten',

					#        -onsubmit => 'javascript: validate_form()',
				       )
			 )
	       ) . "\n";

print $page->end_table . "\n";

print $page->end_form . "\n<br><br>\n";

print "</div>\n\n";

if( $page->param('db') ){
  my $cmd = "mysql $connect{ $db_name } -A $param_substitution -H < $script{ $script_name }{ pfad }";

  my $ret='';

  $ret = `$cmd`;

  print $ret;
}

print $page->end_html;
