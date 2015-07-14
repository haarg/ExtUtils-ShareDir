package ExtUtils::ShareDir;
use strict;
use warnings;

our $VERSION = '0.001000';
$VERSION = eval $VERSION;

use ExtUtils::MakeMaker ();
use File::Find ();
my $CAN_DECODE = eval { require ExtUtils::MakeMaker::Locale; };

our @ISA = ();

sub special_targets {
    my $self = shift;
    my $targets = $self->SUPER::special_targets(@_);
    $targets =~ s/^(\.PHONY: .*)/$1 sharedir/m;
    return $targets;
}

sub init_INST {
    my $self = shift;
    my $out = $self->SUPER::init_INST(@_);
    $self->{INST_SHARE} ||= $self->catdir('$(INST_LIB)', 'auto', 'share');
    return $out;
}

sub constants {
    my $self = shift;
    my $constants = $self->SUPER::constants(@_);
    $constants .= qq{
INST_SHARE       = $self->{INST_SHARE}
};
    return $constants;
}

sub sharedir {
    my ($self, %share) = @_;
    return '' unless %share;

    my %files;
    $self->_sharedir_find_files(\%files, $share{dist}, [qw/ $(INST_SHARE) dist $(DISTNAME) /], \%share) if $share{dist};
    for my $module (keys %{ $share{module} || {} }) {
        my $destination = [ qw/$(INST_SHARE) module/, $module ];
        $self->_sharedir_find_files(\%files, $share{module}{$module}, $destination, \%share);
    }
    my $pm_to_blib = $self->oneliner(q{pm_to_blib({@ARGV}, '$(INST_LIB)')}, ['-MExtUtils::Install']);
    return "\npure_all :: sharedir\n\nsharedir : \n" . join '', map { "\t\$(NOECHO) $_\n" } $self->split_command($pm_to_blib, %files);
}

sub _sharedir_find_files {
    my ($self, $files, $source, $sink, $options) = @_;
    File::Find::find({
        wanted => sub {
            if (-d) {
                $File::Find::prune = 1 if $options->{skip_dotdir} && /^\./;
                return;
            }
            return if $options->{skip_dotfile} && /^\./;
            $files->{$_} = $self->catfile(@{$sink}, $_);
        },
        no_chdir => 1,
    }, $source);
    return;
}

my $_verify_att = \&ExtUtils::MakeMaker::_verify_att;
sub _verify_att {
    my ($att) = @_;

    my $sharedir = delete $att->{sharedir};
    $_verify_att->(@_);
    if ($sharedir) {
        my $given  = ref $sharedir;
        if (ref $sharedir ne 'HASH') {
            my ($has, $takes) = map { _format_att($_) } (ref $sharedir, 'HASH');

            warn "WARNING: sharedir takes a $takes not a $has.\n".
                 "         Please inform the author.\n";
        }
        $att->{sharedir} = $sharedir;
    }
}

sub install_sharedir_shim {
    return
        if ExtUtils::MakeMaker->can('sharedir');

    @ISA = @MM::ISA;
    @MM::ISA = (__PACKAGE__);

    *ExtUtils::MakeMaker::_verify_att = \&_verify_att;

    for my $array (
        \@ExtUtils::MakeMaker::MM_Sections,
        \@ExtUtils::MakeMaker::Overridable,
    ) {
        @$array = map {
            $_ eq 'post_constants' ? ($_, 'sharedir') : ($_)
        } @$array;
    }
}

{
    package # hide from PAUSE
        inc::ExtUtils::ShareDir;

    sub import {
        ExtUtils::ShareDir::install_sharedir_shim();
    }
}

1;


__END__

=head1 NAME

ExtUtils::ShareDir - Sharedir shim for ExtUtils::MakeMaker

=head1 SYNOPSIS

  use ExtUtils::MakeMaker;
  use inc::ExtUtils::ShareDir;

  WriteMakefile(
    ...
    sharedir => {dist => 'share', module => { Foo => 'foo', ... }},
  );

=head1 DESCRIPTION

This module provides a shim for older versions of ExtUtils::MakeMaker that don't
support sharedir installation.  It is meant to be packaged in inc/

=cut
