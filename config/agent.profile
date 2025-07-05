# Firejail security profile for mutation simulator agents
# This profile provides strict isolation for agent processes

# Disable network access
net none

# Create a private /tmp directory with only agent workspace
private-tmp
whitelist /tmp/agents
read-only /tmp/agents

# Disable access to user home directory
private-home

# Create minimal /etc with only essential files
private-etc passwd,group,ld.so.cache,ld.so.conf,ld.so.conf.d,locale.alias,localtime

# Disable access to /opt, /mnt, /media
blacklist /opt
blacklist /mnt  
blacklist /media

# Read-only access to system libraries and binaries
read-only /usr
read-only /lib
read-only /lib64
read-only /bin
read-only /sbin

# Disable access to device files
blacklist /dev
private-dev

# Disable access to system directories
blacklist /sys
blacklist /proc/sys
blacklist /proc/sysrq-trigger
blacklist /proc/mem
blacklist /proc/kmem
blacklist /proc/kcore

# Memory and CPU limits
rlimit-as 64m        # Virtual memory limit: 64MB
rlimit-cpu 5         # CPU time limit: 5 seconds
rlimit-fsize 1m      # File size limit: 1MB
rlimit-nproc 1       # Process limit: 1 process

# Disable capabilities
caps.drop all

# Disable new privileges
nonewprivs

# Use seccomp to restrict system calls
seccomp

# Disable X11
x11 none

# Disable audio
nosound

# Disable 3D acceleration
no3d

# Disable notifications
nodbus

# Set hostname
hostname agent-sandbox

# Enable process isolation
ipc-namespace
pid-namespace
uts-namespace

# Disable shell access
shell none