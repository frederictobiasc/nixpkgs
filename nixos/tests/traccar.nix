{
  pkgs,
  lib,
  ...
}:
{
  name = "traccar";
  meta = {
    maintainers = with lib.maintainers; [ frederictobiasc ];
  };
  interactive.nodes.machine = {
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 18082;
        guest.port = 8082;
      }
      {
        from = "host";
        host.port = 10022;
        guest.port = 22;
      }
    ];
    networking.firewall.allowedTCPPorts = [ 8082 ];
    security.pam.services.sshd.allowNullPassword = true;
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
      extraConfig = ''
        PermitEmptyPasswords yes
      '';
    };
    users.users.root.hashedPasswordFile = "${pkgs.writeText "hpr" ""}";
  };
  nodes.machine = {
    services.traccar = {
      enable = true;
      settings.mail.smtp.host = "$SMTP_HOST";
      environmentFile = pkgs.writeText "traccar.env" ''
        SMTP_HOST=smtp.example.com
      '';
    };
  };
  testScript = ''
    machine.wait_for_unit("traccar.service")

    # Check that environment variables were substituted
    t.assertIn("smtp.example.com", machine.succeed("cat /var/lib/traccar/config.xml"), "environment substitution failed")

    machine.wait_for_open_port(8082)

    # Check that we get the traccar login page
    t.assertIn("Traccar", machine.wait_until_succeeds("curl -sf http://localhost:8082/"), "Traccar frontend seems unreachable")

    # Register the first admin user
    register_data = """
    {
        "email": "admin@example.com",
        "name": "admin",
        "password": "admin123"
    }
    """

    t.assertIn(
      "\"administrator\":true",
      machine.succeed(
        "curl -s -X POST "
        "-H 'Content-Type: application/json' "
        f"-d '{register_data}' "
        "http://localhost:8082/api/users"
      ),
      "Unexpected registration response"
    )
  '';
}
