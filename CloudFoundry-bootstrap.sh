#!/bin/sh
#
# from https://bosh.io/docs/init-azure.html
# date:  11-JAN 2016 

# ensure ARM mode
#
azure config mode arm

# may require MFA, start with http://aka.ms/devicelogin
#
azure login

# capture output for values
#
# "id"			SUBSCRIPTION-ID
# "tenandId"		TENANT-ID
# 
azure account list --json

SUBSCRIPTIONID="**REPLACE**"
TENANTID="**REPLACE**"

# for multiple subscriptions, select the appropriate
#
azure account set $SUBSCRIPTIONID

# change all of this from default value
#
BOSHCPINAME="POC BOSH CPI v01132015"        # consider renaming
IDURIS="http://POCBOSHAzureCPIv01132015"
HOMEPAGE="http://POCBOSHAzureCPIv01132015"

# client-secret		CLIENT-SECRET
#
CLIENTSECRET=""                                 # **REPLACE**

azure ad app create --name "$BOSHCPINAME" --password "$CLIENTSECRET" --identifier-uris ""$IDURIS"" --home-page ""$HOMEPAGE""

# "application Id"	 CLIENT-ID
#
CLIENTID="**REPLACE**"

# create Service Principle
#

SPNAME="http://POCBOSHAzureCPIv01132015"        # **REPLACE**

azure ad sp create $CLIENTID

azure role assignment create --roleName "Contributor"  --spn "$SPNAME" --subscription $SUBSCRIPTIONID

# if Resource Group has not already been created
#

RESOURCEGROUPNAME=""                            # **REPLACE**
RESOURCEGROUPLOC="" 

azure group create --name "$RESOURCEGROUPNAME" --location "$RESOURCEGROUPLOC"

azure group show --name "$RESOURCEGROUPNAME"

# create some networks
#

VNETNAME="POCBOSHnet"                       # **REPLACE**
VNETBLOCK="10.0.0.0/24"                     # **REPLACE**
SUBNETNAME="POCBOSHsubnet"                  # **REPLACE**
SUBNETBLOCK="10.0.0.0/27"                   # **REPLACE**

azure network vnet create --name "$VNETNAME" --address-prefixes "$VNETBLOCK" --resource-group "$RESOURCEGROUPNAME" --location "$RESOURCEGROUPLOC"

azure network vnet subnet create --name "$SUBNETNAME" --vnet-name "$VNETWORK" --address-prefix $SUBNETBLOCK --resource-group "$RESOURCEGROUPNAME"

azure network vnet show --name "$VNETNAME" --resource-group $RESOURCEGROUPNAME

# create some storage
#

STORAGEACCOUNTNAME="pocboshstore"           # name must all be lowercase only
STORAGEACCOUNTTYPE="LRS"                    # the account type(LRS/ZRS/GRS/RAGRS/PLRS)

azure storage account create "$STORAGEACCOUNTNAME" --type "$STORAGEACCOUNTTYPE" --resource-group "$RESOURCEGROUPNAME" --location "$RESOURCEGROUPLOC"

azure storage account show "$STORAGEACCOUNTNAME" --resource-group "$RESOURCEGROUPNAME"

azure storage account keys list "$STORAGEACCOUNTNAME" --resource-group "$RESOURCEGROUPNAME"

STORAGEACCESSKEY="**REPLACE**"                         #

# now go create the two(2) containers needed:  bosh, stemcell
#

CONTAINERBOSH="bosh"
CONTAINERSTEMCELL="stemcell"

azure storage container create --container "$CONTAINERBOSH" --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY

azure storage container create --container "$CONTAINERSTEMCELL" --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY --permission Blob

azure storage container list --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY

CONTAINERTABLE="stemcells"

azure storage table create --table $CONTAINERTABLE --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY

azure storage table list --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY

# tku
# public IPs for VM access, steps omitted for POC
#
