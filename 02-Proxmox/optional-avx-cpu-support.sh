# define a new CPU model based on x86-64-v2-AES that also exposes AVX
# source: https://forum.proxmox.com/threads/cpu-with-avx-support.146138/

# New models can be defined here cluster wide:
nano /etc/pve/virtual-guest/cpu-models.conf

# Add this definition to the /etc/pve/virtual-guest/cpu-models.conf file:

cpu-model: x86-64-v2-AES-AVX
    flags +avx;+avx2;+xsave;+aes;+popcnt;+ssse3;+sse4_1;+sse4_2
    phys-bits host
    hidden 0
    hv-vendor-id proxmox
    reported-model kvm64

# It will then be immediately available in the GUI as a Custom (QEMU) CPU:
# All host must be compatible otherwise it will fail to migrate or failover :)