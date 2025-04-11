{
  description = ''
    Examples of NixOS systems' configuration for Raspberry Pi boards
    using nixos-raspberrypi
  '';

  nixConfig = {
    bash-prompt = "\[nixos-raspberrypi-demo\] ➜ ";
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
    connect-timeout = 5;
  };

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };

    disko = {
      # url = "github:nix-community/disko";
      url = "github:nvmd/disko/gpt-attrs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
    };
  };

  outputs = { self, nixpkgs
            , nixos-raspberrypi, disko
            , nixos-anywhere, ... }@inputs: {

    nixosConfigurations = let

      mkNixOSRPi = let
        # use `nixpkgs` used by nixos-raspberrypi
        # to be able to benefit from its cachix cache
        nixpkgs = self.inputs.nixos-raspberrypi.inputs.nixpkgs;
      in moreModules: nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = inputs;
        modules = [
          nixos-raspberrypi-config
        ] ++ moreModules;
      };

      nixos-raspberrypi-config = { config, ... }: {
        imports = with nixos-raspberrypi.nixosModules; [
          # Nix cache with prebuilt packages,
          # see `devshells/nix-build-to-cachix.nix` for a list
          trusted-nix-caches

          # All RPi and RPi-optimised packages to be available in `pkgs.rpi`
          nixpkgs-rpi
          # Add necessary overlays with kernel, firmware, vendor packages
          nixos-raspberrypi.lib.inject-overlays
          # Optonally add overlays with optimised packages into the global scope
          nixos-raspberrypi.lib.inject-overlays-global
        ];

        system.nixos.tags = let
          cfg = config.boot.loader.raspberryPi;
        in[
          "raspberry-pi-${cfg.variant}"
          cfg.bootloader
          config.boot.kernelPackages.kernel.version
        ];
      };

      common-user-config = {config, ... }: {
        time.timeZone = "UTC";
        networking.hostName = "rpi${config.boot.loader.raspberryPi.variant}-demo";

        services.udev.extraRules = ''
          # Ignore partitions with "Required Partition" GPT partition attribute
          # On our RPi's this is firmware (/boot/firmware) partition
          ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
            ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
            ENV{UDISKS_IGNORE}="1"
        '';
      };
    in {

      rpi02 = mkNixOSRPi [
        ({ config, pkgs, lib, nixos-raspberrypi, ... }: {
          imports = with nixos-raspberrypi.nixosModules; [
            # Hardware configuration
            raspberry-pi-02.base
            usb-gadget-ethernet
            # SD-Card image
            sd-image-uboot
            # config.txt example
            ./pi02-configtxt.nix

            ./modules/nice-looking-console.nix
          ];
        })
        common-user-config
        ({ pkgs, ... }: {
          environment.systemPackages = with pkgs; [
            tree
            raspberrypi-eeprom
            i2c-tools
            cowsay
            neofetch
          ];
        })
      ];

      rpi4 = mkNixOSRPi [
        ({ config, pkgs, lib, nixos-raspberrypi, disko, ... }: {
          imports = with nixos-raspberrypi.nixosModules; [
            # Hardware configuration
            raspberry-pi-4.base
            raspberry-pi-4.display-vc4
            raspberry-pi-4.bluetooth

            # SD-Card image
            # sd-image-uboot
            disko.nixosModules.disko
            ./disko-usb-btrfs.nix

            ./modules/nice-looking-console.nix
          ];
        })
        common-user-config
        {
          boot.tmp.useTmpfs = true;
        }
      ];

      rpi5 = mkNixOSRPi [
        ({ config, pkgs, lib, nixos-raspberrypi, disko, ... }: {
          imports = with nixos-raspberrypi.nixosModules; [
            # Hardware configuration
            raspberry-pi-5.base
            raspberry-pi-5.display-vc4
            raspberry-pi-5.bluetooth

            # SD-Card image
            # sd-image-kernelboot
            disko.nixosModules.disko
            ./disko-nvme-zfs.nix
            { networking.hostId = "8821e309"; } # for zfs

            ./modules/nice-looking-console.nix
          ];
        })
        common-user-config
        {
          boot.tmp.useTmpfs = true;
        }
      ];

    };

  };
}