#!/usr/bin/perl
# vim:ts=4:sw=4

package Text::Flowed;

$VERSION = '0.1';

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(reformat quote quote_fixed);

use strict;

use vars qw($MAX_LENGTH $OPT_LENGTH);

# MAX_LENGTH: This is the maximum length that a line is allowed to be
# (unless faced with a word that is unreasonably long). This module will
# re-wrap a line if it exceeds this length.
$MAX_LENGTH = 79;

# OPT_LENGTH: When this module wraps a line, the newly created lines
# will be split at this length.
$OPT_LENGTH = 72;

# reformat($text, [\%args])
# Reformats $text, where $text is format=flowed plain text as described
# in RFC 2646.
#
# $args->{quote}: Add a level of quoting to the beginning of each line.
# $args->{fixed}: Interpret unquoted lines as format=fixed.
sub reformat {
	my @input = split("\n", $_[0]);
	my $args = $_[1];
	my @output = ();

	# Process message line by line
	while (@input) {
		# Count and strip quote levels
		my $line = shift(@input);
		my $num_quotes = _num_quotes($line);
		$line = _unquote($line);

		# Remove space-stuffing if necessary
		_unstuff(\$line) unless $args->{fixed};

		# While line is flowed, join subsequent lines with flowed text
		unless ($args->{fixed} && !$num_quotes) {
			while (_flowed($line) && @input &&
			       _num_quotes($input[0]) == $num_quotes) {
				$line .= _unquote(shift(@input));
			}
		}
		# Ensure line is fixed, since we joined all flowed lines
		_trim(\$line);

		# Increment quote depth if we're quoting
		$num_quotes++ if $args->{quote};

		if (!$line) {
			# Line is empty
			push(@output, '>' x $num_quotes);
		} elsif (length($line) + $num_quotes <= $MAX_LENGTH - 1) {
			# Line does not require rewrapping
			_stuff(\$line, $num_quotes);
			push(@output, '>' x $num_quotes . $line);
		} else {
			# Rewrap this paragraph
			while ($line) {
				# Stuff and re-quote the line
				_stuff(\$line, $num_quotes);
				$line = '>' x $num_quotes . $line;
				my $min = $num_quotes + 1;
				if (length($line) <= $OPT_LENGTH) {
					# Remaining section of line is short enough
					push(@output, $line);
					last;
				} elsif ($line =~ /^(.{$min,$OPT_LENGTH}) (.*)/ ||
				         $line =~ /^(.{$min,})? (.*)/) {
					# Further wrapping required
					push(@output, "$1 ");
					$line = $2;
				} else {
					# One excessively long word left on line
					push(@output, $line);
					last;
				}
			}
		}
	}

	return join("\n", @output)."\n";
}

# quote(<text>)
# A convenience wrapper for reformat(<text>, {quote => 1}).
sub quote {
	return reformat($_[0], {quote => 1});
}

# quote_fixed(<text>)
# A convenience wrapper for reformat(<text>, {quote => 1, fixed => 1}).
sub quote_fixed {
	return reformat($_[0], {quote => 1, fixed => 1});
}

# _num_quotes(<text>)
# Returns the number of leading '>' characters in <text>.
sub _num_quotes {
	$_[0] =~ /^(>+)/;
	return length($1);
}

# _unquote(<text>)
# Removes all leading '>' characters from <text>.
sub _unquote {
	my $line = shift;
	$line =~ s/^(>+)//g;
	return $line;
}

# _flowed(<text>)
# Returns 1 if <text> is flowed; 0 otherwise.
sub _flowed {
	my $line = shift;
	# Lines with only spaces in them are not considered flowed
	# (heuristic to recover from sloppy user input)
	return 0 if $line =~ /^ *$/;
	return $line =~ / $/;
}

# _trim(<text>)
# Removes all trailing ' ' characters from <text>.
sub _trim {
	my $ref = shift;
	$$ref =~ s/ +$//g;
}

# _stuff(<text>, <num_quotes>)
# Space-stuffs <text> if it starts with " " or ">" or "From ", or if
# quote depth is non-zero (for aesthetic reasons so that there is a
# space after the ">").
sub _stuff {
	my ($ref, $num_quotes) = @_;
	if ($$ref =~ /^ / || $$ref =~ /^>/ || $$ref =~ /^From / ||
		$num_quotes > 0) {
		$$ref = " $$ref";
	}
}

# _unstuff(<text>)
# Un-space-stuffs <text>.
sub _unstuff {
	my $ref = shift;
	$$ref =~ s/^ //;
}

1;

__END__

=head1 NAME

Text::Flowed - text formatting routines for RFC2646 format=flowed

=head1 SYNOPSIS

 use Text::Flowed qw(reformat quote quote_fixed);

 print reformat($text, \%args); # Reformat some format=flowed text
 print quote($text);
 print quote_fixed($text);

=head1 DESCRIPTION

This module provides functions that deals with formatting data with
Content-Type 'text/plain; format=flowed' as described in RFC2646
(F<http://www.rfc-editor.org/rfc/rfc2646.txt>). In a nutshell,
format=flowed text solves the problem in plain text files where it is
not known which lines can be considered a logical paragraph, enabling
lines to be automatically flowed (wrapped and/or joined) as appropriate
when displaying.

In format=flowed, a soft newline is expressed as " \n", while hard
newlines are expressed as "\n". Soft newlines can be automatically
deleted or inserted as appropriate when the text is reformatted.

=over 4

=item B<reformat>($text [, \%args])

The reformat() function takes some format=flowed text as input, and
reformats it. Paragraphs will be rewrapped to the optimum width, with
lines being split or combined as necessary.

    my $formatted_text = reformat($text, \%args);

If $args->{quote} is true, a level of quoting will be added to the
beginning of every line.

If $args->{fixed} is true, unquoted lines in $text will not be
interpreted as format=flowed (with respect to parsing space-stuffing and
flowed lines). This is useful for processing messages posted in
web-based forums, which are not format=flowed, but preserve paragraph
structure due to paragraphs not having internal line breaks.

=item B<quote>($text)

quote($text) is an alias for reformat($text, {quote => 1}).

    my $quoted_text = quote($text);

=item B<quote_fixed>($text)

quote_fixed($text) is an alias for reformat($text, {quote => 1, fixed =>
1}).

	my $quoted_text = quote_fixed($text);

=item B<$MAX_LENGTH>

$MAX_LENGTH is the maximum length of line that reformat() or quote()
will generate. Any lines longer than this length will be rewrapped,
unless there is an excessively long word that makes this impossible, in
which case it will generate a long line containing only that word.

    $Text::Format::MAX_LENGTH = 79; # default

=item B<$OPT_LENGTH>

$OPT_LENGTH is the optimum line length. When reformat() or quote()
rewraps a paragraph, the resulting lines will not exceed this length
(except perhaps for excessively long words).

If a line exceeds $OPT_LENGTH but does not exceed $MAX_LENGTH, it might
not be rewrapped.

    $Text::Format::OPT_LENGTH = 72; # default

=back

=head1 COPYRIGHT

Copyright 2002-2003, Philip Mak

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
