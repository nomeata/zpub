package VorKurzem;

use strict;
use warnings;

use DateTime;
use DateTime::Format::Strptime;

sub format_datetime {
    my ($self,$date) = @_;
    my $now = DateTime->now;
    my $diff = $now - $date;

    if (DateTime::Duration->compare($diff, $self->{minute}) < 0 ){
	if ($diff->seconds == 1)  {
		return "vor einer Sekunde"
	} else {
		return sprintf "vor %d Sekunden", $diff->seconds;
	}
    } elsif (DateTime::Duration->compare($diff, $self->{hour}) < 0 ){
	if ($diff->minutes == 1)  {
		return "vor einer Minute"
	} else {
		return sprintf "vor %d Minuten", $diff->minutes;
	}
    } elsif (DateTime::Duration->compare($diff, $self->{day}) < 0 ){
	if ($diff->hours == 1)  {
		return "vor einer Stunde"
	} else {
		return sprintf "vor %d Stunden", $diff->hours;
	}
    } else {
	$date->set_locale('de_DE');
	return $self->{fallback}->format_datetime($date);
    }
}

sub new {
    my $class = shift;

    return bless {
	fallback =>
		DateTime::Format::Strptime->new(
			pattern     => '%d. %B %Y um %H:%M',
			time_zone   => 'Europe/Berlin',
		),
	minute  =>	DateTime::Duration->new(minutes => 1),
	hour    =>	DateTime::Duration->new(hours   => 1),
	day    =>	DateTime::Duration->new(days   => 1),
    }, $class; 
}

1;
