=head1 NAME

Bloonix::Timeperiod - Parsing time periods.

=head1 SYNOPSIS

    use Bloonix::Timeperiod;

    my @slices = (
        "Monday 00:00 - 23:59",
        "January 00:00 - 23:59",
        "2010-01-01 00:00 - 23:59",
    );

    foreach my $slice (@slices) {
        Bloonix::Timeperiod->parse($slice)
            or die "invalid time slice: $slice";
    }

    Bloonix::Timeperiod->check(\@slices, time)
        or die "no timeslice matched";

=head1 ALLOWED TIME SLICE FORMATS

=head2 TIME SLICE FORMAT

    DAY                             EXAMPLE
    ------------------------------------------------------------
    Weekday                         Monday
    Weekday - Weekday               Monday - Friday
    Month                           Januar
    Month - Month                   Januar - July
    Month Day                       Januar 1
    Month Day - Month Day           Januar 1 - July 15
    Year                            2010
    Year - Year                     2010 - 2012
    YYYY-MM-DD                      2010-01-01
    YYYY-MM-DD - YYYY-MM-DD         2010-01-01 - 2012-06-15

    TIME                            EXAMPLE
    ------------------------------------------------------------
    HH:MM - HH:MM                   09:00 - 17:00
    HH:MM - HH:MM, HH:MM - HH:MM    00:00 - 08:59, 17:01 - 23:59

=head1 FUNCTIONS

=head2 C<new()>

You can create an object if you want for OO style.

=head2 C<parse()>

C<parse> is used to just check if the syntax of a time slice is valid.

The first parameter should be the time periods as a array reference,
if the time period wasn't set with C<new()>. As seconds parameter you
can set the server time in epoch or as string in format "YYYY-MM-DD hh:mm:ss".
The third parameter can be the time zone you wish to check the time period.
You can pass the time zone with C<new()> too.

=head2 C<check()>

=head1 DESCRIPTION

This module provides the functionalety to check if a given time stamp
is within a predefined time range called time period.

=head1 PREREQUISITES

    Carp
    Time::ParseDate

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Timeperiod;

use strict;
use warnings;
use Carp;
use Time::ParseDate;

our $VERSION = "0.1";

my $RX_WEEKDAY = qr/
    (?:
    [Mm]on (?:day){0,1}     |
    [Tt]ue (?:sday){0,1}    |
    [Ww]ed (?:nesday){0,1}  |
    [Tt]hu (?:rsday){0,1}   |
    [Ff]ri (?:day){0,1}     |
    [Ss]at (?:urday){0,1}   |
    [Ss]un (?:day){0,1}
    )
/x;

my $RX_DAY = qr/
    (?:0{0,1}[1-9]|[1-2][0-9]|3[0-1])
/x;

my $RX_MONTH = qr/
    (?:
        [Jj]an (?:uary){0,1}    |
        [Ff]eb (?:ruary){0,1}   |
        [Mm]ar (?:ch){0,1}      |
        [Aa]pr (?:il){0,1}      |
        [Mm]ay                  |
        [Jj]un (?:e){0,1}       |
        [Jj]ul (?:y){0,1}       |
        [Aa]ug (?:ust){0,1}     |
        [Ss]ep (?:tember){0,1}  |
        [Oo]ct (?:ober){0,1}    |
        [Nn]ov (?:ember){0,1}   |
        [Dd]ec (?:ember){0,1}
    )
/x;

my $RX_MONTH_WITH_DAY = qr/
    $RX_MONTH\s+$RX_DAY
/x;

my $RX_YEAR = qr/
    \d{4}
/x;

my $RX_DATE_PRE_YEAR = qr/
    \d{4}                               # year
    [-\/\.]                             # separator
    (?:0{0,1}[1-9]|1[0-2])              # month 01 - 12
    [-\/\.]                             # separator
    (?:0{0,1}[1-9]|[1-2][0-9]|3[0-1])   # day 01 - 31
/x;

my $RX_DATE_POST_YEAR = qr/
    (?:0{0,1}[1-9]|1[0-2])              # month 01 - 12
    [-\/\.]                             # separator
    (?:0{0,1}[1-9]|[1-2][0-9]|3[0-1])   # day 01 - 31
    [-\/\.]                             # separator
    \d{4}                               # year
/x;

my $RX_DATE = qr/
    (?:$RX_DATE_PRE_YEAR|$RX_DATE_POST_YEAR)
/x;

my $RX_TIME = qr/
    (?:[0-1][0-9]|2[0-3]) # hour
    :                     # separator
    (?:[0-5][0-9])        # minute
/x;

my $RX_TIME_TO_TIME = qr/
    $RX_TIME
    \s*-\s*
    $RX_TIME
/x;

my $RX_TIME_LIST = qr/
    $RX_TIME_TO_TIME(?:\s*,\s*$RX_TIME_TO_TIME)*
/x;

my %NAME_2_NUM = (
    jan => 1,  feb => 2,  mar => 3,
    apr => 4,  may => 5,  jun => 6,
    jul => 7,  aug => 8,  sep => 9,
    oct => 10, nov => 11, dec => 12,
    mon => 1,  tue => 2,  wed => 3,
    thu => 4,  fri => 5,  sat => 6,
    sun => 7,
);

my %ALLOWED_FORMATS = (
    weekday         => qr/^($RX_WEEKDAY(?:\s*-\s*$RX_WEEKDAY){0,1})\s+($RX_TIME_LIST)\z/,
    month           => qr/^($RX_MONTH(?:\s*-\s*$RX_MONTH){0,1})\s+($RX_TIME_LIST)\z/,
    month_with_day  => qr/^($RX_MONTH_WITH_DAY(?:\s*-\s*$RX_MONTH_WITH_DAY){0,1})\s+($RX_TIME_LIST)\z/,
    year_month      => qr/^($RX_YEAR\s+$RX_MONTH(?:\s*-\s*$RX_YEAR\s+$RX_MONTH){0,1})\s+($RX_TIME_LIST)\z/,
    year            => qr/^($RX_YEAR(?:\s*-\s*$RX_YEAR){0,1})\s+($RX_TIME_LIST)\z/,
    date            => qr/^($RX_DATE(?:\s*-\s*$RX_DATE){0,1})\s+($RX_TIME_LIST)\z/,
);

sub new {
    my ($class, %opts) = @_;

    return bless \%opts, $class;
}

sub parse {
    @_ == 2 or croak 'Usage: class->parse($string)';
    my ($self, $string) = @_;
    my ($format, $date, $time);

    foreach my $regex (keys %ALLOWED_FORMATS) {
        if ($string =~ $ALLOWED_FORMATS{$regex}) {
            ($date, $time) = ($1, $2);
            $format = $regex;
            last;
        }
    }

    return undef unless $format;
    return wantarray ? ($format, $date, $time) : [$format, $date, $time];
}

sub check {
    my $self    = shift;
    my $periods = shift || $self->{periods};
    my $string  = shift || time;
    my $zone    = shift || $self->{timezone};

    if (!$periods) {
        croak "no periods defined";
    }

    if (ref($periods) ne "ARRAY") {
        $periods = [ $periods ];
    }

    # $time is the timestamp or epoch from $string
    # splitted into its parts as a hash reference.
    my $time = $self->_parse_time_stamp($string, $zone);

    # The $periods are the user defined periods and
    # it must be checked if $time matched any of it.

    foreach my $period (@$periods) {
        my ($format, $date_string, $time_string) = $self->parse($period);

        if (!$format || !$date_string || !$time_string) {
            croak "invalid time period format '$period'";
        }

        $time_string =~ s/\s+//g;
        $date_string =~ s/^\s+//;
        $date_string =~ s/\s+\z//;
        $date_string =~ s/\s+([,:\/\-\.])\s+/$1/;

        # At first we check if the time string matched any time of $time.
        next unless $self->_check_time($time_string, $time->{hour} * 60 + $time->{min});

        # If the time string matched it must be checked if the
        # the date/or that is in $date matched $time.
        my ($from_date, $to_date) = split /-/, $date_string;

        if ($format =~ /^(?:weekday|month|year)\z/) {
            if ($format ne "year") {
                $from_date = substr($from_date, 0, 3);
                $from_date = lc($from_date);
                $from_date = $NAME_2_NUM{$from_date};

                if ($to_date) {
                    $to_date = lc($to_date);
                    $to_date = substr($to_date, 0, 3);
                    $to_date = $NAME_2_NUM{$to_date};
                }
            }

            if ($to_date) {
                if ($time->{$format} >= $from_date && $time->{$format} <= $to_date) {
                    return 1;
                }
            } elsif ($from_date == $time->{$format}) {
                return 1;
            }
        } elsif ($format eq "month_with_day") {
            my ($fmonth, $fday) = split /\s/, $from_date;
            $fmonth = substr($fmonth, 0, 3);
            $fmonth = lc($fmonth);

            if ($to_date) {
                my ($tmonth, $tday) = split /\s/, $to_date;
                $tmonth = substr($tmonth, 0, 3);
                $tmonth = lc($tmonth);

                if (
                    $time->{month} >= $fmonth &&
                    $time->{day}   >= $fday   &&
                    $time->{month} <= $tmonth &&
                    $time->{day}   <= $tday
                ) {
                    return 1;
                }
            } elsif ($fmonth == $time->{month} && $fday == $time->{day}) {
                return 1;
            }
        } elsif ($format eq "year_month") {
            my ($fyear, $fmonth) = split /\s/, $from_date;
            $fmonth = substr($fmonth, 0, 3);
            $fmonth = lc($fmonth);

            if ($to_date) {
                my ($tyear, $tmonth) = split /\s/, $to_date;
                $tmonth = substr($tmonth, 0, 3);
                $tmonth = lc($tmonth);

                if (
                    $time->{year}  >= $fyear  && 
                    $time->{month} >= $fmonth &&
                    $time->{year}  <= $tyear  &&
                    $time->{month} <= $tmonth
                ) {
                    return 1;
                }
            } elsif ($fyear == $time->{year} && $fmonth == $time->{month}) {
                return 1;
            }
        } elsif ($format eq "date") {
            my ($fyear, $fmonth, $fday) = split /\W/, $from_date;

            if ($to_date) {
                my ($tyear, $tmonth, $tday) = split /\W/, $to_date;

                if (
                    $time->{year}  >= $fyear  &&
                    $time->{month} >= $fmonth &&
                    $time->{day}   >= $fday   &&
                    $time->{year}  <= $tyear  &&
                    $time->{month} <= $tmonth &&
                    $time->{day}   <= $tday
                ) {
                    return 1;
                }
            } elsif ($fyear == $time->{year} && $fmonth == $time->{month} && $fday == $time->{day}) {
                return 1;
            }
        }
    }

    return undef;
}

sub _check_time {
    my ($self, $times, $time) = @_;

    foreach my $part (split /,/, $times) {
        my ($fhour, $fmin, $thour, $tmin) = $part =~ /^(\d\d):(\d\d)-(\d\d):(\d\d)\z/;

        my $ftime = $fhour * 60 + $fmin;
        my $ttime = $thour * 60 + $tmin;

        if ($time >= $ftime && $time <= $ttime) {
            return 1;
        }
    }

    return undef;
}

sub _parse_time_stamp {
    my ($self, $time, $zone) = @_;
    my (%time, $old, $tz);

    if ($time !~ /^\d+\z/) {
        $time = Time::ParseDate::parsedate($time)
            or croak "unable to parse time stamp '$time'";
    }

    if ($zone) {
        $tz  = exists $ENV{TZ} ? 1 : 0;
        $old = $ENV{TZ};
        $ENV{TZ} = $zone;
    }

    @time{qw(min hour day month year weekday)} = (localtime($time))[1..6];
    $time{year}     += 1900;
    $time{month}    += 1;
    $time{weekday} ||= 7;

    if ($zone) {
        if ($tz) {
            $ENV{TZ} = $old;
        } else {
            delete $ENV{TZ};
        }
    }

    return \%time;
}

1;
