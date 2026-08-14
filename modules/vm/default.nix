{ config, lib, pkgs, ... }:

with lib;

{
  # Ajustes para convidado QEMU/KVM.
  options.lcars.vm.enable = mkEnableOption "Ajustes para convidado QEMU/KVM.";

  config = mkIf config.lcars.vm.enable {

    # Estes são NOMES DE MÓDULOS DO KERNEL (strings), não pacotes nixpkgs.
    # O `with pkgs;` que estava aqui fazia a avaliação falhar.
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
