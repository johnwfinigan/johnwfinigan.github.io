title: IPsec VPN from Google Cloud to OpenBSD with OpenBGPD
date: 2025-09-18
css: style.css
tags: gcp openbsd

## IPsec VPN from Google Cloud to OpenBSD with OpenBGPD

Like most public clouds, Google Cloud offers a managed IPsec site-to-site VPN gateway to allow you to build hybrid networks.

This a quick guide to configuring OpenBSD as the on-premises IPsec tunnel provider and router, including use of 
the built-in OpenBSD iked for IPSec and built-in OpenBGPD to exchange routes with GCP. At the time of testing, I was using
OpenBSD 7.7.

I am mainly trying to show how to do this with OpenBSD, and will not cover the GCP side beyond saying that you can use the 
Web UI wizard for creating the VPN tunnel, and if you want to use BGP for routing, you must deploy a HA VPN and not a 
Classic VPN.

This is more of a starting point than a production ready setup. I am not an expert in these topics, and I'm sure that 
things like pf rules and cipher choices should be tuned further. For simplicity, I took the Web UI option of creating
a single tunnel, but production setups should probably use at least dual tunnels.

Once you create your tunnel (including its associated VPN Gateway and Cloud Router) in GCP, you will have some pieces of 
critical information available for the rest of the setup:

| Item | Value |
| ---- | ----- |
| Cloud VPN Gateway Public IP | 198.51.100.5 |
| Cloud Router BGP IP | 169.254.149.89 |
| Cloud Router BGP ASN | 65516 |
| BGP peer IP (on-prem) | 169.254.149.90 |
| BGP Peer ASN (on-prem) | 65515 |

In addition you'll have some information about your networks you're routing between cloud and on-prem:

| Item | Value |
| ---- | ----- |
| Your on-prem public IP | 203.0.113.7 |
| Your on-prem local subnet | 172.16.10.0/24 |
| Your GCP subnet #1 | 10.0.8.0/24 |
| Your GCP subnet #2 | 10.0.9.0/24 |


Note that GCP's BGP session here is listening on an ipv4 link-local address. This is not a problem, but we will have
to include it in the tunnel and also have an interface on OpenBSD for bgpd to bind to. Thus, our first OpenBSD config item,
to create a gif virtual interface.

```
$ cat /etc/hostname.gif0
inet 169.254.149.90 255.255.255.252 169.254.149.89
```

You can run ```sh /etc/netstart``` to create or update this virtual interface, once ```/etc/hostname.gif0``` exists.

Next, create ```/etc/iked.conf``` to set up the IPSec tunnel:

```

ikev2 "gcpvpn" active esp \
    from 169.254.149.90/32 to 169.254.149.89/32  \
    from 172.16.10.0/24 to 10.0.8.0/23 \
    local 203.0.113.7 peer 198.51.100.5 \
    ikesa \
      enc aes-256 auth hmac-sha2-256 \
      group modp2048 \
    srcid 203.0.113.7 \
    dstid 198.51.100.5 \
    psk "FAKE_FIXME"
```

Here you can see I have created security associations (tunnels) between both the BGP link local addresses, and the local and remote networks.
I have summarized the two /24 cloud networks down to one /23.

You will also need some rules in ```pf.conf``` to pass ipsec and BGP traffic. You'll have to adjust this based on your local pf config, but this is the core of it:

```

# Remember, this is just a snippet to add to 
# your existing pf.conf 
# It's not a complete pf.conf
# We assume int_if is already trusted
# with something like pass in quick on $int_if

int_net = "172.16.10.0/24"
gcp_net = "10.0.8.0/23"

# Begin ipsec and bgp rules
vpn_if = "enc0"
gcp_vpn_peer = "198.51.100.5"
pass in log quick on $vpn_if from $gcp_net to $int_net
bgp_peer_gcp = "169.254.149.89"
bgp_peer_local = "169.254.149.90"
# Allow incoming VPN traffic (IKE and ESP).
pass in quick on $ext_if proto esp from $gcp_vpn_peer to any
pass in quick on $ext_if proto udp from $gcp_vpn_peer to any port { 500, 4500 }
# Allow BGP traffic over the IPsec tunnel.
pass in quick on $ext_if proto tcp from $bgp_peer_gcp to $bgp_peer_local port 179
pass out quick on $ext_if proto tcp from $bgp_peer_local to $bgp_peer_gcp port 179
# End ipsec and bgp rules
```

It bears repeating that these rules are being added to a setup where the OpenBSD router's internal LAN interfaces already
have a pf rule that allows traffic inbound from them. If not, you will need a new rule which allows traffic from ```int_net```
to ```gcp_net```, just like its inverse which is above.

Once these rules are in place, you can run ```rcctl enable iked``` and ```rcctl start iked``` and you should then have 
active security associations and your VPN gateway in GCP should "go green"

```

# ikectl show sa                                                                                                                                                                                          
iked_sas: 0xc8e0977720 rspi 0x89919a0ae17b9893 ispi 0xb502da797c203a8e 203.0.113.7:500->198.51.100.5:500<IPV4/198.51.100.5>[] ESTABLISHED i nexti 0x0 pol 0xc8fafbb000
  sa_childsas: 0xc8e098f480 ESP 0x3f52449e out 203.0.113.7:500 -> 198.51.100.5:500 (L) B=0x0 P=0xc8e096fa80 @0xc8e0977720
  sa_childsas: 0xc8e096fa80 ESP 0x9bbfc7dd in 198.51.100.5:500 -> 203.0.113.7:500 (LA) B=0x0 P=0xc8e098f480 @0xc8e0977720
  sa_flows: 0xc8e0957400 ESP out 172.16.10.0/24 -> 10.0.8.0/23 [0]@-1 (L) @0xc8e0977720
  sa_flows: 0xc8e0985800 ESP in 10.0.8.0/23 -> 172.16.10.0/24 [0]@-1 (L) @0xc8e0977720
  sa_flows: 0xc8e0965c00 ESP out 169.254.149.90/32 -> 169.254.149.89/32 [0]@-1 (L) @0xc8e0977720
  sa_flows: 0xc8e0965800 ESP in 169.254.149.89/32 -> 169.254.149.90/32 [0]@-1 (L) @0xc8e0977720
iked_activesas: 0xc8e098f480 ESP 0x3f52449e out 203.0.113.7:500 -> 198.51.100.5:500 (L) B=0x0 P=0xc8e096fa80 @0xc8e0977720
iked_activesas: 0xc8e096fa80 ESP 0x9bbfc7dd in 198.51.100.5:500 -> 203.0.113.7:500 (LA) B=0x0 P=0xc8e098f480 @0xc8e0977720
iked_flows: 0xc8e0985800 ESP in 10.0.8.0/23 -> 172.16.10.0/24 [0]@-1 (L) @0xc8e0977720
iked_flows: 0xc8e0965800 ESP in 169.254.149.89/32 -> 169.254.149.90/32 [0]@-1 (L) @0xc8e0977720
iked_flows: 0xc8e0957400 ESP out 172.16.10.0/24 -> 10.0.8.0/23 [0]@-1 (L) @0xc8e0977720
iked_flows: 0xc8e0965c00 ESP out 169.254.149.90/32 -> 169.254.149.89/32 [0]@-1 (L) @0xc8e0977720
iked_dstid_sas: 0xc8e0977720 rspi 0x89919a0ae17b9893 ispi 0xb502da797c203a8e 203.0.113.7:500->198.51.100.5:500<IPV4/198.51.100.5>[] ESTABLISHED i nexti 0x0 pol 0xc8fafbb000
```

Note that sa_flows exist for all our desired connectivity. Now that the tunnel is up, you can configure bgpd.conf: 

```

AS 65515
router-id 169.254.149.90

network 172.16.10.0/24

neighbor 169.254.149.89 {
    remote-as 65516
    descr "GCP VPN Gateway"
}

allow to 169.254.149.89 prefix { 172.16.10.0/24 }
allow from 169.254.149.89 prefix { 10.0.8.0/24, 10.0.9.0/24 }
```


Note that we are filtering routes inbound and outbound, but can't summarize the 10. prefix because that is not what GCP is sending.

You can now run ```rcctl enable bgpd``` followed by ```rcctl start bgpd``` and after a quick wait, should see something like this:

```

r# bgpctl show rib                                                                                                                                                                                         
flags: * = Valid, > = Selected, I = via IBGP, A = Announced,
       S = Stale, E = Error, F = Filtered, L = Leaked
origin validation state: N = not-found, V = valid, ! = invalid
aspa validation state: ? = unknown, V = valid, ! = invalid
origin: i = IGP, e = EGP, ? = Incomplete

flags  vs destination          gateway          lpref   med aspath origin
*>    N-? 10.0.8.0/24          169.254.149.89    100   100 65516 ?
*>    N-? 10.0.9.0/24          169.254.149.89    100   100 65516 ?
AI*>  N-? 172.16.10.0/24       0.0.0.0           100     0 i
```

Importantly, our inbound routes on the 10. prefixes are showing ```*>``` which means "Valid and Selected". 
If you run ```netstat -rn``` you should see them in your OpenBSD router's system routes.

At this point you should be able to ping hosts bidirectionally. On the OpenBSD router, you will probably need to use something
like ```ping -S 172.16.10.1 10.0.9.2``` to ensure the ping originates from an interface that can route to the VPN.

For troubleshooting you can employ ```tcpdump -i enc0``` to see what is going over the tunnel, and similarly for ```gif0```
