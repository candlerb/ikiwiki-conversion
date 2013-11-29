# conversion - a configurable convertor for binary assets.
#
# Copyright © Brian Candler <b.candler@pobox.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY IKIWIKI AND CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE FOUNDATION
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

package IkiWiki::Plugin::conversion;

use warnings;
use strict;
use IkiWiki 3.00;
use Cwd;

sub import {
    hook(type=>"getsetup", id=>"conversion", call=>\&getsetup);
    hook(type=>"checkconfig", id=>"conversion", call=>\&checkconfig);
    hook(type=>"needsbuild", id=>"conversion", call=>\&needsbuild);
}

sub getsetup () {
    return
    plugin => {
        safe => 1,
        rebuild => 1,
    },
}

sub checkconfig {
    if (!defined $config{conversion} || ref $config{conversion} ne "ARRAY") {
        error(sprintf(gettext("Must specify '%s' and it must be a list"), "conversion"));
    }
    # http://ikiwiki.info/bugs/structured_config_data_is_mangled/
    for (my $i=0; $i < @{$config{conversion}}; $i++) {
      $config{conversion}->[$i] = YAML::XS::Load($config{conversion}->[$i]) if
          ref $config{conversion}->[$i] ne 'HASH';
    }
}

sub needsbuild {
    my $files=shift;
    my $nfiles=[];
    foreach my $f (@$files) {
        my $copy_input = 0;
        my %created_ext = ();
        $f =~ /^(.*?)([^\/]*?)([^.]*)$/;
        my ($prefix, $basename, $ext) = ($1, $2, $3);
        foreach my $c (@{$config{conversion}}) {
            next unless $c->{from} && $c->{to};
            my $found = 0;
            my $exts = $c->{from};
            if (ref $exts ne "ARRAY") {
                my @exts = split ' ', $exts;
                $exts = \@exts;
            }
            foreach my $tryext (@$exts) {
                $found = 1 if $ext eq $tryext;
            }
            next unless $found;
            next if $c->{match} && $f !~ $c->{match};
            my $outext = $c->{to};
            next if $created_ext{$outext};
            $created_ext{$outext} = 1;
            $copy_input = 1 if $c->{copy_input};
            my $g = "$prefix$basename$outext";
            debug("converting $f to $g");
            will_render($f, $g);
            my $input = srcfile($f);
            my $output = "$config{destdir}/$g";
            my @cmd;
            if (ref $c->{command} eq "ARRAY") {
                @cmd = @{$c->{command}};
            } else {
                @cmd = ($c->{command});
            }
            my $subs = [
                ["INPUTDIR",   IkiWiki::dirname($input)],
                ["OUTPUTDIR",  IkiWiki::dirname($output)],
                ["INPUTFILE",  $input],
                ["OUTPUTFILE", $output],
                ["INPUTNAME",  "$basename$ext"],
                ["OUTPUTNAME", "$basename$outext"],
                ["INPUTEXT",   $ext],
                ["OUTPUTEXT",  $outext],
            ];
            foreach my $c (@cmd) {
                foreach my $sub (@$subs) {
                    $c =~ s/\$$sub->[0]\b/$sub->[1]/g;
                }
            }
            my $olddir = getcwd;
            if ($c->{chdir}) {
                my $workdir = $c->{chdir};
                $workdir =~ s/\$$subs->[0]->[0]\b/$subs->[0]->[1]/g;
                $workdir =~ s/\$$subs->[1]->[0]\b/$subs->[1]->[1]/g;
                chdir($workdir);
            }
            debug(join " ", @cmd);
            my $rc = system(@cmd);
            if ($c->{chdir}) {
                chdir($olddir);
            }
            if ($rc != 0) {
                error(sprintf(gettext("conversion failed: %s"), join(" ",@cmd)));
            }
        }
        push @$nfiles, $f if !%created_ext || $copy_input;
    };
    return $nfiles;
}

1;
