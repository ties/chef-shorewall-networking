default[:networking][:interfaces] = { }
default[:networking][:nameservers] = %w{8.8.8.8 8.8.4.4 8.8.2.2}
default[:networking][:search] = [ ]

default[:networking][:start_shorewall] = true

default[:networking][:gateway] = false
#
# accept SSH by default - adjust this when wanted.
#
default[:networking][:rules] = {
	accept_ssh: {action: "SSH(ACCEPT)", source: "all", dest: "$FW"}
}

#
# the default value for the family of a network device is implicitly set to 
# inet from the recipe
#