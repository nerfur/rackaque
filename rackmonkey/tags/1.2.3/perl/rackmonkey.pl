#!/usr/bin/env perl
##############################################################################
# RackMonkey - Know Your Racks - http://www.rackmonkey.org                   #
# Version 1.2.%BUILD%                                                        #
# (C)2007 Will Green (wgreen at users.sourceforge.net)                       #
# Main RackMonkey CGI script                                                 #
##############################################################################

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use warnings;

use 5.006_001;

#use Data::Dumper; # for debug only - comment out from release versions

use DBI;
use HTML::Template;
use Time::Local;

use RackMonkey::CGI;
use RackMonkey::Engine;
use RackMonkey::Error;
use RackMonkey::Helper;
use RackMonkey::Conf;

our $VERSION = '1.2.%BUILD%';
our $AUTHOR = 'Will Green (wgreen at users.sourceforge.net)';

our ($template, $cgi);

$cgi = new RackMonkey::CGI;
	
eval 
{
	my $dbh = DBI->connect(DBDCONNECT, DBUSER, DBPASS, {AutoCommit => 1, RaiseError => 1, PrintError => 0, ShowErrorStatement => 1}); 
	checkSupportedDriver();
	my $backend = new RackMonkey::Engine($dbh);

	my $fullURL = $cgi->url;
	my $baseURL = $cgi->baseUrl;
	my $view = $cgi->view;
	my $id = $cgi->viewId;
	my $viewType = $cgi->viewType;
	my $act =  $cgi->act;
	my $orderBy = $cgi->orderBy;
	my $filterBy = $cgi->filterBy;

	if ($act) # perform act, and return status: 303 (See Other) to redirect to a view
	{
		my $updateUser = $ENV{'REMOTE_USER'} || $ENV{'REMOTE_ADDR'};
		die "RMERR: You are logged in as 'guest'. Guest users can't update RackMonkey. Error occured " if (lc($updateUser) eq 'guest');
		
		my $actData = $cgi->vars;
		
		# Trim whitespace from the start and end of all submitted values
		for (values %$actData)
		{
			s/^\s+//;
	        s/\s+$//;
		}
		
		# delete id, only act_ids should be used be used for acts, ids are used for views
		delete $$actData{'id'};
		
		# convert act_id into a normal id for use by the engine
		if ($$actData{'act_id'})
		{
			$$actData{'id'} = $$actData{'act_id'};
			delete $$actData{'act_id'};
		}
		
		my $lastCreatedId = $backend->performAct($cgi->actOn, $act, $updateUser, scalar($cgi->vars));
		$id = $lastCreatedId if (!$id); # use lastCreatedId if there isn't an id
		
		my $redirectUrl = "$fullURL?view=$view&view_type=$viewType";
		$redirectUrl .= "&id=$id" if ($id);
		$cgi->redirect303($redirectUrl);
	}
	else # display a view
	{
		$template = HTML::Template->new(filename => TMPLPATH."/${view}_${viewType}.tmpl", 'die_on_bad_params' => 0, 'global_vars' => 1, 'case_sensitive' => 1, 'loop_context_vars' => 1);

		if ($view eq 'hardware')
		{
			if ($viewType =~ /^default/)
			{
				$template->param('hardware' => $backend->hardwareList($orderBy));
			}
			else
			{
				my $selectedManufacturer = $cgi->lastCreatedId; # need to sort out this mess of CGI vars and make clearer!
	
				if (($viewType =~ /^edit/) || ($viewType =~ /^single/))
				{
					my $hardware = $backend->hardware($id);
					$selectedManufacturer = $$hardware{'manufacturer'} if (!$selectedManufacturer); # Use database value for selected if none in CGI
					$$hardware{'support_url_short'} = shortURL($$hardware{'support_url'}); # not actually needed by edit view
					$$hardware{'spec_url_short'} = shortURL($$hardware{'spec_url'}); # not actually needed by edit view			
					$template->param($hardware);
				}
	
				if (($viewType =~ /^edit/) || ($viewType =~ /^create/))
				{
					$template->param('manufacturerlist' => $cgi->selectItem($backend->listBasicMeta('hardware_manufacturer'), $selectedManufacturer));
				}
			}
		}	
		elsif ($view eq 'os')
		{
			if ($viewType =~ /^default/)
			{
				$template->param('operatingsystems' => $backend->osList($orderBy));
			}
			else
			{
				my $selectedManufacturer = $cgi->lastCreatedId; 
	
				if (($viewType =~ /^edit/) || ($viewType =~ /^single/))
				{
					my $operatingSystem = $backend->os($id);
					$template->param($operatingSystem);
					$selectedManufacturer = $$operatingSystem{'manufacturer'} if (!$selectedManufacturer); # Use database value for selected if none in CGI
				}
	
				if (($viewType =~ /^edit/) || ($viewType =~ /^create/))
				{
					$template->param('manufacturerlist' => $cgi->selectItem($backend->listBasicMeta('software_manufacturer'), $selectedManufacturer));
				}
			}		
		}
		elsif ($view eq 'org')
		{
			if ($viewType =~ /^default/)
			{
				my $orgs = $backend->orgList($orderBy);
				
				for my $o (@$orgs)
				{
					$$o{'descript_short'} = shortStr($$o{'descript'});
				}
				$template->param('orgs' => $orgs);
			}
			elsif (($viewType =~ /^edit/) || ($viewType =~ /^single/))
			{
				$template->param($backend->org($id));
			}
			elsif ($viewType =~ /^create/)
			{
				$template->param({'customer' => $cgi->customer, 'software' => $cgi->software, 'hardware' => $cgi->hardware});
			}
		}	
		elsif ($view eq 'domain')
		{
			if ($viewType =~ /^default/)
			{
				my $domains = $backend->domainList($orderBy);
				for my $d (@$domains)
				{
					$$d{'descript_short'} = shortStr($$d{'descript'});
				}
				$template->param('domains' => $domains);
			}
			elsif (($viewType =~ /^edit/) || ($viewType =~ /^single/))
			{
				$template->param($backend->domain($id));
			}
		}		
		elsif ($view eq 'device')
		{
			if ($viewType =~ /^unracked/)
			{
				my $devices = $backend->deviceListUnracked;
				$template->param('devices' => $devices);
			}
			elsif ($viewType =~ /^default/) 
			{
				my $filterBy = $cgi->filterBy;
				
				my $customers = $backend->listBasicMeta('customer');
				unshift @$customers, {'id' => '', name => 'All'};
				$template->param('customerlist' => $cgi->selectItem($customers, $$filterBy{'device.customer'}));
				
				my $roles = $backend->listBasicMeta('role');
				unshift @$roles, {'id' => '', name => 'All'};
				$template->param('rolelist' => $cgi->selectItem($roles, $$filterBy{'device.role'}));

				my $hardware = $backend->listBasicMeta('hardware');
				unshift @$hardware, {'id' => '', name => 'All'};
				$template->param('hardwarelist' => $cgi->selectItem($hardware, $$filterBy{'device.hardware'}));

				my $os = $backend->listBasicMeta('os');
				unshift @$os, {'id' => '', name => 'All'};
				$template->param('oslist' => $cgi->selectItem($os, $$filterBy{'device.os'}));
								
				my $devices = $backend->deviceList($orderBy, $filterBy);
							
				for my $d (@$devices) # calculate age of devices
				{
					$$d{'age'} = calculateAge($$d{'purchased'});
				}

				$template->param('devices' => $devices);
			}
			else
			{
				my $selectedHardware = $cgi->lastCreatedId; 
				my $selectedOs = $cgi->lastCreatedId; 
				my $selectedRole = $cgi->lastCreatedId; 
				my $selectedCustomer = $cgi->lastCreatedId; 
				my $selectedService = $cgi->lastCreatedId;
				my $selectedRack = $cgi->selectProperty('rack') || $cgi->lastCreatedId; 
				my $selectedDomain = $cgi->lastCreatedId; 
				
				if (($viewType =~ /^edit/) || ($viewType =~ /^single/))
				{
					my $device = $backend->device($id);
					$$device{'age'} = calculateAge($$device{'purchased'});
					$$device{'apps'} = $backend->appOnDeviceList($id);

					if (($viewType =~ /^single/) && (lc($$device{'hardware_manufacturer_name'}) =~ /dell/)) # kludgey!
					{
						$template->param('dell_query' => DELLQUERY);
					}
					
					$template->param($device);

					if ($viewType =~ /^edit/) 
					{
						# Use database value for selected if none in CGI
						$selectedHardware = $$device{'hardware'} if (!$selectedHardware); 
						$selectedOs = $$device{'os'} if (!$selectedOs);
						$selectedRole = $$device{'role'} if (!$selectedRole);
						$selectedCustomer = $$device{'customer'} if (!$selectedCustomer);
						$selectedService = $$device{'service'} if (!$selectedService);
						$selectedRack = $$device{'rack'} if (!$selectedRack);
						$selectedDomain = $$device{'domain'} if (!$selectedDomain);
					}
				}
				if (($viewType =~ /^edit/) || ($viewType =~ /^create/))
				{
					$template->param('hardwarelist' => $cgi->selectHardware($backend->hardwareListBasic, $selectedHardware));
					$template->param('oslist' => $cgi->selectItem($backend->listBasicMeta('os'), $selectedOs));
					$template->param('rolelist' => $cgi->selectItem($backend->listBasicMeta('role'), $selectedRole));
					$template->param('customerlist' => $cgi->selectItem($backend->listBasicMeta('customer'), $selectedCustomer));
					$template->param('servicelist' => $cgi->selectItem($backend->listBasicMeta('service'), $selectedService));
					$template->param('racklist' => $cgi->selectRack($backend->rackListBasic, $selectedRack));
					$template->param('domainlist' => $cgi->selectItem($backend->listBasicMeta('domain'), $selectedDomain));
					$template->param('rack_pos' => $cgi->selectProperty('position'));
				}
			}
		}	
		elsif ($view eq 'role')
		{
			if ($viewType =~ /^default/)
			{
				my $roles = $backend->roleList($orderBy);
				
				for my $r (@$roles)
				{
					$$r{'descript_short'} = shortStr($$r{'descript'});
				}
				$template->param('roles' => $roles);
			}
			elsif (($viewType =~ /^edit/) || ($viewType =~ /^single/))
			{
				$template->param($backend->role($id));
			}
		}	
		elsif ($view eq 'service')
		{
			if ($viewType =~ /^default/)
			{
				my $serviceLevels = $backend->serviceList($orderBy);
				for my $s (@$serviceLevels)
				{
					$$s{'descript_short'} = shortStr($$s{'descript'});
				}
				$template->param('services' => $serviceLevels);
			}
			elsif (($viewType =~ /^edit/) || ($viewType =~ /^single/))
			{
				$template->param($backend->service($id));
			}
		}		
		elsif ($view eq 'building')
		{
			if ($viewType =~ /^default/)
			{
					$template->param('buildings' => $backend->buildingList($orderBy));
			}
			elsif (($viewType =~ /^edit/) || ($viewType =~ /^single/))
			{
				my $building = $backend->building($id);
				if ($viewType =~ /^single/)
				{
					$$building{'rooms'} = $backend->roomListInBuilding($id);
				}
				$template->param($building);
			}
		}
		elsif ($view eq 'app')
		{
			if ($viewType =~ /^default/)
			{
					my $apps = $backend->appList($orderBy);
					for my $a (@$apps)
					{
						$$a{'descript_short'} = shortStr($$a{'descript'});
						$$a{'notes_short'} = shortStr($$a{'notes'});
						
					}
					$template->param('apps' => $apps);
			}
			elsif (($viewType =~ /^edit/) || ($viewType =~ /^single/))
			{
				my $app = $backend->app($id);
				my $devices = $backend->appDevicesUsedList($id);
				$$app{'app_devices'} = $devices;
				$template->param($app);
			}
			elsif ($viewType =~ /^manage/)
			{
				my $devices = $backend->appDevicesUsedList($id);
				$template->param('devices' => $devices);
				$template->param('id' => $id);
			}
		}		
		elsif ($view eq 'room')
		{
			if ($viewType =~ /^default/)
			{
					$template->param('rooms' => $backend->roomList($orderBy));
			}
			else
			{
				my $selectedBuilding = $cgi->lastCreatedId || $cgi->id('building');
	
				if (($viewType =~ /^edit/) || ($viewType =~ /^single/))
				{
					my $room = $backend->room($id);
					$$room{'row_count'} = $backend->rowCountInRoom($id);
					$selectedBuilding = $$room{'building'} if (!$selectedBuilding); # Use database value for selected if none in CGI - not actually needed in single view
					if ($viewType =~ /^single/)
					{
						$$room{'racks'} = $backend->rackListInRoom($id); # fix method then use
					}
					$template->param($room);
				}
								
				if (($viewType =~ /^edit/) || ($viewType =~ /^create/))
				{	
					$template->param('buildinglist' => $cgi->selectItem($backend->listBasic('building'), $selectedBuilding));
				}
			}
		}
		elsif ($view eq 'row')
		{
			$template->param('rows' => $backend->rowListInRoom($cgi->id('room')));
			$template->param($backend->room($cgi->id('room')));
		}
		elsif ($view eq 'rack')
		{
			if ($viewType =~ /^default/)
			{
				$template->param('racks' => $backend->rackList($orderBy));
			}
			elsif ($viewType =~ /^physical/)
			{
				my @rackIdList = $cgi->rackList;
				push (@rackIdList, $id) if (scalar(@rackIdList) == 0); # add current rack id if no list
				die "RMERR: You need to select at least one rack to display.\nError occured" unless $rackIdList[0];
				my @racks;
				for my $rackId (@rackIdList)
				{
					my $rack = $backend->rack($rackId);
					$$rack{'rack_layout'} = $backend->rackPhysical($rackId, $cgi->id('device'));
					push @racks, $rack;
				}
				$template->param('rack_list' => \@racks);
			}
			else
			{
				my $selectedRoom = $cgi->lastCreatedId || $cgi->id('room');
				
				if (($viewType =~ /^edit/) || ($viewType =~ /^single/))
				{
					my $rack = $backend->rack($id);
					$template->param($rack);
					$selectedRoom = $$rack{'room'} if (!$selectedRoom); # Use database value for selected if none in CGI - not actually needed in single view
				}
				
				if (($viewType =~ /^edit/) || ($viewType =~ /^create/))
				{	
					$template->param('roomlist' => $cgi->selectRoom($backend->roomListBasic, $selectedRoom));
				}
			}
		}
		elsif ($view eq 'report')
		{
			$template->param('device_count' => $backend->deviceCount);
			$template->param('rack_count' => $backend->rackCount);
			my $rackSize = $backend->totalSizeRack;
			my $deviceSize = $backend->totalSizeDevice;
			$template->param('total_rack_space' => $rackSize);
			$template->param('used_rack_space' => $deviceSize);
			$template->param('free_rack_space' => $rackSize - $deviceSize);
			$template->param('customer_device_count' => $backend->customerDeviceCount);
			$template->param('role_device_count' => $backend->roleDeviceCount);
			$template->param('hardware_device_count' => $backend->hardwareDeviceCount);
			$template->param('os_device_count' => $backend->osDeviceCount);
		}		
		elsif (($view eq 'config') || ($view eq 'help'))
		{
			# do nothing - pages are static content
		}
		else
		{
			die "RMERR: No such view. This error should not occur, did you manually type this URL?\nError at";
		}
	}
		
	$dbh->disconnect();
	
	# Get version and date for page footer
	$template->param('version' => "$VERSION");
	my ($minute, $hour, $day, $month, $year) = (gmtime)[1, 2, 3, 4, 5];
	my $currentDate = sprintf("%04d-%02d-%02d %02d:%02d GMT", $year+1900, $month+1, $day, $hour, $minute);
	$template->param('date' => "$currentDate");

	# Support overriding the next view of the template
	$template->param('return_view' => $cgi->returnView);
	$template->param('return_view_type' => $cgi->returnViewType);
	$template->param('return_view_id' => $cgi->returnViewId);
	
	# support hiding and showing of filters 
	$template->param('show_filters' => $cgi->showFilters);
	$template->param('filter_string' => $cgi->filterString);

	
	$template->param('base_url' => $baseURL);
	$template->param('web_root' => WWWPATH);
	$template->param('order_by' => $orderBy);
	
	print $cgi->header;
	print $template->output;
};
if ($@)
{
	my $errMsg = $@;
	print $cgi->header;
	my $friendlyErrMsg = RackMonkey::Error::enlighten($errMsg);
	RackMonkey::Error::display($errMsg, $friendlyErrMsg);
}

sub checkSupportedDriver
{
	# Get driver version number
	my ($currentDriver) = DBDCONNECT =~ /dbi:(.*?):/;
	$currentDriver = "DBD::$currentDriver";
	my $driverVersion = eval("\$${currentDriver}::VERSION");
	
	# Check we're using SQLite or Postgres
	unless (($currentDriver eq 'DBD::SQLite') || ($currentDriver eq 'DBD::Pg'))
	{
		die "RMERR: You tried to use an unsupported database driver '$currentDriver'. RackMonkey supports SQLite (DBD::SQLite) or Postgres (DBD::Pg).\nError occured";
	}
	
	# If using SQLite, version v1.09 or higher is required in order to support ADD COLUMN
	if (($currentDriver eq 'DBD::SQLite') && ($driverVersion < 1.09))
	{
		die "RMERR: RackMonkey requires DBD::SQLite v1.09 or higher. You are using DBD::SQLite v$driverVersion. Please consult the installation instructions.\nError occured";
	}
}
