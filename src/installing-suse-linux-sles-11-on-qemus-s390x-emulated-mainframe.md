title: Installing SUSE Linux SLES 11 on qemu's s390x emulated mainframe with virtio
date: 2015-09-14
css: simple.css
tags: qemu s390x mainframe SLES Linux emulation


## Installing SUSE Linux SLES 11 on qemu's s390x emulated mainframe with virtio

(Historical post - this is outdated, but parts are likely still useful)

Installing Linux on an emulated mainframe can be confusing unless you are already a mainframer and you have good install docs for your specific distro. The traditional choice of emulators is [Hercules](http://www.hercules-390.eu), but Hercules is written by mainframers, for mainframers, and there is a lot to learn if you want to build your config from scratch.

Traditional mainframe Linux does not install or boot like amd64 Linux. Hercules is designed to run traditional mainframe operating systems like z/OS, and so presents hardware to the guest that looks like what z/OS expects to see. There is a lot to understand if you just want to try your program on s390x Linux.

However, [QEMU's](http://wiki.qemu.org/Main_Page) s390x abilities have improved recently due to IBM's adoption of KVM virtualization on z Systems as an alternative to z/VM. Most importantly, recent QEMU has new virtio paravirtual IO devices for s390x Linux, meaning that you do not need to configure emulated mainframe channel controllers and DASD.

All of this would not help if mainframe QEMU was only useful for KVM. But it's not: the qemu-system-s390x emulator works just fine.

I used QEMU 2.4, built from source. Everything else came with my Ubuntu 15.04 install. I doubt I would have figured any of this out without looking at this [SHARE presentation by Mark Post](https://share.confex.com/share/125/webprogram/Handout/Session17489/know.your.competition.pdf)

In order for this to work, you will need a mainframe Linux distro that supports virtio mainframe disk and network. Since this is a recent addition, most mainframe Linux distros do *not* have a kernel that supports it. SUSE Linux Enterprise Server 11 SP4 is new enough. You can get a [trial here](https://www.suse.com/products/server/download/)

Too new may also not work: [Apparently RHEL 7 and SLES 12 won't](https://lists.gnu.org/archive/html/qemu-devel/2015-08/msg03884.html). The whole linked discussion is worth reading.

Finally, it's convenient to do the install over HTTP since real mainframes rarely install from CD, so CD is not the path of least resistance.

To prep, get yourself a copy of the SUSE ISO and create a virtual disk file for your root drive:

    $ mkdir $HOME/qemu.test ; cd $HOME/qemu.test
    $ qemu-img create -f qcow2 SLES-11-SP4-s390x.qcow2 20G
    $ ls
    SLES-11-SP4-DVD-s390x-GM-DVD1.iso  SLES-11-SP4-s390x.qcow2

Now, you will need an initrd and kernel to start QEMU with. The initrd is on the ISO, but we have to work a little for the kernel:

    $ mkdir mnt
    $ sudo mount ./SLES-11-SP4-DVD-s390x-GM-DVD1.iso ./mnt
    $ cp mnt/boot/s390x/initrd .
    $ mkdir junk ; cd junk
    $ rpm2cpio ../mnt/suse/s390x/kernel-default-base-3.0.101-63.1.s390x.rpm | cpio -ivd 
    $ zcat boot/vmlinux-3.0.101-63-default.gz > ../kernel
    $ cd .. ; rm -rf junk

Finally, serve the install disk's contents locally using HTTP:

    $ cd ./mnt ; python -m SimpleHTTPServer

Now, in a new terminal, the moment we've all been waiting for::

    $ cd $HOME/qemu.test
    $ qemu-system-s390x -M s390-ccw-virtio -m 1024 -smp 1 -nographic \
      -drive file=SLES-11-SP4-s390x.qcow2,format=qcow2,if=none,id=drive-virtio-disk0 \
      -device virtio-blk-ccw,drive=drive-virtio-disk0,id=virtio-disk0 \
      -netdev user,id=mynet0,hostfwd=tcp::10022-:22 \
      -device virtio-net-ccw,netdev=mynet0,id=net0,mac=08:00:2F:00:11:22,devno=fe.0.0001 \
      -kernel ./kernel -initrd ./initrd

A couple of networking notes: We are using QEMU's "user" networking option here, which uses QEMU's internal NAT gateway and DHCP server, but is slow. It is zero setup though, which is why we're using it. The hostfwd=tcp::10022-:22 argument forwards port 22 (SSH) on the guest to port 10022 on the host. The MAC address is in PR1ME's space, so make sure it does not conflict with any [PRIMOS](https://en.wikipedia.org/wiki/PRIMOS) systems you may be running.

Here's a log of me running through the beginning of the setup once the guest is booted. 10.0.2.2 is QEMU's emulated router and maps to the host.


    >>> Linuxrc v3.3.108 (Kernel 3.0.101-63-default) <<<
    
    Main Menu
    
    0) <-- Back <--
    1) Start Installation          
    2) Settings               
    3) Expert                
    4) Exit or Reboot            
    
    > 1
    
    Start Installation
    
    0) <-- Back <--
    1) Start Installation or Update      
    2) Boot Installed System         
    3) Start Rescue System          
    
    > 1
    
    Choose the source medium.
    
    0) <-- Back <--
    1) DVD / CD-ROM          
    2) Network             
    
    > 2
    
    Choose the network protocol.
    
    0) <-- Back <--
    1) FTP               
    2) HTTP              
    3) HTTPS              
    4) NFS               
    5) SMB / CIFS (Windows Share)   
    6) TFTP              
    
    > 2
    Detecting and loading network drivers
    
    Automatic configuration via DHCP?
    
    0) <-- Back <--
    1) Yes
    2) No
    
    > 1
    Sending DHCP request...
    8021q: adding VLAN 0 to HW filter on device eth0
    
    Enter the IP address of the HTTP server. (Enter '+++' to abort).
    > 10.0.2.2:8000
    
    Enter the directory on the server. (Enter '+++' to abort).
    [/]> 
    
    Do you need a username and password to access the HTTP server?
    
    0) <-- Back <--
    1) Yes
    2) No
    
    > 2
    
    Use a HTTP proxy?
    
    0) <-- Back <--
    1) Yes
    2) No
    
    > 2
    Loading Installation System (1/6) -      100%
    squashfs: version 4.0 (2009/01/31) Phillip Lougher
    Loading Installation System (2/6) -      100%
    Loading Installation System (3/6) -      100%
    Loading Installation System (4/6) -      100%
    Loading Installation System (5/6) -      100%
    Loading Installation System (6/6) -      100%
    Reading Driver Update...
    
    No new Driver Updates found
    
    Select the display type.
    
    0) <-- Back <--
    1) X11               
    2) VNC               
    3) SSH               
    4) ASCII Console          
    
    > 3
    
    Enter your temporary SSH password. (Enter '+++' to abort).
    > (doesn't echo, you'll need this below)
    
    starting hald... ok
    starting syslogd (logging to /dev/tty4)... ok
    starting klogd... ok
    sshd found, prepare remote login
    generating SSH keys  ...  
    ssh-keygen: generating new host keys: RSA1 RSA DSA ECDSA ED25519 
    Starting SSH daemon  ...  
    
    eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
        link/ether 08:00:2f:00:11:22 brd ff:ff:ff:ff:ff:ff
            inet 10.0.2.15/24 brd 10.0.2.255 scope global eth0
    	    inet6 fe80::a00:2fff:fe00:1122/64 scope link 
    	           valid_lft forever preferred_lft forever
    
             ***  sshd has been started  ***
    
    
             ***  login using 'ssh -X root@10.0.2.15'  ***
             ***  run 'yast' to start the installation  ***
    

At this, point, open a new terminal. SSH to locahost and not the reported 10.0.2.15 IP, since QEMU is forwarding the guest's port 22 to the host's port 10022. Do *not* pass the -X flag to ssh, since it will try to do X forwarding of the installer, and it's painfully slow.

    $ ssh -p 10022 root@localhost
    $ yast

From here, it's a normal SUSE install. It will halt when it's finished, and you can then start qemu *without* the supplied kernel and initrd, since it will boot from the root disk now:


    $ qemu-system-s390x -M s390-ccw-virtio -m 1024 -smp 1 -nographic \
      -drive file=SLES-11-SP4-s390x.qcow2,format=qcow2,if=none,id=drive-virtio-disk0 \
      -device virtio-blk-ccw,drive=drive-virtio-disk0,id=virtio-disk0 \
      -netdev user,id=mynet0,hostfwd=tcp::10022-:22 \
      -device virtio-net-ccw,netdev=mynet0,id=net0,mac=08:00:2F:00:11:22,devno=fe.0.0001

It will ask you to run  /usr/lib/YaST2/startup/YaST2.ssh , and after that is finished, you can reboot into a working system. Enjoy!
