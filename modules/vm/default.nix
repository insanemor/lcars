{ config, lib, pkgs, ... }:

with lib;

{
  # Ajustes para convidado QEMU/KVM.
  options.lcars.vm.enable = mkEnableOption "Ajustes para convidado QEMU/KVM.";

  config = mkIf config.lcars.vm.enable {

    boot.initrd.availableKernelModules = with pkgs; [
      virtio_balloon
      virtio_blk
      virtio_net
      virtio_pci
      virtio_scsi
      virtio_input
      virtio_gpu
    ];
    boot.initrd.kernelModules = [ "virtio_balloon" "virtio_console" ];
    boot.kernelParams = [ "console=ttyS0,115200n8" ];

    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;
    services.spice-vdagentd.x11Support = true;

    environment.systemPackages = with pkgs; [
      spice-vdagent
      x86info
    ];
  };
}
