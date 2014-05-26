#
# Cookbook Name:: networking
# Definition:: firewall_hotst
#

define :firewall_hosts, :family => 'inet' do
  hosts = nil
  zones = nil

  begin
    if params[:family].to_s == "inet"
      hosts = resources(:template => "/etc/shorewall/hosts")
      zones = resources(:template => "/etc/shorewall/zones")
    elsif params[:family].to_s == "inet6"
      hosts = resources(:template => "/etc/shorewall6/hosts")
      zones = resources(:template => "/etc/shorewall6/zones")
    else 
      log "Unsupported network family" do
        level :error
      end
    end
  rescue
    log "File should exist after the main recipe runs" do
      level :error
    end
  end

  host = Hash[
    :interface => params[:interface],
    :name => params[:name],
    :parent_zone => params[:parent_zone],
    :ip_ranges => params[:ip_ranges]
  ]

  hosts.variables[:hosts] << host
  zones.variables[:hosts] << host
end
