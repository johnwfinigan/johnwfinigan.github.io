---
layout: post
title: "Building attic backup software on CentOS 7"
description: ""
category: 
tags: ["centos 7", rhel, backup, attic]
---
{% include JB/setup %}

I used to work at a backup vendor. I learned a lot, but am still consistently 
surprised at how expensive good backup software can be. In particular, if you
require that your backups be both encrypted (encrypted data at rest) and also
bandwith efficient, few open source packages will do that for you. If you also
require that older backups can be expired and deleted on a pick-and-choose basis,
while still being deduplicated, the bar is even higher.

[Attic](https://attic-backup.org/) is a pretty great open source backup tool.
It provides encrypted, deduplicated, expirable incremental-forever backups, and
is written in a mix of Python3 and a little bit of C.

Here's how to get it working on CentOS 7 minimal, using pip and EPEL for 
prerequisites:

As root:
       
       rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
       yum -y install python34-devel openssl-devel gcc libacl-devel
       curl -O https://bootstrap.pypa.io/get-pip.py                   
       python3.4 get-pip.py                                           
       pip3.4 install attic  

Once you get it installed, here's how you might back up to a remote system you 
are able to ssh to. Note that attic must be installed on the destination 
system as well.

One time, to set up the remote repository:

       attic init --encryption=keyfile myuser@server.example.com:/home/myuser/attic-test

Each time, to back up:
(each backup set will have a name ending with the current date, and /home gets backed up)

       attic create --stats myuser@server.example.com:/home/myuser/attic-test::mybackup-`date +%Y-%m-%d-%s` /home 

If you have ssh key authentication set up and do not password protect your attic keyfile, this can be run 
as a cron job. But these are just samples -- be sure to read the [Attic Documentation](https://attic-backup.org/index.html)
before deploying. (And test, test, test your restores!)

Bonus: If you're running the destination server, you can constrain the client's attic
backup user using SELinux. See [Major Hayden's blog post on constraining users](https://major.io/2013/07/05/confine-untrusted-users-including-your-children-with-selinux/) - SELinux guest_u works fine for me.
