title: OpenBSD as a single-stack DHCPv6 client
date: 2026-05-10
css: style.css
tags:


## OpenBSD as a single-stack DHCPv6 client

I wanted to try running OpenBSD as a single-stack IPv6 host on a network where ```dnsmasq``` provides stateful DHCPv6. This is a less common deployment case than using SLAAC with or without stateless DHCPv6, but it has the advantage that it allows ```dnsmasq``` to register a FQDN for the client in its local DNS, so that the client can be accessed by name on the local LAN without further configuration. My relevant ```dnsmasq``` config is this:

```
enable-ra
dhcp-range=::10,::ffff,constructor:br6,64,12h
```

The ```dhcp-range``` line implicitly has it serving stateful DHCPv6 on a range derived from the prefix delegated to interface br6, with a prefix length of 64 and a 12 hour lease.

I tried a few linux clients and they all seemed to pick it up without further configuration, but OpenBSD did not. It seems like as of 7.9-current, there is no support for requesting ```IA_NA``` addressing (a non-temporary v6 address for the host) using only base. ```dhcp6leased``` is specialized for requesting ```IA_PD``` (prefix delegation) only.

However, ```dhcpcd``` in ports can request ```IA_NA```. So I temporarily assigned an address by hand using ```ifconfig``` just long enough to do ```pkg_add dhcpcd``` and came up with the following for ```/etc/dhcpcd.conf```

```
ipv6only
hostname "obsd"
interface vio0
ipv6rs
ia_na 1
```

At first this only partially worked. It was getting a v6 address and a DNS server from DHCPv6, but actual outbound access was failing. The reason was, DNS lookups were still returning A records, and something was assigning an APIPA v4 (169.254 autoconfigured link local) address to the NIC (vio0). ```route show``` was indeed showing broken v4 routes related to this. 

The solution was disabling the start of both ```dhcpleased``` and ```dhcp6leased``` and adding ```ipv6only``` to the ```dhcpcd``` config, preventing anything from trying v4 configuration.

After that things are working fine. OpenBSD is now pulling a v6 address via DHCPv6 and working well as a single stack client.
