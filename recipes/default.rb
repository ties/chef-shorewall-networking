#
# Cookbook Name:: networking
# Recipe:: default
#
# Copyright 2010, OpenStreetMap Foundation.
# Copyright 2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# = Requires
# * node[:networking][:nameservers]

require "ipaddr"

node[:networking][:interfaces].each do |name,interface|
  # implicitly set the default family to inet
  if not interface[:family]
        node.default[:networking][:interfaces][name][:family] = 'inet'
  end

  if interface[:role] and role = node[:networking][:roles][interface[:role]]
    if role[interface[:family]]
      node.default[:networking][:interfaces][name][:prefix] = role[interface[:family]][:prefix]
      node.default[:networking][:interfaces][name][:gateway] = role[interface[:family]][:gateway]
    end

    node.default[:networking][:interfaces][name][:metric] = role[:metric]
    node.default[:networking][:interfaces][name][:zone] = role[:zone]
  end

  # prefix/gateway/etc only make sense when setting a manual address
  unless interface[:address].casecmp("dhcp")
    prefix = node[:networking][:interfaces][name][:prefix]

    node.default[:networking][:interfaces][name][:netmask] = (~IPAddr.new(interface[:address]).mask(0)).mask(prefix)
    node.default[:networking][:interfaces][name][:network] = IPAddr.new(interface[:address]).mask(prefix)
  end
end

template "/etc/network/interfaces" do
  source "interfaces.erb"
  owner "root"
  group "root"
  mode 0644
end

execute "hostname" do
  action :nothing
  command "/bin/hostname -F /etc/hostname"
end

template "/etc/hostname" do
  source "hostname.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :run, resources(:execute => "hostname")
end

template "/etc/hosts" do
  source "hosts.erb"
  owner "root"
  group "root"
  mode 0644
end

link "/etc/resolv.conf" do
  action :delete
  link_type :symbolic
  to "/run/resolvconf/resolv.conf"
  only_if { File.symlink?("/etc/resolv.conf") }
end

template "/etc/resolv.conf" do
  source "resolv.conf.erb"
  owner "root"
  group "root"
  mode 0644
end

node.interfaces(:role => :internal) do |interface|
  if interface[:gateway] and interface[:gateway] != interface[:address]
    search(:node, "networking_interfaces*address:#{interface[:gateway]}") do |gateway|
      if gateway[:openvpn]
        gateway[:openvpn][:tunnels].each_value do |tunnel|
          if tunnel[:peer][:address]
            route tunnel[:peer][:address] do
              netmask "255.255.255.255"
              gateway interface[:gateway]
              device interface[:interface]
            end
          end

          if tunnel[:peer][:networks]
            tunnel[:peer][:networks].each do |network|
              route network[:address] do
                netmask network[:netmask]
                gateway interface[:gateway]
                device interface[:interface]
              end
            end
          end
        end
      end
    end
  end
end

zones = Hash.new

search(:node, "networking:interfaces").collect do |n|
  if n[:fqdn] != node[:fqdn]
    n.interfaces.each do |interface|
      if interface[:role] == "external" and interface[:zone]
        zones[interface[:zone]] ||= Hash.new
        zones[interface[:zone]][interface[:family]] ||= Array.new
        zones[interface[:zone]][interface[:family]] << interface[:address]
      end
    end
  end
end

package "shorewall"

service "shorewall" do
  action [ :enable, :start ]
  supports :restart => true
  status_command "shorewall status"
end

template "/etc/default/shorewall" do
  source "shorewall-default.erb"
  owner "root"
  group "root"
  mode 0644
  variables :start => node[:networking][:start_shorewall]
  notifies :restart, resources(:service => "shorewall")
end

template "/etc/shorewall/shorewall.conf" do
  source "shorewall.conf.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, resources(:service => "shorewall")
end

template "/etc/shorewall/zones" do
  source "shorewall-zones.erb"
  owner "root"
  group "root"
  mode 0644
  variables :type => "ipv4"
  notifies :restart, resources(:service => "shorewall")
end

template "/etc/shorewall/interfaces" do
  source "shorewall-interfaces.erb"
  owner "root"
  group "root"
  mode 0644
  variables :interfaces => node[:networking][:interfaces] 
  notifies :restart, resources(:service => "shorewall")
end

template "/etc/shorewall/hosts" do
  source "shorewall-hosts.erb"
  owner "root"
  group "root"
  mode 0644
  variables :zones => zones
  notifies :restart, resources(:service => "shorewall")
end

template "/etc/shorewall/policy" do
  source "shorewall-policy.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, resources(:service => "shorewall")
end

template "/etc/shorewall/rules" do
  source "shorewall-rules.erb"
  owner "root"
  group "root"
  mode 0644
  variables :family => "inet", :rules => []
  notifies :restart, resources(:service => "shorewall")
end

firewall_rule "limit-icmp-echo" do
  action :accept
  family :inet
  source "net"
  dest "fw"
  proto "icmp"
  dest_ports "echo-request"
  rate_limit "s:1/sec:5"
end

if node[:roles].include?("gateway") or node[:networking][:gateway]
  template "/etc/shorewall/masq" do
    source "shorewall-masq.erb"
    owner "root"
    group "root"
    mode 0644
    notifies :restart, resources(:service => "shorewall")
  end
else
  file "/etc/shorewall/masq" do
    action :delete
    notifies :restart, resources(:service => "shorewall")
  end
end

if not node.interfaces(:family => :inet6).empty?
  package "shorewall6"

  service "shorewall6" do
    action [ :enable, :start ]
    supports :restart => true
    status_command "shorewall6 status"
  end

  template "/etc/default/shorewall6" do
    source "shorewall-default.erb"
    owner "root"
    group "root"
    mode 0644
    notifies :restart, resources(:service => "shorewall6")
  end

  template "/etc/shorewall6/shorewall6.conf" do
    source "shorewall6.conf.erb"
    owner "root"
    group "root"
    mode 0644
    notifies :restart, resources(:service => "shorewall6")
  end

  template "/etc/shorewall6/zones" do
    source "shorewall-zones.erb"
    owner "root"
    group "root"
    mode 0644
    variables :type => "ipv6"
    notifies :restart, resources(:service => "shorewall6")
  end

  template "/etc/shorewall6/interfaces" do
    source "shorewall6-interfaces.erb"
    owner "root"
    group "root"
    mode 0644
    notifies :restart, resources(:service => "shorewall6")
  end

  template "/etc/shorewall6/hosts" do
    source "shorewall6-hosts.erb"
    owner "root"
    group "root"
    mode 0644
    variables :zones => zones
    notifies :restart, resources(:service => "shorewall6")
  end

  template "/etc/shorewall6/policy" do
    source "shorewall-policy.erb"
    owner "root"
    group "root"
    mode 0644
    notifies :restart, resources(:service => "shorewall6")
  end

  template "/etc/shorewall6/rules" do
    source "shorewall-rules.erb"
    owner "root"
    group "root"
    mode 0644
    variables :family => "inet6", :rules => []
    notifies :restart, resources(:service => "shorewall6")
  end

  firewall_rule "limit-icmp6-echo" do
    action :accept
    family :inet6
    source "net"
    dest "fw"
    proto "ipv6-icmp"
    dest_ports "echo-request"
    rate_limit "s:1/sec:5"
  end
end

node[:networking][:rules].each do |name,rule|
  firewall_rule name do
    action  rule[:action]
    source  rule[:source]
    dest    rule[:dest]
  end
end