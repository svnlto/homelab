{ pkgs, ... }: {
  # Corosync QDevice Network Daemon (corosync-qnetd)
  #
  # Provides a third-party vote for the 2-node Proxmox cluster (din + grogu).
  # With only 2 corosync voters, losing one node = 50% = no quorum = both fence.
  # The QDevice gives 3 votes total (quorum = 2), so one node can survive.
  #
  # Post-deploy certificate exchange (manual, one-time):
  #   1. On this Pi:     sudo corosync-qnetd-certutil -i
  #   2. Copy CA cert:   scp /var/lib/corosync-qnetd/nssdb/qnetd-cacert.crt to both Proxmox nodes
  #   3. On Proxmox:     pvecm qdevice setup 192.168.0.54
  #   4. Verify:         pvecm status (should show 3 votes, quorum = 2)

  users.users.coroqnetd = {
    isSystemUser = true;
    group = "coroqnetd";
    home = "/var/lib/corosync-qnetd";
  };

  users.groups.coroqnetd = { };

  systemd.services.corosync-qnetd = {
    description = "Corosync QDevice Network Daemon";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.corosync-qdevice}/bin/corosync-qnetd -f";
      User = "coroqnetd";
      Group = "coroqnetd";
      StateDirectory = "corosync-qnetd";
      RuntimeDirectory = "corosync-qnetd";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  environment.systemPackages = [
    pkgs.corosync-qdevice # corosync-qnetd-certutil
    pkgs.nssTools # certutil (NSS database utilities)
  ];
}
