
##############################################################################
# VPC
##############################################################################
/*
module "vpc" {
  # Limitation of Version 1.1.1
  # https://github.com/terraform-ibm-modules/terraform-ibm-vpc/releases
  # if you want to create custom address prefixes and add subnets to it.. 
  # for now you need to two separate modules (vpc, subnet modules). 
  # In the next release we are targeting this feature… so that only vpc module 
  # would suffice to create custom address prefixes and subnets to it
  version                     = "1.1.1"
  source                      = "terraform-ibm-modules/vpc/ibm//modules/vpc"
  create_vpc                  = var.create_vpc
  vpc_name                    = "${var.prefix}-vpc"
  resource_group_id           = ibm_resource_group.resource_group.id
  classic_access              = var.vpc_classic_access
  default_address_prefix      = var.default_address_prefix
  default_network_acl_name    = var.default_network_acl_name
  default_security_group_name = var.default_security_group_name
  default_routing_table_name  = var.default_routing_table_name
  vpc_tags                    = var.tags
  # address_prefixes            = var.address_prefixes
  locations           = var.locations
  subnet_name         = "${var.prefix}-sn"
  number_of_addresses = var.number_of_addresses
  vpc                 = var.vpc
  # Public Gateway required to access the OpenShift Console
  create_gateway      = var.create_gateway
  public_gateway_name = var.public_gateway_name
  floating_ip         = var.floating_ip
  gateway_tags        = var.tags
}
*/


##############################################################################
# Create a VPC
##############################################################################

resource "ibm_is_vpc" "vpc" {
  name                      = "${var.prefix}-vpc"
  resource_group            = ibm_resource_group.resource_group.id
  address_prefix_management = var.vpc_address_prefix_management
  classic_access            = var.vpc_classic_access
  tags                      = var.tags
}


##############################################################################
# Prefixes and subnets for zone 1
##############################################################################

resource "ibm_is_vpc_address_prefix" "subnet_prefix" {

  count = 3
  name  = "${var.prefix}-prefix-zone-${count.index + 1}"
  zone  = "${var.region}-${(count.index % 3) + 1}"
  vpc   = ibm_is_vpc.vpc.id
  cidr  = element(var.vpc_cidr_blocks, count.index)
}


##############################################################################
# Public Gateways
##############################################################################

resource "ibm_is_public_gateway" "pgw" {

  count = var.vpc_enable_public_gateway ? 3 : 0
  name  = "${var.prefix}-pgw-${count.index + 1}"
  vpc   = ibm_is_vpc.vpc.id
  zone  = "${var.region}-${count.index + 1}"

}

##############################################################################
# Create Network ACLs
##############################################################################
resource "ibm_is_network_acl" "multizone_acl" {

  name = "${var.prefix}-multizone-acl"
  vpc  = ibm_is_vpc.vpc.id

  dynamic "rules" {

    for_each = var.vpc_acl_rules

    content {
      name        = rules.value.name
      action      = rules.value.action
      source      = rules.value.source
      destination = rules.value.destination
      direction   = rules.value.direction
    }
  }
}

##############################################################################
# Create Subnets
##############################################################################

resource "ibm_is_subnet" "subnet" {

  count           = 3
  name            = "${var.prefix}-subnet-${count.index + 1}"
  vpc             = ibm_is_vpc.vpc.id
  zone            = "${var.region}-${count.index + 1}"
  ipv4_cidr_block = element(ibm_is_vpc_address_prefix.subnet_prefix.*.cidr, count.index)
  network_acl     = ibm_is_network_acl.multizone_acl.id
  public_gateway  = var.vpc_enable_public_gateway ? element(ibm_is_public_gateway.pgw.*.id, count.index) : null
}