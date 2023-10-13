title: Limiting CPU and Memory on User Login Sessions with Systemd
date: 2023-10-13
css: style.css
tags: linux multiuser


## Limiting CPU and Memory on User Login Sessions with Systemd

On multiuser Linux systems you may need to limit the memory and CPU use of interactive users so that one user cannot hog or crash the box. There's several ways to do this, but I find the systemd approach to be the cleanest. On older systems like RHEL 7 you can still use cgroups with the ```cgred``` approach, and on really old systems there is still ```ulimit```

This approach uses a template for the systemd slice that a user's login session is added to on login. This allows you to use standard systemd resource controls as defined in [the systemd documentation](https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html)

At ```/etc/systemd/system/user-.slice.d/50-userlimits.conf``` create the following:

```
[Slice]
MemoryMax=50G
TasksMax=512
CPUQuota=400%
```

For a given user UID, you can then check some stats, including memory usage,  on their slice using ```systemctl``` - for example:

```
systemctl status user-12345.slice
```

Tested on RHEL 8 and 9.
