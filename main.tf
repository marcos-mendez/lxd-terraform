terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "1.9.1"
    }
  }
}

provider "lxd" {
  # Configuration options
}

# Create two controller nodes
resource "lxd_container" "controller1" {
  name  = "k8s-ctrl-1"
  image = "ubuntu/focal"
}

resource "lxd_container" "controller2" {
  name  = "k8s-ctrl-2"
  image = "ubuntu/focal"
}

# Create three worker nodes
resource "lxd_container" "worker1" {
  name  = "k8s-node1"
  image = "ubuntu/focal"
}

resource "lxd_container" "worker2" {
  name  = "k8s-node2"
  image = "ubuntu/focal"
}

resource "lxd_container" "worker3" {
  name  = "k8s-node3"
  image = "ubuntu/focal"
}

locals {
  private_key_content = file(pathexpand("~/.ssh/id_rsa"))
}

# Install Kubernetes on the controller nodes
resource "null_resource" "install_kubernetes" {
  # Trigger the installation when the controller nodes are ready
  depends_on = [
    lxd_container.controller1,
    lxd_container.controller2,
  ]

  # Run the installation script inside the controller nodes
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = lxd_container.controller1.ip_address
      user        = "ubuntu"
      private_key = local.private_key_content
    }

    inline = [
      "sudo snap install microk8s --classic",
      "sudo usermod -a -G microk8s ubuntu",
      "sudo chown -f -R ubuntu ~/.kube",
      "echo 'alias kubectl=\"microk8s kubectl\"' >> ~/.bashrc",
      "source ~/.bashrc",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = lxd_container.controller2.ip_address
      user        = "ubuntu"
      private_key = local.private_key_content
    }

    inline = [
      "sudo snap install microk8s --classic",
      "sudo usermod -a -G microk8s ubuntu",
      "sudo chown -f -R ubuntu ~/.kube",
      "echo 'alias kubectl=\"microk8s kubectl\"' >> ~/.bashrc",
      "source ~/.bashrc",
    ]
  }
}

# Generate the reverse proxy using Nginx
resource "null_resource" "generate_reverse_proxy" {
  # Trigger the generation when the controller nodes are ready
  depends_on = [
    null_resource.install_kubernetes,
  ]

  # Run the Nginx configuration script inside the controller nodes
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = lxd_container.controller1.ip_address
      user        = "ubuntu"
      private_key = local.private_key_content
    }

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "cat << EOF | sudo tee /etc/nginx/sites-available/k8s",
      "server {",
      "  listen 80;",
      "  listen [::]:80;",
      "  server_name k8s;",
      "",
      "  location / {",
      "    proxy_pass http://localhost:8001;",
      "    proxy_set_header Host $host;",
      "    proxy_set_header X-Real-IP $remote_addr;",
      "    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
      "    proxy_set_header X-Forwarded-Proto $scheme;",
      "  }",
      "}",
      "EOF",
      "sudo ln -sf /etc/nginx/sites-available/k8s /etc/nginx/sites-enabled/k8s",
      "sudo nginx -t",
      "sudo systemctl reload nginx",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = lxd_container.controller2.ip_address
      user        = "ubuntu"
      private_key = local.private_key_content
    }

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "cat << EOF | sudo tee /etc/nginx/sites-available/k8s",
      "server {",
      "  listen 80;",
      "  listen [::]:80;",
      "  server_name k8s;",
      "",
      "  location / {",
      "    proxy_pass http://localhost:8001;",
      "    proxy_set_header Host $host;",
      "    proxy_set_header X-Real-IP $remote_addr;",
      "    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
      "    proxy_set_header X-Forwarded-Proto $scheme;",
      "  }",
      "}",
      "EOF",
      "sudo ln -sf /etc/nginx/sites-available/k8s /etc/nginx/sites-enabled/k8s",
      "sudo nginx -t",
      "sudo systemctl reload nginx",
    ]
  }
}

# Obtain the Kubernetes join token
resource "null_resource" "get_join_token" {
  depends_on = [
    null_resource.install_kubernetes,
  ]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = lxd_container.controller1.ip_address
      user        = "ubuntu"
      private_key = local.private_key_content
    }

    inline = [
      "microk8s add-node | grep 'microk8s join' | awk '{ print $3 }' > /tmp/join_token.txt",
    ]
  }

  provisioner "local-exec" {
    command = "scp -i ${pathexpand("~/.ssh/id_rsa")} -o StrictHostKeyChecking=no ubuntu@${lxd_container.controller1.ip_address}:/tmp/join_token.txt join_token.txt"
  }
}

# Join the worker nodes to the cluster
resource "null_resource" "join_workers" {
  depends_on = [
    null_resource.get_join_token,
    lxd_container.worker1,
    lxd_container.worker2,
    lxd_container.worker3,
  ]

  count = 3
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = count.index == 0 ? lxd_container.worker1.ip_address : (count.index == 1 ? lxd_container.worker2.ip_address : lxd_container.worker3.ip_address)
      user        = "ubuntu"
      private_key = local.private_key_content
    }

    scripts = ["join_workers.sh", "${lxd_container.controller1.ip_address}"]
  }
}
