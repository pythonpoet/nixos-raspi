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
      # the fork is needed for partition attributes support
      url = "github:nvmd/disko/gpt-attrs";
      # url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
    };
  };

  outputs = { self, nixpkgs
            , nixos-raspberrypi, disko
            , nixos-anywhere, ... }@inputs: let
    allSystems = nixpkgs.lib.systems.flakeExposed;
    forSystems = systems: f: nixpkgs.lib.genAttrs systems (system: f system);       
  in {

    devShells = forSystems allSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          nil # lsp language server for nix
          nixpkgs-fmt
          nix-output-monitor
          nixos-anywhere.packages.${system}.default
        ];
      };
    });

    nixosConfigurations = let
      common-user-config = {config, ... }: {
        imports = [ ./modules/nice-looking-console.nix ];

        time.timeZone = "UTC";
        networking.hostName = "rpi${config.boot.loader.raspberryPi.variant}-demo";

        services.udev.extraRules = ''
          # Ignore partitions with "Required Partition" GPT partition attribute
          # On our RPis this is firmware (/boot/firmware) partition
          ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
            ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
            ENV{UDISKS_IGNORE}="1"
        '';

        system.nixos.tags = let
          cfg = config.boot.loader.raspberryPi;
        in [
          "raspberry-pi-${cfg.variant}"
          cfg.bootloader
          config.boot.kernelPackages.kernel.version
        ];
      };
    in {

      rpi02 = nixos-raspberrypi.lib.nixosSystemFull {
        specialArgs = inputs;
        modules = [
          ({ config, pkgs, lib, nixos-raspberrypi, ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              # Hardware configuration
              raspberry-pi-02.base
              usb-gadget-ethernet
              # config.txt example
              ./pi02-configtxt.nix
            ];
          })
          # Disk configuration
          # Assumes the system will continue to reside on the installation media (sd-card),
          # as there're hardly other feasible options on RPi02.
          # (see also https://github.com/nvmd/nixos-raspberrypi/issues/8#issuecomment-2804912881)
          # `sd-image` has lots of dependencies unnecessary for the installed system,
          # replicating its disk layout
          ({ config, pkgs, ... }: {
            fileSystems = {
              "/boot/firmware" = {
                device = "/dev/disk/by-label/FIRMWARE";
                fsType = "vfat";
                options = [
                  "noatime"
                  "noauto"
                  "x-systemd.automount"
                  "x-systemd.idle-timeout=1min"
                ];
              };
              "/" = {
                device = "/dev/disk/by-label/NIXOS_SD";
                fsType = "ext4";
                options = [ "noatime" ];
              };
            };
          })
          # Further user configuration
          common-user-config
          ({ config, pkgs, ... }: {
            environment.systemPackages = with pkgs; [
              tree
              i2c-tools
            ];
          })
        ];
      };

      rpi4 = nixos-raspberrypi.lib.nixosSystem {
        specialArgs = inputs;
        modules = [
          ({ config, pkgs, lib, nixos-raspberrypi, disko, ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              # Hardware configuration
              raspberry-pi-4.base
              raspberry-pi-4.display-vc4
              raspberry-pi-4.bluetooth
            ];
          })
          # Disk configuration
          disko.nixosModules.disko
          ./disko-usb-btrfs.nix
          # Further user configuration
          common-user-config
          {
            boot.tmp.useTmpfs = true;
          }
        ];
      };

      rpi5 = nixos-raspberrypi.lib.nixosSystemFull {
        specialArgs = inputs;
        modules = [
          ({ config, pkgs, lib, nixos-raspberrypi, disko, ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              # Hardware configuration
              raspberry-pi-5.base
              raspberry-pi-5.display-vc4
            ];
          })
          # Disk configuration
          disko.nixosModules.disko
          ./disko-nvme-zfs.nix
          { networking.hostId = "8821e309"; } # for zfs
          # Further user configuration
          common-user-config
          {
            boot.tmp.useTmpfs = true;
          }
        ];
      };

    };

  };
}