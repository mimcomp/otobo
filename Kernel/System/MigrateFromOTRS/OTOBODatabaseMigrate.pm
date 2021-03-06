# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2020 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

package Kernel::System::MigrateFromOTRS::OTOBODatabaseMigrate;    ## no critic

use strict;
use warnings;

use parent qw(Kernel::System::MigrateFromOTRS::Base);

use version;

our @ObjectDependencies = (
    'Kernel::Language',
    'Kernel::System::DB',
    'Kernel::System::MigrateFromOTRS::CloneDB::Backend',
    'Kernel::System::Cache',
    'Kernel::System::DateTime',
    'Kernel::System::Log',
    'Kernel::System::SysConfig'
);

=head1 NAME

Kernel::System::MigrateFromOTRS::OTOBODatabaseMigrate - Checks if MySQL database is using correct charset.

=cut

sub CheckPreviousRequirement {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head1 NAME

Kernel::System::MigrateFromOTRS::OTOBODatabaseMigrate - Copy Database

=cut

=head2 Run()

Check for initial conditions for running this migration step.

Returns 1 on success:

    my $Result = $DBUpdateObject->Run();

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my %Result;

    # check needed stuff
    for my $Key (qw(DBData)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            $Result{Message}    = $Self->{LanguageObject}->Translate("Check if OTOBO version is correct.");
            $Result{Comment}    = $Self->{LanguageObject}->Translate( 'Need %s!', $Key );
            $Result{Successful} = 0;
            return \%Result;
        }
    }

    # check needed stuff
    for my $Key (qw(DBDSN DBType DBHost DBUser DBPassword DBName)) {
        if ( !$Param{DBData}->{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need DBData->$Key!"
            );
            $Result{Message}    = $Self->{LanguageObject}->Translate("Check if OTOBO version is correct.");
            $Result{Comment}    = $Self->{LanguageObject}->Translate( 'Need %s!', $Key );
            $Result{Successful} = 0;
            return \%Result;
        }
    }

    if ( $Param{DBData}->{DBType} =~ /oracle/ ) {
        for my $Key (qw(DBSID DBPort)) {
            if ( !$Param{DBData}->{$Key} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need DBData->$Key!"
                );
                $Result{Message}    = $Self->{LanguageObject}->Translate("Check if OTOBO version is correct.");
                $Result{Comment}    = $Self->{LanguageObject}->Translate( 'Need %s for Oracle db!', $Key );
                $Result{Successful} = 0;
                return \%Result;
            }
        }
    }

    # Set cache object with taskinfo and starttime to show current state in frontend
    my $CacheObject    = $Kernel::OM->Get('Kernel::System::Cache');
    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
    my $Epoch          = $DateTimeObject->ToEpoch();

    $CacheObject->Set(
        Type  => 'OTRSMigration',
        Key   => 'MigrationState',
        Value => {
            Task      => 'OTOBODatabaseMigrate',
            SubTask   => "Copy Database from type $Param{DBData}->{DBType} to OTOBO DB.",
            StartTime => $Epoch,
        },
    );

    # create CloneDB backend object
    my $CloneDBBackendObject = $Kernel::OM->Get('Kernel::System::MigrateFromOTRS::CloneDB::Backend');

    # create OTRS DB connection
    my $SourceDBObject = $CloneDBBackendObject->CreateOTRSDBConnection(
        OTRSDBSettings => $Param{DBData},
    );

    if ( !$SourceDBObject ) {
        $Result{Message}    = $Self->{LanguageObject}->Translate("Copy database.");
        $Result{Comment}    = $Self->{LanguageObject}->Translate("System was unable to connect to OTRS database.");
        $Result{Successful} = 0;
        return \%Result;
    }

    my $SanityResult = $CloneDBBackendObject->SanityChecks(
        OTRSDBObject => $SourceDBObject,
    );

    if ($SanityResult) {
        my $DataTransferResult = $CloneDBBackendObject->DataTransfer(
            OTRSDBObject   => $SourceDBObject,
            OTRSDBSettings => $Param{DBData},
        );

        if ( !$DataTransferResult ) {

            $Result{Message}    = $Self->{LanguageObject}->Translate("Copy database.");
            $Result{Comment}    = $Self->{LanguageObject}->Translate("System was unable to complete data transfer.");
            $Result{Successful} = 0;
            return \%Result;
        }
    }

    $Result{Message}    = $Self->{LanguageObject}->Translate("Copy database.");
    $Result{Comment}    = $Self->{LanguageObject}->Translate("Data transfer completed.");
    $Result{Successful} = 1;
    return \%Result;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTOBO project (L<https://otobo.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
