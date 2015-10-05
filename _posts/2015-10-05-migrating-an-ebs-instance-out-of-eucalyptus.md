---
layout: post
title: "Migrating an EBS instance out of Eucalyptus"
description: ""
category: 
tags: [virtualization, cloud, storage, Linux]
---
{% include JB/setup %}

One of my internal customers asked me to help decomission a [Eucalyptus 4](https://en.wikipedia.org/wiki/Eucalyptus_%28software%29) private cloud setup. Before we turned it off, he wanted to export a couple of the EBS backed instances to a generic format that could be used in KVM on vanilla Linux.

Eucalyptus is an AWS API compatible private cloud provider that runs on top of Linux and uses KVM internally. EBS volumes and snapshots are implemented on the host side using container files, lvm, and loop devices. Between nodes, the loop devices are shared via the Linux iSCSI target. Eucalyptus handles creating the loop devices on the fly, and so you can't get access to a volume's raw contents easily unless the EBS backed instance is booted.

This is bad, since imaging a running machine without snapshotting it will give you a corrupted image. One option would be to create EBS snapshots of all of the EBS instances you want to image, but this is slow (Eucalyptus makes a full copy), and we did not have enough free disk space to hold the copies even if we were willing to wait.

My first guess was to try shutting down the EBS instances and attaching all of their boot volumes to an ephemeral instance. I then planned to dd out their (unmounted) contents to a NFS volume. However, Eucalyptus requires detaching the volumes from the EBS instance before attaching them somewhere else, and for an Eucalyptus EBS instance, detaching its boot volume is a disruptive operation for obvious reasons.

Some experimentation with the `file` command showed that the volume container files in `/var/lib/eucalyptus/volumes` were container files that had been made into lvm physical volumes with `pvcreate`, and each container file contained one volume group and one logical volume. The LV was a raw image of the EBS backed instance's boot volume, partition table and all.

From there, the plan was easy: log directly into the server that the container file is stored on. **With all instances powered down and after rebooting to un-loop all volumes and shutting down Eucalyptus services**, which was feasible since we we were decommissioning, I did something like this (from notes):

**Warning: dangerous operations below. If you're not comfortable with Linux storage management and can't explain every line below, don't do it. If you don't have good backups, don't do it. Even if you do know what you're doing, bad things may happen.**

     [root@localhost vagrant]# lsblk
      NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
      sda      8:0    0 97.7G  0 disk 
      ├─sda1   8:1    0  250M  0 part /boot
      ├─sda2   8:2    0  1.5G  0 part [SWAP]
      └─sda3   8:3    0 95.9G  0 part /
      
     (confirmed that there are no volume containers attached to loop devices)
      
     [root@localhost ~]#  cd /var/lib/eucalyptus/volumes/
     [root@localhost volumes]# ls
     volume-4708bf47  volume-56d555f4
     [root@localhost volumes]# losetup -f volume-4708bf47
     [root@localhost volumes]# losetup -f volume-56d555f4
     [root@localhost volumes]# lsblk
     NAME                                                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
     sda                                                         8:0    0 97.7G  0 disk 
     ├─sda1                                                      8:1    0  250M  0 part /boot
     ├─sda2                                                      8:2    0  1.5G  0 part [SWAP]
     └─sda3                                                      8:3    0 95.9G  0 part /
     loop0                                                       7:0    0 1001M  0 loop 
     └─eucatestvg--volume--4708bf47-eucatest--volume--4708bf47 253:0    0  800M  0 lvm  
     loop1                                                       7:1    0 1001M  0 loop 
     └─eucatestvg--volume--56d555f4-eucatest--volume--56d555f4 253:1    0  800M  0 lvm 
     [root@localhost volumes]# lvscan
       ACTIVE            '/dev/eucatestvg-volume-56d555f4/eucatest-volume-56d555f4' [800.00 MiB] inherit
       ACTIVE            '/dev/eucatestvg-volume-4708bf47/eucatest-volume-4708bf47' [800.00 MiB] inherit
     
     (At this point, you may have to use vgchange -ay if the volumes show up as INACTIVE)
     
     [root@localhost volumes]# dd if=/dev/eucatestvg-volume-4708bf47/eucatest-volume-4708bf47 of=volume-4708bf47-export bs=1M
     800+0 records in
     800+0 records out
     838860800 bytes (839 MB) copied, 2.8842 s, 291 MB/s
     [root@localhost volumes]# dd if=/dev/eucatestvg-volume-56d555f4/eucatest-volume-56d555f4 of=volume-56d555f4-export bs=1M
     800+0 records in
     800+0 records out
     838860800 bytes (839 MB) copied, 2.65189 s, 316 MB/s
     [root@localhost volumes]# ls
     volume-4708bf47  volume-4708bf47-export  volume-56d555f4  volume-56d555f4-export

From here, the exported volumes were bootable in KVM. This isn't exactly a cookbook, but it's a starting point if you're trying to get VMs out of Eucalyptus.
