#
# Fink::VirtPackage class
#
# Fink - a package manager that downloads source and installs it
# Copyright (c) 2001 Christoph Pfisterer
# Copyright (c) 2001-2003 The Fink Package Manager Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA	 02111-1307, USA.
#

package Fink::VirtPackage;

use Fink::Config qw($config $basepath);
use POSIX qw(uname);
use Fink::Status;

use strict;
use warnings;

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION	 = 1.00;
	@ISA		 = qw(Exporter);
	@EXPORT		 = qw();
	@EXPORT_OK	 = qw();	# eg: qw($Var1 %Hashit &func3);
	%EXPORT_TAGS = ( );		# eg: TAG => [ qw!name1 name2! ],
}
our @EXPORT_OK;

my @xservers     = ('XDarwin', 'Xquartz', 'XDarwinQuartz');
my $the_instance = undef;

END { }				# module clean-up code here (global destructor)


### constructor

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = {};
	bless($self, $class);

	$self->initialize();

	$the_instance = $self;
	return $self;
}

### self-initialization

sub initialize {
	my $self = shift;
	my ($hash);
	my ($dummy);
	my ($darwin_version, $cctools_version, $cctools_single_module);
	# determine the kernel version
	($dummy,$dummy,$darwin_version) = uname();

	# now find the cctools version
	if (-x "/usr/bin/ld" and -x "/usr/bin/what") {
		foreach(`/usr/bin/what /usr/bin/ld`) {
			if (/cctools-(\d+)/) {
				$cctools_version = $1;
				last;
			}
		}
	}

	if (-x "/usr/bin/cc" and my $cctestfile = POSIX::tmpnam() and -x "/usr/bin/touch") {
		system("/usr/bin/touch ${cctestfile}.c");
		if (system("/usr/bin/cc -o ${cctestfile}.dylib ${cctestfile}.c -dynamiclib -single_module >/dev/null 2>\&1") == 0) {
			$cctools_single_module = '1.0';
		} else {
			$cctools_single_module = undef;
		}
		unlink($cctestfile);
		unlink("${cctestfile}.c");
		unlink("${cctestfile}.dylib");
	}
	# create dummy object for kernel version
	$hash = {};
	$hash->{package} = "darwin";
	$hash->{status} = "install ok installed";
	$hash->{version} = $darwin_version."-1";
	$hash->{description} = "[virtual package representing the kernel]";
	$self->{$hash->{package}} = $hash;
	
	# create dummy object for system version, if this is OS X at all
	if (Fink::Services::get_sw_vers() ne 0) {
		$hash = {};
		$hash->{package} = "macosx";
		$hash->{status} = "install ok installed";
		$hash->{version} = Fink::Services::get_sw_vers()."-1";
		$hash->{description} = "[virtual package representing the system]";
		$self->{$hash->{package}} = $hash;
	}

	# create dummy object for system perl
	if (defined Fink::Services::get_system_perl_version()) {
		$hash = {};
		$hash->{package} = "system-perl";
		$hash->{status} = "install ok installed";
		$hash->{version} = Fink::Services::get_system_perl_version()."-1";
		$hash->{description} = "[virtual package representing perl]";

		$hash->{provides} = Fink::Services::get_system_perl_version();
		$hash->{provides} =~ s/\.//g;
		$hash->{provides} = 'perl' . $hash->{provides} . '-core';

		$self->{$hash->{package}} = $hash;
	}

	# create dummy object for java
	my $javadir = '/System/Library/Frameworks/JavaVM.framework/Versions';
	if (opendir(DIR, $javadir)) {
		for my $dir ( sort readdir(DIR)) {
			chomp($dir);
			next if ($dir =~ /^\.\.?$/);
			if ($dir =~ /^\d[\d\.]*$/ and -d $javadir . '/' . $dir . '/Commands') {
				# chop the version down to major/minor without dots
				my $ver = $dir;
				$ver =~ s/[^\d]+//g;
				$ver =~ s/^(..).*$/$1/;
				$hash = {};
				$hash->{package}     = "system-java${ver}";
				$hash->{status}      = "install ok installed";
				$hash->{version}     = $dir . "-1";
				$hash->{description} = "[virtual package representing Java $dir]";
				$self->{$hash->{package}} = $hash;

				if (-d $javadir . '/' . $dir . '/Headers') {
					$hash = {};
					$hash->{package}     = "system-java${ver}-dev";
					$hash->{status}      = "install ok installed";
					$hash->{version}     = $dir . "-1";
					$hash->{description} = "[virtual package representing Java $dir development headers]";
					$self->{$hash->{package}} = $hash;
				}
			}
		}
		closedir(DIR);
	}

	# create dummy object for cctools version, if version was found in Config.pm
	if (defined ($cctools_version)) {
		$hash = {};
		$hash->{package} = "cctools";
		$hash->{status} = "install ok installed";
		$hash->{version} = $cctools_version."-1";
		$hash->{description} = "[virtual package representing the developer tools]";
		$hash->{builddependsonly} = "true";
		$self->{$hash->{package}} = $hash;
	}

	# create dummy object for cctools-single-module, if supported
	if ($cctools_single_module) {
		$hash = {};
		$hash->{package} = "cctools-single-module";
		$hash->{status} = "install ok installed";
		$hash->{version} = $cctools_single_module."-1";
		$hash->{description} = "[virtual package, your dev tools support -single_module]";
		$hash->{builddependsonly} = "true";
		$self->{$hash->{package}} = $hash;
	}
	if ( -x '/usr/bin/gcc2' ) {
		$hash = {};
		$hash->{package} = "gcc2";
		$hash->{status} = "install ok installed";
		$hash->{version} = "2.9.5-1";
		$hash->{description} = "[virtual package representing the gcc2 compiler]";
		$hash->{builddependsonly} = "true";
		$self->{$hash->{package}} = $hash;
	}
	if ( -f '/usr/X11R6/lib/libX11.6.dylib' )
	{
		# check the status of xfree86 packages
		my $packagecount = 0;
		for my $packagename ('system-xfree86', 'xfree86-base', 'xfree86-rootless',
			'xfree86-base-threaded', 'system-xfree86-43', 'system-xfree86-42',
			'xfree86-base-shlibs', 'xfree86', 'system-xtools',
			'xfree86-base-threaded-shlibs', 'xfree86-rootless-shlibs',
			'xfree86-rootless-threaded-shlibs')
		{
			$packagecount++ if (Fink::Status->query_package($packagename));
		}

		# if no xfree86 packages are installed, put in our own placeholder
		if ($packagecount == 0) {
			my ($xver, $xvermaj, $xvermin, $xverrev) = check_x11_version();
			if (defined $xver and $xvermaj == 4)
			{
				$hash = {};
				$hash->{package} = "system-xfree86";
				$hash->{status} = "install ok installed";
				$hash->{version} = "2:${xvermaj}.${xvermin}-1";
				$hash->{description} = "[placeholder for user installed x11]";

				my @provides;

				my $found_xserver = 0;
				for my $xserver (@xservers) {
					if (-x '/usr/X11R6/bin/' . $xserver) {
						$found_xserver++;
						push(@provides, 'xserver');
						last;
					}
				}

				# "x11" is a regular x11 environment, shlibs + x server
				# "x11-shlibs" is provided for backwards-compatibility
				if ( has_lib('libX11.6.dylib') and $found_xserver ) {
					push(@provides, 'x11', 'x11-shlibs');
				}
				# "x11-dev" is for BuildDepends: on x11 packages
				if ( has_header('X11/Xlib.h') and has_lib('libX11.6.dylib') ) {
					push(@provides, 'x11-dev');
				}
				# now we do the same for libgl
				if ( has_lib('libGL.1.dylib') ) {
					push(@provides, 'libgl', 'libgl-shlibs');
				}
				if ( has_header('GL/gl.h') and has_lib('libGL.dylib') ) {
					push(@provides, 'libgl-dev');
				}
				if ( has_lib('libXft.dylib') and
						readlink('/usr/X11R6/lib/libXft.dylib') =~ /libXft\.1/ and
						has_header('X11/Xft/Xft.h') ) {
					push(@provides, 'xft1', 'xft1-dev');
				}
				if ( has_lib('libXft.1.dylib') ) {
					push(@provides, 'xft1-shlibs');
				}
				if ( has_lib('libXft.dylib') and
						readlink('/usr/X11R6/lib/libXft.dylib') =~ /libXft\.2/ and
						has_header('X11/Xft/XftCompat.h') ) {
					push(@provides, 'xft2', 'xft2-dev');
				}
				if ( has_lib('libXft.2.dylib') ) {
					push(@provides, 'xft2-shlibs');
				}
				if ( has_lib('libfontconfig.dylib') and
						readlink('/usr/X11R6/lib/libfontconfig.dylib') =~ /libfontconfig\.1/ and
						has_header('fontconfig/fontconfig.h') ) {
					push(@provides, 'fontconfig1', 'fontconfig1-dev');
				}
				if ( has_lib('libfontconfig.1.dylib') ) {
					push(@provides, 'fontconfig1-shlibs');
				}

				push(@provides, 'rman')               if (-x '/usr/X11R6/bin/rman');
				if (-f '/usr/X11R6/lib/libXt.6.dylib' and -x '/usr/bin/grep') {
					if (system('/usr/bin/grep', '-q', '-a', 'pthread_mutex_lock', '/usr/X11R6/lib/libXt.6.dylib') == 0) {
						push(@provides, 'xfree86-base-threaded-shlibs');
						push(@provides, 'xfree86-base-threaded') if (grep(/^x11$/, @provides));
					}
				}

				$hash->{provides} = join(', ', @provides);
				$self->{$hash->{package}} = $hash;
			}
		}    
	}
}

### query by package name
# returns false when not installed
# returns full version when installed and configured

sub query_package {
	my $self = shift;
	my $pkgname = shift;
	my ($hash);

	if (not ref($self)) {
		if (defined($the_instance)) {
			$self = $the_instance;
		} else {
			$self = Fink::VirtPackage->new();
		}
	}

	if (not exists $self->{$pkgname}) {
		return 0;
	}
	$hash = $self->{$pkgname};
	if (not exists $hash->{version}) {
		return 0;
	}
	return $hash->{version};
}

### retrieve whole list with versions
# doesn't care about installed status
# returns a hash ref, key: package name, value: hash with core fields
# in the hash, 'package' and 'version' are guaranteed to exist

sub list {
	my $self = shift;
	my ($list, $pkgname, $hash, $newhash, $field);

	if (not ref($self)) {
		if (defined($the_instance)) {
			$self = $the_instance;
		} else {
			$self = Fink::VirtPackage->new();
		}
	}

	$list = {};
	foreach $pkgname (keys %$self) {
		next if $pkgname =~ /^_/;
		$hash = $self->{$pkgname};
		next unless exists $hash->{version};

		$newhash = { 'package' => $pkgname, 'version' => $hash->{version} };
		foreach $field (qw(depends provides conflicts maintainer description status builddependsonly)) {
			if (exists $hash->{$field}) {
				$newhash->{$field} = $hash->{$field};
			}
		}
		$list->{$pkgname} = $newhash;
	}

	return $list;
}

sub has_header {
	my $headername = shift;
	my $dir;

	if ($headername =~ /^\//) {
		return (-f $headername);
	} else {
		for $dir ('/usr/X11R6/include', $basepath . '/include', '/usr/include') {
			return 1 if (-f $dir . '/' . $headername);
		}
	}
	return;
}

sub has_lib {
	my $libname = shift;
	my $dir;

	if ($libname =~ /^\//) {
		return (-f $libname);
	} else {
		for $dir ('/usr/X11R6/lib', $basepath . '/lib', '/usr/lib') {
			return 1 if (-f $dir . '/' . $libname);
		}
	}
	return;
}

### Check the installed x11 version
sub check_x11_version {
	my (@XF_VERSION_COMPONENTS, $XF_VERSION);
	for my $checkfile ('xterm.1', 'bdftruncate.1', 'gccmakedep.1') {
		if (-f "/usr/X11R6/man/man1/$checkfile") {
			if (open(CHECKFILE, "/usr/X11R6/man/man1/$checkfile")) {
				while (<CHECKFILE>) {
					if (/^.*Version\S* ([^\s]+) .*$/) {
						$XF_VERSION = $1;
						@XF_VERSION_COMPONENTS = split(/\.+/, $XF_VERSION, 3);
						last;
					}
				}
				close(CHECKFILE);
			} else {
				warn "could not read $checkfile: $!\n";
				return;
			}
		}
		last if (defined $XF_VERSION);
	}
	if (not defined $XF_VERSION) {
		for my $binary ('X', 'XDarwin', 'Xquartz') {
			if (-x '/usr/X11R6/bin/' . $binary) {
				if (open (XBIN, "/usr/X11R6/bin/$binary -version -iokit 2>\&1 |")) {
					while (my $line = <XBIN>) {
						if ($line =~ /XFree86 Version ([\d\.]+)/) {
							$XF_VERSION = $1;
							@XF_VERSION_COMPONENTS = split(/\.+/, $XF_VERSION, 3);
							last;
						}
					}
					close(XBIN);
				} else {
					print STDERR "couldn't run $binary: $!\n";
				}
				last;
			}
		}
	}
	if (not defined $XF_VERSION) {
		print STDERR "could not determine XFree86 version number\n";
		return;
	}
	return ($XF_VERSION, @XF_VERSION_COMPONENTS);
}
### EOF
1;
