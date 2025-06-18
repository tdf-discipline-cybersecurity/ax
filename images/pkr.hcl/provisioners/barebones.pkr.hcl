  provisioner "file" {
    source      = "./configs"
    destination = "/tmp/configs"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "echo 'Waiting for cloud-init to finish, this can take a few minutes please be patient...'",
      "/usr/bin/cloud-init status --wait",

      "fallocate -l 2G /swap && chmod 600 /swap && mkswap /swap && swapon /swap",
      "echo '/swap none swap sw 0 0' | sudo tee -a /etc/fstab",

      "echo 'Running dist-uprade'",
      "sudo apt update -qq",
      "DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew dist-upgrade -qq",

      "echo 'Installing pkexec ufw fail2ban net-tools zsh jq build-essential python3-pip unzip git p7zip libpcap-dev rubygems ruby-dev grc'",
      "sudo apt install pkexec fail2ban ufw net-tools zsh zsh-syntax-highlighting zsh-autosuggestions jq build-essential python3-pip unzip git p7zip libpcap-dev rubygems ruby-dev grc -y -qq",

      "ufw allow 22",
      "ufw allow 2266",
      "ufw --force enable",

      "echo 'Creating OP user'",
      "useradd -G sudo -s /usr/bin/zsh -m op",
      "mkdir -p /home/op/.ssh /home/op/c2 /home/op/recon/ /home/op/lists /home/op/go /home/op/bin /home/op/.config/ /home/op/.cache /home/op/work/ /home/op/.config/amass",
      "rm -rf /etc/update-motd.d/*",
      "/bin/su -l op -c 'wget -q https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O - | sh'",
      "chown -R op:users /home/op",
      "touch /home/op/.sudo_as_admin_successful",
      "touch /home/op/.cache/motd.legal-displayed",
      "chown -R op:users /home/op",
      "echo 'op:${var.op_random_password}' | chpasswd",
      "echo 'ubuntu:${var.op_random_password}' | chpasswd",
      "echo 'root:${var.op_random_password}' | chpasswd",

      "echo 'Moving Config files'",
      "mv /tmp/configs/sudoers /etc/sudoers",
      "pkexec chown root:root /etc/sudoers /etc/sudoers.d -R",
      "mv /tmp/configs/bashrc /home/op/.bashrc",
      "mv /tmp/configs/zshrc /home/op/.zshrc",
      "mv /tmp/configs/sshd_config /etc/ssh/sshd_config",
      "mv /tmp/configs/00-header /etc/update-motd.d/00-header",
      "mv /tmp/configs/authorized_keys /home/op/.ssh/authorized_keys",
      "mv /tmp/configs/tmux-splash.sh /home/op/bin/tmux-splash.sh",
      "/bin/su -l op -c 'sudo chmod 600 /home/op/.ssh/authorized_keys'",
      "chown -R op:users /home/op",
      "sudo service sshd restart",
      "chmod +x /etc/update-motd.d/00-header",

      "echo 'Installing Golang ${var.golang_version}'",
      "wget -q https://golang.org/dl/go${var.golang_version}.linux-amd64.tar.gz && sudo tar -C /usr/local -xzf go${var.golang_version}.linux-amd64.tar.gz && rm go${var.golang_version}.linux-amd64.tar.gz",
      "export GOPATH=/home/op/go",

      "echo 'Installing Docker'",
      "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && rm get-docker.sh",
      "sudo usermod -aG docker op",

      "echo 'Installing Interlace'",
      "git clone https://github.com/codingo/Interlace.git /home/op/recon/interlace && cd /home/op/recon/interlace/ && python3 setup.py install",

      "echo 'Optimizing SSH Connections'",
      "/bin/su -l root -c 'echo \"ClientAliveInterval 60\" | sudo tee -a /etc/ssh/sshd_config'",
      "/bin/su -l root -c 'echo \"ClientAliveCountMax 60\" | sudo tee -a /etc/ssh/sshd_config'",
      "/bin/su -l root -c 'echo \"MaxSessions 100\" | sudo tee -a /etc/ssh/sshd_config'",
      "/bin/su -l root -c 'echo \"net.ipv4.netfilter.ip_conntrack_max = 1048576\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"net.nf_conntrack_max = 1048576\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"net.core.somaxconn = 1048576\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"net.ipv4.ip_local_port_range = 1024 65535\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"1024 65535\" | sudo tee -a /proc/sys/net/ipv4/ip_local_port_range'",
      "chmod 600 /home/op/.ssh/authorized_keys",

      "echo 'Installing nmap'",
      "sudo apt-get -qy --no-install-recommends install alien",
      "/bin/su -l op -c 'wget https://nmap.org/dist/nmap-7.97-1.x86_64.rpm -O /home/op/recon/nmap.rpm && cd /home/op/recon/ && sudo alien ./nmap.rpm && sudo dpkg --force-overwrite -i ./nmap*.deb'",
      "/bin/su -l root -c 'apt-get clean'",
      "echo \"CkNvbmdyYXR1bGF0aW9ucywgeW91ciBidWlsZCBpcyBhbG1vc3QgZG9uZSEKCiDilojilojilojilojilojilZcg4paI4paI4pWXICDilojilojilZcgICAg4paI4paI4paI4paI4paI4paI4pWXIOKWiOKWiOKVlyAgIOKWiOKWiOKVl+KWiOKWiOKVl+KWiOKWiOKVlyAgICAg4paI4paI4paI4paI4paI4paI4pWXCuKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVl+KVmuKWiOKWiOKVl+KWiOKWiOKVlOKVnSAgICDilojilojilZTilZDilZDilojilojilZfilojilojilZEgICDilojilojilZHilojilojilZHilojilojilZEgICAgIOKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVlwrilojilojilojilojilojilojilojilZEg4pWa4paI4paI4paI4pWU4pWdICAgICDilojilojilojilojilojilojilZTilZ3ilojilojilZEgICDilojilojilZHilojilojilZHilojilojilZEgICAgIOKWiOKWiOKVkSAg4paI4paI4pWRCuKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVkSDilojilojilZTilojilojilZcgICAgIOKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVl+KWiOKWiOKVkSAgIOKWiOKWiOKVkeKWiOKWiOKVkeKWiOKWiOKVkSAgICAg4paI4paI4pWRICDilojilojilZEK4paI4paI4pWRICDilojilojilZHilojilojilZTilZ0g4paI4paI4pWXICAgIOKWiOKWiOKWiOKWiOKWiOKWiOKVlOKVneKVmuKWiOKWiOKWiOKWiOKWiOKWiOKVlOKVneKWiOKWiOKVkeKWiOKWiOKWiOKWiOKWiOKWiOKWiOKVl+KWiOKWiOKWiOKWiOKWiOKWiOKVlOKVnQrilZrilZDilZ0gIOKVmuKVkOKVneKVmuKVkOKVnSAg4pWa4pWQ4pWdICAgIOKVmuKVkOKVkOKVkOKVkOKVkOKVnSAg4pWa4pWQ4pWQ4pWQ4pWQ4pWQ4pWdIOKVmuKVkOKVneKVmuKVkOKVkOKVkOKVkOKVkOKVkOKVneKVmuKVkOKVkOKVkOKVkOKVkOKVnQoKTWFpbnRhaW5lcjogMHh0YXZpYW4KCvCdk7LwnZO38J2TvPCdk7nwnZOy8J2Tu/Cdk67wnZOtIPCdk6vwnZSCIPCdk6rwnZSB8J2TsvCdk7jwnZO2OiDwnZO98J2TsfCdk64g8J2TrfCdlILwnZO38J2TqvCdk7bwnZOy8J2TrCDwnZOy8J2Tt/Cdk6/wnZO78J2TqvCdk7zwnZO98J2Tu/Cdk77wnZOs8J2TvfCdk77wnZO78J2TriDwnZOv8J2Tu/Cdk6rwnZO28J2TrvCdlIDwnZO48J2Tu/Cdk7Qg8J2Tr/Cdk7jwnZO7IPCdk67wnZO/8J2TrvCdk7vwnZSC8J2Tq/Cdk7jwnZOt8J2UgiEgLSBA8J2TufCdk7vwnZSCMPCdk6zwnZOsIEAw8J2UgfCdk73wnZOq8J2Tv/Cdk7LwnZOq8J2TtwoKUmVhZCB0aGVzZSB3aGlsZSB5b3UncmUgd2FpdGluZyB0byBnZXQgc3RhcnRlZCA6KQoKICAgIC0gTmV3IFdpa2k6IGh0dHBzOi8vYXgtZnJhbWV3b3JrLmdpdGJvb2suaW8vd2lraS8KICAgIC0gRXhpc3RpbmcgVXNlcnM6IGh0dHBzOi8vYXgtZnJhbWV3b3JrLmdpdGJvb2suaW8vd2lraS9vdmVydmlldy9leGlzdGluZy11c2VycwogICAgLSBCcmluZyBZb3VyIE93biBQcm92aXNpb25lcjogaHR0cHM6Ly9heC1mcmFtZXdvcmsuZ2l0Ym9vay5pby93aWtpL2Z1bmRhbWVudGFscy9icmluZy15b3VyLW93bi1wcm92aXNpb25lciAKICAgIC0gRmlsZXN5c3RlbSBVdGlsaXRpZXM6IGh0dHBzOi8vYXgtZnJhbWV3b3JrLmdpdGJvb2suaW8vd2lraS9mdW5kYW1lbnRhbHMvZmlsZXN5c3RlbS11dGlsaXRpZXMKICAgIC0gRmxlZXRzOiBodHRwczovL2F4LWZyYW1ld29yay5naXRib29rLmlvL3dpa2kvZnVuZGFtZW50YWxzL2ZsZWV0cwogICAgLSBTY2FuczogaHR0cHM6Ly9heC1mcmFtZXdvcmsuZ2l0Ym9vay5pby93aWtpL2Z1bmRhbWVudGFscy9zY2FuCg==\" | base64 -d",
      "chown root:root /etc/sudoers /etc/sudoers.d -R"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
