---
layout: post
title: "Minimum viable install: Nagios from epel on Centos 7, with Gmail notifications"

description: ""
category: 
tags: [nagios, centos 7, rhel, monitoring, minimum viable]
---
{% include JB/setup %}

This is how I got basic Nagios running on Centos 7, using the Nagios 3.5.1 packages in [EPEL](https://fedoraproject.org/wiki/EPEL). This is basically a reinterpretation of the guide at the [Nagios Fedora Quickstart](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/quickstart-fedora.html), except we are installing from packages and not source, and a lot of the paths and commands in Centos 7 are different.

Important - this all assmes that selinux is disabled. It will not work if selinux is enforcing. To check and change your selinux settings, edit /etc/sysconfig/selinux. We also assume that the machine you are working on is freshly installed and dedicated to Nagios.

First, to get a basic install running:

###As root:

     rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
     yum install  mod_ssl git nagios*

     chkconfig nagios on
     systemctl enable httpd
     systemctl enable firewalld
     service firewalld start
     firewall-cmd --zone=public --permanent --add-service=http
     firewall-cmd --zone=public --permanent --add-service=https

You can't add the permanent firewalld rules unless firewalld is already running, so we started it.

###Next, edit /etc/httpd/conf.d/nagios.conf

     Remove 2 instances of:
	    
     AuthType Basic
     AuthUserFile /etc/nagios/passwd
		        
     Replace with:
			      
     AuthType Digest
     AuthUserFile /etc/nagios/digest-passwd
		       

     Optionally, uncomment 2 instances of SSLRequireSSL

This accomplishes two things. Firstly, it changes the HTTP authentication method so passwords are never sent in cleartext, but rather in hashed form. Secondly, and optionally, it denies access to Nagios over http, and enforces the use of https. Edit /etc/httpd/conf.d/ssl.conf to point it to a signed ssl certificate if desired.

###As root:
In order to use digest passwords instead of plaintext passwords, we have to create the digest password file:

     htdigest -c /etc/nagios/digest-passwd "Nagios Access" nagiosadmin
     # will prompt for password

     chown root:apache /etc/nagios/digest-passwd
     chmod 640 /etc/nagios/digest-passwd

Next, reboot! This is partially out of laziness so we dont have to start the services manually, and partially due to a virtuous desire to see if our services autostart as requested.

    reboot

At this point you should be able to log in to Nagios on both http and https.

###Next, edit /etc/nagios/objects/contacts.cfg

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
            email                           sysadmin@example.com   <-- CHANGE THIS!
     }

###Define some things to monitor 
By default, what you put in /etc/nagios/conf.d/ gets monitored.

    cd /etc/nagios/conf.d

This directory **starts empty** and you can add config files organized however you like. Here's one barebones layout, as an example. Don't copy and paste, since the hostnames are up to you.

Contents of file /etc/nagios/conf.d/hosts.cfg

    define hostgroup{
            hostgroup_name  all-servers ; The name of the hostgroup
            alias           All Servers ; Long name of the group
    }
    
    define host{
            use             linux-server            ; Inherit default values from a template
            host_name       myserver.example.com    ; The name we're giving to this host
            alias           myserver                ; A longer name associated with the host
            address         10.0.0.10
            hostgroups      all-servers             ; Host groups this host is associated with
    }


Contents of file /etc/nagios/conf.d/ssh.cfg

    define service{
    	use		        generic-service	
    	host_name		myserver.example.com
    	service_description	SSH
    	check_command	        check_ssh
    }

Contents of file /etc/nagios/conf.d/http.cfg

    define service{
    	use		        generic-service
    	host_name		myserver.example.com
    	service_description	HTTP
    	check_command	        check_http
    }

    define service{
    	use		        generic-service
    	host_name		myserver.example.com
    	service_description	HTTP
    	check_command	        check_http!-S -H mysite.example.com  ; checks https on a different virtual host
    }

Important fact: these check commands live in /usr/lib64/nagios/plugins, and can be run manually, including to get help.

    /usr/lib64/nagios/plugins/check_http -h


###Test your config 

If it works, restart Nagios to pick up config file changes. You will do this a lot.

    /usr/sbin/nagios -v /etc/nagios/nagios.cfg
    service nagios restart

###Gmail Notifications

Finally, let's get some notifications going. Nagios is ready to notify as soon as we have a working mta. I use gmail, and don't want to run a real MTA like sendmail. Taking inspiration from [here](http://sharadchhetri.com/2013/07/16/how-to-use-email-id-of-gmail-for-sending-nagios-email-alerts/), we will use the ssmtp "send-only sendmail emulator", but moving around binaries like in the linked post makes me nervous since the moves will be clobbered by future Centos updates, so we'll use the alternatives system to subsititute ssmtp for sendmail instead.

Be very careful if you are already running a MTA like sendmail on your nagios machine and want it to keep working.

    yum install ssmtp
    alternatives --install /sbin/sendmail sendmail /sbin/ssmtp 100

Then append the following to /etc/ssmtp/ssmtp.conf

    AuthUser=my-nagios-sender@gmail.com   <-- CHANGE THIS!
    AuthPass=password123                  <-- CHANGE THIS!
    FromLineOverride=YES
    mailhub=smtp.gmail.com:587
    UseSTARTTLS=YES

###Done!

This is a start anyway. You can spend as much time as you like refining your config; if anything, the difficulty in getting started is that there are so many options.
