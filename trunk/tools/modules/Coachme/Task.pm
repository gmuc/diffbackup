#---------------------------------------------------------------------------------------------------
# $Id$
# $URL$
# $Author$
# $Revision$
# $Date$
#---------------------------------------------------------------------------------------------------

package Coachme::Task;

# Erben von Class::Base_oo
require Exporter;
@ISA    = ('Exporter', 'Class::Base_oo');

use strict;
use warnings;

use Tie::IxHash;
use Class::Base_oo;

our $VERSION = '0.1';

my $G_logger_base;

my  %ok_field;
for my $attr ( qw(description comment category start_time end_time total_time schedule_time concentration) ) { $ok_field{$attr}++; } 

sub new {
  my $classname = shift;
  my %args = @_;

  my $self = {};

  $DB::single=1;

  # check_pflicht_parameter wird als statische Methode aufgerufen, deshalb
  # kann der Test an beliebiger Stelle aufgerufen werden
  # hier ist es sinnvoll, den Test noch vor Aufruf der Superklasse durchzuführen,
  # weil ohne vollständige Pflichtparameter auch der Konstruktor nicht sinnvoll
  # abgearbeitet werden kann
  Class::Base_oo->check_pflicht_parameter([qw(description start_time)],%args);

  $self = $classname->SUPER::new(@_);

  $self->{_ok_field} = \%ok_field;

  $self->{_description} = $args{description};
  $self->{_comment} = $args{comment};
  $self->{_category} = $args{category};
  $self->{_start_time} = $args{start_time};
  $self->{_end_time} = $args{end_time};
  $self->{_schedule_time} = $args{schedule_time};
  $self->{_concentration} = $args{concentration};
  $self->{_total_time} = $args{total_time};

  return $self;
}

1;
