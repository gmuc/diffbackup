#!/usr/bin/perl

# ------------------------------------------
# $URL$
# $Revision$                                        
# $Date$                         
# $Author$                                                                            
# ------------------------------------------

use strict;
use warnings;

my $version = '0.1test';
my $G_programm = 'mysql_report_cgi.pl';

use CGI;
use JSON;
use Encode;

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

my ($G_script_config, $G_script_name, $G_mysql_debug);

my $G_connect_list = $G_config->{ 'connect-list' };

main();

# --------------------------------------- END MAIN -------------------------------------------------
# --------------------------------------- END MAIN -------------------------------------------------
# --------------------------------------- END MAIN -------------------------------------------------

sub main{

  # w = wiederherstellen, s = sichern
  save_restore_cgi('');

  my $tab_style = get_tab_style();

  $DB::single = 1;

  get_script_name_from_param();

  $G_script_config = $G_config->{ 'script-list' }->{ $G_script_name };

  my $db_name = get_db_name_from_param();

  my $sql_limit = $G_page->param( 'sql_limit' ) || 2000;

  my $sql_limit_cfg = $G_script_config->{ show_sql_limit };

  my $parameter = $G_script_config->{ parameter };

  my $mysql_debug = $G_page->param( 'mysql_debug' );

  my $show_mysql_debug = $G_script_config->{ show_sql_debug_button };

  my ($param_substitution, %mysql_param_values) = prepare_parameter( $parameter );

  my $title = $G_script_config->{ title } || '';

  my $description = $G_script_config->{ description } || '';

  # --- start generate html ------------------------------------------------------------------------

  print $G_page->start_html;

  print $tab_style;

  print "<div class=\"qform\">\n";

  print "<b>$title</b><br>$description\n<br><br><br>\n";

  print $G_page->start_form(
			  -name    => 'MySQL Report',
			  -method  => 'PUT',
			  -enctype => &CGI::URL_ENCODED,
			  -action => '/cgi-bin/mysql-report/mysql_report_cgi.pl', # Defaults to 
			  -style => 'border: 0px' ,
			 ) . "\n";


  $DB::single = 1;

  print make_query_param_form( \%mysql_param_values, $parameter, $db_name, $sql_limit_cfg, $show_mysql_debug);

  my $my_sql_arg = '';
  if( $G_page->param( 'mysql_debug' ) eq 'true' ){
    $my_sql_arg = '-v';
  }

  my $tmp_sql_file = "/tmp/_tmp_rep_sql_file.sql";

  `cp $G_script_config->{ path } $tmp_sql_file; chmod 777 $tmp_sql_file;`;

  if($show_mysql_debug){
    `echo " limit $sql_limit;" >> $tmp_sql_file`;
  }

  # mysql -v gibt die Parameter und das SQL aus !!! sehr hilfreich für das Debugging !!!
  my $cmd = "mysql $my_sql_arg $G_connect_list->{ $db_name } -A $param_substitution -H < $tmp_sql_file";

  $DB::single = 1;
  
  my $ret = `$cmd`;
  my $status = $? >> 8;

  if($status != 0){
     print "Error on database access! See httpd errorlog!";

     die "Error '$status' on execution command '$cmd' Output:$ret Systemerror:$!\n";
  }

  if( defined $mysql_debug and $mysql_debug eq 'true' ){
    $ret =~ s/--------------\n/<br>--------------<br>/sg;
  }

  if( ! defined $ret or $ret eq ''){
    print "Nichts gefunden!<br>";
  }
  else{
    print $ret;
  }

  print $G_page->end_html;
}


sub make_query_param_form{
  my ( $mysql_param_values, $parameter, $db_name, $sql_limit, $show_mysql_debug )= @_; 

  
  $DB::single = 1;

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

  if ( $show_mysql_debug eq 'true' ){
    $labels = { 'true' => 'ja', 'false' => 'nein' };
    @values = ( 'true', 'false' );

    $form .= $G_page->Tr(
			 $G_page->td('SQL anzeigen:'),
			 $G_page->td(
				     $G_page->popup_menu(
							 -name    => 'mysql_debug',
							 -values  => \@values, 
							 -labels  => $labels,
							 -default => 'false'
							)
				    )
			) . "\n";

  }

  if ( $sql_limit ){
    my @limits = split /, */, $sql_limit;

    $sql_limit =~ s/, *//g;

    # ??? all limits nummeric ???
    if( $sql_limit =~ /^\d+$/ ){
        $form .= $G_page->Tr(
		  $G_page->td('Max. angezeigte Treffer:'),
		  $G_page->td(
			    $G_page->popup_menu(
					      -name    => 'sql_limit',
					      -values  => \@limits,
					      -default => $limits[0]
					     )
			   )
		 ) . "\n";

    }
  }

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
     $config_data = JSON->new->latin1->decode($data);
     #$config_data = decode_json($data);
     1;
   } or do {
     my $e = $@;
     warn "JASON Parse-Error: '$config_file' $e\n";
     $config_data = '';
   };

   return $config_data;
 }

sub prepare_parameter{
  my ( $parameter ) = @_;

  my %mysql_param_values;
  my $mysql_param_data = '';
  my $param_substitution = '';

  # ??? Sind zu der Abfrage Queryparameter möglich ???
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
    print "Ungültiger DB Name '$db_name'!";
    print $G_page->end_html;
    exit;
  }

  return $db_name;
}


sub get_script_name_from_param{
  $G_script_name = $G_page->param( 'script' );

  if(! exists $G_config->{ 'script-list' }->{ $G_script_name } ){
    print "Ungültiger Script Name '$G_script_name'!";
    print $G_page->end_html;
    exit;
  }
}

sub save_restore_cgi{
  my $mode = shift;

  my $file = '/tmp/test.cgi_data'; # -- test --

  if( $mode eq 'w' ){
    # wiederherstellen
    open(FH,$file) or die "open >$file Error!\n$!"; # -- test --
    $G_page = new CGI(*FH); # -- test --
  }
  elsif( $mode eq 's' ){
    # sichern
    # open(FH,">$file") or die "open >$file Error!\n$!"; # -- test --
    # $G_page->save(*FH); # -- test --
  }
}

__END__

=pod

=head1 Bezeichnung

 mysql_report_cgi.pl - Report von MySQL Abfragen

=head1 Syntax

 diff_backup.pl -c Datei [-v] [-n] [-b] [-version] [-h] [-base [Datei]] [-r]

=head1 Beschreibung

Mittels einer JSON Konfigurationsdatei können SQL Abfragen über den WEBServer gestartet werden.


=head1 COPYRIGHT AND LICENSE

Copyright 2013 by G. Mucha

This code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
