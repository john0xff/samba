# Samba Build System
# - create output for Makefile
#
#  Copyright (C) Stefan (metze) Metzmacher 2004
#  Copyright (C) Jelmer Vernooij 2005
#  Released under the GNU GPL

package smb_build::makefile;
use smb_build::output;
use File::Basename;
use strict;

use Cwd 'abs_path';

sub new($$$)
{
	my ($myname, $config, $mkfile) = @_;
	my $self = {};

	bless($self, $myname);

	$self->_set_config($config);

	$self->{output} = "";

	$self->output("################################################\n");
	$self->output("# Autogenerated by source4/build/smb_build/makefile.pm #\n");
	$self->output("################################################\n");
	$self->output("\n");
	$self->output($mkfile);

	return $self;
}

sub _set_config($$)
{
	my ($self, $config) = @_;

	$self->{config} = $config;

	if (not defined($self->{config}->{srcdir})) {
		$self->{config}->{srcdir} = '.';
	}

	if (not defined($self->{config}->{builddir})) {
		$self->{config}->{builddir}  = '.';
	}

	if ($self->{config}->{prefix} eq "NONE") {
		$self->{config}->{prefix} = $self->{config}->{ac_default_prefix};
	}

	if ($self->{config}->{exec_prefix} eq "NONE") {
		$self->{config}->{exec_prefix} = $self->{config}->{prefix};
	}
}

sub output($$)
{
	my ($self, $text) = @_;

	$self->{output} .= $text;
}

sub _prepare_mk_files($)
{
	my $self = shift;
	my @tmp = ();

	foreach (@smb_build::config_mk::parsed_files) {
		s/ .*$//g;
		push (@tmp, $_);
	}

	$self->output("MK_FILES = " . array2oneperline(\@tmp) . "\n");
}

sub array2oneperline($)
{
	my $array = shift;
	my $output = "";

	foreach (@$array) {
		next unless defined($_);

		$output .= " \\\n\t\t$_";
	}

	return $output;
}

sub _prepare_list($$$)
{
	my ($self,$ctx,$var) = @_;
	my @tmparr = ();

	push(@tmparr, @{$ctx->{$var}}) if defined($ctx->{$var});

	my $tmplist = array2oneperline(\@tmparr);
	return if ($tmplist eq "");

	$self->output("$ctx->{NAME}_$var =$tmplist\n");
}

sub PythonModule($$)
{
	my ($self,$ctx) = @_;

	$self->_prepare_list($ctx, "FULL_OBJ_LIST");
	$self->_prepare_list($ctx, "DEPEND_LIST");
	$self->_prepare_list($ctx, "LINK_FLAGS");

	$self->output("\$(eval \$(call python_c_module_template,$ctx->{LIBRARY_REALNAME},\$($ctx->{NAME}_DEPEND_LIST) \$($ctx->{NAME}_FULL_OBJ_LIST), \$($ctx->{NAME}\_FULL_OBJ_LIST) \$($ctx->{NAME}_LINK_FLAGS)))\n");
}

sub SharedModule($$)
{
	my ($self,$ctx) = @_;

	my $sane_subsystem = lc($ctx->{SUBSYSTEM});
	$sane_subsystem =~ s/^lib//;
	
	$self->output("PLUGINS += $ctx->{SHAREDDIR}/$ctx->{LIBRARY_REALNAME}\n");
	$self->output("\$(eval \$(call shared_module_install_template,$sane_subsystem,$ctx->{LIBRARY_REALNAME}))\n");

	$self->_prepare_list($ctx, "FULL_OBJ_LIST");
	$self->_prepare_list($ctx, "DEPEND_LIST");
	$self->_prepare_list($ctx, "LINK_FLAGS");

	if (defined($ctx->{INIT_FUNCTION}) and $ctx->{INIT_FUNCTION_TYPE} =~ /\(\*\)/ and not ($ctx->{INIT_FUNCTION} =~ /\(/)) {
		$self->output("\$($ctx->{NAME}_OBJ_FILES): CFLAGS+=-D$ctx->{INIT_FUNCTION}=samba_init_module\n");
	}

	$self->output("\$(eval \$(call shared_module_template,$ctx->{SHAREDDIR}/$ctx->{LIBRARY_REALNAME}, \$($ctx->{NAME}_DEPEND_LIST) \$($ctx->{NAME}_FULL_OBJ_LIST), \$($ctx->{NAME}\_FULL_OBJ_LIST) \$($ctx->{NAME}_LINK_FLAGS)))\n");


	if (defined($ctx->{ALIASES})) {
		$self->output("\$(eval \$(foreach alias,". join(' ', @{$ctx->{ALIASES}}) . ",\$(call shared_module_alias_template,$ctx->{SHAREDDIR}/$ctx->{LIBRARY_REALNAME},$sane_subsystem,\$(alias))))\n");
	}
}

sub StaticLibraryPrimitives($$)
{
	my ($self,$ctx) = @_;
 
 	$self->output("$ctx->{NAME}_OUTPUT = $ctx->{OUTPUT}\n");
	$self->_prepare_list($ctx, "FULL_OBJ_LIST");
}

sub SharedLibraryPrimitives($$)
{
	my ($self,$ctx) = @_;

	if (not grep(/STATIC_LIBRARY/, @{$ctx->{OUTPUT_TYPE}})) {
		$self->output("$ctx->{NAME}_OUTPUT = $ctx->{OUTPUT}\n");
		$self->_prepare_list($ctx, "FULL_OBJ_LIST");
	}
}

sub SharedLibrary($$)
{
	my ($self,$ctx) = @_;

	$self->output("SHARED_LIBS += $ctx->{RESULT_SHARED_LIBRARY}\n");

	$self->_prepare_list($ctx, "DEPEND_LIST");
	$self->_prepare_list($ctx, "LINK_FLAGS");

	$self->output("\$(eval \$(call shared_library_template,$ctx->{RESULT_SHARED_LIBRARY}, \$($ctx->{NAME}_DEPEND_LIST) \$($ctx->{NAME}_FULL_OBJ_LIST), \$($ctx->{NAME}\_FULL_OBJ_LIST) \$($ctx->{NAME}_LINK_FLAGS),$ctx->{SHAREDDIR}/$ctx->{LIBRARY_SONAME},$ctx->{SHAREDDIR}/$ctx->{LIBRARY_DEBUGNAME}))\n");
}

sub MergedObj($$)
{
	my ($self, $ctx) = @_;

	$self->output("\$(call partial_link_template, $ctx->{OUTPUT}, \$($ctx->{NAME}_OBJ_FILES))\n");
}

sub InitFunctions($$)
{
	my ($self, $ctx) = @_;
	$self->output("\$($ctx->{NAME}_OBJ_FILES): CFLAGS+=-DSTATIC_$ctx->{NAME}_MODULES=\"\$($ctx->{NAME}_INIT_FUNCTIONS)$ctx->{INIT_FUNCTION_SENTINEL}\"\n");
}

sub StaticLibrary($$)
{
	my ($self,$ctx) = @_;

	$self->output("STATIC_LIBS += $ctx->{RESULT_STATIC_LIBRARY}\n") if ($ctx->{TYPE} eq "LIBRARY");
	$self->output("$ctx->{NAME}_OUTPUT = $ctx->{OUTPUT}\n");
	$self->output("$ctx->{RESULT_STATIC_LIBRARY}: \$($ctx->{NAME}_FULL_OBJ_LIST)\n");
}

sub Binary($$)
{
	my ($self,$ctx) = @_;

	unless (defined($ctx->{INSTALLDIR})) {
	} elsif ($ctx->{INSTALLDIR} eq "SBINDIR") {
		$self->output("\$(eval \$(call sbinary_install_template,$ctx->{RESULT_BINARY}))\n");
	} elsif ($ctx->{INSTALLDIR} eq "BINDIR") {
		$self->output("\$(eval \$(call binary_install_template,$ctx->{RESULT_BINARY}))\n");
	}

	$self->_prepare_list($ctx, "FULL_OBJ_LIST");
	$self->_prepare_list($ctx, "DEPEND_LIST");
	$self->_prepare_list($ctx, "LINK_FLAGS");

	if (defined($ctx->{USE_HOSTCC}) && $ctx->{USE_HOSTCC} eq "YES") {
$self->output("\$(eval \$(call host_binary_link_template, $ctx->{RESULT_BINARY}, \$($ctx->{NAME}_FULL_OBJ_LIST) \$($ctx->{NAME}_DEPEND_LIST), \$($ctx->{NAME}_LINK_FLAGS)))\n");
	} else {
$self->output("\$(eval \$(call binary_link_template, $ctx->{RESULT_BINARY}, \$($ctx->{NAME}_FULL_OBJ_LIST) \$($ctx->{NAME}_DEPEND_LIST), \$($ctx->{NAME}_LINK_FLAGS)))\n");
	}
}

sub write($$)
{
	my ($self, $file) = @_;

	$self->_prepare_mk_files();

	$self->output("ALL_OBJS = " . array2oneperline($self->{all_objs}) . "\n");

	open(MAKEFILE,">$file") || die ("Can't open $file\n");
	print MAKEFILE $self->{output};
	close(MAKEFILE);

	print __FILE__.": creating $file\n";
}

my $sort_available = eval "use sort 'stable'; return 1;";
$sort_available = 0 unless defined($sort_available);

sub by_path {
	return  1 if($a =~ m#^\-I/#);
    	return -1 if($b =~ m#^\-I/#);
	return  0;
}

sub CFlags($$)
{
	my ($self, $key) = @_;

	my $srcdir = $self->{config}->{srcdir};
	my $builddir = $self->{config}->{builddir};

	my $src_ne_build = ($srcdir ne $builddir) ? 1 : 0;

	return unless defined ($key->{FINAL_CFLAGS});
	return unless (@{$key->{FINAL_CFLAGS}} > 0);

	my @sorted_cflags = @{$key->{FINAL_CFLAGS}};
	if ($sort_available) {
		@sorted_cflags = sort by_path @{$key->{FINAL_CFLAGS}};
	}

	# Rewrite CFLAGS so that both the source and the build
	# directories are in the path.
	my @cflags = ();
	foreach my $flag (@sorted_cflags) {
		if($src_ne_build) {
			if($flag =~ m#^-I([^/].*$)#) {
				my $dir = $1;
				if ($dir =~ /^\$\(/) {
					push (@cflags, $flag);
					next;
				}
				$dir =~ s#^\$\((?:src|build)dir\)/?##;
				push(@cflags, "-I$builddir/$dir", "-I$srcdir/$dir");
				next;
			}
		}
		push(@cflags, $flag);
	}
	
	my $cflags = join(' ', @cflags);

	$self->output("\$(patsubst %.ho,%.d,\$($key->{NAME}_OBJ_FILES:.o=.d)) \$($key->{NAME}_OBJ_FILES): CFLAGS+= $cflags\n");
}

1;