package prefork;

=pod

=head1 NAME

prefork - Optimize module loading across forking and non-forking scenarios

=head1 SYNOPSIS

In a module that normally delays module loading with require

  # Module Foo::Bar only uses This::That 25% of the time.
  # We want to preload in in forking scenarios (like mod_perl), but
  # we want to delay loading in non-forking scenarios (like CGI)
  use prefork 'This::That';
  
  sub do_something {
  	my $arg = shift;
  
  	# Load the module at run-time as normal
  	if ( $special_case ) {
  		require This::That;
  		This::That::blah(@_);
  	}
  }
  
  # Register a module to be loaded before forking directly
  prefork::prefork('Module::Name');

In a script or module that is going to be forking.

  package Module::Forker;
  
  # Enable forking mode
  use prefork ':enable';
  
  # Or call it directly
  prefork::enable();

=head1 INTRODUCTION

The task of optimizing module loading in Perl tends to move in two different
directions, depending on the context.

In a procedural context, such as scripts and CGI-type situations, you can
improve the load times and memory usage by loading a module at run-time,
only once you are sure you will need it.

In the other common load profile for perl applications, the application
will start up and then fork off various worker processes. To take full
advantage of memory copy-on-write features, the application should load
as many modules as possible before forking to prevent them consuming memory
in multiple worker processes.

Unfortunately, the strategies used to optimise for these two load profiles
are diametrically opposed. What improves a situation for one tends to
make life worse for the other.

=head1 DESCRIPTION

The prefork pragma is intended to allow module writers to optimise module
loading for B<both> scenarios with as little additional code as possible.

The prefork.pm is intended to serve as a central and optional marshalling
point for state detection (are we running in procedural or pre-forking
mode) and to act as a relatively light-weight module loader.

=head2 Loaders and Forkers

prefork is intended to be used in two different ways.

The first is by a module that wants to indicate that another module should
be loaded before forking. This is known as a "Loader".

The other is a script or module that will be initiating the forking. It
will tell prefork.pm that it is either going to fork, or is about to fork,
and that the modules previously mentioned by the Loaders should be loaded
immediately.

=head2 Usage as a Pragma

A Loader can register a module to be loaded using the following

  use prefork 'My::Module';

A Forker can indicate that it will be forking with the following

  use prefork ':enable';

In any use of prefork as a pragma, you can only pass a single value as
argument. Any additional arguments will be ignored. (This may throw an
error in future versions).

=head2 Compatbility with mod_perl and others

Part of the design of prefork, and it's minimalistic nature, is that it is
intended to work easily with existing modules, needing only small changes.

For example, prefork itself will detect the $ENV{MOD_PERL} environment
variable and automatically start in forking mode.

Over time, we also intend to build in additional compatbility with other
modules involved with dynamic loading, such as Class::Autouse and others.

=head2 Modules Compatible With prefork.pm

=over 4

=item mod_perl

=back

=head1 FUNCTIONS

=cut

use 5.005;
use strict;
use Carp ();

use vars qw{$VERSION $FORKING %MODULES};
BEGIN {
	$VERSION = '0.01_01';

	# The main state variable for this package.
	# Are we in preforking mode.
	$FORKING = '';

	# The queue of modules to ensure are loaded
	%MODULES = ();

	# Early detection of preforking scenarios
	$FORKING = 1 if $ENV{MOD_PERL};
}

sub import {
	return 1 unless $_[1];
	$_[1] eq ':enable' ? enable() : prefork($_[1]);
}

=pod

=head2 prefork $module

The 'prefork' function indicates that a module should be loaded before
the process will fork. If already in forking mode the module will be
loaded immediately.

Otherwise it will be added to a queue to be loaded later if it recieves
instructions that it is going to be forking.

Returns true on success, or dies on error.

=cut

sub prefork ($) {
	# Just hand straight to require if enabled
	my $module = defined $_[0] ? "$_[0]" : ''
		or Carp::croak 'You did not pass a module name to prefork';
	$module =~ /^[^\W\d]\w*(?:(?:'|::)[^\W\d]\w*)*$/
		or Carp::croak "'$module' is not a module name";
	my $file = join( '/', split /(?:\'|::)/, $module ) . '.pm';

	# Is it already loaded or queued
	return 1 if $INC{$file};
	return 1 if $MODULES{$module};

	# Load now if enabled, or add to the module list
	if ( $FORKING ) {
		require $file;
	} else {
		$MODULES{$module} = $file;
	}

	1;
}

=pod

=head2 enable

The C<enable> function indicates to the prefork module that the process is
going to fork, possibly immediately.

When called, prefork.pm will immediately load all outstanding modules, and
will set a flag so that any further 'prefork' calls will load the module
at that time.

Returns true, dieing as normal is there is a problem loading a module.

=cut

sub enable () {
	# Turn on the PREFORK flag, so any additional
	# 'use prefork ...' calls made during loading
	# will load immediately.
	$FORKING = 1;

	# Load all of the modules not yet loaded
	foreach my $module ( sort keys %MODULES ) {
		my $file = $MODULES{$module};

		# Has it been loaded since we were told about it
		next if $INC{$file};

		# Load the module.
		require $file;
	}

	# Clear the modules list
	%MODULES = ();

	1;
}

1;

=pod

=head1 SUPPORT

Bugs should be always submitted via the CPAN bug tracker, located at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=prefork>

For other issues, contact the author.

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Thank you to Phase N Australia (L<http://phase-n.com/>) for permitting
the open sourcing and release of this distribution.

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
