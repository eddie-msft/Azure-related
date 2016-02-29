#!/bin/sh
#
# this script is 'opinionated' and makes the following assumption
#
#   1.  everything will be created against the selected ("Default") Azure subscription
#   2.  current User has sufficient privileges to create AAD application and service principal
#   3.  location is lotterized against US only { centralus, eastus, eastus2, northcentralus, southcentralus, westus }
#   4.  creating a new Resource Group, instead of re-using an existing RG
#   5.  Vnet and subnets are based off of ARM template ranges of 10.2.0.0/16, 10.2.0.0/24, and 10.2.16.0/20
#

# ensure ARM mode
#
azure config mode arm

# start with http://aka.ms/devicelogin
# will spin here until login completes
# azure login

# capture output for values
#
# "id"			SUBSCRIPTION-ID
# "tenandId"		TENANT-ID
# 
#azure account list --json

NAME=`azure account list | grep Enabled | grep true | awk -F '[[:space:]][[:space:]]+' '{ print $2 }'`
SUBSCRIPTIONID=`azure account list | grep Enabled | grep true | awk -F '[[:space:]][[:space:]]+' '{ print $3 }'`

TENANTID=`azure account list --json | grep -A6 ${SUBSCRIPTIONID} | tail -1 | awk -F':' '{ print $2 }' | tr -d ',' | tr -d '"' ` 

# for multiple subscriptions, select the appropriate
#
azure account set $SUBSCRIPTIONID

# change all of this from default value
#


# create unique SP using mmdd
#

#SPVER=`date +"%m%d"`
SPVER=`date +"%m%d%S"`

PCFBOSHNAME="PCFBOSHv${SPVER}"
IDURIS="http://PCFBOSHv${SPVER}"
HOMEPAGE="http://PCFBOSHv${SPVER}"

# client-secret		CLIENT-SECRET
#
CLIENTSECRET=`openssl rand -base64 16 | tr -dc _A-z-a-z-0-9`

# "application Id"	 CLIENT-ID
#

CLIENTID=`azure ad app create --name "$PCFBOSHNAME" --password "$CLIENTSECRET" --identifier-uris ""$IDURIS"" --home-page ""$HOMEPAGE"" | grep  "AppId:" | awk -F':' '{ print $3 } ' | tr -d ' '`


# create Service Principle
#

SPNAME="http://PCFBOSHv${SPVER}"

sleep 2

azure ad sp create $CLIENTID

sleep 4

azure role assignment create --roleName "Contributor"  --spn "$SPNAME" --subscription $SUBSCRIPTIONID

# create Resource Group
#

RGVER=`date +"%m%d"`

RESOURCEGROUPNAME=`openssl rand -base64 8 | tr -dc _A-z-a-z-0-9 | tr [:lower:] [:upper:]`
RESOURCEGROUPNAME="PCF-${RGVER}${RESOURCEGROUPNAME}"

LOCATION=( none centralus eastus eastus2 northcentralus southcentralus westus )
INDEX=$(( ( RANDOM % 6 ) + 1 ))

RESOURCEGROUPLOC=${LOCATION[$INDEX]}

azure group create --name "$RESOURCEGROUPNAME" --location "$RESOURCEGROUPLOC"

# create vnet and subnets
#

PCFVNETNAME="PCF-vnet-bosh-10-2-0-0-16"
PCFVNETBLOCK="10.2.0.0/16"
SUBNETBOSHNAME="PCF-subnet-bosh-10-2-0-0-24"
SUBNETBOSHBLOCK="10.2.0.0/24"
SUBNETCFNAME="PCF-subnet-cf-10-2-16-0-20"
SUBNETCFBLOCK="10.2.16.0/20"

azure network vnet create --name "$PCFVNETNAME" --address-prefixes "$PCFVNETBLOCK" --resource-group "$RESOURCEGROUPNAME" --location "$RESOURCEGROUPLOC"

azure network vnet subnet create --name "$SUBNETBOSHNAME" --vnet-name "$PCFVNETNAME" --address-prefix $SUBNETBOSHBLOCK --resource-group "$RESOURCEGROUPNAME"

azure network vnet subnet create --name "$SUBNETCFNAME" --vnet-name "$PCFVNETNAME" --address-prefix $SUBNETCFBLOCK --resource-group "$RESOURCEGROUPNAME"

# create storage
#

STORVER=`date +"%m%d%S"`
STORAGEACCOUNTNAME="pcfblob${STORVER}"
STORAGEACCOUNTTYPE="RAGRS"

azure storage account create "$STORAGEACCOUNTNAME" --type "$STORAGEACCOUNTTYPE" --resource-group "$RESOURCEGROUPNAME" --location "$RESOURCEGROUPLOC"

azure storage account show "$STORAGEACCOUNTNAME" --resource-group "$RESOURCEGROUPNAME"

STORAGEACCESSKEY=`azure storage account keys list $STORAGEACCOUNTNAME -g $RESOURCEGROUPNAME | grep Primary | awk -F':' '{ print $3 }' | tr -d ' '`

# create bosh storage containers and table
#

CONTAINERBOSH="bosh"
CONTAINERSTEMCELL="stemcell"

azure storage container create --container "$CONTAINERBOSH" --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY

azure storage container create --container "$CONTAINERSTEMCELL" --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY --permission Blob

azure storage container list --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY

CONTAINERTABLE="stemcells"

azure storage table create --table $CONTAINERTABLE --account-name $STORAGEACCOUNTNAME --account-key $STORAGEACCESSKEY

echo "{"
echo "  \"\$schema\": \"http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#\","
echo "  \"contentVersion\": \"1.0.0.0\","
echo "  \"parameters\": {"
echo "     \"SUBSCRIPTION_ID\": {"
echo "       \"value\": \"$SUBSCRIPTIONID\""
echo "    },"
echo "     \"tenantID\": {"
echo "       \"value\": \"$TENANTID\""
echo "    },"
echo "     \"clientID\": {"
echo "       \"value\": \"$CLIENTID\""
echo "    },"
echo "     \"RESOURCE_GROUP_NAME\": {"
echo "       \"value\": \"$RESOURCEGROUPNAME\""
echo "    }"
echo "  }"
echo "}"
