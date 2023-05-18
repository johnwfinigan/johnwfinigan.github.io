title: Polyinstantiating tmp Directories in RHEL 8
date: 2023-05-18
css: simple.css
tags: linux rhel selinux security

## Polyinstantiating tmp Directories in Modern RHEL

Polyinstantiation is a Linux security feature for giving each user a private virtual copy of normally globally visible directories such as ```/tmp```. Linux kernel namespaces are used to map each user's view of the polyinstantiated directory to a separate directory in the default namespace. This is useful for eliminating the side channel that allows users to defeat administratively set file permissions and share data inappropriately by copying it into world writable directories such as ```/tmp```. When ```/tmp``` is polyinstantiated, the user sees his own data in ```/tmp``` and nothing else.

This is similar to the systemd ```PrivateTmp``` hardening feature, but implemented differently.

I have never had good luck with the instructions generally found online for polyinstantiation, [such as these](https://www.redhat.com/en/blog/polyinstantiating-tmp-and-vartmp-directories). They've generally resulted in a broken system for me. The following works for me on RHEL 8. I haven't modified ```pam.d``` files because namespace support was already there by default. I did not manually create the polyinstantiation roots, because I am using the automatic creation feature below. 

```
---
- become: yes
  hosts: all
  tasks:

  - name: polyinstantiate /tmp
    lineinfile:
      path: /etc/security/namespace.conf
      line: '/tmp     /tmp/tmp-inst/       	level:create=0000,root,root   root,adm'

  - name: polyinstantiate /var/tmp
    lineinfile:
      path: /etc/security/namespace.conf
      line: '/var/tmp /var/tmp/tmp-inst/   	level:create=0000,root,root   root,adm'

  - name: polyinstantiate /dev/shm
    lineinfile:
      path: /etc/security/namespace.conf
      line: '/dev/shm    /dev/shm/shm-inst/  tmpfs:create=0000,root,root:mntopts=nodev,nosuid,size=128M      root,adm'

  - name: set polyinstantiation selinux boolean
    seboolean:
      name: polyinstantiation_enabled
      state: true
      persistent: true
```

You'll note that ```/dev/shm``` is created differently, as a ```tmpfs``` mount. Trying to create it via ```level``` in the existing ```/dev/shm``` produced a broken system. 

The ```namespace.conf mntopts``` syntax is only supported on ```tmpfs```, but I am mounting the underlying global ```/tmp``` and ```/var/tmp``` with ```nodev,nosuid``` also, and this carries into the polyinstantiated mounts that are rooted there.

This config probably depends on SELinux.
