LXD-Terraform
==============================================================================================
## Orchestration of a 2 Controller 3 Nodes Kubernetes Cluster 
### For High Availability and a Reverse Proxy

This repository contains the code for orchestrating a Kubernetes cluster with two controllers and three nodes, all running on LXD containers. It also sets up a reverse proxy using Nginx to expose the Kubernetes API server to the outside world.

Getting Started
---------------

To get started, first install LXD by running:

.. code-block:: bash

    sudo snap install lxd

Then, create and initialize the LXD instance with:

.. code-block:: bash

    sudo lxd init

Next, install Terraform by running:

.. code-block:: bash

    sudo snap install terraform

You'll also need to add the Terraform LXD provider plugin by running:

.. code-block:: bash

    terraform init -plugin-dir=$HOME/.terraform.d/plugins/

In the main.tf file, you'll need to add the LXD provider configuration:

.. code-block:: terraform

    provider "lxd" {
      # Configuration options
    }

Before you start Terraform, generate a key for your SSH connection that will be used by Terraform:

.. code-block:: bash

    ssh-keygen -t rsa -b 4096 -C <your_email>

This will save the `id_rsa` and `id_rsa.pub` files to `~/.ssh/`. Make sure to replace `<your_email>` with your email address.

Note that there are two types of images available for LXD containers: `cloud-init` and standard Ubuntu images. The cloud-init images are more lightweight and provide a faster startup, but require cloud-init to be installed and configured. For this reason, this repository uses standard Ubuntu images.

Running Terraform
-----------------

Once you've set up LXD and Terraform, you can run Terraform by executing:

.. code-block:: bash

    terraform apply

This will create the LXD containers and set up the Kubernetes cluster. You'll be prompted to confirm that you want to apply the changes, so enter `yes` when prompted.

Note that this repository is a work in progress and may be unstable at this time. Contributions are welcome.

License
-------

This code is licensed under the MIT license. See LICENSE file for details.
