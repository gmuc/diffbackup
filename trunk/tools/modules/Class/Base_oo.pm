package Class::Base_oo;

require Exporter;
@ISA    = ('Exporter');

use strict;
use warnings;

use Carp;

our $VERSION = '0.1';
our $AUTOLOAD; # wird für die Autoloadfunktion benötigt


# Konstruktor
sub new {
  my $classname = shift;
  my %args = @_;

  my $self = {};

  # Erzeugen der Klassenbindung in Perl
  $self = bless $self, ref $classname || $classname; # Objekt oder Klasse ?

  return $self;
}

sub check_pflicht_parameter{
  my $self = shift;
  my $required_params = shift;
  my %args = @_;

  # Prüfung Pflichtparameter
  foreach my $param_name (@{$required_params}){
    if(!defined $args{$param_name} or $args{$param_name} eq ''){
      croak "Error BASE 005: Der Parameter '$param_name' ist ein Pflichtparameter!";
    }
  }
}

# automatischer Getter und Setter über Autoload
sub AUTOLOAD {
  my $self = shift;
  my $attr = $AUTOLOAD;          # Wert des Felder aus $AUTOLOAD holen
  $attr =~ s/.*:://;             # Modulnamen abschneiden
  return if $attr eq 'DESTROY';  # Verhindern, daß DESTROY überschrieben wird 

  my $classname = ref $self;

  # ??? ist der Parameter zulässig ???
  if ($self->{_ok_field}{$attr}) {
    my $field_name = "_" . $attr;
    
    $self->{$field_name} = shift if @_;
    return $self->{$field_name};
  } 
  else {
    croak "TEST::Base Zugriff auf das unbekannte Attribut '$attr'!";
  } 
}

1;
