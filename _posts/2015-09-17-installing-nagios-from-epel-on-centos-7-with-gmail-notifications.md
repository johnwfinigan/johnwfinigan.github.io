---
layout: post
title: "Installing Nagios from epel on Centos 7, with Gmail notifications"
description: ""
category: 
tags: [nagios, centos7, rhel, monitoring]
---
{% include JB/setup %}

This is how I got basic Nagios running on Centos 7, using the Nagios 3.5.1 packages in [EPEL](https://fedoraproject.org/wiki/EPEL). This is basically a reinterpretation of the guide at the [Nagios Fedora Quickstart](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/quickstart-fedora.html), except we are installing from packages and not source, and a lot of the paths and commands in Centos 7 are different.

Important - this all assmes that selinux is disabled. It will not work if selinux is enforcing. To check and change your selinux settings, edit /etc/sysconfig/selinux

First, to get a basic install running:

As root:

     rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
     yum install  mod_ssl git nagios*

     chkconfig nagios on
     systemctl enable httpd
     systemctl enable firewalld
     service firewalld start
     firewall-cmd --zone=public --permanent --add-service=http
     firewall-cmd --zone=public --permanent --add-service=https

You can't add the permanent firewalld rules unless firewalld is already running, so we started it.

Next, edit /etc/httpd/conf.d/nagios.conf

     Remove 2 instances of:
	    
     AuthType Basic
     AuthUserFile /etc/nagios/passwd
		        
     Replace with:
			      
     AuthType Digest
     AuthUserFile /etc/nagios/digest-passwd
		       

     Optionally, uncomment 2 instances of SSLRequireSSL

This accomplishes two things. Firstly, it changes the HTTP authentication method so passwords are never sent in cleartext, but rather in hashed form. Secondly, and optionally, it denies access to Nagios over http, and enforces the use of https. Edit /etc/httpd/conf.d/ssl.conf to point it to a signed ssl certificate if desired.

In order to use digest passwords instead of plaintext passwords, we have to create the digest password file:

     htdigest -c /etc/nagios/digest-passwd "Nagios Access" nagiosadmin
     # will prompt for password

     chown root:apache /etc/nagios/digest-passwd
     chmod 640 /etc/nagios/digest-passwd

Next, reboot! This is partially out of laziness so we dont have to start the services manually, and partially due to a virtuous desire to see if our services autostart as requested.

    reboot

At this point you should be able to log in to Nagios on both http and https.

Next, edit /etc/nagios/objects/contacts.cfg

    Find the line containing CHANGE THIS TO YOUR EMAIL ADDRESS , and do what it asks.

    Append a sample notification contact and contact group to the end of the file:
    Don't forget to change the email address below.

    define contactgroup {
            contactgroup_name       testgroup
            alias                   Test Contact Group
            members                 testsysadmin
    }
    
    define contact {
            contact_name                    testsysadmin
            alias                           Test-Sysadmin
            service_notification_period     24x7
            host_notification_period        24x7
            service_notification_options    c,r
            host_notification_options       d,r
            service_notification_commands   notify-service-by-email
            host_notification_commands      notify-host-by-email
            email                           sysadmin@example.com   <--CHANGE THIS!
     }

Test your config. You will do this a lot:

    /usr/sbin/nagios -v /etc/nagios/nagios.cfg

Next, we'll need to define some things to monitor. By defauly, what you put in /etc/nagios/conf.d/ gets monitored.

    cd /etc/nagios/conf.d

Here's one barebones layout, as an example:

