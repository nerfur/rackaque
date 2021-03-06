package RackMonkey::Helper;
########################################################################
# RackMonkey - Know Your Racks - http://www.rackmonkey.org
# Version 1.2.%BUILD%
# (C)2007 Will Green (wgreen at users.sourceforge.net)
# Misc helper functions for RackMonkey
########################################################################

use strict;
use warnings;

use Time::Local;

use RackMonkey::Conf;

our $VERSION = '1.2.%BUILD%';
our $AUTHOR = 'Will Green (wgreen at users.sourceforge.net)';

use base 'Exporter';
our @EXPORT = qw/shortStr shortURL httpFixer calculateAge checkName checkNotes checkDate/;

sub shortStr
{
	my $str = shift;
	return unless defined $str;
	if (length($str) > SHORTTEXTLEN)
	{
		return substr($str, 0, SHORTTEXTLEN).'...';
	}
	return '';
}

sub shortURL
{
	my $url = shift;
	return unless defined $url;
	if (length($url) > SHORTURLLEN)
	{
		return substr($url, 0, SHORTURLLEN).'...';
	}
	return '';
}

sub httpFixer
{
	my $url = shift;
	return unless defined $url;
	return unless (length($url)); # Don't add to empty strings
	unless ($url =~ /^\w+:\/\//)  # Does URL begin with a protocol?
	{
		$url = "http://$url";
	}
	return $url;
}

sub calculateAge
{
	my $date = shift;
	return unless defined $date;
	my ($year, $month, $day) = $date =~ /(\d{4})-(\d{2})-(\d{2})/;
	if ($year)
	{
		$month--; # perl months start at 0
		my $startTime = timelocal(0, 0, 12, $day, $month, $year);
		my $age = (time - $startTime) / (86400 * 365.24); # Age in years
		return sprintf("%.1f", $age);
	}
	return '';
}

sub checkName
{
	my $name = shift;
	die "RMERR: You must specify a name." unless defined $name;
	unless ($name =~ /^\S+/)
	{
		die "RMERR: You must specify a valid name. Names may not begin with white space.\nError occured";
	}
	unless (length($name) <= MAXSTRING)
	{
		die "RMERR: Names cannot exceed ".MAXSTRING." characters.\nError occured";
	}
}

sub checkNotes
{
	my $notes = shift;
	return unless defined $notes;
	unless (length($notes) <= MAXNOTE)
	{
		die "RMERR: Notes cannot exceed ".MAXNOTE." characters.\nError occured";
	}
}

sub checkDate
{
	my $date = shift;
	return unless $date;
	die "RMERR: Date not in valid format (YYYY-MM-DD).\nError occured" unless $date =~ /^\d{4}-\d\d?-\d\d?$/;
	my ($year, $month, $day) = split '-', $date;
	eval { timelocal(0, 0, 12, $day, $month - 1, $year - 1900); }; # perl months begin at 0 and perl years at 1900
	die "RMERR: $year-$month-$day is not a valid date of the form YYYY-MM-DD. Check that the date exists. NB. Date validation currently only accepts years 1970 - 2038. This limitation will be lifted in a later release.\n$@\nError occured" if ($@);
	return sprintf("%04d-%02d-%02d", $year, $month, $day);
}

1;
