#!/usr/bin/perl

# ------------------------------------------
# $URL: https://svn.br.de/repos/br-wetter-dev/trunk/WetterImports/WetterDB/stammdaten/upd_stations_filter_Europa.sql $
# $Revision: 13017 $                                        
# $Date: 2011-07-29 14:08:50 +0200 (Fr, 29 Jul 2011) $                         
# $Author: muchag $                                                                            
# ------------------------------------------

use strict;
use warnings;

my $version = '0.1test';
my $G_programm = 'mysql_report_cgi.pl';

use CGI;
use JSON;

my $G_config_file = '/etc/mysql_report_cfg.json';

my $G_page  = new CGI;

print $G_page->header('text/html');

my $G_config = get_json_config( $G_config_file );

if( !$G_config ){
  print $G_page->start_html;

  print "Error on read configuration '$G_config_file'";

  print $G_page->end_html;
  exit;
}

my ($G_script_config, $G_script_name);

my $G_connect_list = $G_config->{ 'connect-list' };

main();

# --------------------------------------- END MAIN -------------------------------------------------
# --------------------------------------- END MAIN -------------------------------------------------
# --------------------------------------- END MAIN -------------------------------------------------

sub main{

  save_restore_cgi();

  my $tab_style = get_tab_style();

  $DB::single = 1;

  get_script_name_from_param();

  $G_script_config = $G_config->{ 'script-list' }->{ $G_script_name };

  my $db_name = get_db_name_from_param();

  my $parameter = $G_script_config->{ parameter };

  my ($param_substitution, %mysql_param_values) = prepare_parameter($parameter);


  # --- start generate html ------------------------------------------------------------------------

  print $G_page->start_html;

  print $tab_style;

  print "<div class=\"qform\">\n";

  print "<b>$G_script_config->{title}</b>\n<br><br>\n";

  print $G_page->start_form(
			  -name    => 'MySQL Report',
			  -method  => 'PUT',
			  -enctype => &CGI::URL_ENCODED,
			  -action => '/cgi-bin/mysql-report/mysql_report_cgi.pl', # Defaults to 
			  -style => 'border: 0px' ,
			 ) . "\n";


  $DB::single = 1;

  print make_query_param_form( \%mysql_param_values, $parameter, $db_name );

  my $mysql_debug = 1;

  my $my_sql_arg = '';
  if( $G_page->param( 'mysql_debug' ) eq 'true' ){
    $my_sql_arg = '-v';
  }

  # mysql -v gibt die Parameter und das SQL aus !!! sehr hilfreich f�r das Debugging !!!
  my $cmd = "mysql $my_sql_arg $G_connect_list->{ $db_name } -A $param_substitution -H < $G_script_config->{ path }";

  $DB::single = 1;
  
  my $ret = `$cmd`;
  my $status = $? >> 8;

  if($status != 0){
     print "Error on database access! See httpd errorlog!";

     die "Error '$status' on execution command '$cmd' Output:$ret Systemerror:$!\n";
  }

  if( $G_page->param( 'mysql_debug' ) eq 'true' ){
    $ret =~ s/--------------\n/<br>--------------<br>/sg;
  }

  print $ret;

  print $G_page->end_html;
}


sub make_query_param_form{
  my ( $mysql_param_values, $parameter, $db_name )= @_; 

  
  my $db = $G_script_config->{ db_list };

  my @values = keys %{ $db }; 
  
  my $labels = $db;

  my $form = $G_page->start_table( {-class => 'qform'} ) . "\n";

  $form .= $G_page->Tr(
		  $G_page->td('Datenbank:'),
		  $G_page->td(
			    $G_page->popup_menu(
					      -name    => 'db',
					      -values  => \@values,
					      -labels  => $labels,
					      -default => $db_name
					     )
			   )
		 ) . "\n";
  
  $form .= $G_page->hidden(
		      -name      => 'script',
		      -default   => $G_script_name
		     );

  $DB::single = 1;

  if($parameter){

    foreach my $field_code (keys $parameter){
      my $field_name = $parameter->{$field_code}->{label};
      my $field_type = $parameter->{$field_code}->{type};

      my $form_element;

      if( $field_type eq 'popup' ){
	my $data = $parameter->{ $field_code }->{ data };
	my $default = $parameter->{ $field_code }->{ default };

	my ( @values, %labels );
	foreach my $value ( sort keys %{ $data } ){
	  push @values, $value;
	  $labels{ $value } = $data->{ $value };
	}

	$form_element = $G_page->popup_menu(
				     -name    => $field_code,
				     -values  => \@values,
				     -labels  => \%labels,
				     -default => $default
				    );
      }
      else{
	$form_element = $G_page->textfield(
					   -name    => $field_code,
					   -size    => 50,
					   -value   => $mysql_param_values->{ $field_code },
					  );
      }

      $form .= $G_page->Tr(
			   $G_page->td( $field_name ),
			   $G_page->td( $form_element )
			  ) . "\n";

    }
  }

  $form .= $G_page->Tr(
		  $G_page->td(''),
		  $G_page->td(
			    $G_page->submit(
					  -name     => 'submit_form',
					  -value    => 'Start search',
					  
					  #        -onsubmit => 'javascript: validate_form()',
					 )
			   )
		 ) . "\n";

  $form .= $G_page->end_table . "\n";

  $form .= $G_page->end_form . "\n<br><br>\n";

  return $form;
}

sub get_tab_style{
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
                text-align:left; word-wrap: break-word; max-width: 220px;
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

            table.qform td { border: 0px; width: 400px }
            table.qform tr:nth-child(even) {
                background-color: #fff; 
            }
            table.qform tr:nth-child(odd) {
                background-color: #fff; 
            }

</style>
END

  return $tab_style;
}

sub get_json_config{
   my $config_file = shift;

   $DB::single = 1;

   open FH,$config_file
     or 
       die "err open '$config_file' $?\n";

   undef $/;
   my $data = <FH>;
   $/ = "\n";

   my $config_data;

   eval {
     $config_data = decode_json($data);
     1;
   } or do {
     my $e = $@;
     warn "JASON Parse-Error: '$config_file' $e\n";
     $config_data = '';
   };

   return $config_data;
 }

sub prepare_parameter{
  my $parameter = shift;

  my %mysql_param_values;
  my $mysql_param_data = '';
  my $param_substitution = '';

  # ??? Sind zu der Abfrage Queryparameter m�glich ???
  if($parameter){
    foreach my $mysql_param_name ( keys $parameter ){

      my $param_value = $G_page->param( $mysql_param_name );

      my $default_value = $parameter->{ $mysql_param_name }->{ default };

      if( !$param_value and $default_value ){
	$param_value = $default_value;
      }

      $mysql_param_values{ $mysql_param_name } = $param_value;

      $mysql_param_data .= "set \@$mysql_param_name=\"$param_value\"; ";

    }

    $param_substitution = $mysql_param_data . " source  $G_script_config->{path};";

    if($param_substitution){
      $param_substitution = "-e'$param_substitution'";
    }
  }

  return $param_substitution, %mysql_param_values;
}

sub get_db_name_from_param{

  my $db_name = $G_page->param('db') || $G_script_config->{ 'default_db' };

  if(! exists $G_connect_list->{ $db_name } ){
    print "Ung�ltiger DB Name '$db_name'!";
    print $G_page->end_html;
    exit;
  }

  return $db_name;
}


sub get_script_name_from_param{
  $G_script_name = $G_page->param( 'script' );

  if(! exists $G_config->{ 'script-list' }->{ $G_script_name } ){
    print "Ung�ltiger Script Name '$G_script_name'!";
    print $G_page->end_html;
    exit;
  }
}

sub save_restore_cgi{
  my $file = '/tmp/test.cgi_data'; # -- test --

  # wiederherstellen
  #open(FH,$file) or die "open >$file Error!\n$!"; # -- test --
  #$G_page = new CGI(*FH); # -- test --

  # sichern
  #open(FH,">$file") or die "open >$file Error!\n$!"; # -- test --
  #$G_page->save(*FH); # -- test --
}

#   my %connect = ( 
# 		 'local_wetter' => '-hlocalhost -Dwetter_koorin -uwikiuser -pmysql1234',
		 
# 		 'devel-koorin' => '-hdb-devel-sin-1.mm.br.de -Dwetter_koorin -uwetter_koorin -pwEtTer5',

# 		 'qs-koorin'    => '-hdb-qs-sin-2.mm.br.de -Dwetter_koorin -uwetter_koorin -pwEtTer5'
# 		);

#   my %script = (
# 		sele_regio_reports => { 
# 				       db => { 'devel-koorin' => 'devel DB koorin', 'qs-koorin' => 'qs DB koorin' },
# 				       pfad =>'/home/mucha/idea/wetter-trunk/database/reports/sele_regio_reports.sql',
# 				       titel => 'Liste der aktuellen Regionalwetterberichte',

# 				      },

# 		sele_single_regio_report => { 
# 					     pfad =>'/home/mucha/idea/wetter-trunk/database/reports/sele_single_regio_report.sql',
# 					     titel => 'Inhalt einzelner Regionalwetterbericht',
# 					     # IDEE: Felder help, default (Defaultwert)
# 					     db => { 'devel-koorin' => 'devel DB koorin', 'qs-koorin' => 'qs DB koorin' },
# 					     parameter => {
# 							   valid_from => { name => "Validierungszeit (yyyy-mm-dd hh24:mi:ss)" }, 
# 							   basetype => { name => "Berichtstyp" },
# 							  },
# 					    },
# 		select_svn_logt => { 
# 				    pfad  => '/home/mucha/pj/subversion/svnlog/select_svn_log.sql',
# 				    titel => 'SVN Log Wetter',
# 				    db    => { 'local_wetter' => 'Lokale Wetter DB' },
# 				    # IDEE: Felder help, default (Defaultwert)
# 				    parameter => {
# 						  autor => { name => "Autor der Version", default => '%' },
# 						  rev => { name => "SVN Revision", default => '%' },
# 						 },
# 				   }
# 	       );
	      
__END__

=pod

=head1 Bezeichnung

 mysql_report_cgi.pl - Report von MySQL Abfragen

=head1 Syntax

 diff_backup.pl -c Datei [-v] [-n] [-b] [-version] [-h] [-base [Datei]] [-r]

=head1 Beschreibung

Mittels einer JSON Konfigurationsdatei k�nnen SQL Abfragen �ber den WEBServer gestartet werden.


=head1 COPYRIGHT AND LICENSE

Copyright 2013 by G. Mucha

This code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
