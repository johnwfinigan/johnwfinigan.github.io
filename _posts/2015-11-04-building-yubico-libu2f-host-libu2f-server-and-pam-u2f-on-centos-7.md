---
layout: post
title: "Building Yubico libu2f host, libu2f server, and pam u2f on CentOS 7"
description: ""
category: 
tags: ["centos 7", "rhel", "yubikey", "u2f", "security"]
---
{% include JB/setup %}

[FIDO U2F](https://www.yubico.com/applications/fido) is a new two factor authentication
standard which lets you use a hardware 2FA device like the [Yubikey Edge](https://www.yubico.com/products/yubikey-hardware/yubikey-edge) to authenticate
to any number of services using public key based authentication that's unique to each
service. 

Yubico has a PAM module to do U2F authentication to a Linux system. Importantly,
you have to be present at the system to insert your U2F device into a USB port
for this to work. The reason is that U2F requires a full USB connection to the 
device, which has an embedded secure processor. It does not work by using the 
U2F device as a USB HID device like a keyboard.

Consequently, you **can't** use this for SSH authentication to a remote system 
yet. OpenSSH server **and client** will have to be modified for this to work.
I do not believe there is an official patch to OpenSSH yet. But I hope one will 
appear eventually.

Google Chrome does have the ability to talk to U2F devices directly over USB,
so for web service authentication, U2F already works fine--if you're using Chrome.

Yubico's instructions for building their U2F PAM infrastructure are good but
Ubuntu-centric. Here is how I got [pam-u2f](https://developers.yubico.com/pam-u2f)
 and its dependencies, [libu2f-host](https://developers.yubico.com/libu2f-host) and
 [libu2f-server](https://developers.yubico.com/libu2f-server) built on CentOS 7.1 minimal.

     #install build dependencies - calibrated for Centos 7 minimal install      
     sudo yum -y groupinstall "Development Tools"                                  
     sudo rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
     sudo yum -y install pam-devel gtk-doc help2man json-c-devel hidapi-devel gengetopt openssl-devel check-devel
                                                                                   
     #help2adoc is only required for make check on u2f server to pass           
     cd                                                                         
     git clone https://github.com/klali/help2adoc.git                           
     cd help2adoc                                                               
     sudo yum -y install asciidoc #only needed for help2adoc                    
     make                                                                       
     sudo make install                                                          
                                                                                
     cd                                                                         
     git clone git://github.com/Yubico/libu2f-host.git                          
     cd libu2f-host                                                             
     make                                                                       
     ./configure --enable-gtk-doc                                               
     make check                                                                 
     sudo make install                                                          
                                                                                
     cd                                                                         
     git clone git://github.com/Yubico/libu2f-server.git                        
     cd libu2f-server                                                           
     autoreconf --install                                                       
     ./configure --enable-gtk-doc                                               
     make check                                                                 
     sudo make install                                                          
                                                                                
     cd                                                                         
     git clone git://github.com/Yubico/pam-u2f.git                              
     cd pam-u2f                                                                 
     export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig                            
     autoreconf --install                                                       
     ./configure                                                                
     make check                                                                    
     sudo make install    


