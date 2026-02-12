{ pkgs, ... }: {
  # Corosync QDevice Network Daemon (corosync-qnetd)
  #
  # Provides a third-party vote for the 2-node Proxmox cluster (din + grogu).
  # With only 2 corosync voters, losing one node = 50% = no quorum = both fence.
  # The QDevice gives 3 votes total (quorum = 2), so one node can survive.
  #
  # Post-deploy setup (one-time, from any Proxmox node):
  #   pvecm qdevice setup 192.168.0.54
  #   pvecm status  # should show 3 votes, quorum = 2

  users.users.coroqnetd = {
    isSystemUser = true;
    group = "coroqnetd";
    home = "/var/lib/corosync-qnetd";
  };

  users.groups.coroqnetd = { };

  # Ensure the nssdb directory exists with correct ownership.
  # corosync-qnetd-certutil creates it at /etc/corosync/qnetd/nssdb/
  # but the service runs as coroqnetd, so it needs read access.
  systemd.tmpfiles.rules = [
    "d /etc/corosync/qnetd 0750 coroqnetd coroqnetd -"
    "d /etc/corosync/qnetd/nssdb 0750 coroqnetd coroqnetd -"
  ];

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
