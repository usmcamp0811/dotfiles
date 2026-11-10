# Terranix definition of one throwaway aarch64 Nix builder on EC2: a key pair, a security group that
# admits SSH from one CIDR, and an instance from the official NixOS AMI. Every value that changes per
# run is a variable, so this file is evaluated once into a static JSON configuration and `ec2-build`
# passes the values at run time (vars.tfvars.json in the run directory).
{...}: let
  var = name: "\${var.${name}}";
  tags = {
    Name = "ec2-build-${var "run_id"}";
    ManagedBy = "ec2-build";
    RunId = var "run_id";
  };
in {
  terraform.required_providers.aws.source = "hashicorp/aws";

  variable = {
    region.type = "string";
    run_id.type = "string";
    ssh_public_key.type = "string";
    ssh_cidr.type = "string";
    instance_type.type = "string";
    volume_gb.type = "number";
    max_minutes.type = "number";
    # An explicit AMI id wins; otherwise the newest official NixOS arm64 AMI matching ami_name.
    ami_id = {
      type = "string";
      default = "";
    };
    ami_name = {
      type = "string";
      default = "nixos/26.05*";
    };
    # Both null: the region's default VPC and one of its default subnets.
    vpc_id = {
      type = "string";
      default = null;
    };
    subnet_id = {
      type = "string";
      default = null;
    };
  };

  provider.aws = {
    region = var "region";
    default_tags.tags = tags;
  };

  # Official NixOS AMIs (https://nixos.org/download/#nixos-amazon).
  data.aws_ami.nixos = {
    count = "\${var.ami_id == \"\" ? 1 : 0}";
    owners = ["427812963091"];
    most_recent = true;
    filter = [
      {
        name = "name";
        values = [(var "ami_name")];
      }
      {
        name = "architecture";
        values = ["arm64"];
      }
    ];
  };

  resource.aws_key_pair.builder = {
    key_name = "ec2-build-${var "run_id"}";
    public_key = var "ssh_public_key";
  };

  resource.aws_security_group.builder = {
    name = "ec2-build-${var "run_id"}";
    description = "ec2-build: SSH from the machine running the build";
    vpc_id = var "vpc_id";
    ingress = [
      {
        description = "SSH";
        from_port = 22;
        to_port = 22;
        protocol = "tcp";
        cidr_blocks = [(var "ssh_cidr")];
        ipv6_cidr_blocks = [];
        prefix_list_ids = [];
        security_groups = [];
        self = false;
      }
    ];
    egress = [
      {
        description = "Everything (caches, git fetches)";
        from_port = 0;
        to_port = 0;
        protocol = "-1";
        cidr_blocks = ["0.0.0.0/0"];
        ipv6_cidr_blocks = ["::/0"];
        prefix_list_ids = [];
        security_groups = [];
        self = false;
      }
    ];
  };

  resource.aws_instance.builder = {
    ami = "\${var.ami_id != \"\" ? var.ami_id : data.aws_ami.nixos[0].id}";
    instance_type = var "instance_type";
    key_name = "\${aws_key_pair.builder.key_name}";
    vpc_security_group_ids = ["\${aws_security_group.builder.id}"];
    subnet_id = var "subnet_id";
    associate_public_ip_address = true;

    # Backstop if ec2-build dies without destroying (kill -9, laptop closed): the user data below
    # schedules a shutdown, and a shutdown from inside the instance terminates it. The key pair and
    # security group are free and stay until `ec2-build --cleanup`.
    instance_initiated_shutdown_behavior = "terminate";
    # NixOS's amazon-init runs user data that starts with "#!" as a shell script, with systemd on PATH.
    user_data = ''
      #!/bin/sh
      shutdown -h +${var "max_minutes"} "ec2-build: maximum lifetime reached"
    '';

    root_block_device = {
      volume_size = var "volume_gb";
      volume_type = "gp3";
      delete_on_termination = true;
    };
  };

  output = {
    public_ip.value = "\${aws_instance.builder.public_ip}";
    instance_id.value = "\${aws_instance.builder.id}";
    ami_id.value = "\${aws_instance.builder.ami}";
  };
}
