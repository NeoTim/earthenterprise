#!/usr/bin/perl -w-
#
# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package AssetGen;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(ReadSrcFile
             EmitAutoGeneratedWarning
             EnsureDirExists
             $config
             @ConfigHistory
             $name
             $base
             $type
             $subtype
             $withreuse
             $haveExtraUpdateInfo
             $missingconfigok
             $formaltypearg
             $forwardtypearg
             $actualtypearg
             $typeref
             $hasinputs
             $formalinputarg
             $forwardinputarg
             $actualinputarg
             $formalcachedinputarg
             $singleformalcachedinputarg
             $forwardcachedinputarg
             $singleforwardcachedinputarg
             $actualcachedinputarg
             $formalExtraUpdateArg
             $singleFormalExtraUpdateArg
             $forwardExtraUpdateArg
             $singleForwardExtraUpdateArg
             $inputsUpToDate
             $deprecated
             $debugIsUpToDate
             $haveBindConfig
             @modify_resistant_config_members
             );

use strict;
use FindBin;
use File::Basename;


our $config;
our @ConfigHistory;
our $name = '';
our $base;
our $type;
our $subtype;
our $withreuse;
our $haveExtraUpdateInfo;
our $missingconfigok;
our $formaltypearg;
our $forwardtypearg;
our $actualtypearg;
our $typeref;
our $hasinputs;
our $formalinputarg;
our $forwardinputarg;
our $actualinputarg;
our $formalcachedinputarg;
our $singleformalcachedinputarg;
our $forwardcachedinputarg;
our $singleforwardcachedinputarg;
our $actualcachedinputarg;
our $formalExtraUpdateArg;
our $singleFormalExtraUpdateArg;
our $forwardExtraUpdateArg;
our $singleForwardExtraUpdateArg;
our $inputsUpToDate;
our $deprecated = 0;
our $debugIsUpToDate;
our $haveBindConfig;
our @modify_resistant_config_members;


sub EmitAutoGeneratedWarning
{
    my ($fh, $cs) = @_;
    $cs = '//' unless defined $cs;
    print $fh <<WARNING;
$cs ***************************************************************************
$cs ***  This file was AUTOGENERATED with the following command:
$cs ***
$cs ***  $FindBin::Script $main::thiscommand
$cs ***
$cs ***  Any changes made here will be lost.
$cs ***************************************************************************
WARNING
}

sub EnsureDirExists
{
    my $dir = dirname($_[0]);
    if (! -d $dir) {
        EnsureDirExists($dir);
        mkdir($dir) || die "Unable to mkdir $dir: $!\n";
    }
}


sub ReadSrcFile
{
    my $srcname = shift;
    my $confhash = shift;

    $confhash->{'Asset.h'} = '';
    $confhash->{'Asset.cpp'} = '';
    $confhash->{'AssetD.h'} = '';
    $confhash->{'AssetD.cpp'} = '';

    my $srcfh;
    open($srcfh, $srcname) || die "Unable to open $srcname: $!\n";
    my $line = <$srcfh>;
    while (defined($line)) {
        if ($line =~ /^#config\s+(\w+)\s+(\S+)/) {
            my $tag = "$1";
            my $val = "$2";
            if ($tag =~ /_array$/) {
                push(@{$confhash->{$tag}}, "$val");
            } else {
              $confhash->{$tag} = $val;
            }
            if ($tag eq 'Name') {
                $name = "$val";
                $confhash->{"${name}AssetImpl"} = '';
                $confhash->{"${name}AssetVersionImpl"} = '';
                $confhash->{"${name}AssetImplD"} = '';
                $confhash->{"${name}AssetVersionImplD"} = '';
            }
        } elsif ($line =~ m,^// ===== $name(\S+) =====,) {
            my $file = $1;
            my $content = '';
            $line = <$srcfh>;
            while ($line && ($line !~ m,^// ===== $name(\S+) =====,)) {
                if ($line =~ /^class (${name}Asset\w+) \{/) {
                    my $class = $1;
                    my $classcontent = '';
                    $line = <$srcfh>;
                    while ($line && ($line !~ /^\};?$/)) {
                        $classcontent .= $line;
                        $line = <$srcfh>;
                    }
                    if ($line) {
                        $line = <$srcfh>; # skip closing '}'
                    }
                    $confhash->{$class} = $classcontent;
                    next;
                }

                $content .= $line;
                $line = <$srcfh>;
            }

            $confhash->{$file} = $content;

            next; # don't read next line, reuse the one I've got
        }
        $line = <$srcfh>;
    }
    close($srcfh);


    # set up some global variables
    $base = $confhash->{Base};
    if ($base !~ /^(Leaf|Composite)$/) {
        warn "\#config Base must be either Leaf or Composite.\n";
        main::usage();
    }
    $type    = $confhash->{FixedType};
    $subtype = $confhash->{Subtype};
    if ((exists $confhash->{Config} && exists $confhash->{ConfigHistory})) {
        warn "\#config Config and \#config ConfigHistory cannot both be specified.\n";
        main::usage();
        
    }
    if (exists $confhash->{Config}) {
        $config  = $confhash->{Config};
        @ConfigHistory = ( $config );
    } elsif (exists $confhash->{ConfigHistory}) {
        @ConfigHistory = split(/,/, $confhash->{ConfigHistory});
        $config = $ConfigHistory[$#ConfigHistory];
    } else {
        warn "You must specify either \#config Config or \#config ConfigHistory.\n";
        main::usage();
    }
   
    if (exists $confhash->{ModifyResistantConfigMembers}) {
        @modify_resistant_config_members =
            split(/,/, $confhash->{ModifyResistantConfigMembers});
    }



    $deprecated = $confhash->{Deprecated};
    $hasinputs = !$confhash->{NoInputs};
    if ($type &&
        $type !~ /^(Imagery|Terrain|Vector|Database|Map|KML)$/) {
        warn "Invalid \#config FixedType: $type\n";
        main::usage();
    }
    $withreuse = $confhash->{WithReuse};
    $haveExtraUpdateInfo = $confhash->{HaveExtraUpdateInfo};
    $missingconfigok = $confhash->{MissingConfigOK};
    $debugIsUpToDate = $confhash->{DebugIsUpToDate};
    $haveBindConfig = $confhash->{HaveBindConfig};

    if ($haveExtraUpdateInfo && $haveBindConfig) {
        die "HaveExtraUpdateInfo and HaveBindConfig are exclusive\n";
    }
    if ($withreuse && $haveBindConfig) {
        die "WithReuse and HaveBindConfig are exclusive\n";
    }


    $formaltypearg = $type ? '' : ', AssetDefs::Type type_';
    $forwardtypearg = $type ? '' : ', type_';
    $actualtypearg = $type ? "AssetDefs::$type" : 'type_';
    $typeref = $type ? "AssetDefs::$type" : 'type_';

    $formalinputarg = $hasinputs?'const MTVector<SharedString>& inputs_,':'';
    $forwardinputarg = $hasinputs ? 'inputs_,' : '';
    $actualinputarg = $hasinputs ? 'inputs_' : 'MTVector<SharedString>()';

    $formalcachedinputarg = $hasinputs?',const std::vector<AssetVersion>& cachedinputs_':'';
    $singleformalcachedinputarg = $hasinputs?'const std::vector<AssetVersion>& cachedinputs_':'';
    $forwardcachedinputarg = $hasinputs ? ',cachedinputs_' : '';
    $singleforwardcachedinputarg = $hasinputs ? 'cachedinputs_' : '';
    $actualcachedinputarg = $hasinputs ? 'inputs_' : 'std::vector<AssetVersion>()';
    $formalExtraUpdateArg = $haveExtraUpdateInfo ? ",const ${name}ExtraUpdateArg &extra" : '';
    $forwardExtraUpdateArg = $haveExtraUpdateInfo ? ',extra' : '';
    $singleFormalExtraUpdateArg  = $haveExtraUpdateInfo ? "const ${name}ExtraUpdateArg &extra" : '';
    $singleForwardExtraUpdateArg = $haveExtraUpdateInfo ? 'extra' : '';
    if ($hasinputs) {
        $inputsUpToDate = 'InputsUpToDate(version, cachedinputs_)';
    } else {
        $inputsUpToDate = 'true /* inputsUpToDate */';
    }
}

1;
