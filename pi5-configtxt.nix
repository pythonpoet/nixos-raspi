{ config, pkgs, lib, ... }:

{
  hardware.raspberry-pi.config = {
    all = { # [all] conditional filter, https://www.raspberrypi.com/documentation/computers/config_txt.html#conditional-filters

      options = {
        # https://www.raspberrypi.com/documentation/computers/config_txt.html#enable_uart
        # in conjunction with `console=serial0,115200` in kernel command line (`cmdline.txt`)
        # creates a serial console, accessible using GPIOs 14 and 15 (pins 
        #  8 and 10 on the 40-pin header)
        enable_uart = {
          enable = true;
          value = true;
        };
        # https://www.raspberrypi.com/documentation/computers/config_txt.html#uart_2ndstage
        # enable debug logging to the UART, also automatically enables 
        # UART logging in `start.elf`
        uart_2ndstage = {
          enable = true;
          value = true;
        };
      };

      # Base DTB parameters
      # https://github.com/raspberrypi/linux/blob/a1d3defcca200077e1e382fe049ca613d16efd2b/arch/arm/boot/dts/overlays/README#L132
      base-dt-params = {

        # https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#enable-pcie
        pciex1 = {
          enable = true;
          value = "on";
        };
        # PCIe Gen 3.0
        # https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#pcie-gen-3-0
        pciex1_gen = {
          enable = true;
          value = "3";
        };

      };

    };
  };
  fileSystems."/data1" = {
    device = "/dev/disk/by-uuid/5a4cb152-78cc-4f24-9941-a11691c9bbca";
    fsType = "btrfs";  # ← Make sure this says "btrfs" not "brtfs"
    options = ["defaults" "noatime" "compress=zstd" "nofail"];
  };

  fileSystems."/data2" = {
    device = "/dev/disk/by-uuid/96d53b77-8166-4217-8101-cfbc14f64f32";
    fsType = "btrfs";  # ← Make sure this says "btrfs" not "brtfs"
    options = ["defaults" "noatime" "compress=zstd" "nofail"];
  };
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/98ce92d7-f04e-4940-8b84-dcfe8ec0c194";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/24D8-6F3A";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # swapDevices =
  #   [ { device = "/dev/disk/by-uuid/81c8115f-7268-4560-8fa8-2df6f51a9f12"; }
  #   ];
}