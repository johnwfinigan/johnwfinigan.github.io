title: Firewalling Linux NFS Servers and OpenBSD NFS Clients
date: 2022-09-13
css: style.css
tags: firewall OpenBSD Linux nfs


## Firewalling Linux NFS Servers and OpenBSD NFS Clients

OpenBSD supports only NFS v3. It does not support NFS v4. While NFS v4 requires only port 2049/tcp to be open between clients and servers, NFS v3 typically requires three or four ports open between a client and a server, and most of these are dynamically chosen and have no fixed port number. NFS v3 predates the widespread use of firewalls and was not designed to be easily firewalled.

In order to firewall NFS v3, the server must be configured to run all needed NFS v3 services on fixed ports. On an OpenBSD client, no special configuration is required on the mount. However, I recommend configuring the mount to run over tcp, both to make firewalling easier and for general robustness. An OpenBSD fstab entry like the following is enough:

    172.16.1.6:/srv/data /data nfs rw,tcp 0 0

For the Linux server configuration, I will use Ansible and Firewalld, but there's nothing special about these and it should be easy to adapt this solution to any firewall or config management method. Ubuntu 22.04 has most NFS server config in ```/etc/nfs.conf```, while older distros such as Ubuntu 20.04 require editing multiple config files. I have configurations for both, below:

### Linux NFS Server Firewalld config

NFS client is at 172.16.1.77

```
---
- name: NFS server firewall config
  become: yes
  hosts: all
  tasks:


  - name: firewalld rich rules
    ansible.posix.firewalld:
      rich_rule: "{{ item }}"
      zone: public
      permanent: yes
      immediate: yes
      state: enabled
    loop:
      - rule family="ipv4" source address="172.16.1.77/32" port port="111" protocol="tcp" accept
      - rule family="ipv4" source address="172.16.1.77/32" port port="111" protocol="udp" accept
      - rule family="ipv4" source address="172.16.1.77/32" port port="50001-50003" protocol="tcp" accept
```

### Ubuntu 22.04 NFS Server Config

```/etc/nfs.conf``` is in ini file format. Ansible ```ini_file``` makes it easy to edit ini programatically, but if you're editing by hand, you can easily pull out the section name, option (key) names, and values below:


```
  - name: nfs v3 port locking for ubuntu 22.04 server
    ini_file:
      path: /etc/nfs.conf
      backup: yes
      section: "{{ item.s }}"
      option: "{{ item.o }}"
      value:  "{{ item.v }}"
    loop:
      - { s: "statd", o: "port", v: "50001" }
      - { s: "statd", o: "outgoing-port", v: "50000" }
      - { s: "mountd", o: "port", v: "50003" }
      - { s: "lockd", o: "port", v: "50002" }
      - { s: "lockd", o: "udp-port", v: "50004" }
```

All of the various NFS server-related services must be restarted to have this take effect. ```systemctl restart nfs-server``` was not sufficient for me. After much fooling around, I gave up and rebooted. I believe the problem may be that some of these services can listen on multiple ports, and a restart causes them to start listening on their new ports, but not abandon their old ports. Which port a new mount request gets is then unpredictable. 

Note that we are pinning the lockd UDP port to 50004 for thoroughness, but the tcp-only client will not use it. 


### Ubuntu 20.04 NFS Server Config  

This configuration, or a close variation on it, should work for any older Ubuntu or RHEL version from the last decade or so. Will not take effect until all NFS server-related services are restarted. 

```
   - name: port locked nfs config 1
     lineinfile:
       line: 'options lockd nlm_udpport=50004 nlm_tcpport=50002' 
       path: /etc/modprobe.d/nfs-lockd.conf
       mode: 0644
       owner: root
       group: root
       backup: yes
       create: yes
   
   - name: port locked nfs config 2
     lineinfile:
       line: 'STATDOPTS="--port 50001 --outgoing-port 50000"'
       path: /etc/default/nfs-common
       backup: yes
       regexp: '^STATDOPTS='
 
 
   - name: port locked nfs config 3
     lineinfile:
       line: 'RPCMOUNTDOPTS="--manage-gids --port 50003"'
       path: /etc/default/nfs-kernel-server
       backup: yes
       regexp: '^RPCMOUNTDOPTS='
```
