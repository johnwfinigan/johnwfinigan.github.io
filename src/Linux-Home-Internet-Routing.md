title: Linux Home Internet Routing
date: 2026-05-15
css: style.css
tags: linux routing


## Linux Home Internet Routing

After nearly a decade of routing home internet with OpenBSD, I wanted to try something different and try out the operational "feel" of Linux in this role.

As on my OpenBSD setup, the major functions are firewall, IPv4 NAT, IPv6 forwarding, IPv6 prefix delegation requested through DHCPv6, IPv6 SLAAC assignment, IPv4 DHCP server, and DNS caching resolver.

The first decision to be made was what distro to use. I have good experience with both Debian and Red Hat flavored distros, but lean more to the Red Hat flavored side, especially for servers. I've also got some experience with image based distros, and wanted to try that here. So I started out with openSUSE Leap Micro 16 and ran that for a few weeks. It was a decent experience, but I found myself fighting it a little too much, so I reinstalled to Fedora. So far, I'm satisfied with Fedora in this role, and I think the combo of huge software selection and "close to upstream" versioning cadence suits this role.

Unlike my OpenBSD config, a few larger more monolithic pieces of software provide most of the major functions. 

Firewalling and forwarding/NAT are configured using ```firewalld```. This barely requires any configuration at all: I moved my WAN interface into the ```external``` zone and my LAN interfaces into the ```trusted``` zone, and forwarding/NAT is taken care of. I set the ```firewalld``` default target to ```drop```. I assigned my interfaces to zones using the NetworkManager ```connection.zone``` property, but it could have been done with ```firewall-cmd``` instead.

NetworkManager is the part of the stack I am least fond of. I find it clunky and hard to manage declaratively. I tried to get it to handle my DHCPv6 prefix delegation from my ISP, but could not get it to work. Instead, I set ```ipv6.method=ignore``` on all interfaces and installed ```dhcpcd``` to handle this. This works fine.

My favorite part of this build is use of ```dnsmasq``` for SLAAC / router advertisements, DHCPv4 server, and DNS caching resolver. Later I also added static DHCPv6 service on a v6 single stack subnet. This allows v6 clients to get their hostnames registered in ```dnsmasq```, such that clients on my LAN can automatically resolve them. I have ```dnsmasq``` using ```stubby``` listening on localhost as its DNS forwarder, so that all DNS queries forwarded by ```dnsmasq``` leave my network as DNS-over-TLS protected queries.

One of my goals for this setup was to be able to run KVM guests on the router hardware. This worked out well. Currently all guests are attached to a bridge interface that ```dhcpcd``` is delegating a /64 prefix to. The bridge has no physical interface associated. All access to the guests is routed from my LAN to the bridge. So far this has been an interesting ipv6-centric setup.

A few config files of interest:

```
# /etc/dhcpcd.conf
ipv6only
noipv6rs
script ""
allowinterfaces enp1s0f0 enp1s0f1 br6
interface enp1s0f0
        ipv6rs
        ia_na 1
        # Reserve two /64s individually to work around
        # ISP not supporting larger delegations
        ia_pd 2/::/64 enp1s0f1/0
        ia_pd 3/::/64 br6/0
```

```
# /etc/dnsmasq.d/10-local-dnsmasq.conf 
interface=enp1s0f1
interface=br6
bind-interfaces
enable-ra
port=53
domain-needed
bogus-priv
no-resolv
no-poll
cache-size=5000
# Use Stubby as upstream DNS over TLS proxy
server=127.0.0.1#5454
log-dhcp

# LAN gets SLAAC and DHCPv4
dhcp-range=::,constructor:enp1s0f1,ra-only
dhcp-range=172.16.1.150,172.16.1.250,8h

# KVM bridge gets stateful DHCPv6 only
dhcp-range=::10,::ffff,constructor:br6,64,12h

expand-hosts
domain=example.com
```

One slight annoyance is that there's a race condition during boot where ```dnsmasq``` startup will usually fail due to networking not being ready yet. I'm working around this using a systemd timer that just tries startup again a few seconds after boot:

```
# /etc/systemd/system/dnsmasq-fix.timer
[Unit]
Description=Delayed retry for dnsmasq

[Timer]
OnBootSec=40
Unit=dnsmasq.service

[Install]
WantedBy=timers.target
```



