---
weight: 100  
title: 逻辑卷扩容  
slug: 逻辑卷扩容  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:14:01+08:00  
lastmod: 2025-12-15T09:21:59+08:00
---
ubuntu22 默认的设置中14.2G的磁盘只分配了10G给逻辑卷  
```  
newuser@ubuntu22:~$ df -h  
Filesystem                         Size  Used Avail Use% Mounted on  
tmpfs                              197M  1.3M  196M   1% /run  
/dev/mapper/ubuntu--vg-ubuntu--lv  9.8G  4.9G  4.4G  53% /  
tmpfs                              982M     0  982M   0% /dev/shm  
tmpfs                              5.0M     0  5.0M   0% /run/lock  
/dev/sda2                          1.7G  130M  1.5G   8% /boot  
tmpfs                              197M  4.0K  197M   1% /run/user/1000  
newuser@ubuntu22:~$ lsblk  
NAME                MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS  
loop0                 7:0    0 63.9M  1 loop /snap/core20/2318  
loop1                 7:1    0   87M  1 loop /snap/lxd/29351  
loop2                 7:2    0 38.8M  1 loop /snap/snapd/21759  
sda                   8:0    0   16G  0 disk  
├─sda1                8:1    0    1M  0 part  
├─sda2                8:2    0  1.8G  0 part /boot  
└─sda3                8:3    0 14.2G  0 part  
  └─ubuntu--vg-ubuntu--lv  
                    253:0    0   10G  0 lvm  /  
sr0                  11:0    1 1024M  0 rom  
# 物理卷  
newuser@ubuntu22:~$ sudo pvdisplay  
  --- Physical volume ---
  PV Name               /dev/sda3  
  VG Name               ubuntu-vg  
  PV Size               <14.25 GiB / not usable 0  
  Allocatable           yes  
  PE Size               4.00 MiB  
  Total PE              3647  
  Free PE               1087  
  Allocated PE          2560  
  PV UUID               C073w4-VDWT-LGGe-LHpi-4kJS-SFAi-whZ9QC  
# 卷组  
newuser@ubuntu22:~$ sudo vgdisplay  
  --- Volume group ---
  VG Name               ubuntu-vg  
  System ID  
  Format                lvm2  
  Metadata Areas        1  
  Metadata Sequence No  2  
  VG Access             read/write  
  VG Status             resizable  
  MAX LV                0  
  Cur LV                1  
  Open LV               1  
  Max PV                0  
  Cur PV                1  
  Act PV                1  
  VG Size               <14.25 GiB  
  PE Size               4.00 MiB  
  Total PE              3647  
  Alloc PE / Size       2560 / 10.00 GiB  
  Free  PE / Size       1087 / <4.25 GiB  
  VG UUID               XTY1w3-T1co-YjRN-D9Hs-Gfav-M7Ms-l236bp  
# 逻辑卷  
newuser@ubuntu22:~$ sudo lvdisplay  
  --- Logical volume ---
  LV Path                /dev/ubuntu-vg/ubuntu-lv  
  LV Name                ubuntu-lv  
  VG Name                ubuntu-vg  
  LV UUID                Z0Dmgj-kPwo-UHEe-n8e7-jb9H-aEDe-u3Y2C1  
  LV Write Access        read/write  
  LV Creation host, time ubuntu-server, 2025-10-25 02:51:29 +0000  
  LV Status              available  
  # open                 1  
  LV Size                10.00 GiB  
  Current LE             2560  
  Segments               1  
  Allocation             inherit  
  Read ahead sectors     auto  
  - currently set to     256  
  Block device           253:0  
```  
可以使用  
```  
# 将逻辑卷扩展到卷组的全部可用空间  
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv  
```  
或者:  
```  
# 指定具体大小  
sudo lvextend -L +4.2G /dev/ubuntu-vg/ubuntu-lv  
```  
扩容后还没有调整文件系统大小:  
```  
newuser@ubuntu22:~$ sudo lvextend -L +4G /dev/ubuntu-vg/ubuntu-lv  
  Size of logical volume ubuntu-vg/ubuntu-lv changed from 10.00 GiB (2560 extents) to 14.00 GiB (3584 extents).  
  Logical volume ubuntu-vg/ubuntu-lv successfully resized.  
newuser@ubuntu22:~$ df -h  
Filesystem                         Size  Used Avail Use% Mounted on  
tmpfs                              197M  1.3M  196M   1% /run  
/dev/mapper/ubuntu--vg-ubuntu--lv  9.8G  4.9G  4.4G  53% /  
tmpfs                              982M     0  982M   0% /dev/shm  
tmpfs                              5.0M     0  5.0M   0% /run/lock  
/dev/sda2                          1.7G  130M  1.5G   8% /boot  
tmpfs                              197M  4.0K  197M   1% /run/user/1000  
newuser@ubuntu22:~$ lsblk  
NAME                MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS  
loop0                 7:0    0 63.9M  1 loop /snap/core20/2318  
loop1                 7:1    0   87M  1 loop /snap/lxd/29351  
loop2                 7:2    0 38.8M  1 loop /snap/snapd/21759  
sda                   8:0    0   16G  0 disk  
├─sda1                8:1    0    1M  0 part  
├─sda2                8:2    0  1.8G  0 part /boot  
└─sda3                8:3    0 14.2G  0 part  
  └─ubuntu--vg-ubuntu--lv  
                    253:0    0   14G  0 lvm  /  
sr0                  11:0    1 1024M  0 rom  
```  
根据使用的文件系统调整即可:  
```  
# df -T 查看文件系统  
newuser@ubuntu22:~$ df -T /  
Filesystem                        Type 1K-blocks    Used Available Use% Mounted on  
/dev/mapper/ubuntu--vg-ubuntu--lv ext4  10218772 5069204   4608896  53% /  
# 我这里使用的是ext4  
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv  
```  
然后就看到逻辑卷已经扩容了4G空间:  
```  
newuser@ubuntu22:~$ df -h  
Filesystem                         Size  Used Avail Use% Mounted on  
tmpfs                              197M  1.3M  196M   1% /run  
/dev/mapper/ubuntu--vg-ubuntu--lv   14G  4.9G  8.2G  38% /  
tmpfs                              982M     0  982M   0% /dev/shm  
tmpfs                              5.0M     0  5.0M   0% /run/lock  
/dev/sda2                          1.7G  130M  1.5G   8% /boot  
tmpfs                              197M  4.0K  197M   1% /run/user/1000  
```