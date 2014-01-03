DESCRIPTION
===========

This is a modified version of the networking cookbook from OpenStreetMap. It it based on a checkout of the [mirror on GitHub](https://github.com/pnorman/openstreetmap-chef) of the main repository.

This recipe configures networking.

## Modifications:
  * Removed `.openstreetmap.org` postfix on hostname
  * Removed internal network zones
  * Support DHCP
  * Accept SSH from the internet by default (see `attributes/default.rb`)
  * Added default (Google) nameservers as fallback

USAGE
=====

Set the networking attributes in a role, for example from my base.rb:

    :networking => {
      :nameservers => [ "10.13.37.120", "10.13.37.40" ],
      :search => [ "int.example.org". "example.org" ]
    }

The resulting /etc/resolv.conf will look like:

    search int.example.org example.org
    nameserver 10.13.37.120
    nameserver 10.13.37.40

LICENSE AND AUTHOR
==================

Author:: OpenStreetMap Administrators (<admins@openstreetmap.org>)

Copyright 2010, OpenStreetMap Foundation.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Based on resolver cookbook:

Author:: Joshua Timberman (<joshua@opscode.com>)

Copyright 2009, Opscode, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
