# Debian Images for Sophgo cv181x/sg200x based boards 
This repository builds debian sid images for Sophgo cv181x/sg200x based boards such as MilkV Duo256/DuoS and Sipeed LicheeRvNano.

## Image Info

**Logins: root/rv and debian/rv**

(root login is disabled via SSH, login via debian, and SU to root if needed)

### USB Gadget Support
by default, a rndis interface is started on the USB port, and the **IP address is 10.42.0.1** - It also starts a DHCP Server on that interface, so your PC should automatically get an IP address in the 10.42.0.x range

To Disable the rndis interface, you can run the following command:
```
systemctl disable usb-gadget-rndis
```

There is also a option to start a serial port (ACM) interface instead of the rndis interface, to do this, you can run the following command:
```
systemctl disable usb-gadget-rndis
systemctl enable usb-gadget-acm
```

After executing these commands, you need to reboot.

### DuoS - USB Type A Port
After disabling the usb-gadgets, if you want to use the USB Type A Ports, then you need to turn them on:
```
systemctl enable usb-switch
```
and reboot afterwards. 

### DuoS - USB Type A Port
On Duos, a bash terminal is accesible via UART on UART0, pins UART0_TX/UART0_RX at https://milkv.io/docs/duo/getting-started/duos

### Wifi on DuoS/LicheeRVNano
For the LicheeRVNano/DuoS board, Wifi is enabled. To connect to your wifi network, execute the following command and select "Activate a connection" and select your wifi network:
```
nmtui
```

### Ethernet
For Boards with ethernet, they should automatically get a IP address if your network has a DHCP Server. You can configure the ethernet port in nmtui.

### Camera/ISP/Panel Support
The images are based on the vendor 5.10 kernel, but exclude the following drivers:
- mipi-rx/csi drivers
- mipi-tx/dsi drivers
- TPU Drivers
- Any of the Video Encoding Drivers

(this is mainly due to compatibility reasons with the glibc version in debian and musl version used in the vendor images)

The images, by default, do not allocate any memory for the ION heap, as they are unused in this image, so you get the full memory of each device

### Ardunio/Freertos Support
The images also include the remoteproc and mailbox drivers so you can load up ardunio/freertos images on the small C906 core. 

### Additional Packages
This image can add the debian repository for https://github.com/Fishwaldo/sophgo-sg200x-packages so you can install additional repositories. The debian repository is hosted at 
https://sophgo.my-ho.st:8443/ which pulls down the compiled debian packages from the above github repository occasionally.


## Building the Image

The configs directory contains patches, configuration and device tree files that are used to build the image.

The configs/common directory contains the common configuration for all boards, and the configs/duos directory contains the board specific configuration.

To add packages to the image, either add the package name in PACKAGES variable of configs/settings.mk or if the package is specific to a board, add it to the configs/\<board\>/settings.mk file

Patches for the kernel, opensbi, u-boot or fsbl can be placed in configs/common/patches/ or configs/\<board\>/patches/ depending what they are for.

To assist with developing the image, you can get a shell in the docker container by running:
```
sudo ./build_docker.sh
sudo docker run --privileged --rm tonistiigi/binfmt --install all
sudo docker run --privileged -it --rm -v ./configs/:/configs -v ./image:/output -v ./scripts/:/builder builder /bin/bash
```
Inside the container, packages are build in the /builder/ directory, and the rootfs is placed at /rootfs/ directory
```
make BOARD=duos image
```

Supported BOARS are :
- duo256
- duos
- licheervnano

If you want to create a image for the DuoS with EMMC, you can add "STORAGE_TYPE=emmc" to the make command:
```
make BOARD=duos STORAGE_TYPE=emmc image
```

The Docker image will build the image and place it in the image directory

addition make targets are available when building:
- image - builds the image
- clean - cleans the build directory
- linux - build a kernel debian package
- fsbl - build the fsbl debain package (that includes cvitek-fsbl, opensbi and u-boot)


## Building a Secure Image
This repository also support a fully secure Debian image, which include U-Boot FIT Signature Verification and IMA appraisal. 

> [!NOTE]
>The Milk-V Duo S (CV1800B/SG2002 SoC) supports a hardware secure boot feature. Secure boot ensures the bootloader and OS are cryptographically verified before execution, so only firmware signed with your keys will run. In practice, the Boot ROM will only load a signed boot image (FIP) that matches a public key hash burned into the chip’s OTP (eFuse) memory. This prevents others from booting tampered or unauthorized code on your board. The secure boot process on this SoC works as follows:
> 1. **Boot ROM -> FSBL:** On reset, the on-chip ROM loads the First Stage Boot Loader (FSBL) from flash into SRAM. If secure boot is enabled, the ROM verifies the FSBL’s digital signature using a stored key-hash. If it succeeds, the FSBL runs. 
> 2. **FSBL -> OpenSBI/Second Stage -> U-Boot:** The FSBL initializes DDR RAM and then loads the next stages (OpenSBI “Monitor” and U-Boot) from the flash image (the FIP bundle). The FSBL verifies these components’ signatures (using a public key, typically embedded or derived from OTP) before handing control over. If any signature check fails, the device will reset or halt, preventing untrusted code.
> 3. **U-Boot -> Kernel:** Finally, U-Boot loads the Linux kernel. To complete the chain of trust, we also configure U-Boot to verify the kernel’s signature during booting. When Secure Boot is enabled, IMA appraisal can deny access to files that have been modified, extending the trust established during boot into the running operating system. 
 
Building a secure and signed Debian image, with a full chain of trust implemented requires several preliminary steps. First at all we need to generate all the required keys, all stored in the keydir directory. 

Create keydir folder inside the main repo directoy:
```
mkdir keydir
```
you should have something like:
```
rtkbase_debian/
├── configs
├── image
├── keydir
└── scripts
```

> [!CAUTION]
> The content of the folder keydir must be kept strictly private and must not be shared with anybody. Be sure not to commit this folder or upload it on a open access cloud. Any data leakage will completely broke the chain of trust making the image vulnerable to malicius attaks.

Inside keydir, generate the FIP keys with the following:
```
openssl genrsa -out rsa_hash0.pem -F4 2048
openssl genrsa -out bl_priv.pem -F4 2048
```
Again inside keydir, run:
```
../configs/ima_appraisal/generate_ima_keys.sh 
```
The script will generate a series of keys implementing an auto-generated full chain of trust. The most important keys are:
  - ima_local_ca.pem      → CA public cert (embed via CONFIG_SYSTEM_TRUSTED_KEYS)
  - ima_local_ca.priv     → CA private key (keep secure, used for signing)
  - privkey_ima.pem       → IMA signing private key (use with evmctl)
  - ima.der          → IMA signing certificate (load via CONFIG_IMA_LOAD_X509 or keyctl)

Now, we are ready to build the image, note that this time the Linux kernel defconfing are specific to defconfig_ima.
```
sudo docker run --privileged --rm tonistiigi/binfmt --install all

sudo docker run --privileged -it --rm -v ./configs/:/configs -v ./image:/output -v ./scripts/:/builder -v ./keydir/:/keydir builder /bin/bash
```
inside the container run:
```
make BOARD=duos SIGN_FIP=1 IMA=1 image
```
at the end of the built, if there are no errors, the FIP hash to be used for the MilkV eFuses is saved:
```
rtkbase_debian/
├── configs
├── image
├── keydir/
│   └── KPUB_HASH.txt
└── scripts
```
### Secure Boot eFuse Setup Process

Use this guide to program the eFuse on the processor: https://doc.sophgo.com/cvitek-develop-docs/master/docs_latest_release/CV180x_CV181x/en/01.software/BSP/eFuse_User_Guide/build/html/index.html

> [!CAUTION]
> eFuse cannot be erased after writing 1 every bit (only allowed to change from 0 to 1), please pay attention before writing. After the specified eFuse is locked, it can no longer be read or written. Please pay attention before locking.

Write the sha256 value required for signature verification into the “SHA256 summary required for signature verification” area of eFuse. The data is an array of 32, expressed as 64 numbers in hexadecimal.
```
u-boot# efusew HASH0_PUBLIC 978bc2031b9377dadb4c7c34467ee985806a63a3ac8ee293a3f0eddcd2b789d8
```
Lock the key area to prevent reading and writing.
```
u-boot# efusew LOCK_HASH0_PUBLIC 01
```
Enable RSA verification process
```
u-boot# efusew SECUREBOOT 01
```

### IMA appraisal policy

The default policy used during build is stored in the CONFIG_IMA_DEFAULT_POLICY variable in `configs/duos/linux/defconfig_ima`. 

At boot the system automatically load the `/etc/ima/ima-policy` (if exists). The policy can be enforced, for example with the command:
```
sudo tee /etc/ima/ima-policy <<EOF
measure func=BPRM_CHECK
appraise func=BPRM_CHECK mask=MAY_EXEC fowner=1000
EOF
```
(here we ask to verify the sign of every executable owned by the Debian user)

followed by the policy update command
```
sudo cat /etc/ima/ima-policy | sudo tee /sys/kernel/security/ima/policy
```

## Flashing the Image

### Duo256, DuoS, and LicheeRVNano
To flash from linux, either build your own image, or download a image from the releases page, and then run the following command:
```
sudo dd if=image/(board)_sd.img of=/dev/sdX bs=4M status=progress
```

From windows, you can use tools such as balena etcher

where the (board)_sd.img is the image file you want to flash, and /dev/sdX is the device you want to flash to.
(if you build for a different board, the image file name will be different)

### DuoS with EMMC
To flash the DuoS with EMMC, you need to use the vendor tools to flash the image to the EMMC. You can follow the
instructions at https://milkv.io/docs/duo/getting-started/duos#emmc-version-firmware-burning but instead of downloading 
the  milkv-duos-emmc-v1.1.0-2024-0410.zip file, you download the duos_emmc.zip from the releases on this repository.

if you already have a image installed, but wish to upgrade, when u-boot loads up, interupt the boot process by pressing any
key and typing the following commands:
```
cvi_update
```

The flashing should then continue