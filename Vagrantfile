# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
echo "Installing Docker..."
sudo apt-get update
sudo apt-get remove docker docker-engine docker.io
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
sudo apt-get update
sudo apt-get install -y docker-ce ntp
# Restart docker to make sure we get the latest version of the daemon if there is an upgrade
sudo service docker restart
# Make sure we can actually use docker as the vagrant user
sudo usermod -aG docker vagrant
sudo docker --version

# Packages required for nomad & consul
sudo apt-get install unzip curl vim -y

echo "Installing Nomad..."
NOMAD_VERSION=1.0.5
cd /tmp/
if ! curl --fail -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip 2>/dev/null; then
  echo "Failed to download Nomad $NOMAD_VERSION"
  exit 1
fi
if ! unzip -q nomad.zip; then
  echo "Failed to extract Nomad $NOMAD_VERSION"
  exit 1
fi
sudo install nomad /usr/bin/nomad
sudo mkdir -p /etc/nomad.d
sudo chmod a+w /etc/nomad.d

echo "Installing CNI plugins..."
CNI_VERSION=0.9.1
if ! curl --fail -sL -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz 2>/dev/null; then
  echo "Failed to download CNI plugins $CNI_VERSION"
  exit 1
fi
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

echo "Installing Consul..."
CONSUL_VERSION=1.9.5
if ! curl --fail -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip > consul.zip 2>/dev/null; then
  echo "Failed to download Consul $CONSUL_VERSION"
  exit 1
fi
if ! unzip -q /tmp/consul.zip; then
  echo "Failed to extract Consul $CONSUL_VERSION"
  exit 1
fi
sudo install consul /usr/bin/consul
(
cat <<-EOF
  [Unit]
  Description=consul agent
  Requires=network-online.target
  After=network-online.target

  [Service]
  Restart=on-failure
  ExecStart=/usr/bin/consul agent -dev -client=0.0.0.0
  ExecReload=/bin/kill -HUP $MAINPID

  [Install]
  WantedBy=multi-user.target
EOF
) | sudo tee /etc/systemd/system/consul.service
sudo systemctl enable consul.service
sudo systemctl start consul

for bin in cfssl cfssl-certinfo cfssljson
do
  echo "Installing $bin..."
  curl -sSL https://pkg.cfssl.org/R1.2/${bin}_linux-amd64 > /tmp/${bin}
  sudo install /tmp/${bin} /usr/local/bin/${bin}
done
nomad -autocomplete-install
sudo mkdir -p /opt/nomad/data/
sudo mkdir -p /etc/nomad/
(
cat <<-EOF
  data_dir  = "/opt/nomad/data/"
  bind_addr = "0.0.0.0"
  plugin "docker" {
    config {
      volumes {
        enabled = true
      }
    }
  }
EOF
  ) | sudo tee /etc/nomad/config.hcl
(
cat <<-EOF
  [Unit]
  Description=nomad dev agent
  Requires=network-online.target
  After=network-online.target

  [Service]
  Environment=PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  Restart=on-failure
  ExecStart=/usr/bin/nomad agent -dev-connect -config=/etc/nomad/config.hcl
  ExecReload=/bin/kill -HUP $MAINPID

  [Install]
  WantedBy=multi-user.target
EOF
) | sudo tee /etc/systemd/system/nomad.service
sudo systemctl enable nomad.service
sudo systemctl start nomad

echo "Setting up iptable to forward dns request to consul..."
sudo iptables -t nat -A PREROUTING -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600

echo "Pulling Docker images"

if [ -n "$DOCKERHUBID" ] && [ -n "$DOCKERHUBPASSWD" ]; then
  echo "Login to Docker Hub as $DOCKERHUBID"
  if ! sudo docker login --username "$DOCKERHUBID" --password "$DOCKERHUBPASSWD"; then
    echo 'Error login to Docker Hub'
    exit 2
  fi
fi

find /vagrant/jobs -maxdepth 1 -type f -name '*.hcl' | xargs grep -E 'image\s*=\s*' | awk '{print $NF}' | sed -e 's/"//g' | while read j; do
  echo "Pulling $j Docker image"
  if ! sudo docker pull $j >/dev/null; then
    echo "Exiting"
    exit 1
  fi
done
if [ $? -ne 0 ]; then
  exit 1
fi

if [ -n "$DOCKERHUBID" ] && [ -n "$DOCKERHUBPASSWD" ]; then
  echo "Logout from Docker Hub as $DOCKERHUBID"
  if ! sudo docker logout; then
    echo 'Error logging out from Docker Hub'
  fi
fi

echo "Installing Grafana stack..."

until nomad status
do
  echo "Waiting nomad to be ready...."
  sleep 3
done

# Handle all Nomad job files one at a time
# Use the naming of Nomad job files to determine scheduling order of services
find /vagrant/jobs -maxdepth 1 -type f -name '*.hcl' | sort | while read j; do
  # Job can be successfully planed (enough resources left)
  svc=$(basename $j | sed -e 's/\.nomad\.hcl//' -e 's/^[0-9][0-9]-//')
  if nomad plan $j | grep -Eq 'All tasks successfully allocated'; then
    echo "Scheduling $svc"
    nomad run $j
  else
    echo "Error can not schedule $svc"
  fi
done
SCRIPT

Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-18.04" # 18.04 LTS
  config.vm.hostname = "ubuntu-nomad"
  config.vm.provision "shell", inline: $script, env: {"DOCKERHUBID"=>ENV['DOCKERHUBID'], "DOCKERHUBPASSWD"=>ENV['DOCKERHUBPASSWD']}, privileged: false

  # Expose the nomad api and ui to the host
  config.vm.network "forwarded_port", guest: 4646, host: 4646
  # consul
  config.vm.network "forwarded_port", guest: 8500, host: 8500
  # grafana
  config.vm.network "forwarded_port", guest: 3000, host: 3000
  # prometheus
  config.vm.network "forwarded_port", guest: 9090, host: 9090
  # loki
  config.vm.network "forwarded_port", guest: 3100, host: 3100
  # promtail
  config.vm.network "forwarded_port", guest: 3200, host: 3200
  # tns app
  config.vm.network "forwarded_port", guest: 8001, host: 8001

  # Increase memory for Parallels Desktop
  config.vm.provider "parallels" do |p, o|
    p.memory = "2048"
  end

  # Increase memory for Virtualbox
  config.vm.provider "virtualbox" do |vb|
        vb.memory = "2048"
  end

  # Increase memory for VMware
  ["vmware_fusion", "vmware_workstation"].each do |p|
    config.vm.provider p do |v|
      v.vmx["memsize"] = "2048"
    end
  end

  # Set the timezone the same as the host so that metrics & logs ingested have the right timestamp.
  require 'time'
  offset = ((Time.zone_offset(Time.now.zone) / 60) / 60)
  timezone_suffix = offset >= 0 ? "-#{offset.to_s}" : "+#{offset.to_s}"
  timezone = 'Etc/GMT' + timezone_suffix
  config.vm.provision :shell, :inline => "sudo rm /etc/localtime && sudo ln -s /usr/share/zoneinfo/" + timezone + " /etc/localtime", run: "always"
end
