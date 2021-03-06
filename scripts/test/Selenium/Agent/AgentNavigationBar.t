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

use strict;
use warnings;
use utf8;

# Set up the test driver $Self when we are running as a standalone script.
use if __PACKAGE__ ne 'Kernel::System::UnitTest::Driver', 'Kernel::System::UnitTest::RegisterDriver';

use vars (qw($Self));

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # Create test user.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        # Get test user ID.
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentDashboard");

        # Wait for the drag & drop initialization to be completed.
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#nav-Admin.CanDrag').length;"
        );

        # TODO: remove limitation to firefox.
        if ( $Selenium->{browser_name} eq 'firefox' ) {
            $Self->True(
                1,
                "TODO: DragAndDrop is currently disabled in Firefox",
            );
        }
        else {

            # Try to drag the admin item to the front of the nav bar.
            $Selenium->DragAndDrop(
                Element      => 'li#nav-Admin',
                Target       => 'ul#Navigation',
                TargetOffset => {
                    X => 0,
                    Y => 0,
                }
            );

            # Wait for the success arrow to show up.
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('#NavigationContainer > .fa-check').length"
            );

            # Now reload the page and see if the new position of the admin item has been re-stored correctly
            # (should be the first element in the list now).
            $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentDashboard");

            # Wait for the navigation bar to be visible.
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && parseInt(\$('#Navigation').css('opacity'), 10) == 1;"
            );

            # Check if the admin item is in the correct position.
            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#Navigation li:first-child').attr('id');"
                ),
                'nav-Admin',
                'Admin item found on correct position',
            );
        }
    }
);

1;
