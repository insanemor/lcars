{ config, lib, pkgs, ... }:

with lib;

{
  options.lcars.hardware.vm.enable = mkEnableOption "Ajustes para convidado QEMU/KVM.";

  config = mkIf config.lcars.hardware.vm.enable {

    # Estes são NOMES DE MÓDULOS DO KERNEL (strings), não pacotes nixpkgs.
    boot.initrd.availableKernelModules = [
      "virtio_balloon"
      "virtio_blk"
      "virtio_net"
      "virtio_pci"
      "virtio_scsi"
      "virtio_input"
      "virtio_gpu"
    ];
    boot.initrd.kernelModules = [ "virtio_balloon" "virtio_console" ];

    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;

    environment.systemPackages = with pkgs; [
      spice-vdagent
    ];
  };
}
