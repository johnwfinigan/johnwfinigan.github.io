title: OpenBSD Home Internet Routing
date: 2026-02-27
css: style.css
tags: openbsd routing

## OpenBSD Home Internet Routing

I've been using OpenBSD to firewall and route my home internet for almost a decade, initially on the excellent [PC Engines APU2](https://www.pcengines.ch/apu2.htm). Currently I run it on a cheap refurbished HP desktop with an i3-10100 CPU and an i350 NIC. I moved to the HP only when my home internet exceeded what the APU2 could forward, somewhere around 400 mbps if I recall.

Major functions are as follows: pf firewall, IPv4 NAT, IPv6 forwarding, IPv6 prefix delegation requested through DHCPv6, IPv6 SLAAC assignment, IPv4 DHCP server, DNS caching resolver. At this point, all of these are available in OpenBSD base without add-on packages.

Originally I ran OpenBSD bare-metal on the HP. After a while, I decided it would be useful to have an always-on VM host, so I installed RHEL on the HP and now run OpenBSD as a KVM guest. I am still routing through the i350, which is dedicated to the OpenBSD guest via PCIe passthrough. This works great. Initially I was annoyed by the VM's high idle CPU use on the host, but this was cured by removing the unneeded virtual USB controller from the OpenBSD guest's KVM config, using "virsh edit".

My basic OpenBSD configuration has not changed much, except that over the years I've been able to retire a few ports (3rd party packages) in favor of new functionality in base. I originally ran ISC ```dhcpd``` for my LAN, but was able to retire it for OpenBSD ```dhcpd``` when I no longer had a device that needed some obscure DHCP options sent.

For IPv6 prefix delegation, similarly I once ran Roy Marples' ```dhcpcd```, but now run ```dhcp6leased``` from OpenBSD base.

SLAAC has always been served by ```rad``` and my caching DNS resolver has always been OpenBSD's built-in ```unbound```. I used to run my own fork of [unbound-adblock](https://www.geoghegan.ca/unbound-adblock.html) but now run ```unbound``` as a non-filtering resolver and run an Adguard Home container on Linux for a filtering resolver.

One of the few ports I still run is ```vnstat``` for bandwith monitoring. OpenBSD base can almost do it all, except for a few userland conveniences like ```git``` and ```vim```. I like ```curl``` but the ```ftp``` in OpenBSD base can fetch https URLs. I usually end up configuring OpenBSD ```httpd``` to serve a few pages to the LAN.

This post is more of a retrospective than anything else. My configs are too specific to my own uses to present, but if you are trying to set up IPv6 prefix delegation via DHCPv6 plus SLAAC for your LAN, these days all you need is this:

(em0 is LAN and em1 is WAN)

```
# cat dhcp6leased.conf                                                                       
request prefix delegation on em1 for {
  em0/64
}

# cat rad.conf                                                                               
interface em0
```

OpenBSD is great for this role and I highly recommend it.
