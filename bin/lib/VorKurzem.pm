# Copyright 2009 Joachim Breitner
# 
# Licensed under the EUPL, Version 1.1 or – as soon they will be approved
# by the European Commission – subsequent versions of the EUPL (the
# "Licence"); you may not use this work except in compliance with the
# Licence.
# You may obtain a copy of the Licence at:
# 
# http://ec.europa.eu/idabc/eupl
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the Licence is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# Licence for the specific language governing permissions and limitations
# under the Licence.

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
