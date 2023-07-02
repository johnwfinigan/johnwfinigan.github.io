title: Creating a Minimal apt Repo From Scratch
date: 2023-02-05
css: style.css
tags: ubuntu apt deb Linux repos


## Creating a Minimal apt Repo From Scratch

Let's say you want to create an apt repo for debs you have built yourself. I spent an hour or two cobbling together these minimalist instructions from various internet sources. The sources I found seemed to be either outdated enough that they were no longer correct for recent tooling and distros, or more complex than what I was trying to accomplish warranted. This is tested against Ubuntu 22.04 clients and servers. Notably, this method has no directory structure inside the repo at all. All files are under the top level directory of the repo. 

### Create a gpg key for signing 

Use the gpg shipped with Ubuntu 22.04 or whatever client distro you plan to support. Set the ```Real Name``` field of your key to whatever you like. Here, it's called ```Mirror Signing Key```. Once generated, export your key using the fingerprint shown when it was generated.

```
gpg --armor --export 73341B91FEC7DCBC8316EE01E45BEE2E63B81095 > MirrorSigningKey.pub
```

This exported key will be copied to your apt clients for apt metadata verification.

Example gpg session at the bottom of this post. In short, it's OK to choose ```RSA and RSA```, and set RSA key size to 4096.

### Populate your repo

Put your debs in a directory that you intend to serve to your clients. Here, it's called ```$repo_dir```

### Install repo build tools

Ensure you have the packages ```dpkg-deb``` and ```apt-utils``` installed, for the next step.

### Create your apt repo

```
#!/bin/bash

set -eu

repo_dir=/path/to/your/repo/directory
cd "$repo_dir"

rm -vf Release Release.gpg InRelease
dpkg-scanpackages --arch amd64 . > Packages
apt-ftparchive release . > Release

echo Enter Passphrase
read pass
gpg  --pinentry-mode loopback --digest-algo SHA512 --batch --yes --no-tty --passphrase $pass --default-key 'Mirror Signing Key' -abs < Release > Release.gpg
gpg  --pinentry-mode loopback --digest-algo SHA512 --batch --yes --no-tty --passphrase $pass --default-key 'Mirror Signing Key' -abs --clearsign < Release > InRelease
unset pass
```

The awkward method of getting the passphrase to gpg is not appropriate for use on untrusted systems, since the passphrase can be read out of ```/proc``` while gpg is executing. Proper gpg pin entry methods seem especially fragile on headless systems, and after an hour of frustration trying to debug pinentry, I resorted to it. Someone with better gpg skills could do better. On the other hand, it's easy to see how this could be modified to work with a secret manager in a CI system - just replace the ```read``` call with a call to your secret manager.

### Set up your clients 

On your clients, create the repo definition file and the public signing key file in ```/etc/apt```

```
install -o root -g root -m0644 <(echo 'deb [signed-by=/etc/apt/trusted.gpg.d/MirrorSigningKey.pub] https://example.org/your/repo ./') /etc/apt/sources.list.d/your_repo.list

install -o root -g root -m0644 MirrorSigningKey.pub /etc/apt/trusted.gpg.d/
```

Note that I'm using ```install``` here as an all-in-one way to copy data while ensuring that permissions are reasonable. Your preferred way to do that should be fine, regardless.

### Done

When you add, update, or remove packages from your repo, simply rerun the repo generation script above.


### Appendix: GPG sample session

```
john@s:~$ gpg --full-generate-key
gpg (GnuPG) 2.2.27; Copyright (C) 2021 Free Software Foundation, Inc.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

gpg: directory '/home/john/.gnupg' created
gpg: keybox '/home/john/.gnupg/pubring.kbx' created
Please select what kind of key you want:
   (1) RSA and RSA (default)
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
  (14) Existing key from card
Your selection? 1
RSA keys may be between 1024 and 4096 bits long.
What keysize do you want? (3072) 4096
Requested keysize is 4096 bits
Please specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0) 
Key does not expire at all
Is this correct? (y/N) y

GnuPG needs to construct a user ID to identify your key.

Real name: Mirror Signing Key
Email address: mirrorsignkey@example.org
Comment: 
You selected this USER-ID:
    "Mirror Signing Key <mirrorsignkey@example.org>"

Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? O
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.


gpg: /home/john/.gnupg/trustdb.gpg: trustdb created
gpg: key E45BEE2E63B81095 marked as ultimately trusted
gpg: directory '/home/john/.gnupg/openpgp-revocs.d' created
gpg: revocation certificate stored as '/home/john/.gnupg/openpgp-revocs.d/73341B91FEC7DCBC8316EE01E45BEE2E63B81095.rev'
public and secret key created and signed.

pub   rsa4096 2023-02-06 [SC]
      73341B91FEC7DCBC8316EE01E45BEE2E63B81095
uid                      Mirror Signing Key <mirrorsignkey@example.org>
sub   rsa4096 2023-02-06 [E]
```
